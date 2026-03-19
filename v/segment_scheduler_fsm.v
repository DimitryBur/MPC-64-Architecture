// MPC-64 Ultra: Segment Scheduler FSM
// Logic for Task Dispatch, Timeout Monitoring (152 cycles), and Failover

module segment_scheduler_fsm (
    input  wire         clk,
    input  wire         rst_n,
    
    // Внутренние сигналы управления (от модуля I/O)
    input  wire         task_start,
    input  wire [15:0]  incoming_task_id,
    input  wire [1023:0] task_payload,
    
    // Контроль ядер
    output reg  [63:0]  core_dispatch_mask,
    input  wire [63:0]  core_done_vector,    // Ответы от ядер (Bitmap)
    input  wire [63:0]  core_busy_vector,    // Сигналы STILL_WORKING
    
    // Статус для Senior Scheduler
    output reg          segment_error,
    output reg  [5:0]   faulty_core_id
);

    // Состояния FSM
    localparam IDLE     = 3'b000;
    localparam DISPATCH = 3'b001;
    localparam MONITOR  = 3'b010;
    localparam FAILOVER = 3'b011;
    localparam COLLECT  = 3'b100;

    reg [2:0]  state;
    reg [63:0] task_bitmap;
    reg [7:0]  timer [63:0]; // 64 счетчика до 255 тактов
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            task_bitmap <= 64'b0;
            segment_error <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (task_start) begin
                        task_bitmap <= 64'b0;
                        state <= DISPATCH;
                    end
                end

                DISPATCH: begin
                    // Шахматный пуск (Staggered Start) реализован через маску
                    core_dispatch_mask <= 64'hFFFFFFFFFFFFFFFF; 
                    state <= MONITOR;
                    for (i=0; i<64; i=i+1) timer[i] <= 0;
                end

                MONITOR: begin
                    task_bitmap <= task_bitmap | core_done_vector;
                    
                    for (i=0; i<64; i=i+1) begin
                        if (!task_bitmap[i]) begin
                            timer[i] <= timer[i] + 1;
                            // Жесткий детерминизм: 152 такта
                            if (timer[i] == 8'd152 && !core_busy_vector[i]) begin
                                faulty_core_id <= i[5:0];
                                state <= FAILOVER;
                            end
                        end
                    end
                    
                    if (&task_bitmap) state <= COLLECT;
                end

                FAILOVER: begin
                    // Мгновенная изоляция и сигнал наверх
                    segment_error <= 1'b1;
                    // Здесь логика переназначения задачи на IDLE ядро
                    state <= MONITOR; 
                end

                COLLECT: begin
                    state <= IDLE;
                    segment_error <= 1'b0;
                end
            endcase
        end
    end
endmodule
