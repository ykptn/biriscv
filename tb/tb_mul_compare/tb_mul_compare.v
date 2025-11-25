`include "../../src/core/biriscv_defs.v"

module tb_mul_compare;

localparam PASS_PC         = 32'h80000128;
localparam FAIL_PC         = 32'h8000012c;
localparam EXPECTED_RESULT = 32'd63;

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
reg [15:0] cycle_count;
integer mul_issue_cycle;
integer mul_done_cycle;
integer mule_issue_cycle;
integer mule_done_cycle;
reg [31:0] mul_wb_value;
reg [31:0] mule_wb_value;
reg        pass_reported;
reg        fail_reported;

initial begin
    last_pc          = 32'h0;
    cycle_count      = 0;
    mul_issue_cycle  = -1;
    mul_done_cycle   = -1;
    mule_issue_cycle = -1;
    mule_done_cycle  = -1;
    mul_wb_value     = 32'h0;
    mule_wb_value    = 32'h0;
    pass_reported    = 1'b0;
    fail_reported    = 1'b0;
end

task automatic report_summary;
    input pass;
    input [31:0] pc_value;
begin
    if (pass)
    begin
        $display("\n*** COMPARE PASSED! ***");
        $display("PC reached 0x%08h and both units computed correctly: x12 = %0d, x13 = %0d",
                 pc_value,
                 u_dut.u_issue.u_regfile.REGFILE.reg_r12_q,
                 u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
    end
    else
    begin
        $display("\n*** COMPARE FAILED! ***");
        $display("PC reached 0x%08h but results differ: x12 = %0d, x13 = %0d (expected %0d)",
                 pc_value,
                 u_dut.u_issue.u_regfile.REGFILE.reg_r12_q,
                 u_dut.u_issue.u_regfile.REGFILE.reg_r13_q,
                 EXPECTED_RESULT);
    end

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

wire regs_match_w = (u_dut.u_issue.u_regfile.REGFILE.reg_r12_q == EXPECTED_RESULT) &&
                    (u_dut.u_issue.u_regfile.REGFILE.reg_r13_q == EXPECTED_RESULT);

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;

        if (mul_issue_cycle < 0 && u_dut.mul_opcode_valid_w && u_dut.mul_opcode_rd_idx_w == 5'd12) begin
            mul_issue_cycle <= cycle_count;
            $display("[Cycle %0d] MUL issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mul_opcode_ra_operand_w,
                     u_dut.mul_opcode_rb_operand_w,
                     u_dut.mul_opcode_rd_idx_w);
        end

        if (mule_issue_cycle < 0 && u_dut.mule_opcode_valid_w && u_dut.mule_opcode_rd_idx_w == 5'd13) begin
            mule_issue_cycle <= cycle_count;
            $display("[Cycle %0d] MULE issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mule_opcode_ra_operand_w,
                     u_dut.mule_opcode_rb_operand_w,
                     u_dut.mule_opcode_rd_idx_w);
        end

        if (mul_done_cycle < 0) begin
            if (pipe0_mul_wb_valid_w && pipe0_rd_wb_idx_w == 5'd12) begin
                mul_done_cycle <= cycle_count;
                mul_wb_value   <= pipe0_result_wb_data_w;
                $display("[Cycle %0d] MUL writeback x12 = %0d (pipe0 WB)",
                         cycle_count, pipe0_result_wb_data_w);
            end
            else if (pipe1_mul_wb_valid_w && pipe1_rd_wb_idx_w == 5'd12) begin
                mul_done_cycle <= cycle_count;
                mul_wb_value   <= pipe1_result_wb_data_w;
                $display("[Cycle %0d] MUL writeback x12 = %0d (pipe1 WB)",
                         cycle_count, pipe1_result_wb_data_w);
            end
        end

        if (mule_done_cycle < 0 && mule_wb_valid_w && mule_wb_rd_idx_w == 5'd13) begin
            mule_done_cycle <= cycle_count;
            mule_wb_value  <= mule_wb_value_w;
            $display("[Cycle %0d] MULE writeback x13 = %0d (raw WB signal)",
                     cycle_count, mule_wb_value_w);
        end

        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);

            if ((mem_i_pc_w == FAIL_PC) && !fail_reported) begin
                fail_reported <= 1'b1;
                report_summary(1'b0, FAIL_PC);
            end
        end

        if (!pass_reported && !fail_reported &&
            mul_done_cycle >= 0 && mule_done_cycle >= 0) begin
            if (regs_match_w) begin
                pass_reported <= 1'b1;
                report_summary(1'b1, mem_i_pc_w);
            end else begin
                fail_reported <= 1'b1;
                report_summary(1'b0, mem_i_pc_w);
            end
        end

        if (cycle_count > 2000 && !pass_reported && !fail_reported) begin
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
