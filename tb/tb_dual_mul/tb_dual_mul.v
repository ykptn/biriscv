`include "../../src/core/biriscv_defs.v"

module tb_dual_mul;

localparam PASS_PC = 32'h80000324;
localparam FAIL_PC = 32'h80000328;
localparam PARALLEL_TEST_PC = 32'h80000200;
localparam SEQUENTIAL_TEST_PC = 32'h800002a0;

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting Dual MUL Parallel Execution Test");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_dual_mul);
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
        u_mem.u_ram.ram[i/8][((i%8)*8) +: 8] = mem[i];
end

always #5 clk = ~clk;

reg [31:0] cycle_count;
reg [31:0] last_pc;

// Track parallel MUL execution
reg        parallel_test_active;
integer    pipe0_mul_issue_cycle;
integer    pipe1_mul_issue_cycle;
integer    pipe0_mul_done_cycle;
integer    pipe1_mul_done_cycle;
reg        pipe0_mul_issued;
reg        pipe1_mul_issued;

// Track sequential MUL execution  
reg        sequential_test_active;
integer    seq_mul1_issue_cycle;
integer    seq_mul2_issue_cycle;
integer    seq_mul1_done_cycle;
integer    seq_mul2_done_cycle;
reg        seq_mul1_issued;
reg        seq_mul2_issued;

initial begin
    cycle_count = 0;
    last_pc = 32'h0;
    parallel_test_active = 1'b0;
    pipe0_mul_issue_cycle = -1;
    pipe1_mul_issue_cycle = -1;
    pipe0_mul_done_cycle = -1;
    pipe1_mul_done_cycle = -1;
    pipe0_mul_issued = 1'b0;
    pipe1_mul_issued = 1'b0;
    
    sequential_test_active = 1'b0;
    seq_mul1_issue_cycle = -1;
    seq_mul2_issue_cycle = -1;
    seq_mul1_done_cycle = -1;
    seq_mul2_done_cycle = -1;
    seq_mul1_issued = 1'b0;
    seq_mul2_issued = 1'b0;
end

// Wire probes for internal signals (use memory interface PC as proxy)
wire [31:0] pc_w = mem_i_pc_w;

wire        pipe0_mul_issue_w = u_dut.u_issue.pipe0_mul_e1_w;
wire        pipe1_mul_issue_w = u_dut.u_issue.pipe1_mul_e1_w;
wire [4:0]  pipe0_rd_w = u_dut.u_issue.pipe0_rd_e1_w;
wire [4:0]  pipe1_rd_w = u_dut.u_issue.pipe1_rd_e1_w;

wire        pipe0_wb_valid_w = u_dut.u_issue.pipe0_valid_wb_w;
wire        pipe1_wb_valid_w = u_dut.u_issue.pipe1_valid_wb_w;
wire [4:0]  pipe0_wb_rd_w = u_dut.u_issue.pipe0_rd_wb_w;
wire [4:0]  pipe1_wb_rd_w = u_dut.u_issue.pipe1_rd_wb_w;
wire [31:0] pipe0_wb_result_w = u_dut.u_issue.pipe0_result_wb_w;
wire [31:0] pipe1_wb_result_w = u_dut.u_issue.pipe1_result_wb_w;

wire [31:0] x12_w = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] x13_w = u_dut.u_issue.u_regfile.REGFILE.reg_r13_q;
wire [31:0] x14_w = u_dut.u_issue.u_regfile.REGFILE.reg_r14_q;
wire [31:0] x15_w = u_dut.u_issue.u_regfile.REGFILE.reg_r15_q;

always @(posedge clk) begin
    if (!rst) begin
        cycle_count <= cycle_count + 1;
        
        // Detect parallel test start (PC at parallel_muls label)
        if (pc_w == PARALLEL_TEST_PC && !parallel_test_active) begin
            parallel_test_active <= 1'b1;
            pipe0_mul_issued <= 1'b0;
            pipe1_mul_issued <= 1'b0;
            $display("\n[Cycle %0d] ========== PARALLEL MUL TEST STARTED ==========", cycle_count);
        end
        
        // Detect sequential test start (PC at sequential_muls label)
        if (pc_w == SEQUENTIAL_TEST_PC && !sequential_test_active) begin
            sequential_test_active <= 1'b1;
            seq_mul1_issued <= 1'b0;
            seq_mul2_issued <= 1'b0;
            $display("\n[Cycle %0d] ========== SEQUENTIAL MUL TEST STARTED ==========", cycle_count);
        end
        
        // Monitor parallel MUL issue
        if (parallel_test_active && !pipe0_mul_issued && pipe0_mul_issue_w && pipe0_rd_w == 5'd14) begin
            pipe0_mul_issue_cycle <= cycle_count;
            pipe0_mul_issued <= 1'b1;
            $display("[Cycle %0d] PIPE0 MUL issued: rd=x14", cycle_count);
        end
        
        if (parallel_test_active && !pipe1_mul_issued && pipe1_mul_issue_w && pipe1_rd_w == 5'd15) begin
            pipe1_mul_issue_cycle <= cycle_count;
            pipe1_mul_issued <= 1'b1;
            $display("[Cycle %0d] PIPE1 MUL issued: rd=x15", cycle_count);
        end
        
        // Monitor parallel MUL completion
        if (parallel_test_active && pipe0_wb_valid_w && pipe0_wb_rd_w == 5'd14 && pipe0_mul_done_cycle < 0) begin
            pipe0_mul_done_cycle <= cycle_count;
            $display("[Cycle %0d] PIPE0 MUL completed: x14=%0d", cycle_count, pipe0_wb_result_w);
        end
        
        if (parallel_test_active && pipe1_wb_valid_w && pipe1_wb_rd_w == 5'd15 && pipe1_mul_done_cycle < 0) begin
            pipe1_mul_done_cycle <= cycle_count;
            $display("[Cycle %0d] PIPE1 MUL completed: x15=%0d", cycle_count, pipe1_wb_result_w);
        end
        
        // Monitor sequential MUL issue
        if (sequential_test_active && !seq_mul1_issued && pipe0_mul_issue_w && pipe0_rd_w == 5'd12) begin
            seq_mul1_issue_cycle <= cycle_count;
            seq_mul1_issued <= 1'b1;
            $display("[Cycle %0d] SEQ MUL1 issued: rd=x12 (first multiply)", cycle_count);
        end
        
        if (sequential_test_active && seq_mul1_issued && !seq_mul2_issued && 
            (pipe0_mul_issue_w || pipe1_mul_issue_w) && 
            ((pipe0_rd_w == 5'd12) || (pipe1_rd_w == 5'd12))) begin
            seq_mul2_issue_cycle <= cycle_count;
            seq_mul2_issued <= 1'b1;
            if (pipe0_mul_issue_w && pipe0_rd_w == 5'd12)
                $display("[Cycle %0d] SEQ MUL2 issued on PIPE0: rd=x12 (dependent multiply)", cycle_count);
            else
                $display("[Cycle %0d] SEQ MUL2 issued on PIPE1: rd=x12 (dependent multiply)", cycle_count);
        end
        
        // Check for PASS/FAIL
        if (pc_w == PASS_PC) begin
            $display("\n========================================");
            $display("*** TEST PASSED! ***");
            $display("========================================");
            
            if (pipe0_mul_issue_cycle >= 0 && pipe1_mul_issue_cycle >= 0) begin
                $display("\nPARALLEL MUL TEST RESULTS:");
                $display("  PIPE0 issue -> done: cycle %0d -> %0d (latency %0d)", 
                         pipe0_mul_issue_cycle, pipe0_mul_done_cycle, 
                         pipe0_mul_done_cycle - pipe0_mul_issue_cycle);
                $display("  PIPE1 issue -> done: cycle %0d -> %0d (latency %0d)", 
                         pipe1_mul_issue_cycle, pipe1_mul_done_cycle,
                         pipe1_mul_done_cycle - pipe1_mul_issue_cycle);
                $display("  Issue cycle difference: %0d cycles", 
                         (pipe1_mul_issue_cycle > pipe0_mul_issue_cycle) ? 
                         (pipe1_mul_issue_cycle - pipe0_mul_issue_cycle) :
                         (pipe0_mul_issue_cycle - pipe1_mul_issue_cycle));
                
                if ((pipe0_mul_issue_cycle == pipe1_mul_issue_cycle) ||
                    (pipe0_mul_issue_cycle - pipe1_mul_issue_cycle == 1) ||
                    (pipe1_mul_issue_cycle - pipe0_mul_issue_cycle == 1)) begin
                    $display("  ✓ PARALLEL EXECUTION CONFIRMED!");
                end else begin
                    $display("  ⚠ NOT parallel - issue cycles differ by more than 1");
                end
            end
            
            if (seq_mul1_issue_cycle >= 0 && seq_mul2_issue_cycle >= 0) begin
                $display("\nSEQUENTIAL MUL TEST RESULTS:");
                $display("  MUL1 issued: cycle %0d", seq_mul1_issue_cycle);
                $display("  MUL2 issued: cycle %0d", seq_mul2_issue_cycle);
                $display("  Issue cycle difference: %0d cycles", 
                         seq_mul2_issue_cycle - seq_mul1_issue_cycle);
                
                if (seq_mul2_issue_cycle - seq_mul1_issue_cycle > 3) begin
                    $display("  ✓ DEPENDENCY STALL CONFIRMED (waited for first MUL to complete)");
                end else begin
                    $display("  ⚠ Unexpected: dependent MUL issued too early");
                end
            end
            
            $display("\nFinal register values: x12=%0d, x13=%0d, x14=%0d, x15=%0d", x12_w, x13_w, x14_w, x15_w);
            $finish;
        end
        
        if (pc_w == FAIL_PC) begin
            $display("\n*** TEST FAILED! ***");
            $display("Final register values: x12=%0d, x13=%0d, x14=%0d, x15=%0d", x12_w, x13_w, x14_w, x15_w);
            $finish;
        end
        
        // Timeout
        if (cycle_count > 500) begin
            $display("\n*** TIMEOUT! ***");
            $display("Last PC: 0x%08h", pc_w);
            $finish;
        end
    end
end

// Memory interface wires
wire        mem_i_rd_w;
wire        mem_i_flush_w;
wire        mem_i_invalidate_w;
wire [31:0] mem_i_pc_w;
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
    .mem_d_data_rd_o(mem_d_data_rd_w),
    .mem_d_accept_o(mem_d_accept_w),
    .mem_d_ack_o(mem_d_ack_w),
    .mem_d_error_o(mem_d_error_w),
    .mem_d_resp_tag_o(mem_d_resp_tag_w)
);

endmodule
