`include "../../src/core/biriscv_defs.v"

module tb_mul_compare;

localparam PASS_PC         = 32'h80000190;
localparam FAIL_PC         = 32'h80000194;
localparam [31:0] TOTAL_TESTS = 32'd1000;
localparam integer MUL_LAT_FIFO_DEPTH = 128;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting MUL vs MULE compare testbench");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_mul_compare);
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
integer mul_issue_cycle;
integer mul_done_cycle;
integer mule_issue_cycle;
integer mule_done_cycle;
reg [31:0] mul_wb_value;
reg [31:0] mule_wb_value;
reg        pass_reported;
reg        fail_reported;
integer    mul_total_latency;
integer    mule_total_latency;
integer    mul_completed_ops;
integer    mule_completed_ops;
reg        mule_inflight;
integer    mul_issue_fifo   [0:MUL_LAT_FIFO_DEPTH-1];
integer    mul_fifo_wr_ptr;
integer    mul_fifo_rd_ptr;
integer    mul_fifo_count;
integer    mul_issue_cycle_entry;
reg        pipe0_mul_e1_prev;
reg        pipe1_mul_e1_prev;

initial begin
    last_pc          = 32'h0;
    cycle_count      = 0;
    reg_r10_prev     = 32'h0;
    reg_r11_prev     = 32'h0;
    reg_r12_prev     = 32'h0;
    reg_r13_prev     = 32'h0;
    mul_issue_cycle  = -1;
    mul_done_cycle   = -1;
    mule_issue_cycle = -1;
    mule_done_cycle  = -1;
    mul_wb_value     = 32'h0;
    mule_wb_value    = 32'h0;
    pass_reported    = 1'b0;
    fail_reported    = 1'b0;
    mul_total_latency   = 0;
    mule_total_latency  = 0;
    mul_completed_ops   = 0;
    mule_completed_ops  = 0;
    mule_inflight       = 1'b0;
    mul_fifo_wr_ptr     = 0;
    mul_fifo_rd_ptr     = 0;
    mul_fifo_count      = 0;
    pipe0_mul_e1_prev   = 1'b0;
    pipe1_mul_e1_prev   = 1'b0;
end

wire [31:0] reg_mul_result_w  = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_mule_result_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] reg_iteration_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
wire [31:0] reg_operand_a_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
wire [31:0] reg_operand_b_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;

task automatic report_summary;
    input pass;
    input [31:0] pc_value;
    real mul_avg_latency;
    real mule_avg_latency;
begin

    mul_avg_latency  = (mul_completed_ops  > 0) ? (1.0 * mul_total_latency)  / mul_completed_ops  : 0.0;
    mule_avg_latency = (mule_completed_ops > 0) ? (1.0 * mule_total_latency) / mule_completed_ops : 0.0;

    if (pass)
    begin
        $display("\n*** COMPARE PASSED! ***");
        $display("PC reached 0x%08h and both units computed correctly: x12 = %0d, x13 = %0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w);
    end
    else
    begin
        $display("\n*** COMPARE FAILED! ***");
        $display("PC reached 0x%08h but results differ: x12 = %0d, x13 = %0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w);
    end

    $display("Last operands observed: mul=%0d, mule=%0d (iteration %0d of %0d)",
             reg_operand_a_w,
             reg_operand_b_w,
             reg_iteration_w,
             TOTAL_TESTS);
    $display("MUL  completions: %0d, total latency %0d cycles, average %0f cycles",
             mul_completed_ops, mul_total_latency, mul_avg_latency);
    $display("MULE completions: %0d, total latency %0d cycles, average %0f cycles",
             mule_completed_ops, mule_total_latency, mule_avg_latency);

    if (mul_issue_cycle >= 0 && mul_done_cycle >= 0)
        $display("MUL issue/writeback cycles  = %0d -> %0d (latency %0d)",
                 mul_issue_cycle, mul_done_cycle, mul_done_cycle - mul_issue_cycle);
    else
        $display("MUL completion not observed (issue %0d, done %0d)",
                 mul_issue_cycle, mul_done_cycle);

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

wire pipe0_mul_wb_valid_w = u_dut.u_issue.pipe0_valid_wb_w &&
                            u_dut.u_issue.u_pipe0_ctrl.ctrl_wb_q[`PCINFO_MUL];
wire [4:0]  pipe0_rd_wb_idx_w    = u_dut.u_issue.pipe0_rd_wb_w;
wire [31:0] pipe0_result_wb_data_w = u_dut.u_issue.pipe0_result_wb_w;

wire pipe1_mul_wb_valid_w = u_dut.u_issue.pipe1_valid_wb_w &&
                            u_dut.u_issue.u_pipe1_ctrl.ctrl_wb_q[`PCINFO_MUL];
wire [4:0]  pipe1_rd_wb_idx_w    = u_dut.u_issue.pipe1_rd_wb_w;
wire [31:0] pipe1_result_wb_data_w = u_dut.u_issue.pipe1_result_wb_w;

wire mule_wb_valid_w = u_dut.writeback_mule_valid_w;
wire [4:0] mule_wb_rd_idx_w = u_dut.writeback_mule_rd_idx_w;
wire [31:0] mule_wb_value_w = u_dut.writeback_mule_value_w;
wire pipe0_mul_issue_event_w = u_dut.u_issue.pipe0_mul_e1_w &&
                               ~pipe0_mul_e1_prev &&
                               (u_dut.u_issue.pipe0_rd_e1_w == 5'd12);
wire pipe1_mul_issue_event_w = u_dut.u_issue.pipe1_mul_e1_w &&
                               ~pipe1_mul_e1_prev &&
                               (u_dut.u_issue.pipe1_rd_e1_w == 5'd12);

always @(posedge clk) begin
    if (rst) begin
        cycle_count        <= 0;
        last_pc            <= 32'h0;
        reg_r10_prev       <= 32'h0;
        reg_r11_prev       <= 32'h0;
        reg_r12_prev       <= 32'h0;
        reg_r13_prev       <= 32'h0;
        mul_issue_cycle    <= -1;
        mul_done_cycle     <= -1;
        mule_issue_cycle   <= -1;
        mule_done_cycle    <= -1;
        mul_total_latency  <= 0;
        mule_total_latency <= 0;
        mul_completed_ops  <= 0;
        mule_completed_ops <= 0;
        mule_inflight      <= 1'b0;
        pass_reported      <= 1'b0;
        fail_reported      <= 1'b0;
        mul_fifo_wr_ptr    <= 0;
        mul_fifo_rd_ptr    <= 0;
        mul_fifo_count     <= 0;
        pipe0_mul_e1_prev  <= 1'b0;
        pipe1_mul_e1_prev  <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        if (cycle_count > 0 && cycle_count < 200) begin
            reg_r10_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
            reg_r11_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r11_q;
            reg_r12_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
            reg_r13_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;

            if (u_dut.u_issue.u_regfile.REGFILE.reg_r10_q != reg_r10_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r11_q != reg_r11_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r12_q != reg_r12_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r13_q != reg_r13_prev) begin

                $display("[Cycle %0d] Register update detected:", cycle_count);
                $display("      x10 (a0) = %0d (prev: %0d)",
                         u_dut.u_issue.u_regfile.REGFILE.reg_r10_q, reg_r10_prev);
                $display("      x11 (a1) = %0d (prev: %0d)",
                         u_dut.u_issue.u_regfile.REGFILE.reg_r11_q, reg_r11_prev);
                $display("      x12 (a2) = %0d (prev: %0d)",
                         u_dut.u_issue.u_regfile.REGFILE.reg_r12_q, reg_r12_prev);
                $display("      x13 (a3) = %0d (prev: %0d)",
                         u_dut.u_issue.u_regfile.REGFILE.reg_r13_q, reg_r13_prev);
            end
        end

        if (pipe0_mul_issue_event_w) begin
            if (mul_fifo_count < MUL_LAT_FIFO_DEPTH) begin
                mul_issue_cycle <= (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_issue_fifo[mul_fifo_wr_ptr] = (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_fifo_wr_ptr <= (mul_fifo_wr_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_wr_ptr + 1;
                mul_fifo_count  <= mul_fifo_count + 1;
                $display("[Cycle %0d] MUL issue (pipe0): ra=%0d rb=%0d rd=%0d (fifo depth %0d)",
                         cycle_count,
                         u_dut.u_issue.pipe0_operand_ra_e1_w,
                         u_dut.u_issue.pipe0_operand_rb_e1_w,
                         u_dut.u_issue.pipe0_rd_e1_w,
                         mul_fifo_count + 1);
            end else begin
                $display("[Cycle %0d] WARNING: MUL latency FIFO overflow", cycle_count);
            end
        end
        if (pipe1_mul_issue_event_w) begin
            if (mul_fifo_count < MUL_LAT_FIFO_DEPTH) begin
                mul_issue_cycle <= (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_issue_fifo[mul_fifo_wr_ptr] = (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_fifo_wr_ptr <= (mul_fifo_wr_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_wr_ptr + 1;
                mul_fifo_count  <= mul_fifo_count + 1;
                $display("[Cycle %0d] MUL issue (pipe1): ra=%0d rb=%0d rd=%0d (fifo depth %0d)",
                         cycle_count,
                         u_dut.u_issue.pipe1_operand_ra_e1_w,
                         u_dut.u_issue.pipe1_operand_rb_e1_w,
                         u_dut.u_issue.pipe1_rd_e1_w,
                         mul_fifo_count + 1);
            end else begin
                $display("[Cycle %0d] WARNING: MUL latency FIFO overflow", cycle_count);
            end
        end

        if (!mule_inflight && u_dut.mule_opcode_valid_w && u_dut.mule_opcode_rd_idx_w == 5'd13) begin
            mule_issue_cycle <= cycle_count;
            mule_inflight    <= 1'b1;
            $display("[Cycle %0d] MULE issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mule_opcode_ra_operand_w,
                     u_dut.mule_opcode_rb_operand_w,
                     u_dut.mule_opcode_rd_idx_w);
        end

        if (pipe0_mul_wb_valid_w && pipe0_rd_wb_idx_w == 5'd12) begin
            mul_issue_cycle_entry = (mul_fifo_count > 0) ? mul_issue_fifo[mul_fifo_rd_ptr] : cycle_count;
            if (mul_fifo_count > 0) begin
                mul_fifo_rd_ptr  <= (mul_fifo_rd_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_rd_ptr + 1;
                mul_fifo_count   <= mul_fifo_count - 1;
            end else begin
                $display("[Cycle %0d] WARNING: MUL writeback observed with empty FIFO", cycle_count);
            end

            mul_issue_cycle   <= mul_issue_cycle_entry;
            mul_done_cycle    <= cycle_count;
            mul_wb_value      <= pipe0_result_wb_data_w;
            mul_total_latency <= mul_total_latency + (cycle_count - mul_issue_cycle_entry);
            mul_completed_ops <= mul_completed_ops + 1;
            $display("[Cycle %0d] MUL writeback x12 = %0d (pipe0 WB, latency %0d) -- iter %0d",
                     cycle_count, pipe0_result_wb_data_w, cycle_count - mul_issue_cycle_entry, reg_iteration_w);
        end
        else if (pipe1_mul_wb_valid_w && pipe1_rd_wb_idx_w == 5'd12) begin
            mul_issue_cycle_entry = (mul_fifo_count > 0) ? mul_issue_fifo[mul_fifo_rd_ptr] : cycle_count;
            if (mul_fifo_count > 0) begin
                mul_fifo_rd_ptr  <= (mul_fifo_rd_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_rd_ptr + 1;
                mul_fifo_count   <= mul_fifo_count - 1;
            end else begin
                $display("[Cycle %0d] WARNING: MUL writeback observed with empty FIFO", cycle_count);
            end

            mul_issue_cycle   <= mul_issue_cycle_entry;
            mul_done_cycle    <= cycle_count;
            mul_wb_value      <= pipe1_result_wb_data_w;
            mul_total_latency <= mul_total_latency + (cycle_count - mul_issue_cycle_entry);
            mul_completed_ops <= mul_completed_ops + 1;
            $display("[Cycle %0d] MUL writeback x12 = %0d (pipe1 WB, latency %0d) -- iter %0d",
                     cycle_count, pipe1_result_wb_data_w, cycle_count - mul_issue_cycle_entry, reg_iteration_w);
        end

        if (mule_inflight && mule_wb_valid_w && mule_wb_rd_idx_w == 5'd13) begin
            mule_done_cycle    <= cycle_count;
            mule_wb_value      <= mule_wb_value_w;
            mule_total_latency <= mule_total_latency + (cycle_count - mule_issue_cycle);
            mule_completed_ops <= mule_completed_ops + 1;
            mule_inflight      <= 1'b0;
            $display("[Cycle %0d] MULE writeback x13 = %0d (raw WB signal) -- iter %0d",
                     cycle_count, mule_wb_value_w, reg_iteration_w);
        end

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

        pipe0_mul_e1_prev <= u_dut.u_issue.pipe0_mul_e1_w;
        pipe1_mul_e1_prev <= u_dut.u_issue.pipe1_mul_e1_w;
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
