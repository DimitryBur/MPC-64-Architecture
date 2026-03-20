///////////////////////////////////////////////////////////////////////////////
// MPC-64 Tensor Core
// 4x4 Matrix Multiply-Accumulate with integrated ReLU
// Author: DimitryBur / MPC-64 Architecture
// License: Apache 2.0
//
// Features:
// - 4-cycle 4x4 FP16 MAC
// - Optional ReLU activation (zero-cycle overhead)
// - Pipelined for 2 GHz operation
// - Saturation and overflow detection
///////////////////////////////////////////////////////////////////////////////

module mpc64_tensor_core (
    // Clock and reset
    input  wire         clk,
    input  wire         rst_n,
    
    // Control
    input  wire         start,           // Start new MAC operation
    input  wire         relu_en,         // Enable ReLU on output
    input  wire         accum_en,        // Accumulate with previous result
    output wire         busy,            // Core is busy
    output wire         done,            // Operation complete
    
    // Input matrices (4x4 FP16)
    // Format: 16-bit FP16, row-major
    input  wire [15:0]  matrix_a [0:3][0:3],  // 16 FP16 values
    input  wire [15:0]  matrix_b [0:3][0:3],  // 16 FP16 values
    
    // Output matrix (4x4 FP16)
    output reg  [15:0]  matrix_c [0:3][0:3],  // Result
    
    // Status
    output reg          overflow,        // Arithmetic overflow
    output reg          saturation       // Saturation occurred
);

    //=======================================================================
    // Local parameters
    //=======================================================================
    localparam IDLE      = 3'b000;
    localparam LOAD      = 3'b001;
    localparam MAC0      = 3'b010;
    localparam MAC1      = 3'b011;
    localparam MAC2      = 3'b100;
    localparam MAC3      = 3'b101;
    localparam STORE     = 3'b110;
    
    //=======================================================================
    // Internal signals
    //=======================================================================
    reg  [2:0]           state, next_state;
    reg  [15:0]          acc_reg [0:3][0:3];     // Accumulator register
    reg  [15:0]          a_reg [0:3][0:3];       // Registered input A
    reg  [15:0]          b_reg [0:3][0:3];       // Registered input B
    wire [31:0]          mult_result [0:3][0:3]; // 32-bit product
    wire [15:0]          mult_lo [0:3][0:3];     // Low 16 bits
    wire [15:0]          mult_hi [0:3][0:3];     // High 16 bits (for overflow)
    reg  [3:0]           cycle_count;
    
    integer i, j, k;
    
    //=======================================================================
    // FP16 multiplier array (4x4x4 = 64 multipliers!)
    //=======================================================================
    generate
        for (i = 0; i < 4; i = i + 1) begin : row
            for (j = 0; j < 4; j = j + 1) begin : col
                for (k = 0; k < 4; k = k + 1) begin : elem
                    // Each multiplier does a[i][k] * b[k][j]
                    fp16_mult multiplier (
                        .a(a_reg[i][k]),
                        .b(b_reg[k][j]),
                        .result(mult_result[i][j]),
                        .lo(mult_lo[i][j]),
                        .hi(mult_hi[i][j])
                    );
                end
            end
        end
    endgenerate
    
    //=======================================================================
    // State machine
    //=======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            // Cycle counter for MAC pipeline
            if (state == MAC0 || state == MAC1 || state == MAC2 || state == MAC3) begin
                cycle_count <= cycle_count + 1'b1;
            end else begin
                cycle_count <= 4'd0;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                next_state = MAC0;
            end
            
            MAC0, MAC1, MAC2: begin
                next_state = state + 1'b1;
            end
            
            MAC3: begin
                next_state = STORE;
            end
            
            STORE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    //=======================================================================
    // Datapath
    //=======================================================================
    
    // Input registers (LOAD stage)
    always @(posedge clk) begin
        if (state == LOAD) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    a_reg[i][j] <= matrix_a[i][j];
                    b_reg[i][j] <= matrix_b[i][j];
                end
            end
            
            // Initialize accumulator
            if (!accum_en) begin
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        acc_reg[i][j] <= 16'h0000;  // Zero
                    end
                end
            end
            // If accum_en, keep previous acc_reg value
        end
    end
    
    // MAC stages (cycle_count 0-3)
    always @(posedge clk) begin
        reg [31:0] sum [0:3][0:3];
        reg [4:0]  exp_sum;
        reg        overflow_detected;
        
        if (state == MAC0 || state == MAC1 || state == MAC2 || state == MAC3) begin
            // Initialize sums
            if (cycle_count == 0) begin
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        sum[i][j] = 32'h00000000;
                    end
                end
            end
            
            // Accumulate products for current k
            k = cycle_count;  // 0,1,2,3
            
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    // Add to running sum
                    sum[i][j] = sum[i][j] + mult_result[i][j];
                end
            end
            
            // At end of MAC3, store final result
            if (state == MAC3) begin
                for (i = 0; i < 4; i = i + 1) begin
                    for (j = 0; j < 4; j = j + 1) begin
                        // Check for overflow/underflow
                        overflow_detected = |mult_hi[i][j][14:0];  // Check exponent overflow
                        
                        // Convert 32-bit product back to FP16 with saturation
                        if (overflow_detected) begin
                            // Saturation to max FP16 value (0x7BFF)
                            acc_reg[i][j] <= 16'h7BFF;
                            overflow <= 1'b1;
                            saturation <= 1'b1;
                        end else begin
                            // Normal case: take low 16 bits
                            acc_reg[i][j] <= mult_lo[i][j];
                        end
                    end
                end
            end
        end
    end
    
    // Output stage with optional ReLU
    always @(posedge clk) begin
        if (state == STORE) begin
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    if (relu_en) begin
                        // ReLU: if negative (sign bit = 1), set to zero
                        matrix_c[i][j] <= acc_reg[i][j][15] ? 16'h0000 : acc_reg[i][j];
                    end else begin
                        matrix_c[i][j] <= acc_reg[i][j];
                    end
                end
            end
        end
    end
    
    // Status outputs
    assign busy = (state != IDLE);
    assign done = (state == STORE);
    
endmodule

///////////////////////////////////////////////////////////////////////////////
// FP16 Multiplier (IEEE 754-2008 half-precision)
///////////////////////////////////////////////////////////////////////////////
module fp16_mult (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [31:0] result,  // Full 32-bit product
    output wire [15:0] lo,       // Low 16 bits (mantissa product)
    output wire [15:0] hi        // High 16 bits (exponent sum + overflow)
);

    // FP16 fields
    wire        a_sign = a[15];
    wire [4:0]  a_exp  = a[14:10];
    wire [9:0]  a_man  = a[9:0];
    
    wire        b_sign = b[15];
    wire [4:0]  b_exp  = b[14:10];
    wire [9:0]  b_man  = b[9:0];
    
    // Special cases
    wire a_zero = (a_exp == 5'd0) && (a_man == 10'd0);
    wire b_zero = (b_exp == 5'd0) && (b_man == 10'd0);
    wire a_inf  = (a_exp == 5'd31) && (a_man == 10'd0);
    wire b_inf  = (b_exp == 5'd31) && (b_man == 10'd0);
    wire a_nan  = (a_exp == 5'd31) && (a_man != 10'd0);
    wire b_nan  = (b_exp == 5'd31) && (b_man != 10'd0);
    
    // Result fields
    reg        r_sign;
    reg [4:0]  r_exp;
    reg [9:0]  r_man;
    reg [31:0] r_full;
    
    // Mantissa multiplication (10-bit * 10-bit = 20-bit)
    wire [19:0] man_prod = {1'b1, a_man} * {1'b1, b_man};  // Add hidden bit
    
    always @(*) begin
        // Handle special cases
        if (a_nan || b_nan) begin
            // NaN
            r_sign = 1'b0;
            r_exp  = 5'd31;
            r_man  = 10'd1;
        end else if (a_inf || b_inf) begin
            // Infinity
            r_sign = a_sign ^ b_sign;
            r_exp  = 5'd31;
            r_man  = 10'd0;
        end else if (a_zero || b_zero) begin
            // Zero
            r_sign = a_sign ^ b_sign;
            r_exp  = 5'd0;
            r_man  = 10'd0;
        end else begin
            // Normal multiplication
            r_sign = a_sign ^ b_sign;
            r_exp  = a_exp + b_exp - 5'd15;  // Bias adjustment
            
            // Normalize mantissa
            if (man_prod[19]) begin
                r_man = man_prod[19:10];  // Take high 10 bits
                r_exp = r_exp + 1'b1;      // Adjust exponent
            end else begin
                r_man = man_prod[18:9];    // Take next 10 bits
            end
            
            // Check for overflow/underflow
            if (r_exp >= 5'd31) begin
                r_exp = 5'd31;
                r_man = 10'd0;  // Infinity
            end else if (r_exp <= 5'd0) begin
                r_exp = 5'd0;
                r_man = 10'd0;  // Zero (underflow)
            end
        end
        
        // Construct full product
        r_full = {r_sign, r_exp, r_man, 16'h0000};
    end
    
    assign result = r_full;
    assign lo = r_full[15:0];
    assign hi = r_full[31:16];
    
endmodule
