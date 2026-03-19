module mpc64_main_scheduler (
    input  wire         clk,
    input  wire         rst_n,
    
    // Интерфейс с Хостом (CPU)
    input  wire [1023:0] host_request,    // [OpCode][Size][Data...]
    input  wire          host_req_valid,
    output reg           host_ready,
    
    // Интерфейс с 64 сегментами
    output reg  [1023:0] bus_to_segments, // Данные/Прошивки
    output reg  [5:0]    target_segment,  // ID текущего сегмента
    input  wire [1023:0] bus_from_segments, 
    input  wire [63:0]   segment_wait_bus,  // WAIT от каждого сегмента
    
    output reg  [1023:0] final_result
);

    // --- БИБЛИОТЕКА ПРОШИВОК (Firmware ROM) ---
    localparam FW_MATMUL = 1024'hAA_0000_1122_3344_5566; 
    localparam FW_NORM   = 1024'hAA_0000_AABB_CCDD_EEFF; 

    // --- ТАБЛИЦЫ СОСТОЯНИЯ ---
    reg [1023:0] task_mirror    [0:63]; // Зеркало для переброски задач
    reg [7:0]    watchdog_timer [0:63]; // Таймеры для детерминизма
    reg [5:0]    health_map     [0:63]; // Кол-во живых ядер (0-80)
    reg [63:0]   segment_busy;          // Флаг занятости сегмента

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            host_ready <= 1'b1;
            segment_busy <= 64'b0;
            for (i = 0; i < 64; i = i + 1) begin
                watchdog_timer[i] <= 8'd0;
                health_map[i] <= 6'd80; // Начинаем с 80 ядер (64+16)
            end
        end else begin

            // 1. ПРИЕМ ЗАДАЧИ: Рассылка SOFT-BOOT и нарезка
            if (host_req_valid && host_ready) begin
                if (host_request[1023:1016] == 8'h01) 
                    bus_to_segments <= FW_MATMUL;
                else 
                    bus_to_segments <= FW_NORM;
                
                host_ready <= 1'b0; // Занят нарезкой и раздачей
            end

            // 2. ДИНАМИЧЕСКИЙ БАЛАНС (ПЕРЕБРОСКА ПРИ ЗАВИСАНИИ)
            for (i = 0; i < 64; i = i + 1) begin
                if (segment_wait_bus[i]) begin
                    watchdog_timer[i] <= watchdog_timer[i] + 1'b1;
                    
                    // Если сегмент не успевает (превышен порог 152 + запас)
                    if (watchdog_timer[i] > 8'd210) begin
                        // Ищем свободный сегмент через функцию
                        // Перенаправляем задачу из task_mirror[i]
                        bus_to_segments <= task_mirror[i];
                        target_segment <= find_next_free(segment_busy);
                        
                        // Помечаем зависший сегмент как "больной"
                        if (health_map[i] > 0) health_map[i] <= health_map[i] - 1'b1;
                        watchdog_timer[i] <= 8'd0;
                    end
                end else begin
                    watchdog_timer[i] <= 8'd0;
                end
            end

            // 3. СБОРКА ОТВЕТОВ В ХЕШ-ТАБЛИЦУ
            if (bus_from_segments[1023:1017] != 7'b0) begin
                final_result <= bus_from_segments; 
                segment_busy[bus_from_segments[1023:1018]] <= 1'b0; 
                host_ready <= 1'b1; // Готов к новой глобальной задаче
            end
        end
    end

    // Функция поиска свободного сегмента
    function [5:0] find_next_free(input [63:0] busy_bits);
        integer j;
        begin
            find_next_free = 6'd0;
            for (j = 0; j < 64; j = j + 1)
                if (!busy_bits[j]) find_next_free = j[5:0];
        end
    endfunction

endmodule
