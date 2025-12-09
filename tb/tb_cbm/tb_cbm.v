module tb_cbm;

reg clk;
reg rst;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting CBM standalone testbench");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_cbm);
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
reg        pass_reported;
reg        fail_reported;
wire [31:0] reg_r10_w = u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
wire [31:0] reg_r11_w = u_dut.u_issue.u_regfile.REGFILE.reg_r11_q;
wire [31:0] reg_r12_w = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_r13_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [63:0] expected_full_w = reg_r10_w * reg_r11_w;
wire [31:0] expected_result_w = expected_full_w[31:0];

initial begin
    last_pc       = 32'h0;
    cycle_count   = 0;
    reg_r10_prev  = 0;
    reg_r11_prev  = 0;
    reg_r12_prev  = 0;
    reg_r13_prev  = 0;
    pass_reported = 1'b0;
    fail_reported = 1'b0;
end

// Trace instruction fetches every cycle
always @(posedge clk) begin
    if (!rst && mem_i_rd_w && mem_i_accept_w) begin
        $display("[Cycle %0d] FETCH: PC=0x%08h, Inst=0x%016h",
                 cycle_count, mem_i_pc_w, mem_i_inst_w);
    end
end

always @(posedge clk) begin
    if (rst) begin
        cycle_count  <= 0;
        last_pc      <= 32'h0;
        pass_reported <= 1'b0;
        fail_reported <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        if (cycle_count > 0 && cycle_count < 200) begin
            reg_r10_prev <= reg_r10_w;
            reg_r11_prev <= reg_r11_w;
            reg_r12_prev <= reg_r12_w;
            reg_r13_prev <= reg_r13_w;

            if (reg_r10_w != reg_r10_prev ||
                reg_r11_w != reg_r11_prev ||
                reg_r12_w != reg_r12_prev ||
                reg_r13_w != reg_r13_prev) begin
                $display("[Cycle %0d] Register update detected:", cycle_count);
                $display("      x10 (a0) = %0d (prev: %0d)", reg_r10_w, reg_r10_prev);
                $display("      x11 (a1) = %0d (prev: %0d)", reg_r11_w, reg_r11_prev);
                $display("      x12 (a2) = %0d (prev: %0d)", reg_r12_w, reg_r12_prev);
                $display("      x13 (a3) = %0d (prev: %0d)", reg_r13_w, reg_r13_prev);
            end
        end

        if (u_dut.cbm_opcode_valid_w) begin
            $display("[Cycle %0d] CBM ISSUE: ra=%0d, rb=%0d, rd=%0d",
                     cycle_count,
                     u_dut.cbm_opcode_ra_operand_w,
                     u_dut.cbm_opcode_rb_operand_w,
                     u_dut.cbm_opcode_rd_idx_w);
        end

        if (u_dut.writeback_cbm_valid_w) begin
            $display("[Cycle %0d] CBM WRITEBACK: rd=%0d value=%0d",
                     cycle_count,
                     u_dut.writeback_cbm_rd_idx_w,
                     u_dut.writeback_cbm_value_w);
        end

        if (u_dut.u_cbm.state_q != 2'd0 || u_dut.u_cbm.busy_o || u_dut.u_cbm.done_o) begin
            $display("[Cycle %0d] CBM STATE: state=%0d mask=0x%08h busy=%b rd_idx=%0d",
                     cycle_count,
                     u_dut.u_cbm.state_q,
                     u_dut.u_cbm.column_mask_q,
                     u_dut.u_cbm.busy_o,
                     u_dut.u_cbm.rd_idx_q);
            $display("                 multiplicand=%0d accum=0x%016h",
                     u_dut.u_cbm.multiplicand_q,
                     u_dut.u_cbm.accumulator_q);
        end

        if (u_dut.u_issue.opcode_a_issue_r || u_dut.u_issue.opcode_b_issue_r) begin
            $display("[Cycle %0d] ISSUE: opcode_a=0x%08h (valid=%b issue=%b), opcode_b=0x%08h (valid=%b issue=%b)",
                     cycle_count,
                     u_dut.u_issue.opcode_a_r,
                     u_dut.u_issue.opcode_a_valid_r,
                     u_dut.u_issue.opcode_a_issue_r,
                     u_dut.u_issue.opcode_b_r,
                     u_dut.u_issue.opcode_b_valid_r,
                     u_dut.u_issue.opcode_b_issue_r);
        end

        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);

            if (mem_i_pc_w == PASS_PC && !pass_reported) begin
                pass_reported <= 1'b1;
                $display("\n*** CBM TEST PASSED! ***");
                $display("PC reached 0x%08h. MUL raw: x12 = %0d, CBM raw: x13 = %0d",
                         PASS_PC, reg_r12_w, reg_r13_w);
                $finish;
            end else if (mem_i_pc_w == FAIL_PC && !fail_reported) begin
                fail_reported <= 1'b1;
                $display("\n*** CBM TEST FAILED! ***");
                $display("PC reached 0x%08h before mismatch: x12 = %0d, x13 = %0d (expected %0d)",
                         FAIL_PC, reg_r12_w, reg_r13_w, expected_result_w);
                $finish;
            end
        end

        if (cycle_count > 5000 && !pass_reported && !fail_reported) begin
            fail_reported <= 1'b1;
            $display("\nTimeout after %0d cycles at PC 0x%08h", cycle_count, mem_i_pc_w);
            $display("Last observed MUL = %0d, CBM = %0d (expected %0d)",
                     reg_r12_w, reg_r13_w, expected_result_w);
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
