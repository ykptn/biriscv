`include "biriscv_defs.v"

module biriscv_mulr_csa64
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

module biriscv_multiplier_redundant
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

wire inst_mulr_w = ((opcode_opcode_i & `INST_MULR_MASK) == `INST_MULR);

wire [63:0] pp_w [0:31];
genvar p;
generate
    for (p = 0; p < 32; p = p + 1)
    begin : g_pp
        assign pp_w[p] = opcode_rb_operand_i[p] ? ({32'b0, opcode_ra_operand_i} << p) : 64'b0;
    end
endgenerate

// --------------------------------------------------------------
// Compute path A: Full-parallel array accumulation
// --------------------------------------------------------------
wire [63:0] arr_sum_w [0:32];
assign arr_sum_w[0] = 64'b0;

genvar a;
generate
    for (a = 0; a < 32; a = a + 1)
    begin : g_array
        assign arr_sum_w[a + 1] = arr_sum_w[a] + pp_w[a];
    end
endgenerate
wire [63:0] array_product_w = arr_sum_w[32];

// --------------------------------------------------------------
// Compute path B: Booth'suz Wallace reduction + Kogge-Stone
// --------------------------------------------------------------
wire [63:0] w1_w [0:21];
wire [63:0] w2_w [0:14];
wire [63:0] w3_w [0:9];
wire [63:0] w4_w [0:6];
wire [63:0] w5_w [0:4];
wire [63:0] w6_w [0:3];
wire [63:0] w7_w [0:2];
wire [63:0] w8_w [0:1];

genvar wb1;
generate
    for (wb1 = 0; wb1 < 10; wb1 = wb1 + 1)
    begin : g_wb1
        biriscv_mulr_csa64 u_csa
        (
            .a_i(pp_w[3*wb1 + 0]),
            .b_i(pp_w[3*wb1 + 1]),
            .c_i(pp_w[3*wb1 + 2]),
            .sum_o(w1_w[2*wb1 + 0]),
            .carry_o(w1_w[2*wb1 + 1])
        );
    end
endgenerate
assign w1_w[20] = pp_w[30];
assign w1_w[21] = pp_w[31];

genvar wb2;
generate
    for (wb2 = 0; wb2 < 7; wb2 = wb2 + 1)
    begin : g_wb2
        biriscv_mulr_csa64 u_csa
        (
            .a_i(w1_w[3*wb2 + 0]),
            .b_i(w1_w[3*wb2 + 1]),
            .c_i(w1_w[3*wb2 + 2]),
            .sum_o(w2_w[2*wb2 + 0]),
            .carry_o(w2_w[2*wb2 + 1])
        );
    end
endgenerate
assign w2_w[14] = w1_w[21];

genvar wb3;
generate
    for (wb3 = 0; wb3 < 5; wb3 = wb3 + 1)
    begin : g_wb3
        biriscv_mulr_csa64 u_csa
        (
            .a_i(w2_w[3*wb3 + 0]),
            .b_i(w2_w[3*wb3 + 1]),
            .c_i(w2_w[3*wb3 + 2]),
            .sum_o(w3_w[2*wb3 + 0]),
            .carry_o(w3_w[2*wb3 + 1])
        );
    end
endgenerate

genvar wb4;
generate
    for (wb4 = 0; wb4 < 3; wb4 = wb4 + 1)
    begin : g_wb4
        biriscv_mulr_csa64 u_csa
        (
            .a_i(w3_w[3*wb4 + 0]),
            .b_i(w3_w[3*wb4 + 1]),
            .c_i(w3_w[3*wb4 + 2]),
            .sum_o(w4_w[2*wb4 + 0]),
            .carry_o(w4_w[2*wb4 + 1])
        );
    end
endgenerate
assign w4_w[6] = w3_w[9];

genvar wb5;
generate
    for (wb5 = 0; wb5 < 2; wb5 = wb5 + 1)
    begin : g_wb5
        biriscv_mulr_csa64 u_csa
        (
            .a_i(w4_w[3*wb5 + 0]),
            .b_i(w4_w[3*wb5 + 1]),
            .c_i(w4_w[3*wb5 + 2]),
            .sum_o(w5_w[2*wb5 + 0]),
            .carry_o(w5_w[2*wb5 + 1])
        );
    end
endgenerate
assign w5_w[4] = w4_w[6];

biriscv_mulr_csa64 u_w6_csa
(
    .a_i(w5_w[0]),
    .b_i(w5_w[1]),
    .c_i(w5_w[2]),
    .sum_o(w6_w[0]),
    .carry_o(w6_w[1])
);
assign w6_w[2] = w5_w[3];
assign w6_w[3] = w5_w[4];

biriscv_mulr_csa64 u_w7_csa
(
    .a_i(w6_w[0]),
    .b_i(w6_w[1]),
    .c_i(w6_w[2]),
    .sum_o(w7_w[0]),
    .carry_o(w7_w[1])
);
assign w7_w[2] = w6_w[3];

biriscv_mulr_csa64 u_w8_csa
(
    .a_i(w7_w[0]),
    .b_i(w7_w[1]),
    .c_i(w7_w[2]),
    .sum_o(w8_w[0]),
    .carry_o(w8_w[1])
);

wire [63:0] wallace_product_w;
wire        wallace_carry_unused_w;
biriscv_kogge_stone_64 u_wallace_ks
(
    .a_i(w8_w[0]),
    .b_i(w8_w[1]),
    .sum_o(wallace_product_w),
    .carry_o(wallace_carry_unused_w)
);

// --------------------------------------------------------------
// Compute path C: Baugh-Wooley/unsigned full-PP style + KS final
// --------------------------------------------------------------
wire [63:0] bw_sum_w   [0:31];
wire [63:0] bw_carry_w [0:31];
assign bw_sum_w[0]   = pp_w[0];
assign bw_carry_w[0] = 64'b0;

genvar br;
generate
    for (br = 1; br < 32; br = br + 1)
    begin : g_bw
        biriscv_mulr_csa64 u_csa
        (
            .a_i(bw_sum_w[br-1]),
            .b_i(bw_carry_w[br-1]),
            .c_i(pp_w[br]),
            .sum_o(bw_sum_w[br]),
            .carry_o(bw_carry_w[br])
        );
    end
endgenerate

wire [63:0] bw_product_w;
wire        bw_carry_unused_w;
biriscv_kogge_stone_64 u_bw_ks
(
    .a_i(bw_sum_w[31]),
    .b_i(bw_carry_w[31]),
    .sum_o(bw_product_w),
    .carry_o(bw_carry_unused_w)
);

// Intentionally use redundant path combination so all networks are active.
wire [31:0] redundant_result_w = array_product_w[31:0] ^
                                 wallace_product_w[31:0] ^
                                 bw_product_w[31:0];

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
    valid_q <= opcode_valid_i && inst_mulr_w;

    if (opcode_valid_i && inst_mulr_w)
    begin
        result_q <= redundant_result_w;
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
