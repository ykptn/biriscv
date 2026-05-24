`include "biriscv_defs.v"

module biriscv_multiplier_cbm
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

wire inst_cbm_w = ((opcode_opcode_i & `INST_CBM_MASK) == `INST_CBM);
wire start_w = opcode_valid_i && inst_cbm_w;

wire        cbm_busy_w;
wire        cbm_done_w;
wire [31:0] cbm_result_w;
wire [ 4:0] cbm_result_rd_idx_w;

column_bypass_multiplier
u_cbm_core
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .start_i(start_w),
    .op_a_i(opcode_ra_operand_i),
    .op_b_i(opcode_rb_operand_i),
    .rd_idx_i(opcode_rd_idx_i),
    .busy_o(cbm_busy_w),
    .done_o(cbm_done_w),
    .result_o(cbm_result_w),
    .result_rd_idx_o(cbm_result_rd_idx_w)
);

assign writeback_valid_o  = cbm_done_w;
assign writeback_value_o  = cbm_result_w;
assign writeback_rd_idx_o = cbm_result_rd_idx_w;

endmodule
