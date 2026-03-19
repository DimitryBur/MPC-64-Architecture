module mpc64_main_scheduler (
    input  wire         clk,
    input  wire         rst_n,
    
    // Интерфейс с Хостом (CPU)
    input  wire [1023:0] host_request,    // Команда: [OpCode][Size][Data...]
    input  wire          host_req_valid,
    output reg           host_ready,
    
    // Интерфейс с 64 сегментами (Шина + Сигналы управления)
    output reg  [1023:0] bus_to_segments, // Данные/Прошивки для сегментов
    output reg  [5:0]    target_segment,  // ID сегмента (0-63)
    input  wire [1023:0] bus_from_segments, // Ответы от сегментов
    input  wire [63:0]   segment_wait_bus,  // Линии WAIT от каждого сегмента
    
    // Выходной результат
    output reg  [1023:0] final_result
);

    // --- БИБЛИОТЕКА ТИПОВЫХ ПРОШИВОК (Firmware ROM) ---
    localparam FW_MATMUL = 1024'hAA_0000_1122_3344_5566; // Пример прошивки MAC 4x4
    localparam FW_NORM   = 1024'hAA_0000_AABB_CCDD_EEFF; // Пример прошивки Normalization

    // --- ТАБЛИЦА СОСТОЯНИЯ И ЗЕРКАЛО ЗАПРОСОВ ---
    reg [1023:0] task_mirror    [0:63]; // Храним копию того, что отправили в сегмент
    reg [7:0]    watchdog_timer [0:63]; // Таймеры ожидания для каждого сегмента
    reg [5:0]    health_map     [0:63]; // Кол-во живых ядер в каждом сегменте
    reg [63:0]   segment_busy;          // Флаги: 1 = сегмент занят задачей

    integer i;

    // --- ЛОГИКА ПЛАНИРОВАНИЯ ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            host_ready <= 1'b1;
            segment_busy <= 64'b0;
            for (i = 0; i < 64; i = i + 1) begin
                watchdog_timer[i] <= 8'd0;
                health_map[i]     <= 6'd64; // По умолчанию все 64 ядра живы
            end
        end else begin

            // 1. ПРИЕМ НОВОЙ ЗАДАЧИ ОТ ХОСТА
            if (host_req_valid && host_ready) begin
                // Определяем тип операции и рассылаем нужную прошивку (SOFT-BOOT)
                if (host_request[1023:1016] == 8'h01) bus_to_segments <= FW_MATMUL;
                else                                  bus_to_segments <= FW_NORM;
                
                // Нарезаем тензор и заполняем task_mirror (упрощенно - по сегментам)
                // Здесь работает логика адаптивной нарезки по health_map
                host_ready <= 1'b0; 
            end

            // 2. МОНИТОРИНГ И ПЕРЕРАСПРЕДЕЛЕНИЕ (DYNAMIC RE-SCHEDULING)
            for (i = 0; i < 64; i = i + 1) begin
                if (segment_wait_bus[i]) begin
                    watchdog_timer[i] <= watchdog_timer[i] + 1'b1;
                    
                    // Если сегмент "висит" дольше 200 тактов (лимит 152 + запас)
                    if (watchdog_timer[i] > 8'd200) begin
                        // Ищем свободный сегмент для перехвата задачи
                        if (~&segment_busy) begin // Если есть хоть один свободный
                            // Перебрасываем зеркало задачи из task_mirror[i] в свободный узел
                            bus_to_segments <= task_mirror[i];
                            target_segment  <= next_free_segment(segment_busy);
                            
                            // Штрафуем зависший сегмент (уменьшаем здоровье в таблице)
                            if (health_map[i] > 0) health_map[i] <= health_map[i] - 1'b1;
                            
                            watchdog_timer[i] <= 8'd0; // Сброс таймера после переброски
                        end
                    end
                end else begin
                    watchdog_timer[i] <= 8'd0; // Обнуляем, если сегмент ответил вовремя
                end
            end

            // 3. СБОРКА ХЕШ-ТАБЛИЦЫ ОТВЕТОВ
            // Если пришел пакет с валидным ID, записываем в итоговый тензор
            if (bus_from_segments[1023:1018] != 6'b0) begin
                final_result <= bus_from_segments; 
                segment_busy[bus_from_segments[1023:1018]] <= 1'b0; // Освобождаем сегмент
            end
        end
    end

    // Вспомогательная функция поиска свободного сегмента
    function [5:0] next_free_segment(input [63:0] busy_map);
        integer j;
        begin
            next_free_segment = 6'd0;
            for (j = 0; j < 64; j = j + 1)
                if (!busy_map[j]) next_free_segment = j[5:0];
        end
    endfunction

endmodule
