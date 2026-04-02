`include "../../src/core/biriscv_defs.v"

module tb_parallel_matmul;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;

reg clk;
reg rst;

// Forward-declare for probes
wire [31:0] mem_i_pc_w;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting Parallel MatMul Benchmark (2xMUL dual-issue)");

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

//-------------------------------------------------------------
// Cycle / dual-issue counters
//-------------------------------------------------------------
reg [31:0] cycle_count;
integer    dual_mul_count;     // times both pipes issued a MUL in the same cycle
integer    single_mul_count;   // times only one pipe issued a MUL
integer    total_cycles;

wire pipe0_mul_e1 = u_dut.u_issue.pipe0_mul_e1_w;
wire pipe1_mul_e1 = u_dut.u_issue.pipe1_mul_e1_w;

// PC of instructions in E1 stage
wire [31:0] pipe0_pc_e1 = u_dut.u_issue.u_pipe0_ctrl.pc_e1_q;
wire [31:0] pipe1_pc_e1 = u_dut.u_issue.u_pipe1_ctrl.pc_e1_q;

// Extra probes for debugging dual-issue
wire        opcode_a_issue  = u_dut.u_issue.opcode_a_issue_r;
wire        opcode_b_issue  = u_dut.u_issue.opcode_b_issue_r;
wire        issue_a_mul     = u_dut.u_issue.issue_a_mul_w;
wire        issue_b_mul     = u_dut.u_issue.issue_b_mul_w;
wire        dual_ok         = u_dut.u_issue.dual_issue_ok_w;
wire        opcode_a_valid  = u_dut.u_issue.opcode_a_valid_r;
wire        opcode_b_valid  = u_dut.u_issue.opcode_b_valid_r;
wire [31:0] issue_pc_a      = u_dut.u_issue.opcode0_pc_o;
wire [31:0] issue_pc_b      = u_dut.u_issue.opcode1_pc_o;
wire        lsu_stall       = u_dut.u_issue.lsu_stall_i;
wire        stall            = u_dut.u_issue.stall_w;
wire        pipe0_load_e1   = u_dut.u_issue.pipe0_load_e1_w;
wire        pipe1_load_e1   = u_dut.u_issue.pipe1_load_e1_w;

// First 3 iterations only - log in detail
reg [3:0] log_iter;
initial log_iter = 0;

initial begin
    cycle_count      = 0;
    dual_mul_count   = 0;
    single_mul_count = 0;
    total_cycles     = 0;
end

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;

        // Count MUL issue events
        if (pipe0_mul_e1 && pipe1_mul_e1)
            dual_mul_count = dual_mul_count + 1;
        else if (pipe0_mul_e1 || pipe1_mul_e1)
            single_mul_count = single_mul_count + 1;

        // Log first 20 MUL E1 events
        if ((pipe0_mul_e1 || pipe1_mul_e1) && (dual_mul_count + single_mul_count < 21))
            $display("[C%0d] E1: p0_mul=%b(pc=0x%08h) p1_mul=%b(pc=0x%08h)",
                cycle_count, pipe0_mul_e1, pipe0_pc_e1, pipe1_mul_e1, pipe1_pc_e1);

        // Detect PASS
        if (mem_i_pc_w == PASS_PC) begin
            total_cycles = cycle_count;
            $display("\n========================================");
            $display("*** PARALLEL MATMUL PASS ***");
            $display("========================================");
            $display("Total cycles       : %0d", total_cycles);
            $display("Dual-MUL cycles    : %0d  (both pipes MUL)", dual_mul_count);
            $display("Single-MUL cycles  : %0d  (one pipe MUL)", single_mul_count);
            $display("Total MUL ops      : %0d", dual_mul_count * 2 + single_mul_count);
            if (dual_mul_count + single_mul_count > 0)
                $display("Dual-issue ratio   : %0d%%",
                         dual_mul_count * 100 / (dual_mul_count + single_mul_count));
            $display("========================================");
            $finish;
        end

        // Detect FAIL
        if (mem_i_pc_w == FAIL_PC) begin
            $display("\n*** PARALLEL MATMUL FAIL ***");
            $display("Cycle: %0d  PC: 0x%08h", cycle_count, mem_i_pc_w);
            $finish;
        end

        // Timeout
        if (cycle_count > 500000) begin
            $display("\n*** TIMEOUT at cycle %0d ***", cycle_count);
            $finish;
        end
    end
end

//-------------------------------------------------------------
// Memory interface wires
//-------------------------------------------------------------
wire        mem_i_rd_w;
wire        mem_i_flush_w;
wire        mem_i_invalidate_w;
// mem_i_pc_w already declared above
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

//-------------------------------------------------------------
// DUT
//-------------------------------------------------------------
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

//-------------------------------------------------------------
// TCM memory
//-------------------------------------------------------------
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
