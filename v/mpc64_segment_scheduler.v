module mpc64_segment_scheduler (
    input wire clk,
    input wire rst_n,
    input wire [1023:0] main_bus_data,  // Кусок тензора от Главного
    output reg [1023:0] ring_bus_out,   // Микро-задачи в кольцо ядер
    input wire [1023:0] ring_bus_in,    // Ответы от ядер
    output reg main_wait_signal         // Просьба к Главному подождать (если был NOT_READY)
);

    // Локальное хранилище сегмента (SRAM планировщика)
    // Здесь лежит полученный от Главного кусок тензора
    reg [1023:0] segment_work_buffer [0:63]; 
    reg [5:0] retry_count;

    always @(posedge clk) begin
        // 1. ПОЛУЧЕНИЕ: Главный прислал кусок -> Малый начинает дробление
        // Рассылаем микро-задачи ядрам по кольцевой шине с их ID
        
        // 2. КОНТРОЛЬ: Слушаем кольцо
        if (ring_bus_in[1017:1010] == 8'hFF) begin // Получен статус NOT_READY от ядра
            // Малый планировщик сам берет кусок из буфера и 
            // отправляет его резервному ядру, не беспокоя Главного
            ring_bus_out <= segment_work_buffer[next_reserve_id];
            main_wait_signal <= 1'b1; // Сигнал наверх: "Переделываю, подожди!"
        end
        
        // 3. SOFT-BOOT: Проброс прошивки
        if (main_bus_data[1023:1016] == 8'hAA) begin // Пометка 'soft'
            ring_bus_out <= main_bus_data; // Рассылка микрокода в SRAM ядер
        end
    end
endmodule
