`include "biriscv_defs.v"

module biriscv_bw_csa64
(
    input  [63:0] a_i,
    input  [63:0] b_i,
    input  [63:0] c_i,
    output [63:0] sum_o,
    output [63:0] carry_o
);
assign sum_o   = a_i ^ b_i ^ c_i;
assign carry_o = ((a_i & b_i) | (a_i & c_i) | (b_i & c_i)) << 1;
endmodule

module biriscv_multiplier_baugh_wooley
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

// This unit is configured as unsigned full partial-product 32x32
// with a Kogge-Stone final adder (aggressive power profile).
wire inst_mulb_w = ((opcode_opcode_i & `INST_MULB_MASK) == `INST_MULB);

wire [63:0] pp_w [0:31];
genvar p;
generate
    for (p = 0; p < 32; p = p + 1)
    begin : g_pp
        assign pp_w[p] = opcode_rb_operand_i[p] ? ({32'b0, opcode_ra_operand_i} << p) : 64'b0;
    end
endgenerate

wire [63:0] row_sum_w   [0:31];
wire [63:0] row_carry_w [0:31];

assign row_sum_w[0]   = pp_w[0];
assign row_carry_w[0] = 64'b0;

genvar r;
generate
    for (r = 1; r < 32; r = r + 1)
    begin : g_array_reduce
        biriscv_bw_csa64 u_csa
        (
            .a_i(row_sum_w[r-1]),
            .b_i(row_carry_w[r-1]),
            .c_i(pp_w[r]),
            .sum_o(row_sum_w[r]),
            .carry_o(row_carry_w[r])
        );
    end
endgenerate

wire [63:0] final_product_w;
wire        final_carry_unused_w;
biriscv_kogge_stone_64
u_final_ks
(
    .a_i(row_sum_w[31]),
    .b_i(row_carry_w[31]),
    .sum_o(final_product_w),
    .carry_o(final_carry_unused_w)
);

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
    valid_q <= opcode_valid_i && inst_mulb_w;

    if (opcode_valid_i && inst_mulb_w)
    begin
        result_q <= final_product_w[31:0];
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
