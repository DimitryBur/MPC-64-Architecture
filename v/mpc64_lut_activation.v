// MPC-64 Ultra: Vector Activation LUT
// Latency: 1 Cycle | Throughput: 1024-bit per cycle (via parallel LUTs)

module mpc64_lut_activation (
    input  wire        clk,
    input  wire        lut_we,          // Сигнал обновления таблицы (Broadcast)
    input  wire [7:0]  lut_addr_in,     // Адрес записи при обновлении
    input  wire [15:0] lut_data_in,     // Данные функции (FP16)
    
    input  wire [15:0] vector_in,       // Входное значение (от TMAC/ALU)
    output reg  [15:0] vector_out       // Результат активации
);

    // Локальная SRAM для хранения аппроксимации функции
    reg [15:0] sram_lut [0:255];

    // 1. Процесс обновления (Configuration Phase)
    always @(posedge clk) begin
        if (lut_we)
            sram_lut[lut_addr_in] <= lut_data_in;
    end

    // 2. Процесс инференса (Inference Phase)
    // Используем старшие 8 бит мантиссы/порядка как индекс
    // Для 2.0 GHz используем простейшую выборку (Zero-order hold)
    always @(posedge clk) begin
        vector_out <= sram_lut[vector_in[15:8]]; 
    end

endmodule
