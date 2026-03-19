module mpc64_segment_scheduler (
    input wire clk,
    input wire rst_n,
    input wire [1023:0] main_task_data,
    output reg [1023:0] to_ring_bus,
    input wire [1023:0] from_ring_bus,
    input wire [79:0]   cluster_ready,
    output reg          main_wait_sig
);
    reg [5:0] send_ptr;   // 0-63
    reg [3:0] backup_ptr; // 0-15 (резерв)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_ptr <= 6'd0; backup_ptr <= 4'd0; main_wait_sig <= 1'b0;
        end else begin
            // Конвейерная рассылка с шагом в 1 такт
            if (send_ptr < 64) begin
                if (cluster_ready[send_ptr]) begin
                    to_ring_bus[1023:1017] <= {1'b0, send_ptr};
                    send_ptr <= send_ptr + 1'b1;
                end else if (backup_ptr < 16) begin
                    // Мгновенная подмена на резервное ядро (ID 64+)
                    to_ring_bus[1023:1017] <= 7'd64 + backup_ptr;
                    backup_ptr <= backup_ptr + 1'b1;
                    send_ptr <= send_ptr + 1'b1;
                    main_wait_sig <= 1'b1; // Просим главный подождать
                end
            end
        end
    end
endmodule
