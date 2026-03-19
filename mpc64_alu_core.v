module mpc64_alu_node #(
    parameter [5:0] CORE_ID = 6'd0
)(
    input wire clk,
    input wire rst_n,
    input wire [1023:0] ring_bus_in,
    output reg [1023:0] ring_bus_out,
    output reg status_not_ready // 1 = ошибка/не успел, 0 = всё ОК
);

    reg [7:0] timer;
    reg busy;

    wire [5:0] target_id = ring_bus_in[1023:1018];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer <= 8'd0;
            busy <= 1'b0;
            status_not_ready <= 1'b0;
            ring_bus_out <= 1024'b0;
        end else begin
            // 1. Прием задачи
            if (target_id == CORE_ID && !busy) begin
                busy <= 1'b1;
                timer <= 8'd152; 
                status_not_ready <= 1'b0;
            end

            // 2. Процесс вычисления (ровно 152 такта)
            if (busy) begin
                if (timer > 1) begin
                    timer <= timer - 1'b1;
                    // Если внутри произошел аппаратный сбой (например, ECC памяти)
                    // выставляем статус "not_ready" заранее
                end else begin
                    // ФИНАЛ: 152-й такт. Либо пан, либо пропал.
                    if (status_not_ready) begin
                        // Ядро не справилось: затираем данные, выдаем статус ошибки
                        ring_bus_out[1017:1010] <= 8'hFF; // Код ошибки/Not Ready
                    end else begin
                        // Успех: кладем результат в шину
                        ring_bus_out[1009:0] <= 1010'hRESULT_DATA; 
                    end
                    
                    // Мгновенный сброс: ядро снова чисто и готово к новой задаче
                    busy <= 1'b0;
                    timer <= 8'd0;
                end
            end else begin
                ring_bus_out <= ring_bus_in; // Транзит
            end
        end
    end
endmodule
