// Модуль малого ядра MPC-64 (Упрощенная версия)
module mpc64_small_core (
    input wire clk,
    input wire rst_n,
    input wire [63:0] instruction, // 64-битная команда от планировщика сегмента
    input wire [511:0] data_in,    // Входные данные (например, строка матрицы)
    output reg [511:0] data_out,   // Результат
    output reg ready               // Флаг готовности (для детерминизма)
);

    // Локальная SRAM (регистровый файл 1024 байта = 128 слов по 64 бита)
    reg [63:0] sram [0:127];
    
    // Внутренние регистры для MAC 4x4 (16 элементов)
    // Допустим, работаем с 16-битными весами для компактности в 64-битном ядре
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
            data_out <= 512'b0;
        end else begin
            case (instruction[63:56]) // Код операции (OpCode)
                
                // Операция MAC 4x4 (Multiply-Accumulate)
                8'hA1: begin 
                    // Упрощенная логика: перемножаем входящий вектор на локальные веса
                    // В реальном чипе здесь будет 16 параллельных умножителей
                    for (i = 0; i < 16; i = i + 1) begin
                        // Результат = Аккумулятор + (Данные * Веса из SRAM)
                        sram[i] <= sram[i] + (data_in[i*32 +: 32] * instruction[31:0]);
                    end
                    ready <= 1'b1; // Операция детерминирована, занимает фиксированные такты
                end

                // Загрузка данных в локальную SRAM
                8'hL1: begin
                    sram[instruction[15:0]] <= data_in[63:0];
                    ready <= 1'b1;
                end

                default: ready <= 1'b0;
            endcase
        end
    end
endmodule
