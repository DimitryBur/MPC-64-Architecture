// MPC-64 Ultra: Segment Top-Level I/O
// Interface for Global Spine, Local Ring, and L2 SRAM

module segment_top_io (
    input  wire          clk,
    input  wire          rst_n,

    // GLOBAL SPINE INTERFACE (1024 data + 64 header)
    input  wire [1087:0] g_spine_in,
    output wire [1087:0] g_spine_out,
    input  wire          g_spine_valid,
    
    // LOCAL RING INTERFACE (To 64 Cores)
    output wire [1087:0] l_ring_out,
    input  wire [1087:0] l_ring_in,
    
    // L2 SRAM INTERFACE (4MB Shared)
    output wire [19:0]   l2_addr,
    output wire [1023:0] l2_data_w,
    input  wire [1023:0] l2_data_r,
    output wire          l2_we,

    // DIAGNOSTICS
    output wire [1:0]    seg_status,
    output wire [5:0]    core_fault_report
);

    // Внутренние сигналы для связи с FSM
    wire task_trigger;
    assign task_trigger = (g_spine_in[1075:1072] == 4'h5) && g_spine_valid; // ID сегмента = 5

    // Инстанс логики планировщика
    segment_scheduler_fsm fsm_inst (
        .clk(clk),
        .rst_n(rst_n),
        .task_start(task_trigger),
        .incoming_task_id(g_spine_in[1055:1040]),
        .task_payload(g_spine_in[1023:0]),
        .segment_error(seg_status[1]),
        .faulty_core_id(core_fault_report)
    );

    // Сквозная трансляция на выход (Cut-through)
    assign g_spine_out = g_spine_in;

endmodule
