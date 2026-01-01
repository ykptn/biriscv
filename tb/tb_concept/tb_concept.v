`timescale 1ns / 1ps

`define TRACE 1

module tb_concept;

    reg clk;
    reg rst;
    
    // Cycle counter
    integer cycle_count;
    
    // Memory for loading program
    reg [7:0] mem[131072:0];
    integer i;
    integer f;

    // Instruction and Data Memory interface
    wire [31:0] mem_i_addr;
    wire        mem_i_rd;
    wire        mem_i_flush;
    wire        mem_i_invalidate;
    wire [31:0] mem_i_pc;
    reg  [63:0] mem_i_inst;
    reg         mem_i_valid;
    reg         mem_i_error;

    wire [31:0] mem_d_addr;
    wire [31:0] mem_d_data_wr;
    wire        mem_d_rd;
    wire [3:0]  mem_d_wr;
    wire        mem_d_cacheable;
    wire [10:0] mem_d_req_tag;
    wire        mem_d_invalidate;
    wire        mem_d_writeback;
    wire        mem_d_flush;
    reg  [31:0] mem_d_data_rd;
    reg         mem_d_accept;
    reg         mem_d_ack;
    reg         mem_d_error;
    reg  [10:0] mem_d_resp_tag;

    // Instantiate TCM memory
    tcm_mem u_mem (
        .clk_i(clk),
        .rst_i(rst),
        .mem_i_rd_i(mem_i_rd),
        .mem_i_flush_i(mem_i_flush),
        .mem_i_invalidate_i(mem_i_invalidate),
        .mem_i_pc_i(mem_i_pc),
        .mem_i_accept_o(),
        .mem_i_valid_o(mem_i_valid),
        .mem_i_error_o(mem_i_error),
        .mem_i_inst_o(mem_i_inst),
        .mem_d_addr_i(mem_d_addr),
        .mem_d_data_wr_i(mem_d_data_wr),
        .mem_d_rd_i(mem_d_rd),
        .mem_d_wr_i(mem_d_wr),
        .mem_d_cacheable_i(mem_d_cacheable),
        .mem_d_req_tag_i(mem_d_req_tag),
        .mem_d_invalidate_i(mem_d_invalidate),
        .mem_d_writeback_i(mem_d_writeback),
        .mem_d_flush_i(mem_d_flush),
        .mem_d_data_rd_o(mem_d_data_rd),
        .mem_d_accept_o(mem_d_accept),
        .mem_d_ack_o(mem_d_ack),
        .mem_d_error_o(mem_d_error),
        .mem_d_resp_tag_o(mem_d_resp_tag)
    );

    // Instantiate RISC-V core
    riscv_core #(
        .SUPPORT_MULDIV(1),
        .SUPPORT_SUPER(0),
        .SUPPORT_MMU(0),
        .SUPPORT_DUAL_ISSUE(0),
        .SUPPORT_LOAD_BYPASS(1),
        .SUPPORT_MUL_BYPASS(1),
        .SUPPORT_REGFILE_XILINX(0),
        .EXTRA_DECODE_STAGE(0)
    ) u_core (
        .clk_i(clk),
        .rst_i(rst),
        
        .mem_d_addr_o(mem_d_addr),
        .mem_d_data_wr_o(mem_d_data_wr),
        .mem_d_rd_o(mem_d_rd),
        .mem_d_wr_o(mem_d_wr),
        .mem_d_cacheable_o(mem_d_cacheable),
        .mem_d_req_tag_o(mem_d_req_tag),
        .mem_d_invalidate_o(mem_d_invalidate),
        .mem_d_writeback_o(mem_d_writeback),
        .mem_d_flush_o(mem_d_flush),
        .mem_d_data_rd_i(mem_d_data_rd),
        .mem_d_accept_i(mem_d_accept),
        .mem_d_ack_i(mem_d_ack),
        .mem_d_error_i(mem_d_error),
        .mem_d_resp_tag_i(mem_d_resp_tag),
        
        .mem_i_accept_i(1'b1),
        .mem_i_rd_o(mem_i_rd),
        .mem_i_flush_o(mem_i_flush),
        .mem_i_invalidate_o(mem_i_invalidate),
        .mem_i_pc_o(mem_i_pc),
        .mem_i_inst_i(mem_i_inst),
        .mem_i_valid_i(mem_i_valid),
        .mem_i_error_i(mem_i_error),
        
        .intr_i(1'b0),
        .reset_vector_i(32'h80000000),
        .cpu_id_i(32'h0)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset and simulation control
    initial begin
        $display("Starting Concept testbench");
        
        if (`TRACE) begin
            $dumpfile("waveform.vcd");
            $dumpvars(0, tb_concept);
        end
        
        // Reset
        rst = 1;
        cycle_count = 0;
        
        // Initialize memory
        for (i=0; i<131072; i=i+1)
            mem[i] = 0;
        
        // Load program binary
        f = $fopenr("./build/tcm.bin");
        i = $fread(mem, f);
        $display("Loaded %0d bytes from tcm.bin", i);
        for (i=0; i<131072; i=i+1)
            u_mem.write(i, mem[i]);
        
        // Debug: verify RAM contents
        $display("RAM[0] = 0x%016h", u_mem.u_ram.ram[0]);
        $display("RAM[1] = 0x%016h", u_mem.u_ram.ram[1]);
        $display("RAM[2] = 0x%016h", u_mem.u_ram.ram[2]);
        
        repeat (5) @(posedge clk);
        rst = 0;
        
        // Let simulation run - completion is handled by always blocks
        #10000000; // 10ms timeout
        $display("WARNING: Simulation timed out");
        $finish;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;
        end
    end

    // Waveform dumping (moved to initial block above)
    
    // Monitor key signals and detect completion
    always @(posedge clk) begin
        if (!rst) begin
            // Check if we reached pass_loop or fail_loop
            if (mem_i_pc == 32'h80000168) begin
                $display("==============================================");
                $display("TEST PASSED!");
                $display("Total cycles: %0d", cycle_count);
                $display("==============================================");
                $finish;
            end else if (mem_i_pc == 32'h8000016c) begin
                $display("==============================================");
                $display("TEST FAILED!");
                $display("Total cycles: %0d", cycle_count);
                $display("==============================================");
                $finish;
            end
            
            // Timeout after reasonable number of cycles
            if (cycle_count > 100000) begin
                $display("==============================================");
                $display("TEST TIMEOUT! PC = 0x%h", mem_i_pc);
                $display("Total cycles: %0d", cycle_count);
                $display("==============================================");
                $finish;
            end
        end
    end
    
    // Monitor instruction execution
    always @(posedge clk) begin
        if (!rst && mem_i_valid && mem_i_rd && cycle_count < 200) begin
            $display("[Cycle %0d] PC=0x%h Inst=0x%h", cycle_count, mem_i_pc, mem_i_inst[31:0]);
        end
    end

endmodule
