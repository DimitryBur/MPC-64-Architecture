module reduction_adder_tree (
    input clk,
    input reset,
    input en,                     // Сигнал запуска вычисления
    input [1023:0] vector_in,     // Входной 1024-битный регистр (16 x 64-bit)
    output reg [63:0] sum_out,    // Итоговая сумма
    output reg ready              // Флаг готовности результата
);

    // Внутренние регистры для этапов конвейера (Pipeline)
    reg [63:0] stage1 [7:0]; // 16 -> 8
    reg [63:0] stage2 [3:0]; // 8 -> 4
    reg [63:0] stage3 [1:0]; // 4 -> 2
    reg [1:0] delay_counter; // Счетчик тактов

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sum_out <= 64'b0;
            ready <= 1'b0;
            delay_counter <= 2'b0;
        end else if (en) begin
            // Этап 1: Складываем 16 элементов парами (8 сумматоров)
            stage1[0] <= vector_in[63:0]     + vector_in[127:64];
            stage1[1] <= vector_in[191:128]  + vector_in[255:192];
            stage1[2] <= vector_in[319:256]  + vector_in[383:320];
            stage1[3] <= vector_in[447:384]  + vector_in[511:448];
            stage1[4] <= vector_in[575:512]  + vector_in[639:576];
            stage1[5] <= vector_in[703:640]  + vector_in[767:704];
            stage1[6] <= vector_in[831:768]  + vector_in[895:832];
            stage1[7] <= vector_in[959:896]  + vector_in[1023:960];

            // Этап 2: Складываем 8 результатов (4 сумматора)
            stage2[0] <= stage1[0] + stage1[1];
            stage2[1] <= stage1[2] + stage1[3];
            stage2[2] <= stage1[4] + stage1[5];
            stage2[3] <= stage1[6] + stage1[7];

            // Этап 3: Складываем 4 результата (2 сумматора)
            stage3[0] <= stage2[0] + stage2[1];
            stage3[1] <= stage2[2] + stage2[3];

            // Этап 4: Финальная сумма
            sum_out <= stage3[0] + stage3[1];
            
            // Логика готовности (через 4 такта после подачи en)
            if (delay_counter < 3) 
                delay_counter <= delay_counter + 1;
            else 
                ready <= 1'b1;
        end else begin
            ready <= 1'b0;
            delay_counter <= 2'b0;
        end
    end
endmodule
