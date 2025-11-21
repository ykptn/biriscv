module tb_mul_compare;

localparam PASS_PC         = 32'h80000148;
localparam FAIL_PC         = 32'h8000014C;
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
reg [31:0] cycle_count;
reg [31:0] reg_mul_prev, reg_mule_prev, reg_expected_prev;
reg [2:0]  mule_state_prev;
reg [31:0] mule_last_value;
reg        mule_seen;
reg [31:0] mul_last_value;
reg        mul_seen;
reg [31:0] mule_cycle;
reg [31:0] mul_cycle;
reg [31:0] mul_issue_cycle;
reg [31:0] mule_issue_cycle;
reg        mul_issue_seen;
reg        mule_issue_seen;

initial begin
    last_pc           = 0;
    cycle_count       = 0;
    reg_mul_prev      = 0;
    reg_mule_prev     = 0;
    reg_expected_prev = 0;
    mule_state_prev   = 0;
    mule_last_value   = 0;
    mule_seen         = 0;
    mul_last_value    = 0;
    mul_seen          = 0;
    mule_cycle        = 0;
    mul_cycle         = 0;
    mul_issue_cycle   = 0;
    mule_issue_cycle  = 0;
    mul_issue_seen    = 0;
    mule_issue_seen   = 0;
end

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;

        if (cycle_count > 0 && cycle_count < 500) begin
            reg_mul_prev      <= u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
            reg_mule_prev     <= u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
            reg_expected_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;

            if (u_dut.u_issue.u_regfile.REGFILE.reg_r12_q != reg_mul_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r13_q != reg_mule_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r14_q != reg_expected_prev) begin

                $display("[Cycle %0d] Result registers updated:", cycle_count);
                $display("      MUL result  (x12) = %0d (prev %0d)",
                    u_dut.u_issue.u_regfile.REGFILE.reg_r12_q, reg_mul_prev);
                $display("      MULE result (x13) = %0d (prev %0d)",
                    u_dut.u_issue.u_regfile.REGFILE.reg_r13_q, reg_mule_prev);
                $display("      MUL saved   (x14) = %0d (prev %0d)",
                    u_dut.u_issue.u_regfile.REGFILE.reg_r14_q, reg_expected_prev);
            end
        end

        if (u_dut.mul_opcode_valid_w && !mul_issue_seen &&
            (u_dut.mul_opcode_rd_idx_w == 5'd12)) begin
            mul_issue_cycle <= cycle_count;
            mul_issue_seen  <= 1'b1;
            $display("[Cycle %0d] MUL issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mul_opcode_ra_operand_w,
                     u_dut.mul_opcode_rb_operand_w,
                     u_dut.mul_opcode_rd_idx_w);
        end

        if (u_dut.mule_opcode_valid_w && !mule_issue_seen &&
            (u_dut.mule_opcode_rd_idx_w == 5'd13)) begin
            mule_issue_cycle <= cycle_count;
            mule_issue_seen  <= 1'b1;
            $display("[Cycle %0d] MULE issue: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mule_opcode_ra_operand_w,
                     u_dut.mule_opcode_rb_operand_w,
                     u_dut.mule_opcode_rd_idx_w);
        end

        if (u_dut.u_mule.state_q != mule_state_prev) begin
            mule_state_prev <= u_dut.u_mule.state_q;
            $display("[Cycle %0d] MULE state -> %0d | a=%0d b=%0d p0=%0d p1=%0d p2=%0d",
                     cycle_count,
                     u_dut.u_mule.state_q,
                     u_dut.u_mule.a_q,
                     u_dut.u_mule.b_q,
                     u_dut.u_mule.p0_q,
                     u_dut.u_mule.p1_q,
                     u_dut.u_mule.p2_q);
        end

        if (!mul_seen) begin
            if (u_dut.u_issue.pipe0_valid_wb_w && u_dut.u_issue.pipe0_rd_wb_w == 5'd12) begin
                mul_seen       <= 1'b1;
                mul_cycle      <= cycle_count;
                mul_last_value <= u_dut.u_issue.pipe0_result_wb_w;
                $display("[Cycle %0d] MUL writeback (pipe0) value=%0d",
                         cycle_count, u_dut.u_issue.pipe0_result_wb_w);
            end
            else if (u_dut.u_issue.pipe1_valid_wb_w && u_dut.u_issue.pipe1_rd_wb_w == 5'd12) begin
                mul_seen       <= 1'b1;
                mul_cycle      <= cycle_count;
                mul_last_value <= u_dut.u_issue.pipe1_result_wb_w;
                $display("[Cycle %0d] MUL writeback (pipe1) value=%0d",
                         cycle_count, u_dut.u_issue.pipe1_result_wb_w);
            end
        end

        if (!mule_seen) begin
            if (u_dut.u_issue.pipe0_valid_wb_w && u_dut.u_issue.pipe0_rd_wb_w == 5'd13) begin
                mule_seen       <= 1'b1;
                mule_cycle      <= cycle_count;
                mule_last_value <= u_dut.u_issue.pipe0_result_wb_w;
                $display("[Cycle %0d] MULE writeback (pipe0) value=%0d",
                         cycle_count, u_dut.u_issue.pipe0_result_wb_w);
            end
            else if (u_dut.u_issue.pipe1_valid_wb_w && u_dut.u_issue.pipe1_rd_wb_w == 5'd13) begin
                mule_seen       <= 1'b1;
                mule_cycle      <= cycle_count;
                mule_last_value <= u_dut.u_issue.pipe1_result_wb_w;
                $display("[Cycle %0d] MULE writeback (pipe1) value=%0d",
                         cycle_count, u_dut.u_issue.pipe1_result_wb_w);
            end
        end

        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);

            if (mem_i_pc_w == PASS_PC) begin
                if (mule_seen && mul_seen &&
                    (mul_last_value == mule_last_value) &&
                    (mul_last_value == EXPECTED_RESULT)) begin
                    $display("\n*** TEST PASSED! ***");
                    $display("Standard MUL writeback      = %0d", mul_last_value);
                    $display("Custom  MULE writeback      = %0d", mule_last_value);
                    $display("MUL issue/writeback cycles  = %0d -> %0d (latency %0d)",
                             mul_issue_cycle, mul_cycle, mul_cycle - mul_issue_cycle);
                    $display("MULE issue/writeback cycles = %0d -> %0d (latency %0d)",
                             mule_issue_cycle, mule_cycle, mule_cycle - mule_issue_cycle);
                    $display("Register x12                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                    $display("Register x13                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
                    $display("Register x14                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r14_q);
                end else begin
                    $display("\n*** RESULT MISMATCH! ***");
                    $display("Standard MUL writeback      = %0d (seen=%0d)", mul_last_value,  mul_seen);
                    $display("Custom  MULE writeback      = %0d (seen=%0d)", mule_last_value, mule_seen);
                    if (mul_seen)
                        $display("MUL issue/writeback cycles  = %0d -> %0d (latency %0d)",
                                 mul_issue_cycle, mul_cycle, mul_cycle - mul_issue_cycle);
                    if (mule_seen)
                        $display("MULE issue/writeback cycles = %0d -> %0d (latency %0d)",
                                 mule_issue_cycle, mule_cycle, mule_cycle - mule_issue_cycle);
                    $display("Register x12                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                    $display("Register x13                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
                    $display("Register x14                = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r14_q);
                    $display("Expected value             = %0d", EXPECTED_RESULT);
                end
                $finish;
            end
            else if (mem_i_pc_w == FAIL_PC) begin
                $display("\n*** TEST FAILED! (program detected mismatch) ***");
                $display("Standard MUL result (x12) = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                $display("Custom  MULE result (x13) = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
                $display("Saved MUL copy   (x14) = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r14_q);
                $finish;
            end
        end

        if (cycle_count > 2000) begin
            $display("\nTimeout after %0d cycles at PC 0x%08h",
                     cycle_count, mem_i_pc_w);
            $finish;
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
