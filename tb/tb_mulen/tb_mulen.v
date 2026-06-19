module tb_mulen;

reg clk;
reg rst;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting MULEN standalone testbench");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_mulen);
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
end

reg [31:0] last_pc;
reg [31:0] cycle_count;
reg        pass_reported;
reg        fail_reported;
reg        mulen_seen;
reg        mulen_writeback_seen;
reg        progress_before_writeback;
reg        pipe1_issue_seen;

wire [31:0] reg_r12_w = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_r13_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] reg_r14_w = u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
wire [31:0] reg_r15_w = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
wire [31:0] reg_r16_w = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
wire [31:0] reg_r17_w = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;

initial begin
    last_pc = 32'h0;
    cycle_count = 0;
    pass_reported = 1'b0;
    fail_reported = 1'b0;
    mulen_seen = 1'b0;
    mulen_writeback_seen = 1'b0;
    progress_before_writeback = 1'b0;
    pipe1_issue_seen = 1'b0;
end

always @(posedge clk) begin
    if (rst) begin
        cycle_count <= 0;
        last_pc <= 32'h0;
        pass_reported <= 1'b0;
        fail_reported <= 1'b0;
        mulen_seen <= 1'b0;
        mulen_writeback_seen <= 1'b0;
        progress_before_writeback <= 1'b0;
        pipe1_issue_seen <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        if (u_dut.mulen_opcode_valid_w) begin
            mulen_seen <= 1'b1;
            if (u_dut.u_issue.pipe1_mux_mulen_r)
                pipe1_issue_seen <= 1'b1;
            $display("[Cycle %0d] MULEN ISSUE: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mulen_opcode_ra_operand_w,
                     u_dut.mulen_opcode_rb_operand_w,
                     u_dut.mulen_opcode_rd_idx_w);
        end

        if (mulen_seen && !mulen_writeback_seen &&
            ((u_dut.exec0_opcode_valid_w &&
              (u_dut.opcode0_rd_idx_w == 5'd14 || u_dut.opcode0_rd_idx_w == 5'd15 ||
               u_dut.opcode0_rd_idx_w == 5'd16 || u_dut.opcode0_rd_idx_w == 5'd17)) ||
             (u_dut.exec1_opcode_valid_w &&
              (u_dut.opcode1_rd_idx_w == 5'd14 || u_dut.opcode1_rd_idx_w == 5'd15 ||
               u_dut.opcode1_rd_idx_w == 5'd16 || u_dut.opcode1_rd_idx_w == 5'd17))))
            progress_before_writeback <= 1'b1;

        if (u_dut.writeback_mulen_valid_w) begin
            mulen_writeback_seen <= 1'b1;
            $display("[Cycle %0d] MULEN WRITEBACK: rd=%0d value=%0d",
                     cycle_count,
                     u_dut.writeback_mulen_rd_idx_w,
                     u_dut.writeback_mulen_value_w);
        end

        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;

            if (mem_i_pc_w == PASS_PC && !pass_reported) begin
                if ((reg_r12_w == reg_r13_w) &&
                    (reg_r14_w == 32'd5) &&
                    (reg_r15_w == 32'd8) &&
                    (reg_r16_w == 32'd15) &&
                    (reg_r17_w == 32'd16) &&
                    progress_before_writeback &&
                    pipe1_issue_seen) begin
                    pass_reported <= 1'b1;
                    $display("\n*** MULEN TEST PASSED! ***");
                    $display("Cycle %0d reached 0x%08h. MULEN x12 = %0d, MUL x13 = %0d, progress_before_writeback = %0d, pipe1_issue_seen = %0d",
                             cycle_count, PASS_PC, reg_r12_w, reg_r13_w, progress_before_writeback, pipe1_issue_seen);
                    $finish;
                end else begin
                    fail_reported <= 1'b1;
                    $display("\n*** MULEN TEST FAILED! ***");
                    $display("PASS loop reached with bad state: x12=%0d x13=%0d x14=%0d x15=%0d x16=%0d x17=%0d progress=%0d pipe1=%0d",
                             reg_r12_w, reg_r13_w, reg_r14_w, reg_r15_w, reg_r16_w, reg_r17_w,
                             progress_before_writeback, pipe1_issue_seen);
                    $finish;
                end
            end else if (mem_i_pc_w == FAIL_PC && !fail_reported) begin
                fail_reported <= 1'b1;
                $display("\n*** MULEN TEST FAILED! ***");
                $display("Reached fail loop: x12=%0d x13=%0d x14=%0d x15=%0d x16=%0d x17=%0d progress=%0d pipe1=%0d",
                         reg_r12_w, reg_r13_w, reg_r14_w, reg_r15_w, reg_r16_w, reg_r17_w,
                         progress_before_writeback, pipe1_issue_seen);
                $finish;
            end
        end

        if (cycle_count > 5000 && !pass_reported && !fail_reported) begin
            fail_reported <= 1'b1;
            $display("\nTimeout after %0d cycles at PC 0x%08h", cycle_count, mem_i_pc_w);
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
