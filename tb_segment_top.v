`timescale 1ns / 1ps

module tb_segment_top();

    reg clk;
    reg rst_n;
    reg [1087:0] g_spine_in;
    reg g_spine_valid;
    
    wire [1:0] seg_status;
    wire [5:0] fault_report;
    
    // Эмуляция векторов ответов от ядер (Bitmap)
    reg [63:0] mock_core_done;
    reg [63:0] mock_core_busy;

    // Инстанс нашего модуля I/O + FSM
    segment_top_io uut (
        .clk(clk),
        .rst_n(rst_n),
        .g_spine_in(g_spine_in),
        .g_spine_valid(g_spine_valid),
        .seg_status(seg_status),
        .core_fault_report(fault_report)
    );

    // Генерация частоты 2.0 GHz (период 0.5 нс)
    always #0.25 clk = ~clk;

    initial begin
        // Инициализация
        clk = 0;
        rst_n = 0;
        g_spine_in = 0;
        g_spine_valid = 0;
        mock_core_done = 0;
        mock_core_busy = 0;

        #2 rst_n = 1; // Сброс окончен
        
        // --- ТЕСТ 1: ЗАПУСК ЗАДАЧИ ---
        #1;
        g_spine_valid = 1;
        // Заголовок: [Type:5 (Data)][Segment:5][Task:0xAAAA][Slot:0x0001]
        g_spine_in[1087:1024] = {4'h5, 4'h0, 4'h5, 4'h0, 16'hAAAA, 16'h0001, 12'h0};
        g_spine_in[1023:0]    = 1024'hDEADBEEF_CAFEBABE; // Тестовые данные
        
        #0.5 g_spine_valid = 0; // Импульс старта 1 такт

        // --- ТЕСТ 2: ОЖИДАНИЕ И ЭМУЛЯЦИЯ СБОЯ ---
        // Ждем 152 такта (76 нс). 
        // Допустим, все ядра кроме #5 ответили на 140-м такте.
        #70; 
        mock_core_done = 64'hFFFFFFFFFFFFFFDF; // Все "1", кроме 5-го бита (0)
        
        // Проверяем реакцию на 152-м такте
        #6; // Суммарно 76нс
        if (seg_status == 2'b10) begin
            $display("SUCCESS: Fault detected on Core ID: %d", fault_report);
        end else begin
            $display("FAILED: Scheduler did not catch the silent core!");
        end

        #10 $finish;
    end
endmodule
