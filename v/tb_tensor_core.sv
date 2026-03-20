///////////////////////////////////////////////////////////////////////////////
// Testbench for MPC-64 Tensor Core
///////////////////////////////////////////////////////////////////////////////
module tb_mpc64_tensor_core;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         relu_en;
    reg         accum_en;
    wire        busy;
    wire        done;
    
    reg  [15:0] matrix_a [0:3][0:3];
    reg  [15:0] matrix_b [0:3][0:3];
    wire [15:0] matrix_c [0:3][0:3];
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end
    
    // Test sequence
    initial begin
        integer i, j;
        
        // Initialize
        rst_n = 0;
        start = 0;
        relu_en = 0;
        accum_en = 0;
        
        // Fill matrices with test data
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                matrix_a[i][j] = 16'h3C00;  // 1.0 in FP16
                matrix_b[i][j] = 16'h3C00;  // 1.0 in FP16
            end
        end
        
        // Reset
        #20;
        rst_n = 1;
        #10;
        
        // Test 1: Simple multiply (all ones)
        $display("Test 1: 4x4 matrix of ones * ones");
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        #10;
        
        // Display result
        for (i = 0; i < 4; i = i + 1) begin
            $display("Row %0d: %h %h %h %h", 
                i, matrix_c[i][0], matrix_c[i][1], 
                matrix_c[i][2], matrix_c[i][3]);
        end
        
        // Test 2: With ReLU
        $display("\nTest 2: With ReLU");
        relu_en = 1;
        start = 1;
        #10;
        start = 0;
        
        wait(done);
        #10;
        
        // Display result
        for (i = 0; i < 4; i = i + 1) begin
            $display("Row %0d: %h %h %h %h", 
                i, matrix_c[i][0], matrix_c[i][1], 
                matrix_c[i][2], matrix_c[i][3]);
        end
        
        #100;
        $finish;
    end
    
    // Instantiate DUT
    mpc64_tensor_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .relu_en(relu_en),
        .accum_en(accum_en),
        .busy(busy),
        .done(done),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_c(matrix_c),
        .overflow(),
        .saturation()
    );
    
endmodule
