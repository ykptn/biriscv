`include "../../src/core/biriscv_defs.v"

module tb_1000mul;

localparam DONE_FLAG      = 32'h0000_0001;
localparam TIMEOUT_CYCLES = 32'd800000;  // Longer timeout for 1000 multicycle MULE ops

reg clk;
reg rst;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting 1000 MULE testbench");

    if (`TRACE) begin
        $dumpfile("1000mul.vcd");
        $dumpvars(0, tb_1000mul);
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
end

initial begin
    forever clk = #5 ~clk;
end

reg [31:0] cycle_count;
reg        done_reported;

wire [31:0] reg_done_w     = u_dut.u_issue.u_regfile.REGFILE.reg_r30_q;
wire [31:0] reg_checksum_w = u_dut.u_issue.u_regfile.REGFILE.reg_r5_q;
wire [31:0] reg_last_mule_w = u_dut.u_issue.u_regfile.REGFILE.reg_r12_q;
wire [31:0] reg_s0_w       = u_dut.u_issue.u_regfile.REGFILE.reg_r8_q;

// Periodic progress report
always @(posedge clk) begin
    if (!rst && (cycle_count[14:0] == 15'd0)) begin // every 32768 cycles
        $display("[Cycle %0d] s0=%0d checksum=%0d (0x%08h) last_mule=%0d done=%0d",
                 cycle_count, reg_s0_w, reg_checksum_w, reg_checksum_w, reg_last_mule_w, reg_done_w);
    end
end

always @(posedge clk) begin
    if (rst) begin
        cycle_count   <= 0;
        done_reported <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;

        if (!done_reported && reg_done_w == DONE_FLAG) begin
            done_reported <= 1'b1;
            $display("\n1000 MULE operations complete!");
            $display("Cycle %0d | checksum=%0d (0x%08h) last_mule=%0d",
                     cycle_count, reg_checksum_w, reg_checksum_w, reg_last_mule_w);
            $finish;
        end

        if (!done_reported && cycle_count > TIMEOUT_CYCLES) begin
            done_reported <= 1'b1;
            $display("\nTIMEOUT after %0d cycles", cycle_count);
            $display("s0=%0d checksum=%0d (0x%08h) last_mule=%0d",
                     reg_s0_w, reg_checksum_w, reg_checksum_w, reg_last_mule_w);
            $finish;
        end
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
