`include "biriscv_defs.v"

module biriscv_multiplier_braun
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

wire inst_mulp_w = ((opcode_opcode_i & `INST_MULP_MASK) == `INST_MULP);

// Braun-style full partial-product matrix (unsigned).
wire [63:0] pp_w [0:31];
genvar p;
generate
    for (p = 0; p < 32; p = p + 1)
    begin : g_pp
        assign pp_w[p] = opcode_rb_operand_i[p] ? ({32'b0, opcode_ra_operand_i} << p) : 64'b0;
    end
endgenerate

// Row-wise accumulation (regular array-style reduction).
wire [63:0] row_sum_w [0:32];
assign row_sum_w[0] = 64'b0;

genvar r;
generate
    for (r = 0; r < 32; r = r + 1)
    begin : g_rows
        assign row_sum_w[r + 1] = row_sum_w[r] + pp_w[r];
    end
endgenerate

wire [63:0] product_w = row_sum_w[32];

// Intentionally slow 32-bit ripple-carry final adder stage.
wire [31:0] low_a_w = product_w[31:0];
wire [31:0] low_b_w = 32'b0;
wire [32:0] rca_c_w;
wire [31:0] final_low_w;

assign rca_c_w[0] = 1'b0;

genvar k;
generate
    for (k = 0; k < 32; k = k + 1)
    begin : g_rca
        assign final_low_w[k] = low_a_w[k] ^ low_b_w[k] ^ rca_c_w[k];
        assign rca_c_w[k + 1] = (low_a_w[k] & low_b_w[k]) |
                                (low_a_w[k] & rca_c_w[k]) |
                                (low_b_w[k] & rca_c_w[k]);
    end
endgenerate

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
    valid_q <= opcode_valid_i && inst_mulp_w;

    if (opcode_valid_i && inst_mulp_w)
    begin
        result_q <= final_low_w;
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
