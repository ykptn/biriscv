`include "biriscv_defs.v"

module biriscv_multiplier_array
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           opcode_valid_i
    ,input  [ 31:0]  opcode_opcode_i
    ,input  [ 31:0]  opcode_pc_i
    ,input           opcode_invalid_i
    ,input  [  4:0]  opcode_rd_idx_i
    ,input  [  4:0]  opcode_ra_idx_i
    ,input  [  4:0]  opcode_rb_idx_i
    ,input  [ 31:0]  opcode_ra_operand_i
    ,input  [ 31:0]  opcode_rb_operand_i

    // Outputs
    ,output          writeback_valid_o
    ,output [ 31:0]  writeback_value_o
    ,output [  4:0]  writeback_rd_idx_o
);

wire inst_mula_w = ((opcode_opcode_i & `INST_MULA_MASK) == `INST_MULA);

wire [63:0] pp_w [0:31];
wire [63:0] sum_w [0:32];

genvar i;
generate
    for (i = 0; i < 32; i = i + 1)
    begin : g_pp
        assign pp_w[i] = opcode_rb_operand_i[i] ? ({32'b0, opcode_ra_operand_i} << i) : 64'b0;
    end
endgenerate

assign sum_w[0] = 64'b0;

genvar j;
generate
    for (j = 0; j < 32; j = j + 1)
    begin : g_reduce
        assign sum_w[j + 1] = sum_w[j] + pp_w[j];
    end
endgenerate

wire [63:0] product_w = sum_w[32];

reg         valid_q;
reg [31:0]  result_q;
reg [ 4:0]  rd_idx_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    valid_q  <= 1'b0;
    result_q <= 32'b0;
    rd_idx_q <= 5'b0;
end
else
begin
    valid_q <= opcode_valid_i && inst_mula_w;

    if (opcode_valid_i && inst_mula_w)
    begin
        result_q <= product_w[31:0];
        rd_idx_q <= opcode_rd_idx_i;
    end
    else
    begin
        result_q <= 32'b0;
        rd_idx_q <= 5'b0;
    end
end

assign writeback_valid_o  = valid_q;
assign writeback_value_o  = result_q;
assign writeback_rd_idx_o = rd_idx_q;

endmodule
