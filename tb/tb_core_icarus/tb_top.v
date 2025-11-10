module tb_top;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial
begin
    $display("Starting bench");

    if (`TRACE)
    begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);
    end

    // Reset
    clk = 0;
    rst = 1;
    repeat (5) @(posedge clk);
    rst = 0;

    // Load TCM memory
    for (i=0;i<131072;i=i+1)
        mem[i] = 0;

    f = $fopenr("./build/tcm.bin");
    i = $fread(mem, f);
    $display("Loaded %0d bytes from tcm.bin", i);
    for (i=0;i<131072;i=i+1)
        u_mem.write(i, mem[i]);
    
    // Debug: verify RAM contents
    $display("RAM[0] = 0x%016h", u_mem.u_ram.ram[0]);
    $display("RAM[1] = 0x%016h", u_mem.u_ram.ram[1]);
    $display("RAM[2] = 0x%016h", u_mem.u_ram.ram[2]);
end

// Monitor PC to detect test pass/fail
reg [31:0] last_pc;
reg [15:0] cycle_count;
reg [31:0] reg_r10_prev, reg_r11_prev, reg_r12_prev, reg_r13_prev;
initial begin
    last_pc = 32'h0;
    cycle_count = 0;
    reg_r10_prev = 0;
    reg_r11_prev = 0;
    reg_r12_prev = 0;
    reg_r13_prev = 0;
end

// Monitor instruction fetches
always @(posedge clk) begin
    if (!rst && mem_i_rd_w && mem_i_accept_w) begin
        $display("[Cycle %0d] FETCH: PC=0x%08h, Inst=0x%016h", cycle_count, mem_i_pc_w, mem_i_inst_w);
    end
end

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;
        
        // Monitor mulf FSM EVERY cycle - outside PC change check
        if (cycle_count >= 8 && cycle_count <= 20) begin
            $display("[Cycle %0d] MULF: state=%0d, a=%0d, b=%0d, mult_a=%0d, mult_b=%0d, mult_out=%0d",
                cycle_count, u_dut.u_mulf.state_q,
                u_dut.u_mulf.a_q, u_dut.u_mulf.b_q,
                u_dut.u_mulf.mult_a_in_w, u_dut.u_mulf.mult_b_in_w, u_dut.u_mulf.mult_out_w);
            //$display("              p0=%0d, p1=%0d, p2=%0d, result=%0d, valid=%b",                old
                //u_dut.u_mulf.p0_q, u_dut.u_mulf.p1_q, u_dut.u_mulf.p2_q,
                //u_dut.u_mulf.result_r, u_dut.u_mulf.writeback_valid_o);
            $display("              p0=%0d, p1=%0d, p2=%0d, valid=%b",
                u_dut.u_mulf.p0_q, u_dut.u_mulf.p1_q, u_dut.u_mulf.p2_q,
                u_dut.u_mulf.writeback_valid_o);
            // Monitor writeback signals to issue stage
            if (u_dut.writeback_mulf_valid_w) begin
                $display("              WRITEBACK: mulf_valid=%b, mulf_value=%0d",
                    u_dut.writeback_mulf_valid_w, u_dut.writeback_mulf_value_w);
            end
        end
        
        // Monitor register changes EVERY cycle (moved outside PC change block)
        if (cycle_count > 0 && cycle_count < 100) begin
            // Store previous values to detect changes
            reg_r10_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
            reg_r11_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r11_q;
            reg_r12_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
            reg_r13_prev <= u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
            
            // Check for changes in key registers
            if (u_dut.u_issue.u_regfile.REGFILE.reg_r10_q != reg_r10_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r11_q != reg_r11_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r12_q != reg_r12_prev ||
                u_dut.u_issue.u_regfile.REGFILE.reg_r13_q != reg_r13_prev) begin
                $display("[Cycle %0d] Register update detected:", cycle_count);
                $display("      x10 (a0) = %0d (prev: %0d)", u_dut.u_issue.u_regfile.REGFILE.reg_r10_q, reg_r10_prev);
                $display("      x11 (a1) = %0d (prev: %0d)", u_dut.u_issue.u_regfile.REGFILE.reg_r11_q, reg_r11_prev);
                $display("      x12 (a2) = %0d (prev: %0d)", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q, reg_r12_prev);
                $display("      x13 (a3) = %0d (prev: %0d)", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q, reg_r13_prev);
            end
        end
        
        if (mem_i_pc_w != last_pc) begin
            last_pc <= mem_i_pc_w;
            $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);
            
            // Debug: show values at branch instruction (0x80000010)
            // Check a bit later to allow writeback to complete
            if (mem_i_pc_w == 32'h80000014 || mem_i_pc_w == 32'h80000018) begin
                $display("  --> Registers after branch:");
                $display("      x10 (a0) = %0d (expected 7)", u_dut.u_issue.u_regfile.REGFILE.reg_r10_q);
                $display("      x11 (a1) = %0d (expected 9)", u_dut.u_issue.u_regfile.REGFILE.reg_r11_q);
                $display("      x12 (a2) = %0d (expected 63 if mulf worked)", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                $display("      x13 (a3) = %0d (expected 63)", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
            end
            
            if (u_dut.u_mulf.opcode_valid_i) begin
                $display("[Cycle %0d] MULF INPUT: a=%0d, b=%0d, rd_idx=%0d",
                    cycle_count, u_dut.u_mulf.opcode_ra_operand_i, u_dut.u_mulf.opcode_rb_operand_i,
                    u_dut.u_mulf.opcode_rd_idx_i);
            end

            // Monitor instruction issue
            if (cycle_count > 2 && cycle_count < 20) begin
                if (u_dut.u_issue.opcode_a_issue_r || u_dut.u_issue.opcode_b_issue_r) begin
                    $display("[Cycle %0d] ISSUE: opcode_a=0x%08h (valid=%b, issue=%b), opcode_b=0x%08h (valid=%b, issue=%b)", 
                        cycle_count,
                        u_dut.u_issue.opcode_a_r, u_dut.u_issue.opcode_a_valid_r, u_dut.u_issue.opcode_a_issue_r,
                        u_dut.u_issue.opcode_b_r, u_dut.u_issue.opcode_b_valid_r, u_dut.u_issue.opcode_b_issue_r);
                end
            end

            // Monitor PC to see when branch is taken
            if (mem_i_pc_w == 32'h80000030) begin
                $display("[Cycle %0d] PC = 0x%08h", cycle_count, mem_i_pc_w);
                $display("  --> Registers after mulf:");
                $display("      x10 (a0) = %0d (expected 7)", u_dut.u_issue.u_regfile.REGFILE.reg_r10_q);
                $display("      x11 (a1) = %0d (expected 9)", u_dut.u_issue.u_regfile.REGFILE.reg_r11_q);
                $display("      x12 (a2) = %0d (expected 63 if mulf worked)", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                $display("      x13 (a3) = %0d (expected 63)", u_dut.u_issue.u_regfile.REGFILE.reg_r13_q);
            end

            // pass_loop is at 0x8000012c, fail_loop is at 0x80000130
            if (mem_i_pc_w == 32'h8000012c) begin
                $display("\n*** TEST PASSED! ***");
                $display("PC reached pass_loop at 0x8000012c");
                $display("mulf instruction correctly computed 7 * 9 = 63");
                $display("Final register x12 (a2) = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                $finish;
            end
            else if (mem_i_pc_w == 32'h80000130) begin
                $display("\n*** TEST FAILED! ***");
                $display("PC reached fail_loop at 0x80000130");
                $display("mulf instruction did not produce correct result");
                $display("Final register x12 (a2) = %0d", u_dut.u_issue.u_regfile.REGFILE.reg_r12_q);
                $finish;
            end
        end
        
        // Timeout after too many cycles
        if (cycle_count > 1000) begin
            $display("\nTimeout after %0d cycles at PC 0x%08h", cycle_count, mem_i_pc_w);
            $finish;
        end
    end
end

initial
begin
    forever
    begin 
        clk = #5 ~clk;
    end
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

riscv_core
u_dut
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
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

    // Outputs
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

tcm_mem
u_mem
(
    // Inputs
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

    // Outputs
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