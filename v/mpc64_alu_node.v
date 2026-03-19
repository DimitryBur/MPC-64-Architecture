module mpc64_alu_node #(
    parameter [6:0] CORE_ID = 7'd0  // 0-63 основные, 64-79 резервные
)(
    input wire clk,
    input wire rst_n,
    input wire [1023:0] ring_bus_in,
    output reg [1023:0] ring_bus_out,
    output reg          ready_flag      // Статус для планировщика сегмента
);
    reg [7:0]  timer;
    reg        busy;
    wire [6:0] target_id = ring_bus_in[1023:1017];
    wire [7:0] command   = ring_bus_in[1016:1009];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer <= 8'd0; busy <= 1'b0; ready_flag <= 1'b1;
            ring_bus_out <= 1024'b0;
        end else begin
            // Захват задачи (конвейерный вход)
            if (target_id == CORE_ID && !busy && command != 8'h00) begin
                busy <= 1'b1;
                ready_flag <= 1'b0;
                timer <= 8'd152; 
                ring_bus_out <= 1024'b0; // Поглощаем пакет
            end 
            // Отсчет 152 тактов
            else if (busy) begin
                if (timer > 1) begin
                    timer <= timer - 1'b1;
                    ring_bus_out <= ring_bus_in; // Транзит чужих пакетов
                end else begin
                    // Выдача ответа ровно на 152-й такт
                    ring_bus_out[1023:1017] <= CORE_ID;
                    ring_bus_out[1008:0]    <= 1009'hABC; // Данные результата
                    busy <= 1'b0; ready_flag <= 1'b1; timer <= 8'd0;
                end
            end else begin
                ring_bus_out <= ring_bus_in; // Простой транзит
            end
        end
    end
endmodule
