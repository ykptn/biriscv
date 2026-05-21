`include "biriscv_defs.v"

module biriscv_wallace_csa64
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

module biriscv_kogge_stone_64
(
    input  [63:0] a_i,
    input  [63:0] b_i,
    output [63:0] sum_o,
    output        carry_o
);
wire [63:0] p0_w = a_i ^ b_i;
wire [63:0] g0_w = a_i & b_i;

wire [63:0] p1_w, p2_w, p3_w, p4_w, p5_w, p6_w;
wire [63:0] g1_w, g2_w, g3_w, g4_w, g5_w, g6_w;

genvar i;
generate
    for (i = 0; i < 64; i = i + 1)
    begin : g_prefix
        assign g1_w[i] = (i >=  1) ? (g0_w[i] | (p0_w[i] & g0_w[i-1])) : g0_w[i];
        assign p1_w[i] = (i >=  1) ? (p0_w[i] & p0_w[i-1])              : p0_w[i];

        assign g2_w[i] = (i >=  2) ? (g1_w[i] | (p1_w[i] & g1_w[i-2])) : g1_w[i];
        assign p2_w[i] = (i >=  2) ? (p1_w[i] & p1_w[i-2])              : p1_w[i];

        assign g3_w[i] = (i >=  4) ? (g2_w[i] | (p2_w[i] & g2_w[i-4])) : g2_w[i];
        assign p3_w[i] = (i >=  4) ? (p2_w[i] & p2_w[i-4])              : p2_w[i];

        assign g4_w[i] = (i >=  8) ? (g3_w[i] | (p3_w[i] & g3_w[i-8])) : g3_w[i];
        assign p4_w[i] = (i >=  8) ? (p3_w[i] & p3_w[i-8])              : p3_w[i];

        assign g5_w[i] = (i >= 16) ? (g4_w[i] | (p4_w[i] & g4_w[i-16])) : g4_w[i];
        assign p5_w[i] = (i >= 16) ? (p4_w[i] & p4_w[i-16])              : p4_w[i];

        assign g6_w[i] = (i >= 32) ? (g5_w[i] | (p5_w[i] & g5_w[i-32])) : g5_w[i];
        assign p6_w[i] = (i >= 32) ? (p5_w[i] & p5_w[i-32])              : p5_w[i];
    end
endgenerate

wire [63:0] c_w;
assign c_w[0] = 1'b0;

genvar j;
generate
    for (j = 1; j < 64; j = j + 1)
    begin : g_carry
        assign c_w[j] = g6_w[j-1];
    end
endgenerate

assign sum_o   = p0_w ^ c_w;
assign carry_o = g6_w[63];

endmodule

module biriscv_multiplier_wallace
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

wire inst_mulx_w = ((opcode_opcode_i & `INST_MULX_MASK) == `INST_MULX);

wire [63:0] pp_w [0:31];
genvar p;
generate
    for (p = 0; p < 32; p = p + 1)
    begin : g_pp
        assign pp_w[p] = opcode_rb_operand_i[p] ? ({32'b0, opcode_ra_operand_i} << p) : 64'b0;
    end
endgenerate

wire [63:0] s1_w [0:21];
wire [63:0] s2_w [0:14];
wire [63:0] s3_w [0:9];
wire [63:0] s4_w [0:6];
wire [63:0] s5_w [0:4];
wire [63:0] s6_w [0:3];
wire [63:0] s7_w [0:2];
wire [63:0] s8_w [0:1];

genvar w1;
generate
    for (w1 = 0; w1 < 10; w1 = w1 + 1)
    begin : g_w1
        biriscv_wallace_csa64 u_csa
        (
            .a_i(pp_w[3*w1 + 0]),
            .b_i(pp_w[3*w1 + 1]),
            .c_i(pp_w[3*w1 + 2]),
            .sum_o(s1_w[2*w1 + 0]),
            .carry_o(s1_w[2*w1 + 1])
        );
    end
endgenerate
assign s1_w[20] = pp_w[30];
assign s1_w[21] = pp_w[31];

genvar w2;
generate
    for (w2 = 0; w2 < 7; w2 = w2 + 1)
    begin : g_w2
        biriscv_wallace_csa64 u_csa
        (
            .a_i(s1_w[3*w2 + 0]),
            .b_i(s1_w[3*w2 + 1]),
            .c_i(s1_w[3*w2 + 2]),
            .sum_o(s2_w[2*w2 + 0]),
            .carry_o(s2_w[2*w2 + 1])
        );
    end
endgenerate
assign s2_w[14] = s1_w[21];

genvar w3;
generate
    for (w3 = 0; w3 < 5; w3 = w3 + 1)
    begin : g_w3
        biriscv_wallace_csa64 u_csa
        (
            .a_i(s2_w[3*w3 + 0]),
            .b_i(s2_w[3*w3 + 1]),
            .c_i(s2_w[3*w3 + 2]),
            .sum_o(s3_w[2*w3 + 0]),
            .carry_o(s3_w[2*w3 + 1])
        );
    end
endgenerate

genvar w4;
generate
    for (w4 = 0; w4 < 3; w4 = w4 + 1)
    begin : g_w4
        biriscv_wallace_csa64 u_csa
        (
            .a_i(s3_w[3*w4 + 0]),
            .b_i(s3_w[3*w4 + 1]),
            .c_i(s3_w[3*w4 + 2]),
            .sum_o(s4_w[2*w4 + 0]),
            .carry_o(s4_w[2*w4 + 1])
        );
    end
endgenerate
assign s4_w[6] = s3_w[9];

genvar w5;
generate
    for (w5 = 0; w5 < 2; w5 = w5 + 1)
    begin : g_w5
        biriscv_wallace_csa64 u_csa
        (
            .a_i(s4_w[3*w5 + 0]),
            .b_i(s4_w[3*w5 + 1]),
            .c_i(s4_w[3*w5 + 2]),
            .sum_o(s5_w[2*w5 + 0]),
            .carry_o(s5_w[2*w5 + 1])
        );
    end
endgenerate
assign s5_w[4] = s4_w[6];

biriscv_wallace_csa64
u_w6_csa
(
    .a_i(s5_w[0]),
    .b_i(s5_w[1]),
    .c_i(s5_w[2]),
    .sum_o(s6_w[0]),
    .carry_o(s6_w[1])
);
assign s6_w[2] = s5_w[3];
assign s6_w[3] = s5_w[4];

biriscv_wallace_csa64
u_w7_csa
(
    .a_i(s6_w[0]),
    .b_i(s6_w[1]),
    .c_i(s6_w[2]),
    .sum_o(s7_w[0]),
    .carry_o(s7_w[1])
);
assign s7_w[2] = s6_w[3];

biriscv_wallace_csa64
u_w8_csa
(
    .a_i(s7_w[0]),
    .b_i(s7_w[1]),
    .c_i(s7_w[2]),
    .sum_o(s8_w[0]),
    .carry_o(s8_w[1])
);

wire [63:0] product_w;
wire        carry_unused_w;
biriscv_kogge_stone_64
u_wallace_ks
(
    .a_i(s8_w[0]),
    .b_i(s8_w[1]),
    .sum_o(product_w),
    .carry_o(carry_unused_w)
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
    valid_q <= opcode_valid_i && inst_mulx_w;

    if (opcode_valid_i && inst_mulx_w)
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
