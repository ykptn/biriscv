`include "../../src/core/biriscv_defs.v"

module tb_mule_only;

localparam PASS_PC         = 32'h80000190;
localparam FAIL_PC         = 32'h80000194;
localparam [31:0] TOTAL_TESTS = 32'd1000;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting MULE-only compare testbench");

    if (`TRACE) begin
        $dumpfile("mule_only.vcd");
        $dumpvars(0, tb_mule_only);
    end

    clk = 0;
    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    for (i = 0; i < 131072; i = i + 1)
        mem[i] = 0;

    f = $fopenr("./build/tcm.bin");
    i = $fread(mem, f);
    $display("Loaded %0d bytes from tcm.bin", i);
    for (i = 0; i < 131072; i = i + 1)
        u_mem.write(i, mem[i]);

    $display("RAM[0] = 0x%016h", u_mem.u_ram.ram[0]);
    $display("RAM[1] = 0x%016h", u_mem.u_ram.ram[1]);
    $display("RAM[2] = 0x%016h", u_mem.u_ram.ram[2]);
end

reg [31:0] last_pc;
reg [31:0] cycle_count;
reg [31:0] reg_r10_prev, reg_r11_prev, reg_r12_prev, reg_r13_prev;
integer mule_issue_cycle;
integer mule_done_cycle;
integer mule_last_issue_cycle;
integer mule_last_latency;
reg [31:0] mule_wb_value;
reg        pass_reported;
reg        fail_reported;
integer    mule_total_latency;
integer    mule_completed_ops;
reg        mule_inflight;

initial begin
    last_pc          = 32'h0;
    cycle_count      = 0;
    reg_r10_prev     = 32'h0;
    reg_r11_prev     = 32'h0;
    reg_r12_prev     = 32'h0;
    reg_r13_prev     = 32'h0;
    mule_issue_cycle = -1;
    mule_done_cycle  = -1;
    mule_last_issue_cycle = -1;
    mule_last_latency = 0;
    mule_wb_value    = 32'h0;
    pass_reported    = 1'b0;
    fail_reported    = 1'b0;
    mule_total_latency  = 0;
    mule_completed_ops  = 0;
    mule_inflight       = 1'b0;
    mule_last_issue_cycle = -1;
    mule_last_latency = 0;
end

wire [31:0] reg_mul_result_w  = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_mule_result_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] reg_iteration_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
wire [31:0] reg_operand_a_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
wire [31:0] reg_operand_b_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;

task automatic report_summary;
    input pass;
    input [31:0] pc_value;
    real mule_avg_latency;
begin

    mule_avg_latency = (mule_completed_ops > 0) ? (1.0 * mule_total_latency) / mule_completed_ops : 0.0;

    if (pass)
    begin
        $display("\n*** MULE-ONLY PASSED ***");
        $display("PC reached 0x%08h and MULE produced matching results: x12 = %0d, x13 = %0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w);
    end
    else
    begin
        $display("\n*** MULE-ONLY FAILED ***");
        $display("PC reached 0x%08h but results differ: x12 = %0d, x13 = %0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w);
    end

    $display("Last operands observed: ra=%0d, rb=%0d (iteration %0d of %0d)",
             reg_operand_a_w,
             reg_operand_b_w,
             reg_iteration_w,
             TOTAL_TESTS);
    $display("MULE completions: %0d, total latency %0d cycles, average %0f cycles",
             mule_completed_ops, mule_total_latency, mule_avg_latency);

    if (mule_issue_cycle >= 0 && mule_done_cycle >= 0)
        $display("MULE issue/writeback cycles = %0d -> %0d (latency %0d)",
                 mule_issue_cycle, mule_done_cycle, mule_done_cycle - mule_issue_cycle);
    else
        $display("MULE completion not observed (issue %0d, done %0d)",
                 mule_issue_cycle, mule_done_cycle);

    $finish;
end
endtask

// Instruction fetch trace (mirrors tb_mul for easier debug)
always @(posedge clk) begin
    if (!rst && mem_i_rd_w && mem_i_accept_w) begin
        $display("[Cycle %0d] FETCH: PC=0x%08h, Inst=0x%016h",
                 cycle_count, mem_i_pc_w, mem_i_inst_w);
    end
end

wire mule_wb_valid_w = u_dut.writeback_mule_valid_w;
wire [4:0] mule_wb_rd_idx_w = u_dut.writeback_mule_rd_idx_w;
wire [31:0] mule_wb_value_w = u_dut.writeback_mule_value_w;

always @(posedge clk) begin
    if (rst) begin
        cycle_count        <= 0;
        last_pc            <= 32'h0;
        reg_r10_prev       <= 32'h0;
        reg_r11_prev       <= 32'h0;
        reg_r12_prev       <= 32'h0;
        reg_r13_prev       <= 32'h0;
        mule_issue_cycle   <= -1;
        mule_done_cycle    <= -1;
        mule_last_issue_cycle <= -1;
        mule_last_latency  <= 0;
        mule_total_latency <= 0;
        mule_completed_ops <= 0;
        mule_inflight      <= 1'b0;
        pass_reported      <= 1'b0;
        fail_reported      <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        // Monitor MULE issue event (any MULE operation)
        if (!mule_inflight && u_dut.mule_opcode_valid_w) begin
            mule_issue_cycle <= cycle_count;
            mule_inflight    <= 1'b1;
            $display("[Cycle %0d] MULE issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mule_opcode_ra_operand_w,
                     u_dut.mule_opcode_rb_operand_w,
                     u_dut.mule_opcode_rd_idx_w);
        end

        // Monitor MULE writeback (any MULE completion)
        if (mule_inflight && mule_wb_valid_w) begin
            mule_done_cycle    <= cycle_count;
            mule_wb_value      <= mule_wb_value_w;
            mule_last_latency  <= cycle_count - mule_issue_cycle;
            mule_total_latency <= mule_total_latency + (cycle_count - mule_issue_cycle);
            mule_completed_ops <= mule_completed_ops + 1;
            mule_inflight      <= 1'b0;
            $display("[Cycle %0d] MULE writeback rd[%0d] = %0d (latency %0d)",
                     cycle_count, mule_wb_rd_idx_w, mule_wb_value_w, cycle_count - mule_issue_cycle);
        end

        // Check test completion
        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);

            if ((mem_i_pc_w == FAIL_PC) && !fail_reported) begin
                fail_reported <= 1'b1;
                report_summary(1'b0, FAIL_PC);
            end
            else if ((mem_i_pc_w == PASS_PC) && !pass_reported && (reg_iteration_w == TOTAL_TESTS)) begin
                pass_reported <= 1'b1;
                report_summary(1'b1, PASS_PC);
            end
        end

        if (cycle_count > 100000 && !pass_reported && !fail_reported) begin
            $display("\nTimeout after %0d cycles at PC 0x%08h",
                     cycle_count, mem_i_pc_w);
            fail_reported <= 1'b1;
            report_summary(1'b0, mem_i_pc_w);
        end
    end
end

initial begin
    forever clk = #5 ~clk;
end

wire          mem_i_rd_w;
wire          mem_i_flush_w;
wire          mem_i_invalidate_w;
wire [ 31:0]  mem_i_pc_w;
wire [ 31:0]  mem_d_addr_w;
wire [ 31:0]  mem_d_data_wr_w;
wire          mem_d_rd_w;
wire [  3:0]  mem_d_wr_w;
wire          mem_d_cacheable_w;
wire [ 10:0]  mem_d_req_tag_w;
wire          mem_d_invalidate_w;
wire          mem_d_writeback_w;
wire          mem_d_flush_w;
wire          mem_i_accept_w;
wire          mem_i_valid_w;
wire          mem_i_error_w;
wire [ 63:0]  mem_i_inst_w;
wire [ 31:0]  mem_d_data_rd_w;
wire          mem_d_accept_w;
wire          mem_d_ack_w;
wire          mem_d_error_w;
wire [ 10:0]  mem_d_resp_tag_w;

riscv_core u_dut
(
     .clk_i(clk)
    ,.rst_i(rst)
    ,.mem_d_data_rd_i(mem_d_data_rd_w)
    ,.mem_d_accept_i(mem_d_accept_w)
    ,.mem_d_ack_i(mem_d_ack_w)
    ,.mem_d_error_i(mem_d_error_w)
    ,.mem_d_resp_tag_i(mem_d_resp_tag_w)
    ,.mem_i_accept_i(mem_i_accept_w)
    ,.mem_i_valid_i(mem_i_valid_w)
    ,.mem_i_error_i(mem_i_error_w)
    ,.mem_i_inst_i(mem_i_inst_w)
    ,.intr_i(1'b0)
    ,.reset_vector_i(32'h80000000)
    ,.cpu_id_i('b0)
    ,.mem_d_addr_o(mem_d_addr_w)
    ,.mem_d_data_wr_o(mem_d_data_wr_w)
    ,.mem_d_rd_o(mem_d_rd_w)
    ,.mem_d_wr_o(mem_d_wr_w)
    ,.mem_d_cacheable_o(mem_d_cacheable_w)
    ,.mem_d_req_tag_o(mem_d_req_tag_w)
    ,.mem_d_invalidate_o(mem_d_invalidate_w)
    ,.mem_d_writeback_o(mem_d_writeback_w)
    ,.mem_d_flush_o(mem_d_flush_w)
    ,.mem_i_rd_o(mem_i_rd_w)
    ,.mem_i_flush_o(mem_i_flush_w)
    ,.mem_i_invalidate_o(mem_i_invalidate_w)
    ,.mem_i_pc_o(mem_i_pc_w)
);


tcm_mem u_mem
(
     .clk_i(clk)
    ,.rst_i(rst)
    ,.mem_i_rd_i(mem_i_rd_w)
    ,.mem_i_flush_i(mem_i_flush_w)
    ,.mem_i_invalidate_i(mem_i_invalidate_w)
    ,.mem_i_pc_i(mem_i_pc_w)
    ,.mem_d_addr_i(mem_d_addr_w)
    ,.mem_d_data_wr_i(mem_d_data_wr_w)
    ,.mem_d_rd_i(mem_d_rd_w)
    ,.mem_d_wr_i(mem_d_wr_w)
    ,.mem_d_cacheable_i(mem_d_cacheable_w)
    ,.mem_d_req_tag_i(mem_d_req_tag_w)
    ,.mem_d_invalidate_i(mem_d_invalidate_w)
    ,.mem_d_writeback_i(mem_d_writeback_w)
    ,.mem_d_flush_i(mem_d_flush_w)
    ,.mem_i_accept_o(mem_i_accept_w)
    ,.mem_i_valid_o(mem_i_valid_w)
    ,.mem_i_error_o(mem_i_error_w)
    ,.mem_i_inst_o(mem_i_inst_w)
    ,.mem_d_data_rd_o(mem_d_data_rd_w)
    ,.mem_d_accept_o(mem_d_accept_w)
    ,.mem_d_ack_o(mem_d_ack_w)
    ,.mem_d_error_o(mem_d_error_w)
    ,.mem_d_resp_tag_o(mem_d_resp_tag_w)
);

endmodule
