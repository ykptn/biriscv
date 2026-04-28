`include "biriscv_defs.v"

module tb_matmul_absorbtion;

reg clk;
reg rst;

localparam PASS_PC = 32'h80000130;
localparam FAIL_PC = 32'h80000134;
localparam TIMEOUT_CYCLES = 64'd250000;

reg [7:0] mem[131072:0];
integer i;
integer f;

initial begin
    $display("Starting benchmark runner");

    if (`TRACE) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_matmul_absorbtion);
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

reg [63:0] cycle_count;
reg [63:0] retired_instr_count;
reg [63:0] retired_plain_mul_count;
reg [63:0] retired_mule_count;
reg [63:0] retired_mulh_family_count;
reg [63:0] retired_integer_mul_count;
reg pass_reported;
reg fail_reported;

wire [31:0] return_code_w = u_dut.u_issue.u_regfile.REGFILE.reg_r10_q;
wire        pipe0_retire_w = u_dut.u_issue.pipe0_valid_wb_w;
wire        pipe1_retire_w = u_dut.u_issue.pipe1_valid_wb_w;
wire [31:0] pipe0_retire_opcode_w = u_dut.u_issue.pipe0_opc_wb_w;
wire [31:0] pipe1_retire_opcode_w = u_dut.u_issue.pipe1_opc_wb_w;

function is_plain_mul;
    input [31:0] opcode;
begin
    is_plain_mul = ((opcode & `INST_MUL_MASK) == `INST_MUL);
end
endfunction

function is_mule;
    input [31:0] opcode;
begin
    is_mule = ((opcode & `INST_MULE_MASK) == `INST_MULE);
end
endfunction

function is_mulh_family;
    input [31:0] opcode;
begin
    is_mulh_family = ((opcode & `INST_MULH_MASK) == `INST_MULH) ||
                     ((opcode & `INST_MULHU_MASK) == `INST_MULHU) ||
                     ((opcode & `INST_MULHSU_MASK) == `INST_MULHSU);
end
endfunction

wire [1:0] retire_count_w = {1'b0, pipe0_retire_w} + {1'b0, pipe1_retire_w};
wire [1:0] plain_mul_count_w =
    {1'b0, (pipe0_retire_w && is_plain_mul(pipe0_retire_opcode_w))} +
    {1'b0, (pipe1_retire_w && is_plain_mul(pipe1_retire_opcode_w))};
wire [1:0] mule_count_w =
    {1'b0, (pipe0_retire_w && is_mule(pipe0_retire_opcode_w))} +
    {1'b0, (pipe1_retire_w && is_mule(pipe1_retire_opcode_w))};
wire [1:0] mulh_family_count_w =
    {1'b0, (pipe0_retire_w && is_mulh_family(pipe0_retire_opcode_w))} +
    {1'b0, (pipe1_retire_w && is_mulh_family(pipe1_retire_opcode_w))};
wire [2:0] integer_mul_count_w =
    {1'b0, plain_mul_count_w} + {1'b0, mule_count_w} + {1'b0, mulh_family_count_w};

task report_results;
begin
    $display("main_return = %0d", return_code_w);
    $display("sim_total_cycles = %0d", cycle_count);
    $display("retired_total_instructions = %0d", retired_instr_count);
    $display("retired_plain_mul = %0d", retired_plain_mul_count);
    $display("retired_mule = %0d", retired_mule_count);
    $display("retired_mulh_family = %0d", retired_mulh_family_count);
    $display("retired_integer_multiply_total = %0d", retired_integer_mul_count);
    if (retired_instr_count != 0)
        $display("retired_integer_multiply_ratio_ppm = %0d",
                 (retired_integer_mul_count * 64'd1000000) / retired_instr_count);
end
endtask

initial begin
    cycle_count = 0;
    retired_instr_count = 0;
    retired_plain_mul_count = 0;
    retired_mule_count = 0;
    retired_mulh_family_count = 0;
    retired_integer_mul_count = 0;
    pass_reported = 1'b0;
    fail_reported = 1'b0;
end

always @(posedge clk) begin
    if (rst) begin
        cycle_count <= 0;
        retired_instr_count <= 0;
        retired_plain_mul_count <= 0;
        retired_mule_count <= 0;
        retired_mulh_family_count <= 0;
        retired_integer_mul_count <= 0;
        pass_reported <= 1'b0;
        fail_reported <= 1'b0;
    end else begin
        cycle_count <= cycle_count + 1;
        retired_instr_count <= retired_instr_count + retire_count_w;
        retired_plain_mul_count <= retired_plain_mul_count + plain_mul_count_w;
        retired_mule_count <= retired_mule_count + mule_count_w;
        retired_mulh_family_count <= retired_mulh_family_count + mulh_family_count_w;
        retired_integer_mul_count <= retired_integer_mul_count + integer_mul_count_w;

        if (!pass_reported && mem_i_pc_w == PASS_PC) begin
            pass_reported <= 1'b1;
            $display("\n*** BENCHMARK PASS ***");
            report_results();
            $finish;
        end else if (!fail_reported && mem_i_pc_w == FAIL_PC) begin
            fail_reported <= 1'b1;
            $display("\n*** BENCHMARK FAIL ***");
            report_results();
            $finish;
        end else if (cycle_count > TIMEOUT_CYCLES && !pass_reported && !fail_reported) begin
            fail_reported <= 1'b1;
            $display("\nTimeout after %0d cycles (last PC 0x%08h)", cycle_count, mem_i_pc_w);
            report_results();
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