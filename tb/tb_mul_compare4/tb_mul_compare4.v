`include "../../src/core/biriscv_defs.v"

module tb_mul_compare;

localparam [31:0] TOTAL_TESTS = 32'd1000;
localparam integer MUL_LAT_FIFO_DEPTH = 128;

reg [31:0] PASS_PC;
reg [31:0] FAIL_PC;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;
reg [1023:0] vcd_name;

initial begin

    $display("Starting 4-MUL compare testbench (MUL / MULE / CBM / MULP)");

    // Read PASS_PC / FAIL_PC from plusargs (set by makefile after objdump)
    if (!$value$plusargs("passpc=%h", PASS_PC))
        PASS_PC = 32'h800001c0;   // fallback
    if (!$value$plusargs("failpc=%h", FAIL_PC))
        FAIL_PC = 32'h800001d0;   // fallback
    $display("PASS_PC = 0x%08h, FAIL_PC = 0x%08h", PASS_PC, FAIL_PC);

    if (`TRACE) begin
        if (!$value$plusargs("dumpfile=%s", vcd_name)) begin
            vcd_name = "waveform.vcd";
        end
        $display("Dumping VCD to %0s", vcd_name);
        $dumpfile(vcd_name);
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

// ========================================================================
// Tracking state
// ========================================================================
reg [31:0] last_pc;
reg [31:0] cycle_count;

reg [31:0] reg_r10_prev, reg_r11_prev, reg_r12_prev, reg_r13_prev, reg_r14_prev, reg_r20_prev;
integer    pass_pc_count;
integer    fail_pc_count;

integer mul_issue_cycle,  mul_done_cycle;
integer mule_issue_cycle, mule_done_cycle;
integer cbm_issue_cycle,  cbm_done_cycle;
integer mulp_issue_cycle, mulp_done_cycle;

reg [31:0] mul_wb_value;
reg [31:0] mule_wb_value;

reg        pass_reported;
reg        fail_reported;

integer    mul_total_latency,  mul_completed_ops;
integer    mule_total_latency, mule_completed_ops;
integer    cbm_total_latency,  cbm_completed_ops;
integer    mulp_total_latency, mulp_completed_ops;

reg        mule_inflight;
reg        cbm_inflight;
reg        mulp_inflight;

integer    mul_issue_fifo   [0:MUL_LAT_FIFO_DEPTH-1];
integer    mul_fifo_wr_ptr;
integer    mul_fifo_rd_ptr;
integer    mul_fifo_count;
integer    mul_issue_cycle_entry;

reg        pipe0_mul_e1_prev;
reg        pipe1_mul_e1_prev;

initial begin
    last_pc              = 32'h0;
    cycle_count          = 0;
    reg_r10_prev         = 32'h0;
    reg_r11_prev         = 32'h0;
    reg_r12_prev         = 32'h0;
    reg_r13_prev         = 32'h0;
    reg_r14_prev         = 32'h0;
    reg_r20_prev         = 32'h0;
    pass_pc_count        = 0;
    fail_pc_count        = 0;
    mul_issue_cycle      = -1;
    mul_done_cycle       = -1;
    mule_issue_cycle     = -1;
    mule_done_cycle      = -1;
    cbm_issue_cycle      = -1;
    cbm_done_cycle       = -1;
    mulp_issue_cycle     = -1;
    mulp_done_cycle      = -1;
    mul_wb_value         = 32'h0;
    mule_wb_value        = 32'h0;
    pass_reported        = 1'b0;
    fail_reported        = 1'b0;
    mul_total_latency    = 0;
    mule_total_latency   = 0;
    cbm_total_latency    = 0;
    mulp_total_latency   = 0;
    mul_completed_ops    = 0;
    mule_completed_ops   = 0;
    cbm_completed_ops    = 0;
    mulp_completed_ops   = 0;
    mule_inflight        = 1'b0;
    cbm_inflight         = 1'b0;
    mulp_inflight        = 1'b0;
    mul_fifo_wr_ptr      = 0;
    mul_fifo_rd_ptr      = 0;
    mul_fifo_count       = 0;
    pipe0_mul_e1_prev    = 1'b0;
    pipe1_mul_e1_prev    = 1'b0;
end

// ========================================================================
// Register-file probes
// ========================================================================
wire [31:0] reg_mul_result_w  = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_mule_result_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] reg_cbm_result_w  = u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
wire [31:0] reg_mulp_result_w = u_dut.u_issue.u_regfile.REGFILE.reg_r20_q;
wire [31:0] reg_iteration_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
wire [31:0] reg_operand_a_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
wire [31:0] reg_operand_b_w   = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;

// ========================================================================
// summary task
// ========================================================================
task automatic report_summary;
    input pass;
    input [31:0] pc_value;
    real mul_avg, mule_avg, cbm_avg, mulp_avg;
begin

    mul_avg  = (mul_completed_ops  > 0) ? (1.0 * mul_total_latency)  / mul_completed_ops  : 0.0;
    mule_avg = (mule_completed_ops > 0) ? (1.0 * mule_total_latency) / mule_completed_ops : 0.0;
    cbm_avg  = (cbm_completed_ops  > 0) ? (1.0 * cbm_total_latency)  / cbm_completed_ops  : 0.0;
    mulp_avg = (mulp_completed_ops > 0) ? (1.0 * mulp_total_latency) / mulp_completed_ops : 0.0;

    if (pass) begin
        $display("\n*** 4-MUL COMPARE PASSED! ***");
        $display("PC = 0x%08h | x12=%0d  x13=%0d  x14=%0d  x20=%0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w,
                 reg_cbm_result_w,
                 reg_mulp_result_w);
    end else begin
        $display("\n*** 4-MUL COMPARE FAILED! ***");
        $display("PC = 0x%08h | x12=%0d  x13=%0d  x14=%0d  x20=%0d",
                 pc_value,
                 reg_mul_result_w,
                 reg_mule_result_w,
                 reg_cbm_result_w,
                 reg_mulp_result_w);
    end

    $display("Operands: a=%0d  b=%0d  (iter %0d / %0d)",
             reg_operand_a_w, reg_operand_b_w,
             reg_iteration_w, TOTAL_TESTS);

    $display("MUL   completions: %0d, total %0d cyc, avg %0f cyc",
             mul_completed_ops,  mul_total_latency,  mul_avg);
    $display("MULE  completions: %0d, total %0d cyc, avg %0f cyc",
             mule_completed_ops, mule_total_latency, mule_avg);
    $display("CBM   completions: %0d, total %0d cyc, avg %0f cyc",
             cbm_completed_ops,  cbm_total_latency,  cbm_avg);
    $display("MULP  completions: %0d, total %0d cyc, avg %0f cyc",
             mulp_completed_ops, mulp_total_latency, mulp_avg);

    $finish;
end
endtask

// ========================================================================
// Instruction fetch trace (first 200 cycles)
// ========================================================================
always @(posedge clk) begin
    if (!rst && mem_i_rd_w && mem_i_accept_w) begin
        $display("[Cycle %0d] FETCH: PC=0x%08h, Inst=0x%016h",
                 cycle_count, mem_i_pc_w, mem_i_inst_w);
    end
end

// ========================================================================
// MUL pipeline issue / writeback probes  (dual-issue pipes)
// ========================================================================
wire pipe0_mul_wb_valid_w = u_dut.u_issue.pipe0_valid_wb_w &&
                            u_dut.u_issue.u_pipe0_ctrl.ctrl_wb_q[`PCINFO_MUL];
wire [4:0]  pipe0_rd_wb_idx_w      = u_dut.u_issue.pipe0_rd_wb_w;
wire [31:0] pipe0_result_wb_data_w = u_dut.u_issue.pipe0_result_wb_w;

wire pipe1_mul_wb_valid_w = u_dut.u_issue.pipe1_valid_wb_w &&
                            u_dut.u_issue.u_pipe1_ctrl.ctrl_wb_q[`PCINFO_MUL];
wire [4:0]  pipe1_rd_wb_idx_w      = u_dut.u_issue.pipe1_rd_wb_w;
wire [31:0] pipe1_result_wb_data_w = u_dut.u_issue.pipe1_result_wb_w;

// MULE
wire mule_wb_valid_w  = u_dut.writeback_mule_valid_w;
wire [4:0]  mule_wb_rd_idx_w = u_dut.writeback_mule_rd_idx_w;
wire [31:0] mule_wb_value_w  = u_dut.writeback_mule_value_w;

// CBM
wire cbm_issue_valid_w = u_dut.cbm_opcode_valid_w && (u_dut.cbm_opcode_rd_idx_w == 5'd14);
wire [31:0] cbm_issue_ra_w = u_dut.cbm_opcode_ra_operand_w;
wire [31:0] cbm_issue_rb_w = u_dut.cbm_opcode_rb_operand_w;
wire cbm_wb_valid_w  = u_dut.writeback_cbm_valid_w;
wire [4:0]  cbm_wb_rd_idx_w = u_dut.writeback_cbm_rd_idx_w;
wire [31:0] cbm_wb_value_w  = u_dut.writeback_cbm_value_w;

// MULP
wire mulp_issue_valid_w = u_dut.mulp_opcode_valid_w && (u_dut.mulp_opcode_rd_idx_w == 5'd20);
wire [31:0] mulp_issue_ra_w = u_dut.mulp_opcode_ra_operand_w;
wire [31:0] mulp_issue_rb_w = u_dut.mulp_opcode_rb_operand_w;
wire mulp_wb_valid_w  = u_dut.writeback_mulp_valid_w;
wire [4:0]  mulp_wb_rd_idx_w = u_dut.writeback_mulp_rd_idx_w;
wire [31:0] mulp_wb_value_w  = u_dut.writeback_mulp_value_w;

localparam PC_STABLE_THRESH = 3;  // require PC at pass/fail for N cycles

// MUL issue edge detection
wire pipe0_mul_issue_event_w = u_dut.u_issue.pipe0_mul_e1_w &&
                               ~pipe0_mul_e1_prev &&
                               (u_dut.u_issue.pipe0_rd_e1_w == 5'd12);
wire pipe1_mul_issue_event_w = u_dut.u_issue.pipe1_mul_e1_w &&
                               ~pipe1_mul_e1_prev &&
                               (u_dut.u_issue.pipe1_rd_e1_w == 5'd12);

// ========================================================================
// Main tracking always block
// ========================================================================
always @(posedge clk) begin
    if (rst) begin
        cycle_count        <= 0;
        last_pc            <= 32'h0;
        reg_r10_prev       <= 32'h0;
        reg_r11_prev       <= 32'h0;
        reg_r12_prev       <= 32'h0;
        reg_r13_prev       <= 32'h0;
        reg_r14_prev       <= 32'h0;
        reg_r20_prev       <= 32'h0;
        pass_pc_count      <= 0;
        fail_pc_count      <= 0;
        mul_issue_cycle    <= -1;
        mul_done_cycle     <= -1;
        mule_issue_cycle   <= -1;
        mule_done_cycle    <= -1;
        cbm_issue_cycle    <= -1;
        cbm_done_cycle     <= -1;
        mulp_issue_cycle   <= -1;
        mulp_done_cycle    <= -1;
        mul_total_latency  <= 0;
        mule_total_latency <= 0;
        cbm_total_latency  <= 0;
        mulp_total_latency <= 0;
        mul_completed_ops  <= 0;
        mule_completed_ops <= 0;
        cbm_completed_ops  <= 0;
        mulp_completed_ops <= 0;
        mule_inflight      <= 1'b0;
        cbm_inflight       <= 1'b0;
        mulp_inflight      <= 1'b0;
        pass_reported      <= 1'b0;
        fail_reported      <= 1'b0;
        mul_fifo_wr_ptr    <= 0;
        mul_fifo_rd_ptr    <= 0;
        mul_fifo_count     <= 0;
        pipe0_mul_e1_prev  <= 1'b0;
        pipe1_mul_e1_prev  <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        // ------ early register-change trace (first 200 cycles) ------
        if (cycle_count > 0 && cycle_count < 200) begin
            reg_r10_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
            reg_r11_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r11_q;
            reg_r12_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
            reg_r13_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
            reg_r14_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
            reg_r20_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r20_q;

            if (u_dut.u_issue.u_regfile.REGFILE.reg_r10_q != reg_r10_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r11_q != reg_r11_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r12_q != reg_r12_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r13_q != reg_r13_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r14_q != reg_r14_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r20_q != reg_r20_prev) begin

                $display("[Cycle %0d] Register update:", cycle_count);
                $display("  x10=%0d  x11=%0d  x12=%0d  x13=%0d  x14=%0d  x20=%0d",
                         u_dut.u_issue.u_regfile.REGFILE.reg_r10_q,
                         u_dut.u_issue.u_regfile.REGFILE.reg_r11_q,
                         u_dut.u_issue.u_regfile.REGFILE.reg_r12_q,
                         u_dut.u_issue.u_regfile.REGFILE.reg_r13_q,
                         u_dut.u_issue.u_regfile.REGFILE.reg_r14_q,
                         u_dut.u_issue.u_regfile.REGFILE.reg_r20_q);
            end
        end

        // ------ MUL issue (FIFO-based, dual-issue pipes) ------
        if (pipe0_mul_issue_event_w) begin
            if (mul_fifo_count < MUL_LAT_FIFO_DEPTH) begin
                mul_issue_cycle <= (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_issue_fifo[mul_fifo_wr_ptr] = (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_fifo_wr_ptr <= (mul_fifo_wr_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_wr_ptr + 1;
                mul_fifo_count  <= mul_fifo_count + 1;
                $display("[Cycle %0d] MUL issue (pipe0): rd=%0d (fifo %0d)",
                         cycle_count, u_dut.u_issue.pipe0_rd_e1_w, mul_fifo_count + 1);
            end
        end
        if (pipe1_mul_issue_event_w) begin
            if (mul_fifo_count < MUL_LAT_FIFO_DEPTH) begin
                mul_issue_cycle <= (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_issue_fifo[mul_fifo_wr_ptr] = (cycle_count > 0) ? (cycle_count - 1) : cycle_count;
                mul_fifo_wr_ptr <= (mul_fifo_wr_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_wr_ptr + 1;
                mul_fifo_count  <= mul_fifo_count + 1;
                $display("[Cycle %0d] MUL issue (pipe1): rd=%0d (fifo %0d)",
                         cycle_count, u_dut.u_issue.pipe1_rd_e1_w, mul_fifo_count + 1);
            end
        end

        // ------ MULE issue ------
        if (!mule_inflight && u_dut.mule_opcode_valid_w && u_dut.mule_opcode_rd_idx_w == 5'd13) begin
            mule_issue_cycle <= cycle_count;
            mule_inflight    <= 1'b1;
            $display("[Cycle %0d] MULE issue: rd=13", cycle_count);
        end

        // ------ CBM issue ------
        if (!cbm_inflight && cbm_issue_valid_w) begin
            cbm_issue_cycle <= cycle_count;
            cbm_inflight    <= 1'b1;
            $display("[Cycle %0d] CBM issue: rd=14", cycle_count);
        end

        // ------ MULP issue ------
        if (!mulp_inflight && mulp_issue_valid_w) begin
            mulp_issue_cycle <= cycle_count;
            mulp_inflight    <= 1'b1;
            $display("[Cycle %0d] MULP issue: rd=20", cycle_count);
        end

        // ------ MUL writeback (pipe0 / pipe1) ------
        if (pipe0_mul_wb_valid_w && pipe0_rd_wb_idx_w == 5'd12) begin
            mul_issue_cycle_entry = (mul_fifo_count > 0) ? mul_issue_fifo[mul_fifo_rd_ptr] : cycle_count;
            if (mul_fifo_count > 0) begin
                mul_fifo_rd_ptr <= (mul_fifo_rd_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_rd_ptr + 1;
                mul_fifo_count  <= mul_fifo_count - 1;
            end
            mul_done_cycle    <= cycle_count;
            mul_wb_value      <= pipe0_result_wb_data_w;
            mul_total_latency <= mul_total_latency + (cycle_count - mul_issue_cycle_entry);
            mul_completed_ops <= mul_completed_ops + 1;
            $display("[Cycle %0d] MUL  WB x12=%0d  lat=%0d  iter=%0d",
                     cycle_count, pipe0_result_wb_data_w,
                     cycle_count - mul_issue_cycle_entry, reg_iteration_w);
        end
        else if (pipe1_mul_wb_valid_w && pipe1_rd_wb_idx_w == 5'd12) begin
            mul_issue_cycle_entry = (mul_fifo_count > 0) ? mul_issue_fifo[mul_fifo_rd_ptr] : cycle_count;
            if (mul_fifo_count > 0) begin
                mul_fifo_rd_ptr <= (mul_fifo_rd_ptr == (MUL_LAT_FIFO_DEPTH-1)) ? 0 : mul_fifo_rd_ptr + 1;
                mul_fifo_count  <= mul_fifo_count - 1;
            end
            mul_done_cycle    <= cycle_count;
            mul_wb_value      <= pipe1_result_wb_data_w;
            mul_total_latency <= mul_total_latency + (cycle_count - mul_issue_cycle_entry);
            mul_completed_ops <= mul_completed_ops + 1;
            $display("[Cycle %0d] MUL  WB x12=%0d  lat=%0d  iter=%0d",
                     cycle_count, pipe1_result_wb_data_w,
                     cycle_count - mul_issue_cycle_entry, reg_iteration_w);
        end

        // ------ MULE writeback ------
        if (mule_inflight && mule_wb_valid_w && mule_wb_rd_idx_w == 5'd13) begin
            mule_done_cycle    <= cycle_count;
            mule_wb_value      <= mule_wb_value_w;
            mule_total_latency <= mule_total_latency + (cycle_count - mule_issue_cycle);
            mule_completed_ops <= mule_completed_ops + 1;
            mule_inflight      <= 1'b0;
            $display("[Cycle %0d] MULE WB x13=%0d  lat=%0d  iter=%0d",
                     cycle_count, mule_wb_value_w,
                     cycle_count - mule_issue_cycle, reg_iteration_w);
        end

        // ------ CBM writeback ------
        if (cbm_inflight && cbm_wb_valid_w && cbm_wb_rd_idx_w == 5'd14) begin
            cbm_done_cycle    <= cycle_count;
            cbm_total_latency <= cbm_total_latency + (cycle_count - cbm_issue_cycle);
            cbm_completed_ops <= cbm_completed_ops + 1;
            cbm_inflight      <= 1'b0;
            $display("[Cycle %0d] CBM  WB x14=%0d  lat=%0d  iter=%0d",
                     cycle_count, cbm_wb_value_w,
                     cycle_count - cbm_issue_cycle, reg_iteration_w);
        end

        // ------ MULP writeback ------
        if (mulp_inflight && mulp_wb_valid_w && mulp_wb_rd_idx_w == 5'd20) begin
            mulp_done_cycle    <= cycle_count;
            mulp_total_latency <= mulp_total_latency + (cycle_count - mulp_issue_cycle);
            mulp_completed_ops <= mulp_completed_ops + 1;
            mulp_inflight      <= 1'b0;
            $display("[Cycle %0d] MULP WB x20=%0d  lat=%0d  iter=%0d",
                     cycle_count, mulp_wb_value_w,
                     cycle_count - mulp_issue_cycle, reg_iteration_w);
        end

        // ------ PC pass/fail detection (stable-count approach) ------
        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);
        end

        // Count consecutive cycles at pass/fail PC
        if (mem_i_pc_w == FAIL_PC)
            fail_pc_count <= fail_pc_count + 1;
        else
            fail_pc_count <= 0;

        if (mem_i_pc_w == PASS_PC)
            pass_pc_count <= pass_pc_count + 1;
        else
            pass_pc_count <= 0;

        if (fail_pc_count >= PC_STABLE_THRESH && !fail_reported) begin
            fail_reported <= 1'b1;
            report_summary(1'b0, FAIL_PC);
        end
        else if (pass_pc_count >= PC_STABLE_THRESH && !pass_reported) begin
            pass_reported <= 1'b1;
            report_summary(1'b1, PASS_PC);
        end

        // ------ timeout ------
        if (cycle_count > 200000 && !pass_reported && !fail_reported) begin
            $display("\nTimeout after %0d cycles at PC 0x%08h", cycle_count, mem_i_pc_w);
            fail_reported <= 1'b1;
            report_summary(1'b0, mem_i_pc_w);
        end

        pipe0_mul_e1_prev <= u_dut.u_issue.pipe0_mul_e1_w;
        pipe1_mul_e1_prev <= u_dut.u_issue.pipe1_mul_e1_w;
    end
end

// ========================================================================
// Clock
// ========================================================================
initial begin
    forever clk = #5 ~clk;
end

// ========================================================================
// DUT + Memory
// ========================================================================
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
