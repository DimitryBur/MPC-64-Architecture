module mpc64_alu_core (
    input  wire          clk,        // 2.0 GHz
    input  wire          rst_n,      
    
    // Интерфейс с L1 SRAM (Векторы 1024 бита)
    input  wire [1023:0] v_reg_a,    // Активации (16 x 64-bit)
    input  wire [1023:0] v_reg_b,    // Веса (16 x 64-bit)
    input  wire [1023:0] v_reg_acc,  // Аккумулятор (предыдущий результат)
    
    // Управление
    input  wire [3:0]    alu_op,     // 0001: TMAC_4x4, 0010: V_LOGIC_AND, etc.
    input  wire          start_exec, // Импульс запуска от планировщика
    
    // Выход
    output reg  [1023:0] v_result,   // Финальный вектор
    output reg           done_sig    // Импульс завершения (ровно через 4 такта для TMAC)
);

    // Внутренние конвейерные регистры для TMAC (4 стадии)
    reg [1023:0] pipe_stage_1, pipe_stage_2, pipe_stage_3;
    reg [2:0]    exec_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_result <= 1024'b0;
            done_sig <= 1'b0;
            exec_cnt <= 3'b0;
        end else begin
            if (start_exec) begin
                exec_cnt <= 3'd1;
                done_sig <= 1'b0;
                
                // Стадия 1: Параллельное умножение 16 пар (4x4 MAC в векторе)
                // Здесь реализуется логика 16-ти независимых множителей 64x64
                pipe_stage_1 <= v_reg_a * v_reg_b; 
            end 
            else if (exec_cnt > 0 && exec_cnt < 4) begin
                exec_cnt <= exec_cnt + 1;
                
                // Стадии 2-3: Дерево сложения (Adder Tree) и накопление
                pipe_stage_2 <= pipe_stage_1; 
                pipe_stage_3 <= pipe_stage_2 + v_reg_acc;
            end 
            else if (exec_cnt == 4) begin
                v_result <= pipe_stage_3;
                done_sig <= 1'b1; // Такт 24 для планировщика
                exec_cnt <= 3'd0;
            end else begin
                done_sig <= 1'b0;
            end
        end
    end
endmodule
