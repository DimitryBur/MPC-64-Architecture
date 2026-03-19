module mpc64_segment (
    input wire clk,
    input wire rst_n,
    input wire [1023:0] segment_in,
    output wire [1023:0] segment_out,
    output wire [79:0]   cluster_ready_map
);
    wire [1023:0] ring_bus [0:80];
    assign ring_bus[0] = segment_in;
    assign segment_out = ring_bus[80];

    genvar i;
    generate
        for (i = 0; i < 80; i = i + 1) begin : node_ring
            mpc64_alu_node #(.CORE_ID(i[6:0])) node_inst (
                .clk(clk), .rst_n(rst_n),
                .ring_bus_in(ring_bus[i]),
                .ring_bus_out(ring_bus[i+1]),
                .ready_flag(cluster_ready_map[i])
            );
        end
    endgenerate
endmodule
