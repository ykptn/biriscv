module tb_mule3n;

reg clk;
reg rst;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;

reg [7:0] mem[131072:0];
integer i;
integer f;
reg        synthetic_collision_done;
reg        synthetic_collision_failed;
reg        synthetic_phase_active;

initial begin
    $display("Starting MULE3N standalone testbench");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_mule3n);
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

    synthetic_collision_done = 1'b0;
    synthetic_collision_failed = 1'b0;
    synthetic_phase_active = 1'b1;
end

reg [31:0] last_pc;
reg [31:0] cycle_count;
reg        pass_reported;
reg        fail_reported;
reg        mule3n_seen;
reg        mule3n_writeback_seen;
reg        progress_before_writeback;
reg        pipe1_issue_seen;
reg        wb_collision_seen;
reg [4:0]  wb_collision_rd;
reg [31:0] wb_collision_value;

wire [31:0] reg_r12_w = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_r13_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] reg_r14_w = u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
wire [31:0] reg_r15_w = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
wire [31:0] reg_r16_w = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
wire [31:0] reg_r17_w = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;

function [31:0] reg_value_by_idx;
    input [4:0] idx;
begin
    case (idx)
    5'd0:  reg_value_by_idx = 32'd0;
    5'd1:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r1_q;
    5'd2:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r2_q;
    5'd3:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r3_q;
    5'd4:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r4_q;
    5'd5:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r5_q;
    5'd6:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r6_q;
    5'd7:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r7_q;
    5'd8:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r8_q;
    5'd9:  reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r9_q;
    5'd10: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
    5'd11: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r11_q;
    5'd12: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
    5'd13: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
    5'd14: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
    5'd15: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;
    5'd16: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r16_q;
    5'd17: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r17_q;
    5'd18: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r18_q;
    5'd19: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r19_q;
    5'd20: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r20_q;
    5'd21: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r21_q;
    5'd22: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r22_q;
    5'd23: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r23_q;
    5'd24: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r24_q;
    5'd25: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r25_q;
    5'd26: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r26_q;
    5'd27: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r27_q;
    5'd28: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r28_q;
    5'd29: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r29_q;
    5'd30: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r30_q;
    5'd31: reg_value_by_idx = u_dut.u_issue.u_regfile.REGFILE.reg_r31_q;
    default: reg_value_by_idx = 32'hx;
    endcase
end
endfunction

initial begin
    last_pc = 32'h0;
    cycle_count = 0;
    pass_reported = 1'b0;
    fail_reported = 1'b0;
    mule3n_seen = 1'b0;
    mule3n_writeback_seen = 1'b0;
    progress_before_writeback = 1'b0;
    pipe1_issue_seen = 1'b0;
    wb_collision_seen = 1'b0;
    wb_collision_rd = 5'd0;
    wb_collision_value = 32'd0;
end

initial begin
    wait(rst == 1'b0);
    @(posedge clk);

    force u_dut.u_issue.mule3n_pending_q         = 1'b1;
    force u_dut.u_issue.mule3n_rd_q              = 5'd12;
    force u_dut.u_issue.writeback_mule3n_valid_i = 1'b1;
    force u_dut.u_issue.writeback_mule3n_rd_idx_i= 5'd12;
    force u_dut.u_issue.writeback_mule3n_value_i = 32'd63;
    force u_dut.u_issue.pipe0_rd_wb_w            = 5'd14;
    force u_dut.u_issue.pipe0_result_wb_w        = 32'd5;
    force u_dut.u_issue.pipe1_rd_wb_w            = 5'd0;
    force u_dut.u_issue.pipe1_result_wb_w        = 32'd0;

    @(posedge clk);

    release u_dut.u_issue.mule3n_pending_q;
    release u_dut.u_issue.mule3n_rd_q;
    release u_dut.u_issue.writeback_mule3n_valid_i;
    release u_dut.u_issue.writeback_mule3n_rd_idx_i;
    release u_dut.u_issue.writeback_mule3n_value_i;
    release u_dut.u_issue.pipe0_rd_wb_w;
    release u_dut.u_issue.pipe0_result_wb_w;
    release u_dut.u_issue.pipe1_rd_wb_w;
    release u_dut.u_issue.pipe1_result_wb_w;

    @(posedge clk);

    if ((reg_r12_w !== 32'd63) || (reg_r14_w !== 32'd5)) begin
        synthetic_collision_failed = 1'b1;
        $display("\n*** MULE3N SYNTHETIC COLLISION FAILED! ***");
        $display("Expected x12=63 and x14=5, got x12=%0d x14=%0d", reg_r12_w, reg_r14_w);
        $finish;
    end

    synthetic_collision_done = 1'b1;
    synthetic_phase_active = 1'b0;
    $display("[Synthetic] MULE3N writeback arbitration check passed: x12=%0d x14=%0d",
             reg_r12_w, reg_r14_w);
end

always @(posedge clk) begin
    if (rst) begin
        cycle_count <= 0;
        last_pc <= 32'h0;
        pass_reported <= 1'b0;
        fail_reported <= 1'b0;
        mule3n_seen <= 1'b0;
        mule3n_writeback_seen <= 1'b0;
        progress_before_writeback <= 1'b0;
        pipe1_issue_seen <= 1'b0;
        wb_collision_seen <= 1'b0;
        wb_collision_rd <= 5'd0;
        wb_collision_value <= 32'd0;
        synthetic_collision_failed <= 1'b0;
        synthetic_phase_active <= 1'b1;
    end else begin
        cycle_count <= cycle_count + 1;

        if (!synthetic_phase_active && u_dut.mule3n_opcode_valid_w) begin
            mule3n_seen <= 1'b1;
            if (u_dut.u_issue.pipe1_mux_mule3n_r)
                pipe1_issue_seen <= 1'b1;
            $display("[Cycle %0d] MULE3N ISSUE: ra=%0d rb=%0d rd=%0d",
                     cycle_count,
                     u_dut.mule3n_opcode_ra_operand_w,
                     u_dut.mule3n_opcode_rb_operand_w,
                     u_dut.mule3n_opcode_rd_idx_w);
        end

        if (!synthetic_phase_active &&
            mule3n_seen && !mule3n_writeback_seen &&
            ((u_dut.u_issue.opcode_a_issue_r && !u_dut.mule3n_opcode_valid_w) ||
             (u_dut.u_issue.opcode_b_issue_r && !u_dut.mule3n_opcode_valid_w)))
            progress_before_writeback <= 1'b1;

        if (!synthetic_phase_active && u_dut.writeback_mule3n_valid_w) begin
            mule3n_writeback_seen <= 1'b1;
            $display("[Cycle %0d] MULE3N WRITEBACK: rd=%0d value=%0d",
                     cycle_count,
                     u_dut.writeback_mule3n_rd_idx_w,
                     u_dut.writeback_mule3n_value_w);
        end

        if (!synthetic_phase_active &&
            !wb_collision_seen &&
            u_dut.writeback_mule3n_valid_w &&
            (u_dut.u_issue.pipe0_rd_wb_base_w != 5'd0)) begin
            wb_collision_seen <= 1'b1;
            wb_collision_rd <= u_dut.u_issue.pipe0_rd_wb_base_w;
            wb_collision_value <= u_dut.u_issue.pipe0_result_wb_base_w;
            $display("[Cycle %0d] MULE3N WB COLLISION: custom rd=%0d value=%0d, pipe0 rd=%0d value=%0d",
                     cycle_count,
                     u_dut.writeback_mule3n_rd_idx_w,
                     u_dut.writeback_mule3n_value_w,
                     u_dut.u_issue.pipe0_rd_wb_base_w,
                     u_dut.u_issue.pipe0_result_wb_base_w);
        end

        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;

            if (mem_i_pc_w == PASS_PC && !pass_reported) begin
                if ((reg_r12_w == reg_r13_w) &&
                    (reg_r15_w == 32'd8) &&
                    (reg_r16_w == 32'd15) &&
                    (reg_r17_w == 32'd16) &&
                    synthetic_collision_done &&
                    progress_before_writeback &&
                    pipe1_issue_seen &&
                    (!wb_collision_seen ||
                     (reg_value_by_idx(wb_collision_rd) == wb_collision_value))) begin
                    pass_reported <= 1'b1;
                    $display("\n*** MULE3N TEST PASSED! ***");
                    $display("Cycle %0d reached 0x%08h. MULE3N x12 = %0d, MUL x13 = %0d, progress_before_writeback = %0d, pipe1_issue_seen = %0d, collision_seen = %0d",
                             cycle_count, PASS_PC, reg_r12_w, reg_r13_w, progress_before_writeback, pipe1_issue_seen, wb_collision_seen);
                    $finish;
                end else begin
                    fail_reported <= 1'b1;
                    $display("\n*** MULE3N TEST FAILED! ***");
                    $display("PASS loop reached with bad state: x12=%0d x13=%0d x14=%0d x15=%0d x16=%0d x17=%0d progress=%0d pipe1=%0d collision=%0d collision_rd=x%0d collision_reg=%0d expected=%0d",
                             reg_r12_w, reg_r13_w, reg_r14_w, reg_r15_w, reg_r16_w, reg_r17_w,
                             progress_before_writeback, pipe1_issue_seen, wb_collision_seen, wb_collision_rd,
                             reg_value_by_idx(wb_collision_rd), wb_collision_value);
                    $finish;
                end
            end else if (mem_i_pc_w == FAIL_PC && !fail_reported) begin
                fail_reported <= 1'b1;
                $display("\n*** MULE3N TEST FAILED! ***");
                $display("Reached fail loop: x12=%0d x13=%0d x14=%0d x15=%0d x16=%0d x17=%0d progress=%0d pipe1=%0d collision=%0d collision_rd=x%0d collision_reg=%0d expected=%0d",
                         reg_r12_w, reg_r13_w, reg_r14_w, reg_r15_w, reg_r16_w, reg_r17_w,
                         progress_before_writeback, pipe1_issue_seen, wb_collision_seen, wb_collision_rd,
                         reg_value_by_idx(wb_collision_rd), wb_collision_value);
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
