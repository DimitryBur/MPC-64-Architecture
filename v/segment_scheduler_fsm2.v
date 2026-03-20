// MPC-64 Ultra: Segment Scheduler FSM
// Target: 2.0 GHz (500 ps), 10nm FinFET
// Logic: Shadow Loading, Context Flip, Alive_Bitmap Failover

module segment_scheduler_fsm (
    input  wire         clk,           // 0.5 ns period
    input  wire         rst_n,
    input  wire [63:0]  cores_ready,   // Флаги готовности от 64 ядер
    input  wire         spine_data_vld,// Данные из Copper Spine для Shadow-загрузки
    
    // Интерфейс памяти (Ping-Pong)
    output reg          active_plane,  // 0: SRAM_A active, 1: SRAM_B active
    output wire [5:0]   current_core_id,
    
    // Логика надежности (80/20)
    output reg  [63:0]  alive_bitmap,  // Битмап "здоровых" ядер
    output reg          trigger_spare  // Сигнал переброса на резервное ядро
);

    // Внутренний счетчик цикла (152 тика)
    reg [7:0] tick_cnt;
    
    // Параметры тайминг-карты (согласно Манифесту)
    localparam T_DISPATCH_END = 8'd63;
    localparam T_SERVICE_A    = 8'd97;
    localparam T_SERVICE_B    = 8'd131;
    localparam T_COMMIT       = 8'd151; // Последний такт перед сбросом

    // 1. Основной счетчик цикла
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            tick_cnt <= 8'd0;
        else if (tick_cnt == T_COMMIT)
            tick_cnt <= 8'd0;
        else
            tick_cnt <= tick_cnt + 1'b1;
    end

    // 2. Логика Context Flip (Ping-Pong Switch)
    // Происходит мгновенно на такте 152
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_plane <= 1'b0;
        else if (tick_cnt == T_COMMIT)
            active_plane <= ~active_plane; // Переключаем рабочую плоскость
    end

    // 3. Мониторинг Alive_Bitmap (Silence = Fault)
    // Проверяем каждое ядро в его персональный такт ответа
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alive_bitmap <= {64{1'b1}}; // Все живы при старте
            trigger_spare <= 1'b0;
        end else begin
            // Окна проверки (Collect A & B)
            if ((tick_cnt >= 8'd64 && tick_cnt <= 8'd96) || 
                (tick_cnt >= 8'd99 && tick_cnt <= 8'd130)) begin
                
                // Если ядро не выставило Ready в свой слот
                if (!cores_ready[tick_cnt[5:0]]) begin
                    alive_bitmap[tick_cnt[5:0]] <= 1'b0; // Изоляция
                    trigger_spare <= 1'b1;               // Мгновенный запрос к Spare Core
                end else begin
                    trigger_spare <= 1'b0;
                end
            end else {
                trigger_spare <= 1'b0;
            }
        end
    end

    // 4. Индекс текущего ядра для Dispatch
    assign current_core_id = tick_cnt[5:0];

endmodule
