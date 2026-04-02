`include "../../src/core/biriscv_defs.v"

module tb_parallel_matmul;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;

reg clk;
reg rst;

wire [31:0] mem_i_pc_w;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting Parallel MatMul Benchmark (Hybrid MUL+MULE)");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_parallel_matmul);
    end

    clk = 0;
    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    for (i = 0; i < 131072; i = i + 1)
        mem[i] = 0;

    f = $fopen("./build/tcm.bin", "rb");
    i = $fread(mem, f);
    $display("Loaded %0d bytes from tcm.bin", i);
    for (i = 0; i < 131072; i = i + 1)
        u_mem.u_ram.ram[i/8][((i%8)*8) +: 8] = mem[i];
end

always #5 clk = ~clk;

reg [31:0] cycle_count;

initial cycle_count = 0;

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;

        if (mem_i_pc_w == PASS_PC) begin
            $display("\n*** PARALLEL MATMUL PASS (Hybrid) ***");
            $display("Total cycles: %0d", cycle_count);
            $finish;
        end
        if (mem_i_pc_w == FAIL_PC) begin
            $display("\n*** PARALLEL MATMUL FAIL ***");
            $finish;
        end
        if (cycle_count > 500000) begin
            $display("\n*** TIMEOUT ***");
            $finish;
        end
    end
end

wire        mem_i_rd_w;
wire        mem_i_flush_w;
wire        mem_i_invalidate_w;
wire        mem_i_accept_w;
wire        mem_i_valid_w;
wire        mem_i_error_w;
wire [63:0] mem_i_inst_w;

wire [31:0] mem_d_addr_w;
wire [31:0] mem_d_data_wr_w;
wire        mem_d_rd_w;
wire [3:0]  mem_d_wr_w;
wire        mem_d_cacheable_w;
wire [10:0] mem_d_req_tag_w;
wire        mem_d_invalidate_w;
wire        mem_d_writeback_w;
wire        mem_d_flush_w;
wire [31:0] mem_d_data_rd_w;
wire        mem_d_accept_w;
wire        mem_d_ack_w;
wire        mem_d_error_w;
wire [10:0] mem_d_resp_tag_w;

riscv_core
#(
    .SUPPORT_DUAL_ISSUE(1),
    .SUPPORT_MULDIV(1),
    .SUPPORT_LOAD_BYPASS(1),
    .SUPPORT_MUL_BYPASS(1)
)
u_dut
(
    .clk_i(clk),
    .rst_i(rst),
    .mem_d_data_rd_i(mem_d_data_rd_w),
    .mem_d_accept_i(mem_d_accept_w),
    .mem_d_ack_i(mem_d_ack_w),
    .mem_d_error_i(mem_d_error_w),
    .mem_d_resp_tag_i(mem_d_resp_tag_w),
    .mem_i_accept_i(mem_i_accept_w),
    .mem_i_valid_i(mem_i_valid_w),
    .mem_i_error_i(mem_i_error_w),
    .mem_i_inst_i(mem_i_inst_w),
    .intr_i(1'b0),
    .reset_vector_i(32'h80000000),
    .cpu_id_i(32'h00000000),
    .mem_d_addr_o(mem_d_addr_w),
    .mem_d_data_wr_o(mem_d_data_wr_w),
    .mem_d_rd_o(mem_d_rd_w),
    .mem_d_wr_o(mem_d_wr_w),
    .mem_d_cacheable_o(mem_d_cacheable_w),
    .mem_d_req_tag_o(mem_d_req_tag_w),
    .mem_d_invalidate_o(mem_d_invalidate_w),
    .mem_d_writeback_o(mem_d_writeback_w),
    .mem_d_flush_o(mem_d_flush_w),
    .mem_i_rd_o(mem_i_rd_w),
    .mem_i_flush_o(mem_i_flush_w),
    .mem_i_invalidate_o(mem_i_invalidate_w),
    .mem_i_pc_o(mem_i_pc_w)
);

tcm_mem
u_mem
(
    .clk_i(clk),
    .rst_i(rst),
    .mem_i_rd_i(mem_i_rd_w),
    .mem_i_flush_i(mem_i_flush_w),
    .mem_i_invalidate_i(mem_i_invalidate_w),
    .mem_i_pc_i(mem_i_pc_w),
    .mem_i_accept_o(mem_i_accept_w),
    .mem_i_valid_o(mem_i_valid_w),
    .mem_i_error_o(mem_i_error_w),
    .mem_i_inst_o(mem_i_inst_w),
    .mem_d_addr_i(mem_d_addr_w),
    .mem_d_data_wr_i(mem_d_data_wr_w),
    .mem_d_rd_i(mem_d_rd_w),
    .mem_d_wr_i(mem_d_wr_w),
    .mem_d_cacheable_i(mem_d_cacheable_w),
    .mem_d_req_tag_i(mem_d_req_tag_w),
    .mem_d_invalidate_i(mem_d_invalidate_w),
    .mem_d_writeback_i(mem_d_writeback_w),
    .mem_d_flush_i(mem_d_flush_w),
    .mem_d_accept_o(mem_d_accept_w),
    .mem_d_ack_o(mem_d_ack_w),
    .mem_d_error_o(mem_d_error_w),
    .mem_d_resp_tag_o(mem_d_resp_tag_w),
    .mem_d_data_rd_o(mem_d_data_rd_w)
);

endmodule
