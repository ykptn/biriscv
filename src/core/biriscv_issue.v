//-----------------------------------------------------------------
//                         biRISC-V CPU
//                            V0.8.1
//                     Ultra-Embedded.com
//                     Copyright 2019-2020
//
//                   admin@ultra-embedded.com
//
//                     License: Apache 2.0
//-----------------------------------------------------------------
// Copyright 2020 Ultra-Embedded.com
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

module biriscv_issue
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter SUPPORT_MULDIV   = 1
    ,parameter SUPPORT_DUAL_ISSUE = 1
    ,parameter SUPPORT_LOAD_BYPASS = 1
    ,parameter SUPPORT_MUL_BYPASS = 1
    ,parameter SUPPORT_REGFILE_XILINX = 0
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           fetch0_valid_i
    ,input  [ 31:0]  fetch0_instr_i
    ,input  [ 31:0]  fetch0_pc_i
    ,input           fetch0_fault_fetch_i
    ,input           fetch0_fault_page_i
    ,input           fetch0_instr_exec_i
    ,input           fetch0_instr_lsu_i
    ,input           fetch0_instr_branch_i
    ,input           fetch0_instr_mul_i
    ,input           fetch0_instr_div_i
    ,input           fetch0_instr_csr_i
    ,input           fetch0_instr_rd_valid_i
    ,input           fetch0_instr_invalid_i
    ,input           fetch1_valid_i
    ,input  [ 31:0]  fetch1_instr_i
    ,input  [ 31:0]  fetch1_pc_i
    ,input           fetch1_fault_fetch_i
    ,input           fetch1_fault_page_i
    ,input           fetch1_instr_exec_i
    ,input           fetch1_instr_lsu_i
    ,input           fetch1_instr_branch_i
    ,input           fetch1_instr_mul_i
    ,input           fetch1_instr_div_i
    ,input           fetch1_instr_csr_i
    ,input           fetch0_instr_mule_i
    ,input           fetch1_instr_mule_i
    ,input           fetch0_instr_mulen_i
    ,input           fetch1_instr_mulen_i
    ,input           fetch0_instr_mule2_i
    ,input           fetch1_instr_mule2_i
    ,input           fetch0_instr_mule2n_i
    ,input           fetch1_instr_mule2n_i
    ,input           fetch0_instr_mule3_i
    ,input           fetch1_instr_mule3_i
    ,input           fetch0_instr_mule3n_i
    ,input           fetch1_instr_mule3n_i
    ,input           fetch0_instr_mule5_i
    ,input           fetch1_instr_mule5_i
    ,input           fetch0_instr_mule5n_i
    ,input           fetch1_instr_mule5n_i
    ,input           fetch0_instr_cbm_i
    ,input           fetch1_instr_cbm_i
    ,input           fetch0_instr_mula_i
    ,input           fetch1_instr_mula_i
    ,input           fetch0_instr_mulx_i
    ,input           fetch1_instr_mulx_i
    ,input           fetch0_instr_mulb_i
    ,input           fetch1_instr_mulb_i
    ,input           fetch0_instr_mulr_i
    ,input           fetch1_instr_mulr_i
    ,input           fetch0_instr_mulp_i
    ,input           fetch1_instr_mulp_i
    ,input           fetch0_instr_mulc_i
    ,input           fetch1_instr_mulc_i
    ,input           fetch1_instr_rd_valid_i
    ,input           fetch1_instr_invalid_i
    ,input           branch_exec0_request_i
    ,input           branch_exec0_is_taken_i
    ,input           branch_exec0_is_not_taken_i
    ,input  [ 31:0]  branch_exec0_source_i
    ,input           branch_exec0_is_call_i
    ,input           branch_exec0_is_ret_i
    ,input           branch_exec0_is_jmp_i
    ,input  [ 31:0]  branch_exec0_pc_i
    ,input           branch_d_exec0_request_i
    ,input  [ 31:0]  branch_d_exec0_pc_i
    ,input  [  1:0]  branch_d_exec0_priv_i
    ,input           branch_exec1_request_i
    ,input           branch_exec1_is_taken_i
    ,input           branch_exec1_is_not_taken_i
    ,input  [ 31:0]  branch_exec1_source_i
    ,input           branch_exec1_is_call_i
    ,input           branch_exec1_is_ret_i
    ,input           branch_exec1_is_jmp_i
    ,input  [ 31:0]  branch_exec1_pc_i
    ,input           branch_d_exec1_request_i
    ,input  [ 31:0]  branch_d_exec1_pc_i
    ,input  [  1:0]  branch_d_exec1_priv_i
    ,input           branch_csr_request_i
    ,input  [ 31:0]  branch_csr_pc_i
    ,input  [  1:0]  branch_csr_priv_i
    ,input  [ 31:0]  writeback_exec0_value_i
    ,input  [ 31:0]  writeback_exec1_value_i
    ,input           writeback_mem_valid_i
    ,input  [ 31:0]  writeback_mem_value_i
    ,input  [  5:0]  writeback_mem_exception_i
    ,input  [ 31:0]  writeback_mul_value_i
    ,input           writeback_div_valid_i
    ,input  [ 31:0]  writeback_div_value_i
    ,input           writeback_mule_valid_i
    ,input  [ 31:0]  writeback_mule_value_i
    ,input  [  4:0]  writeback_mule_rd_idx_i
    ,input           writeback_mulen_valid_i
    ,input  [ 31:0]  writeback_mulen_value_i
    ,input  [  4:0]  writeback_mulen_rd_idx_i
    ,input           writeback_mule2_valid_i
    ,input  [ 31:0]  writeback_mule2_value_i
    ,input  [  4:0]  writeback_mule2_rd_idx_i
    ,input           writeback_mule2n_valid_i
    ,input  [ 31:0]  writeback_mule2n_value_i
    ,input  [  4:0]  writeback_mule2n_rd_idx_i
    ,input           writeback_mule3_valid_i
    ,input  [ 31:0]  writeback_mule3_value_i
    ,input  [  4:0]  writeback_mule3_rd_idx_i
    ,input           writeback_mule3n_valid_i
    ,input  [ 31:0]  writeback_mule3n_value_i
    ,input  [  4:0]  writeback_mule3n_rd_idx_i
    ,input           writeback_mule5_valid_i
    ,input  [ 31:0]  writeback_mule5_value_i
    ,input  [  4:0]  writeback_mule5_rd_idx_i
    ,input           writeback_mule5n_valid_i
    ,input  [ 31:0]  writeback_mule5n_value_i
    ,input  [  4:0]  writeback_mule5n_rd_idx_i
    ,input           writeback_cbm_valid_i
    ,input  [ 31:0]  writeback_cbm_value_i
    ,input  [  4:0]  writeback_cbm_rd_idx_i
    ,input           writeback_mula_valid_i
    ,input  [ 31:0]  writeback_mula_value_i
    ,input  [  4:0]  writeback_mula_rd_idx_i
    ,input           writeback_mulx_valid_i
    ,input  [ 31:0]  writeback_mulx_value_i
    ,input  [  4:0]  writeback_mulx_rd_idx_i
    ,input           writeback_mulb_valid_i
    ,input  [ 31:0]  writeback_mulb_value_i
    ,input  [  4:0]  writeback_mulb_rd_idx_i
    ,input           writeback_mulr_valid_i
    ,input  [ 31:0]  writeback_mulr_value_i
    ,input  [  4:0]  writeback_mulr_rd_idx_i
    ,input           writeback_mulp_valid_i
    ,input  [ 31:0]  writeback_mulp_value_i
    ,input  [  4:0]  writeback_mulp_rd_idx_i
    ,input           writeback_mulc_valid_i
    ,input  [ 31:0]  writeback_mulc_value_i
    ,input  [  4:0]  writeback_mulc_rd_idx_i
    ,input  [ 31:0]  csr_result_e1_value_i
    ,input           csr_result_e1_write_i
    ,input  [ 31:0]  csr_result_e1_wdata_i
    ,input  [  5:0]  csr_result_e1_exception_i
    ,input           lsu_stall_i
    ,input           take_interrupt_i

    // Outputs
    ,output          fetch0_accept_o
    ,output          fetch1_accept_o
    ,output          branch_request_o
    ,output [ 31:0]  branch_pc_o
    ,output [  1:0]  branch_priv_o
    ,output          branch_info_request_o
    ,output          branch_info_is_taken_o
    ,output          branch_info_is_not_taken_o
    ,output [ 31:0]  branch_info_source_o
    ,output          branch_info_is_call_o
    ,output          branch_info_is_ret_o
    ,output          branch_info_is_jmp_o
    ,output [ 31:0]  branch_info_pc_o
    ,output          exec0_opcode_valid_o
    ,output          exec1_opcode_valid_o
    ,output          lsu_opcode_valid_o
    ,output          csr_opcode_valid_o
    ,output          mul_opcode_valid_o
    ,output          div_opcode_valid_o
    ,output          mule_opcode_valid_o
    ,output          mulen_opcode_valid_o
    ,output          mule2_opcode_valid_o
    ,output          mule2n_opcode_valid_o
    ,output          mule3_opcode_valid_o
    ,output          mule3n_opcode_valid_o
    ,output          mule5_opcode_valid_o
    ,output          mule5n_opcode_valid_o
    ,output          mula_opcode_valid_o
    ,output          mulx_opcode_valid_o
    ,output          mulb_opcode_valid_o
    ,output          mulr_opcode_valid_o
    ,output          mulp_opcode_valid_o
    ,output          mulc_opcode_valid_o
    ,output          cbm_inst_opcode_valid_o
    ,output [ 31:0]  opcode0_opcode_o
    ,output [ 31:0]  opcode0_pc_o
    ,output          opcode0_invalid_o
    ,output [  4:0]  opcode0_rd_idx_o
    ,output [  4:0]  opcode0_ra_idx_o
    ,output [  4:0]  opcode0_rb_idx_o
    ,output [ 31:0]  opcode0_ra_operand_o
    ,output [ 31:0]  opcode0_rb_operand_o
    ,output [ 31:0]  opcode1_opcode_o
    ,output [ 31:0]  opcode1_pc_o
    ,output          opcode1_invalid_o
    ,output [  4:0]  opcode1_rd_idx_o
    ,output [  4:0]  opcode1_ra_idx_o
    ,output [  4:0]  opcode1_rb_idx_o
    ,output [ 31:0]  opcode1_ra_operand_o
    ,output [ 31:0]  opcode1_rb_operand_o
    ,output [ 31:0]  lsu_opcode_opcode_o
    ,output [ 31:0]  lsu_opcode_pc_o
    ,output          lsu_opcode_invalid_o
    ,output [  4:0]  lsu_opcode_rd_idx_o
    ,output [  4:0]  lsu_opcode_ra_idx_o
    ,output [  4:0]  lsu_opcode_rb_idx_o
    ,output [ 31:0]  lsu_opcode_ra_operand_o
    ,output [ 31:0]  lsu_opcode_rb_operand_o
    ,output [ 31:0]  mul_opcode_opcode_o
    ,output [ 31:0]  mul_opcode_pc_o
    ,output          mul_opcode_invalid_o
    ,output [  4:0]  mul_opcode_rd_idx_o
    ,output [  4:0]  mul_opcode_ra_idx_o
    ,output [  4:0]  mul_opcode_rb_idx_o
    ,output [ 31:0]  mul_opcode_ra_operand_o
    ,output [ 31:0]  mul_opcode_rb_operand_o
    ,output [ 31:0]  csr_opcode_opcode_o
    ,output [ 31:0]  mule_opcode_opcode_o
    ,output [ 31:0]  mule_opcode_pc_o
    ,output          mule_opcode_invalid_o
    ,output [  4:0]  mule_opcode_rd_idx_o
    ,output [  4:0]  mule_opcode_ra_idx_o
    ,output [  4:0]  mule_opcode_rb_idx_o
    ,output [ 31:0]  mule_opcode_ra_operand_o
    ,output [ 31:0]  mule_opcode_rb_operand_o
    ,output [ 31:0]  mulen_opcode_opcode_o
    ,output [ 31:0]  mulen_opcode_pc_o
    ,output          mulen_opcode_invalid_o
    ,output [  4:0]  mulen_opcode_rd_idx_o
    ,output [  4:0]  mulen_opcode_ra_idx_o
    ,output [  4:0]  mulen_opcode_rb_idx_o
    ,output [ 31:0]  mulen_opcode_ra_operand_o
    ,output [ 31:0]  mulen_opcode_rb_operand_o
    ,output [ 31:0]  mule2_opcode_opcode_o
    ,output [ 31:0]  mule2_opcode_pc_o
    ,output          mule2_opcode_invalid_o
    ,output [  4:0]  mule2_opcode_rd_idx_o
    ,output [  4:0]  mule2_opcode_ra_idx_o
    ,output [  4:0]  mule2_opcode_rb_idx_o
    ,output [ 31:0]  mule2_opcode_ra_operand_o
    ,output [ 31:0]  mule2_opcode_rb_operand_o
    ,output [ 31:0]  mule2n_opcode_opcode_o
    ,output [ 31:0]  mule2n_opcode_pc_o
    ,output          mule2n_opcode_invalid_o
    ,output [  4:0]  mule2n_opcode_rd_idx_o
    ,output [  4:0]  mule2n_opcode_ra_idx_o
    ,output [  4:0]  mule2n_opcode_rb_idx_o
    ,output [ 31:0]  mule2n_opcode_ra_operand_o
    ,output [ 31:0]  mule2n_opcode_rb_operand_o
    ,output [ 31:0]  mule3_opcode_opcode_o
    ,output [ 31:0]  mule3_opcode_pc_o
    ,output          mule3_opcode_invalid_o
    ,output [  4:0]  mule3_opcode_rd_idx_o
    ,output [  4:0]  mule3_opcode_ra_idx_o
    ,output [  4:0]  mule3_opcode_rb_idx_o
    ,output [ 31:0]  mule3_opcode_ra_operand_o
    ,output [ 31:0]  mule3_opcode_rb_operand_o
    ,output [ 31:0]  mule3n_opcode_opcode_o
    ,output [ 31:0]  mule3n_opcode_pc_o
    ,output          mule3n_opcode_invalid_o
    ,output [  4:0]  mule3n_opcode_rd_idx_o
    ,output [  4:0]  mule3n_opcode_ra_idx_o
    ,output [  4:0]  mule3n_opcode_rb_idx_o
    ,output [ 31:0]  mule3n_opcode_ra_operand_o
    ,output [ 31:0]  mule3n_opcode_rb_operand_o
    ,output [ 31:0]  mule5_opcode_opcode_o
    ,output [ 31:0]  mule5_opcode_pc_o
    ,output          mule5_opcode_invalid_o
    ,output [  4:0]  mule5_opcode_rd_idx_o
    ,output [  4:0]  mule5_opcode_ra_idx_o
    ,output [  4:0]  mule5_opcode_rb_idx_o
    ,output [ 31:0]  mule5_opcode_ra_operand_o
    ,output [ 31:0]  mule5_opcode_rb_operand_o
    ,output [ 31:0]  mule5n_opcode_opcode_o
    ,output [ 31:0]  mule5n_opcode_pc_o
    ,output          mule5n_opcode_invalid_o
    ,output [  4:0]  mule5n_opcode_rd_idx_o
    ,output [  4:0]  mule5n_opcode_ra_idx_o
    ,output [  4:0]  mule5n_opcode_rb_idx_o
    ,output [ 31:0]  mule5n_opcode_ra_operand_o
    ,output [ 31:0]  mule5n_opcode_rb_operand_o
    ,output [ 31:0]  mula_opcode_opcode_o
    ,output [ 31:0]  mula_opcode_pc_o
    ,output          mula_opcode_invalid_o
    ,output [  4:0]  mula_opcode_rd_idx_o
    ,output [  4:0]  mula_opcode_ra_idx_o
    ,output [  4:0]  mula_opcode_rb_idx_o
    ,output [ 31:0]  mula_opcode_ra_operand_o
    ,output [ 31:0]  mula_opcode_rb_operand_o
    ,output [ 31:0]  mulx_opcode_opcode_o
    ,output [ 31:0]  mulx_opcode_pc_o
    ,output          mulx_opcode_invalid_o
    ,output [  4:0]  mulx_opcode_rd_idx_o
    ,output [  4:0]  mulx_opcode_ra_idx_o
    ,output [  4:0]  mulx_opcode_rb_idx_o
    ,output [ 31:0]  mulx_opcode_ra_operand_o
    ,output [ 31:0]  mulx_opcode_rb_operand_o
    ,output [ 31:0]  mulb_opcode_opcode_o
    ,output [ 31:0]  mulb_opcode_pc_o
    ,output          mulb_opcode_invalid_o
    ,output [  4:0]  mulb_opcode_rd_idx_o
    ,output [  4:0]  mulb_opcode_ra_idx_o
    ,output [  4:0]  mulb_opcode_rb_idx_o
    ,output [ 31:0]  mulb_opcode_ra_operand_o
    ,output [ 31:0]  mulb_opcode_rb_operand_o
    ,output [ 31:0]  mulr_opcode_opcode_o
    ,output [ 31:0]  mulr_opcode_pc_o
    ,output          mulr_opcode_invalid_o
    ,output [  4:0]  mulr_opcode_rd_idx_o
    ,output [  4:0]  mulr_opcode_ra_idx_o
    ,output [  4:0]  mulr_opcode_rb_idx_o
    ,output [ 31:0]  mulr_opcode_ra_operand_o
    ,output [ 31:0]  mulr_opcode_rb_operand_o
    ,output [ 31:0]  mulp_opcode_opcode_o
    ,output [ 31:0]  mulp_opcode_pc_o
    ,output          mulp_opcode_invalid_o
    ,output [  4:0]  mulp_opcode_rd_idx_o
    ,output [  4:0]  mulp_opcode_ra_idx_o
    ,output [  4:0]  mulp_opcode_rb_idx_o
    ,output [ 31:0]  mulp_opcode_ra_operand_o
    ,output [ 31:0]  mulp_opcode_rb_operand_o
    ,output [ 31:0]  mulc_opcode_opcode_o
    ,output [ 31:0]  mulc_opcode_pc_o
    ,output          mulc_opcode_invalid_o
    ,output [  4:0]  mulc_opcode_rd_idx_o
    ,output [  4:0]  mulc_opcode_ra_idx_o
    ,output [  4:0]  mulc_opcode_rb_idx_o
    ,output [ 31:0]  mulc_opcode_ra_operand_o
    ,output [ 31:0]  mulc_opcode_rb_operand_o
    ,output [ 31:0]  cbm_inst_opcode_opcode_o
    ,output [ 31:0]  cbm_inst_opcode_pc_o
    ,output          cbm_inst_opcode_invalid_o
    ,output [  4:0]  cbm_inst_opcode_rd_idx_o
    ,output [  4:0]  cbm_inst_opcode_ra_idx_o
    ,output [  4:0]  cbm_inst_opcode_rb_idx_o
    ,output [ 31:0]  cbm_inst_opcode_ra_operand_o
    ,output [ 31:0]  cbm_inst_opcode_rb_operand_o
    ,output          cbm_opcode_valid_o
    ,output [ 31:0]  cbm_opcode_opcode_o
    ,output [ 31:0]  cbm_opcode_pc_o
    ,output          cbm_opcode_invalid_o
    ,output [  4:0]  cbm_opcode_rd_idx_o
    ,output [  4:0]  cbm_opcode_ra_idx_o
    ,output [  4:0]  cbm_opcode_rb_idx_o
    ,output [ 31:0]  cbm_opcode_ra_operand_o
    ,output [ 31:0]  cbm_opcode_rb_operand_o
    ,output [ 31:0]  csr_opcode_pc_o
    ,output          csr_opcode_invalid_o
    ,output [  4:0]  csr_opcode_rd_idx_o
    ,output [  4:0]  csr_opcode_ra_idx_o
    ,output [  4:0]  csr_opcode_rb_idx_o
    ,output [ 31:0]  csr_opcode_ra_operand_o
    ,output [ 31:0]  csr_opcode_rb_operand_o
    ,output          csr_writeback_write_o
    ,output [ 11:0]  csr_writeback_waddr_o
    ,output [ 31:0]  csr_writeback_wdata_o
    ,output [  5:0]  csr_writeback_exception_o
    ,output [ 31:0]  csr_writeback_exception_pc_o
    ,output [ 31:0]  csr_writeback_exception_addr_o
    ,output          exec0_hold_o
    ,output          exec1_hold_o
    ,output          mul_hold_o
    ,output          interrupt_inhibit_o
);



`include "biriscv_defs.v"

wire enable_dual_issue_w = SUPPORT_DUAL_ISSUE;
wire enable_muldiv_w     = SUPPORT_MULDIV;
wire enable_mul_bypass_w = SUPPORT_MUL_BYPASS;

wire stall_w;
wire squash_w;

//-------------------------------------------------------------
// PC
//-------------------------------------------------------------
wire        single_issue_w;
wire        dual_issue_w;
reg  [31:0] pc_x_q;
reg   [1:0] priv_x_q;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    pc_x_q <= 32'b0;
else if (branch_csr_request_i)
    pc_x_q <= branch_csr_pc_i;
else if (branch_d_exec1_request_i)
    pc_x_q <= branch_d_exec1_pc_i;
else if (branch_d_exec0_request_i)
    pc_x_q <= branch_d_exec0_pc_i;
else if (dual_issue_w)
    pc_x_q <= pc_x_q + 32'd8;
else if (single_issue_w)
    pc_x_q <= pc_x_q + 32'd4;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    priv_x_q <= `PRIV_MACHINE;
else if (branch_csr_request_i)
    priv_x_q <= branch_csr_priv_i;

//-------------------------------------------------------------
// Issue Select
//-------------------------------------------------------------
reg mispredicted_r;
reg slot0_valid_r;
reg slot1_valid_r;

always @ *
begin
    mispredicted_r = 1'b0;
    slot0_valid_r  = 1'b0;
    slot1_valid_r  = 1'b0;

    // Flush due to CSR branch
    if (branch_csr_request_i || squash_w)
    begin
        slot0_valid_r  = 1'b0;
        slot1_valid_r  = 1'b0;
    end
    // Word 0 valid and expected PC (word 1 may also be valid)
    else if (fetch0_valid_i && {fetch0_pc_i[31:2], 2'b0} == {pc_x_q[31:2], 2'b0})
        slot0_valid_r  = 1'b1;
    // Word 1 valid and expected PC
    else if (fetch1_valid_i && {fetch1_pc_i[31:2], 2'b0} == {pc_x_q[31:2], 2'b0})
        slot1_valid_r  = 1'b1;
    // Neither word is the expected PC - must be a branch misprediction
    else if (fetch0_valid_i || fetch1_valid_i)
        mispredicted_r = 1'b1;
end

// Branch request (CSR branch - ecall, xret, or branch misprediction)
// Note: Correctly predicted branches are silent
assign branch_request_o          = branch_csr_request_i | mispredicted_r;
assign branch_pc_o               = branch_csr_request_i ? branch_csr_pc_i : pc_x_q;
assign branch_priv_o             = branch_csr_request_i ? branch_csr_priv_i : priv_x_q;

//-------------------------------------------------------------
// Instruction Decoder
//-------------------------------------------------------------
reg        opcode_a_valid_r;
reg        opcode_b_valid_r;
reg [1:0]  opcode_a_fault_r;
reg [1:0]  opcode_b_fault_r;
reg [31:0] opcode_a_r;
reg [31:0] opcode_b_r;
reg [31:0] opcode_a_pc_r;
reg [31:0] opcode_b_pc_r;

always @ *
begin
    opcode_a_r       = 32'b0;
    opcode_b_r       = 32'b0;
    opcode_a_valid_r = 1'b0;
    opcode_b_valid_r = 1'b0;
    opcode_a_fault_r = 2'b0;
    opcode_b_fault_r = 2'b0;
    opcode_a_pc_r    = 32'b0;
    opcode_b_pc_r    = 32'b0;

    // Word 0 (and possibly slot 1) are valid instructions
    if (slot0_valid_r)
    begin
        opcode_a_valid_r = 1'b1;
        opcode_b_valid_r = fetch1_valid_i;
        opcode_a_r       = fetch0_instr_i;
        opcode_a_pc_r    = fetch0_pc_i;
        opcode_a_fault_r = {fetch0_fault_page_i, fetch0_fault_fetch_i};
        opcode_b_r       = fetch1_instr_i;
        opcode_b_pc_r    = fetch1_pc_i;
        opcode_b_fault_r = {fetch1_fault_page_i, fetch1_fault_fetch_i};
    end
    // Word 1 valid - mux to first issue slot
    // Note: Some instruction types can only issue in slot0, hence this muxing
    else if (slot1_valid_r)
    begin
        opcode_a_valid_r = 1'b1;
        opcode_b_valid_r = 1'b0;
        opcode_a_r       = fetch1_instr_i;
        opcode_a_pc_r    = fetch1_pc_i;
        opcode_a_fault_r = {fetch1_fault_page_i, fetch1_fault_fetch_i};
        opcode_b_r       = 32'b0;
        opcode_b_pc_r    = 32'b0;
        opcode_b_fault_r = 2'b0;
    end
end

wire [4:0] issue_a_ra_idx_w   = opcode_a_r[19:15];
wire [4:0] issue_a_rb_idx_w   = opcode_a_r[24:20];
wire [4:0] issue_a_rd_idx_w   = opcode_a_r[11:7];
wire       issue_a_sb_alloc_w = (slot0_valid_r ? fetch0_instr_rd_valid_i : fetch1_instr_rd_valid_i);
wire       issue_a_exec_w     = (slot0_valid_r ? fetch0_instr_exec_i     : fetch1_instr_exec_i);
wire       issue_a_lsu_w      = (slot0_valid_r ? fetch0_instr_lsu_i      : fetch1_instr_lsu_i);
wire       issue_a_branch_w   = (slot0_valid_r ? fetch0_instr_branch_i   : fetch1_instr_branch_i);
wire       issue_a_mul_w      = (slot0_valid_r ? fetch0_instr_mul_i      : fetch1_instr_mul_i);
wire       issue_a_div_w      = (slot0_valid_r ? fetch0_instr_div_i      : fetch1_instr_div_i);
wire       issue_a_mule_w     = (slot0_valid_r ? fetch0_instr_mule_i     : fetch1_instr_mule_i);
wire       issue_a_mulen_w    = (slot0_valid_r ? fetch0_instr_mulen_i    : fetch1_instr_mulen_i);
wire       issue_a_mule2_w    = (slot0_valid_r ? fetch0_instr_mule2_i    : fetch1_instr_mule2_i);
wire       issue_a_mule2n_w   = (slot0_valid_r ? fetch0_instr_mule2n_i   : fetch1_instr_mule2n_i);
wire       issue_a_mule3_w    = (slot0_valid_r ? fetch0_instr_mule3_i    : fetch1_instr_mule3_i);
wire       issue_a_mule3n_w   = (slot0_valid_r ? fetch0_instr_mule3n_i   : fetch1_instr_mule3n_i);
wire       issue_a_mule5_w    = (slot0_valid_r ? fetch0_instr_mule5_i    : fetch1_instr_mule5_i);
wire       issue_a_mule5n_w   = (slot0_valid_r ? fetch0_instr_mule5n_i   : fetch1_instr_mule5n_i);
wire       issue_a_cbm_inst_w = (slot0_valid_r ? fetch0_instr_cbm_i      : fetch1_instr_cbm_i);
wire       issue_a_mula_w     = (slot0_valid_r ? fetch0_instr_mula_i     : fetch1_instr_mula_i);
wire       issue_a_mulx_w     = (slot0_valid_r ? fetch0_instr_mulx_i     : fetch1_instr_mulx_i);
wire       issue_a_mulb_w     = (slot0_valid_r ? fetch0_instr_mulb_i     : fetch1_instr_mulb_i);
wire       issue_a_mulr_w     = (slot0_valid_r ? fetch0_instr_mulr_i     : fetch1_instr_mulr_i);
wire       issue_a_mulp_w     = (slot0_valid_r ? fetch0_instr_mulp_i     : fetch1_instr_mulp_i);
wire       issue_a_mulc_w     = (slot0_valid_r ? fetch0_instr_mulc_i     : fetch1_instr_mulc_i);
wire       issue_a_csr_w      = (slot0_valid_r ? fetch0_instr_csr_i      : fetch1_instr_csr_i);
wire       issue_a_invalid_w  = (slot0_valid_r ? fetch0_instr_invalid_i  : fetch1_instr_invalid_i);
wire       issue_a_any_mule_w = issue_a_mule_w | issue_a_mulen_w | issue_a_mule2_w | issue_a_mule2n_w | issue_a_mule3_w | issue_a_mule3n_w | issue_a_mule5_w | issue_a_mule5n_w;
wire       issue_a_any_custom_w = issue_a_mule_w | issue_a_mulen_w | issue_a_mule2_w | issue_a_mule2n_w | issue_a_mule3_w | issue_a_mule3n_w | issue_a_mule5_w | issue_a_mule5n_w |
                                  issue_a_cbm_inst_w | issue_a_mula_w | issue_a_mulx_w |
                                  issue_a_mulb_w | issue_a_mulr_w | issue_a_mulp_w |
                                  issue_a_mulc_w;


wire [4:0] issue_b_ra_idx_w   = opcode_b_r[19:15];
wire [4:0] issue_b_rb_idx_w   = opcode_b_r[24:20];
wire [4:0] issue_b_rd_idx_w   = opcode_b_r[11:7];
wire       issue_b_sb_alloc_w = fetch1_instr_rd_valid_i;
wire       issue_b_exec_w     = fetch1_instr_exec_i;
wire       issue_b_lsu_w      = fetch1_instr_lsu_i;
wire       issue_b_branch_w   = fetch1_instr_branch_i;
wire       issue_b_mul_w      = fetch1_instr_mul_i;
wire       issue_b_mule_w     = fetch1_instr_mule_i;
wire       issue_b_mulen_w    = fetch1_instr_mulen_i;
wire       issue_b_mule2_w    = fetch1_instr_mule2_i;
wire       issue_b_mule2n_w   = fetch1_instr_mule2n_i;
wire       issue_b_mule3_w    = fetch1_instr_mule3_i;
wire       issue_b_mule3n_w   = fetch1_instr_mule3n_i;
wire       issue_b_mule5_w    = fetch1_instr_mule5_i;
wire       issue_b_mule5n_w   = fetch1_instr_mule5n_i;
wire       issue_b_div_w      = fetch1_instr_div_i;
wire       issue_b_csr_w      = fetch1_instr_csr_i;
wire       issue_b_invalid_w  = fetch1_instr_invalid_i;
wire       issue_b_any_mule_w = issue_b_mule_w | issue_b_mulen_w | issue_b_mule2_w | issue_b_mule2n_w | issue_b_mule3_w | issue_b_mule3n_w | issue_b_mule5_w | issue_b_mule5n_w;

//-------------------------------------------------------------
// Pipe0 - Status tracking
//------------------------------------------------------------- 
wire        pipe0_squash_e1_e2_w;
wire        pipe1_squash_e1_e2_w;

reg         opcode_a_issue_r;
reg         opcode_a_accept_r;
wire        pipe0_stall_raw_w;

wire        pipe0_load_e1_w;
wire        pipe0_store_e1_w;
wire        pipe0_mul_e1_w;
wire        pipe0_branch_e1_w;
wire [4:0]  pipe0_rd_e1_w;

wire [31:0] pipe0_pc_e1_w;
wire [31:0] pipe0_opcode_e1_w;
wire [31:0] pipe0_operand_ra_e1_w;
wire [31:0] pipe0_operand_rb_e1_w;

wire        pipe0_load_e2_w;
wire        pipe0_mul_e2_w;
wire [4:0]  pipe0_rd_e2_w;
wire [31:0] pipe0_result_e2_w;

wire        pipe0_valid_wb_w;
wire        pipe0_csr_wb_w;
wire [4:0]  pipe0_rd_wb_w;
wire [31:0] pipe0_result_wb_w;
wire [31:0] pipe0_pc_wb_w;
wire [31:0] pipe0_opc_wb_w;
wire [31:0] pipe0_ra_val_wb_w;
wire [31:0] pipe0_rb_val_wb_w;
wire [`EXCEPTION_W-1:0] pipe0_exception_wb_w;

wire [`EXCEPTION_W-1:0] issue_a_fault_w = opcode_a_fault_r[0] ? `EXCEPTION_FAULT_FETCH:
                                          opcode_a_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST: `EXCEPTION_W'b0;

biriscv_pipe_ctrl
#( 
     .SUPPORT_LOAD_BYPASS(SUPPORT_LOAD_BYPASS)
    ,.SUPPORT_MUL_BYPASS(SUPPORT_MUL_BYPASS)
)
u_pipe0_ctrl
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)    

    // Issue
    ,.issue_valid_i(opcode_a_issue_r)
    ,.issue_accept_i(opcode_a_accept_r)
    ,.issue_stall_i(stall_w)
    ,.issue_lsu_i(issue_a_lsu_w)
    ,.issue_csr_i(issue_a_csr_w)
    ,.issue_div_i(issue_a_div_w)
    ,.issue_mul_i(issue_a_mul_w)
    ,.issue_mule_i(issue_a_mule_w)
    ,.issue_mulen_i(issue_a_mulen_w)
    ,.issue_mule2_i(issue_a_mule2_w)
    ,.issue_mule2n_i(issue_a_mule2n_w)
    ,.issue_mule3_i(issue_a_mule3_w)
    ,.issue_mule3n_i(issue_a_mule3n_w)
    ,.issue_mule5_i(issue_a_mule5_w)
    ,.issue_mule5n_i(issue_a_mule5n_w)
    ,.issue_cbm_i(issue_a_cbm_inst_w)
    ,.issue_mula_i(issue_a_mula_w)
    ,.issue_mulx_i(issue_a_mulx_w)
    ,.issue_mulb_i(issue_a_mulb_w)
    ,.issue_mulr_i(issue_a_mulr_w)
    ,.issue_mulp_i(issue_a_mulp_w)
    ,.issue_mulc_i(issue_a_mulc_w)
    ,.issue_branch_i(issue_a_branch_w)
    ,.issue_rd_valid_i(issue_a_sb_alloc_w)
    ,.issue_rd_i(issue_a_rd_idx_w)
    ,.issue_exception_i(issue_a_fault_w)
    ,.issue_pc_i(opcode0_pc_o)
    ,.issue_opcode_i(opcode0_opcode_o)
    ,.issue_operand_ra_i(opcode0_ra_operand_o)
    ,.issue_operand_rb_i(opcode0_rb_operand_o)
    ,.issue_branch_taken_i(branch_d_exec0_request_i)
    ,.issue_branch_target_i(branch_d_exec0_pc_i)
    ,.take_interrupt_i(take_interrupt_i)

    // Execution stage 1: ALU result
    ,.alu_result_e1_i(writeback_exec0_value_i)
    ,.csr_result_value_e1_i(csr_result_e1_value_i)
    ,.csr_result_write_e1_i(csr_result_e1_write_i)
    ,.csr_result_wdata_e1_i(csr_result_e1_wdata_i)
    ,.csr_result_exception_e1_i(csr_result_e1_exception_i)

    // Execution stage 1
    ,.load_e1_o(pipe0_load_e1_w)
    ,.store_e1_o(pipe0_store_e1_w)
    ,.mul_e1_o(pipe0_mul_e1_w)
    ,.branch_e1_o(pipe0_branch_e1_w)
    ,.rd_e1_o(pipe0_rd_e1_w)
    ,.pc_e1_o(pipe0_pc_e1_w)
    ,.opcode_e1_o(pipe0_opcode_e1_w)
    ,.operand_ra_e1_o(pipe0_operand_ra_e1_w)
    ,.operand_rb_e1_o(pipe0_operand_rb_e1_w)

    // Execution stage 2: Other results
    ,.mem_complete_i(writeback_mem_valid_i)
    ,.mem_result_e2_i(writeback_mem_value_i)
    ,.mem_exception_e2_i(writeback_mem_exception_i)
    ,.mul_result_e2_i(writeback_mul_value_i)

    // Execution stage 2
    ,.load_e2_o(pipe0_load_e2_w)
    ,.mul_e2_o(pipe0_mul_e2_w)
    ,.rd_e2_o(pipe0_rd_e2_w)
    ,.result_e2_o(pipe0_result_e2_w)

    ,.stall_o(pipe0_stall_raw_w)
    ,.squash_e1_e2_o(pipe0_squash_e1_e2_w)
    ,.squash_e1_e2_i(pipe1_squash_e1_e2_w)
    ,.squash_wb_i(1'b0)

    // Out of pipe: Divide Result
    ,.div_complete_i(writeback_div_valid_i)
    ,.div_result_i(writeback_div_value_i)
    ,.mule_complete_i(writeback_mule_valid_i)
    ,.mule_result_i(writeback_mule_value_i)
    ,.mule2_complete_i(writeback_mule2_valid_i)
    ,.mule2_result_i(writeback_mule2_value_i)
    ,.mule2n_complete_i(writeback_mule2n_valid_i)
    ,.mule2n_result_i(writeback_mule2n_value_i)
    ,.mule3_complete_i(writeback_mule3_valid_i)
    ,.mule3_result_i(writeback_mule3_value_i)
    ,.mule3n_complete_i(writeback_mule3n_valid_i)
    ,.mule3n_result_i(writeback_mule3n_value_i)
    ,.mule5_complete_i(writeback_mule5_valid_i)
    ,.mule5_result_i(writeback_mule5_value_i)
    ,.mule5n_complete_i(writeback_mule5n_valid_i)
    ,.mule5n_result_i(writeback_mule5n_value_i)
    ,.cbm_complete_i(writeback_cbm_valid_i)
    ,.cbm_result_i(writeback_cbm_value_i)
    ,.mula_complete_i(writeback_mula_valid_i)
    ,.mula_result_i(writeback_mula_value_i)
    ,.mulx_complete_i(writeback_mulx_valid_i)
    ,.mulx_result_i(writeback_mulx_value_i)
    ,.mulb_complete_i(writeback_mulb_valid_i)
    ,.mulb_result_i(writeback_mulb_value_i)
    ,.mulr_complete_i(writeback_mulr_valid_i)
    ,.mulr_result_i(writeback_mulr_value_i)
    ,.mulp_complete_i(writeback_mulp_valid_i)
    ,.mulp_result_i(writeback_mulp_value_i)
    ,.mulc_complete_i(writeback_mulc_valid_i)
    ,.mulc_result_i(writeback_mulc_value_i)

    // Commit
    ,.valid_wb_o(pipe0_valid_wb_w)
    ,.csr_wb_o(pipe0_csr_wb_w)
    ,.rd_wb_o(pipe0_rd_wb_w)
    ,.result_wb_o(pipe0_result_wb_w)
    ,.pc_wb_o(pipe0_pc_wb_w)
    ,.opcode_wb_o(pipe0_opc_wb_w)
    ,.operand_ra_wb_o(pipe0_ra_val_wb_w)
    ,.operand_rb_wb_o(pipe0_rb_val_wb_w)
    ,.exception_wb_o(pipe0_exception_wb_w)
    ,.csr_write_wb_o(csr_writeback_write_o)
    ,.csr_waddr_wb_o(csr_writeback_waddr_o)
    ,.csr_wdata_wb_o(csr_writeback_wdata_o)   
);

assign exec0_hold_o = stall_w;
assign mul_hold_o   = stall_w;

//-------------------------------------------------------------
// Pipe1 - Status tracking
//-------------------------------------------------------------
reg         opcode_b_issue_r;
reg         opcode_b_accept_r;
wire        pipe1_stall_raw_w;

wire        pipe1_load_e1_w;
wire        pipe1_store_e1_w;
wire        pipe1_mul_e1_w;
wire        pipe1_branch_e1_w;
wire [4:0]  pipe1_rd_e1_w;

wire [31:0] pipe1_pc_e1_w;
wire [31:0] pipe1_opcode_e1_w;
wire [31:0] pipe1_operand_ra_e1_w;
wire [31:0] pipe1_operand_rb_e1_w;

wire        pipe1_load_e2_w;
wire        pipe1_mul_e2_w;
wire [4:0]  pipe1_rd_e2_w;
wire [31:0] pipe1_result_e2_w;

wire        pipe1_valid_wb_w;
wire [4:0]  pipe1_rd_wb_w;
wire [31:0] pipe1_result_wb_w;
wire [31:0] pipe1_pc_wb_w;
wire [31:0] pipe1_opc_wb_w;
wire [31:0] pipe1_ra_val_wb_w;
wire [31:0] pipe1_rb_val_wb_w;
wire [`EXCEPTION_W-1:0] pipe1_exception_wb_w;

wire [`EXCEPTION_W-1:0] issue_b_fault_w = opcode_b_fault_r[0] ? `EXCEPTION_FAULT_FETCH:
                                          opcode_b_fault_r[1] ? `EXCEPTION_PAGE_FAULT_INST: `EXCEPTION_W'b0;

biriscv_pipe_ctrl
#( 
     .SUPPORT_LOAD_BYPASS(SUPPORT_LOAD_BYPASS)
    ,.SUPPORT_MUL_BYPASS(SUPPORT_MUL_BYPASS)
)
u_pipe1_ctrl
(
     .clk_i(clk_i)
    ,.rst_i(rst_i)

    // Issue
    ,.issue_valid_i(opcode_b_issue_r)
    ,.issue_accept_i(opcode_b_accept_r)
    ,.issue_stall_i(stall_w)
    ,.issue_lsu_i(issue_b_lsu_w)
    ,.issue_csr_i(1'b0)
    ,.issue_div_i(1'b0)
    ,.issue_mul_i(issue_b_mul_w)
    ,.issue_mule_i(issue_b_mule_w)
    ,.issue_mulen_i(issue_b_mulen_w)
    ,.issue_mule2_i(issue_b_mule2_w)
    ,.issue_mule2n_i(issue_b_mule2n_w)
    ,.issue_mule3_i(issue_b_mule3_w)
    ,.issue_mule3n_i(issue_b_mule3n_w)
    ,.issue_mule5_i(issue_b_mule5_w)
    ,.issue_mule5n_i(issue_b_mule5n_w)
    ,.issue_cbm_i(1'b0)
    ,.issue_mula_i(1'b0)
    ,.issue_mulx_i(1'b0)
    ,.issue_mulb_i(1'b0)
    ,.issue_mulr_i(1'b0)
    ,.issue_mulp_i(1'b0)
    ,.issue_mulc_i(1'b0)
    ,.issue_branch_i(issue_b_branch_w)
    ,.issue_rd_valid_i(issue_b_sb_alloc_w)
    ,.issue_rd_i(issue_b_rd_idx_w)
    ,.issue_exception_i(issue_b_fault_w)
    ,.issue_pc_i(opcode1_pc_o)
    ,.issue_opcode_i(opcode1_opcode_o)
    ,.issue_operand_ra_i(opcode1_ra_operand_o)
    ,.issue_operand_rb_i(opcode1_rb_operand_o)
    ,.issue_branch_taken_i(branch_d_exec1_request_i)
    ,.issue_branch_target_i(branch_d_exec1_pc_i)
    ,.take_interrupt_i(take_interrupt_i)

    // Execution stage 1: ALU, CSR result
    ,.alu_result_e1_i(writeback_exec1_value_i)
    ,.csr_result_value_e1_i(csr_result_e1_value_i)
    ,.csr_result_write_e1_i(csr_result_e1_write_i)
    ,.csr_result_wdata_e1_i(csr_result_e1_wdata_i)
    ,.csr_result_exception_e1_i(csr_result_e1_exception_i)

    // Execution stage 1
    ,.load_e1_o(pipe1_load_e1_w)
    ,.store_e1_o(pipe1_store_e1_w)
    ,.mul_e1_o(pipe1_mul_e1_w)
    ,.branch_e1_o(pipe1_branch_e1_w)
    ,.rd_e1_o(pipe1_rd_e1_w)
    ,.pc_e1_o(pipe1_pc_e1_w)
    ,.opcode_e1_o(pipe1_opcode_e1_w)
    ,.operand_ra_e1_o(pipe1_operand_ra_e1_w)
    ,.operand_rb_e1_o(pipe1_operand_rb_e1_w)

    // Execution stage 2: Other results
    ,.mem_complete_i(writeback_mem_valid_i)
    ,.mem_result_e2_i(writeback_mem_value_i)
    ,.mem_exception_e2_i(writeback_mem_exception_i)
    ,.mul_result_e2_i(writeback_mul_value_i)

    // Execution stage 2
    ,.load_e2_o(pipe1_load_e2_w)
    ,.mul_e2_o(pipe1_mul_e2_w)
    ,.rd_e2_o(pipe1_rd_e2_w)
    ,.result_e2_o(pipe1_result_e2_w)

    ,.stall_o(pipe1_stall_raw_w)
    ,.squash_e1_e2_o(pipe1_squash_e1_e2_w)
    ,.squash_e1_e2_i(pipe0_squash_e1_e2_w)
    ,.squash_wb_i(pipe0_squash_e1_e2_w)

    // Out of pipe: Divide Result
    ,.div_complete_i(writeback_div_valid_i)
    ,.div_result_i(writeback_div_value_i)
    ,.mule_complete_i(writeback_mule_valid_i)
    ,.mule_result_i(writeback_mule_value_i)
    ,.mule2_complete_i(writeback_mule2_valid_i)
    ,.mule2_result_i(writeback_mule2_value_i)
    ,.mule2n_complete_i(writeback_mule2n_valid_i)
    ,.mule2n_result_i(writeback_mule2n_value_i)
    ,.mule3_complete_i(writeback_mule3_valid_i)
    ,.mule3_result_i(writeback_mule3_value_i)
    ,.mule3n_complete_i(writeback_mule3n_valid_i)
    ,.mule3n_result_i(writeback_mule3n_value_i)
    ,.mule5_complete_i(writeback_mule5_valid_i)
    ,.mule5_result_i(writeback_mule5_value_i)
    ,.mule5n_complete_i(writeback_mule5n_valid_i)
    ,.mule5n_result_i(writeback_mule5n_value_i)
    ,.cbm_complete_i(writeback_cbm_valid_i)
    ,.cbm_result_i(writeback_cbm_value_i)
    ,.mula_complete_i(writeback_mula_valid_i)
    ,.mula_result_i(writeback_mula_value_i)
    ,.mulx_complete_i(writeback_mulx_valid_i)
    ,.mulx_result_i(writeback_mulx_value_i)
    ,.mulb_complete_i(writeback_mulb_valid_i)
    ,.mulb_result_i(writeback_mulb_value_i)
    ,.mulr_complete_i(writeback_mulr_valid_i)
    ,.mulr_result_i(writeback_mulr_value_i)
    ,.mulp_complete_i(writeback_mulp_valid_i)
    ,.mulp_result_i(writeback_mulp_value_i)
    ,.mulc_complete_i(writeback_mulc_valid_i)
    ,.mulc_result_i(writeback_mulc_value_i)

    // Commit
    ,.valid_wb_o(pipe1_valid_wb_w)
    ,.csr_wb_o()
    ,.rd_wb_o(pipe1_rd_wb_w)
    ,.result_wb_o(pipe1_result_wb_w)
    ,.pc_wb_o(pipe1_pc_wb_w)
    ,.opcode_wb_o(pipe1_opc_wb_w)
    ,.operand_ra_wb_o(pipe1_ra_val_wb_w)
    ,.operand_rb_wb_o(pipe1_rb_val_wb_w)
    ,.exception_wb_o(pipe1_exception_wb_w)
    ,.csr_write_wb_o()
    ,.csr_waddr_wb_o()
    ,.csr_wdata_wb_o()
);

assign exec1_hold_o = stall_w;

assign csr_writeback_exception_o      = pipe0_exception_wb_w | pipe1_exception_wb_w;
assign csr_writeback_exception_pc_o   = (|pipe0_exception_wb_w) ? pipe0_pc_wb_w     : pipe1_pc_wb_w;
assign csr_writeback_exception_addr_o = (|pipe0_exception_wb_w) ? pipe0_result_wb_w : pipe1_result_wb_w;

//-------------------------------------------------------------
// Branch predictor info
//-------------------------------------------------------------
// This info is used to learn future prediction, and to correct 
// BTB, BHT, GShare, RAS indexes on mispredictions.
assign branch_info_request_o      = mispredicted_r;
assign branch_info_is_taken_o     = (pipe1_branch_e1_w & branch_exec1_is_taken_i)     | (pipe0_branch_e1_w & branch_exec0_is_taken_i);
assign branch_info_is_not_taken_o = (pipe1_branch_e1_w & branch_exec1_is_not_taken_i) | (pipe0_branch_e1_w & branch_exec0_is_not_taken_i);
assign branch_info_is_call_o      = (pipe1_branch_e1_w & branch_exec1_is_call_i)      | (pipe0_branch_e1_w & branch_exec0_is_call_i);
assign branch_info_is_ret_o       = (pipe1_branch_e1_w & branch_exec1_is_ret_i)       | (pipe0_branch_e1_w & branch_exec0_is_ret_i);
assign branch_info_is_jmp_o       = (pipe1_branch_e1_w & branch_exec1_is_jmp_i)       | (pipe0_branch_e1_w & branch_exec0_is_jmp_i);
assign branch_info_source_o       = (pipe1_branch_e1_w & branch_exec1_request_i)      ? branch_exec1_source_i : branch_exec0_source_i;
assign branch_info_pc_o           = (pipe1_branch_e1_w & branch_exec1_request_i)      ? branch_exec1_pc_i     : branch_exec0_pc_i;

//-------------------------------------------------------------
// Blocking events (division, CSR unit access)
//-------------------------------------------------------------
reg div_pending_q;
reg csr_pending_q;
reg mule_pending_q;
reg mulen_pending_q;
reg mulen_wb_pending_q;
reg cbm_pending_q;
wire [4:0] mule_issue_rd_idx_w;
wire [4:0] mulen_issue_rd_idx_w;
reg mule2_pending_q;
reg mule2n_pending_q;
reg mule2n_wb_pending_q;
reg mule3_pending_q;
reg mule3n_pending_q;
reg mule3n_wb_pending_q;
reg mule5_pending_q;
reg mule5n_pending_q;
reg mule5n_wb_pending_q;
reg mula_pending_q;
reg mulx_pending_q;
reg mulb_pending_q;
reg mulr_pending_q;
reg mulp_pending_q;
reg mulc_pending_q;
wire        mulen_writeback_safe_w;
wire        mule2n_writeback_safe_w;
wire        mule3n_writeback_safe_w;
wire        mule5n_writeback_safe_w;
wire [4:0] mule2_issue_rd_idx_w;
wire [4:0] mule2n_issue_rd_idx_w;
wire [4:0] mule3_issue_rd_idx_w;
wire [4:0] mule3n_issue_rd_idx_w;
wire [4:0] mule5_issue_rd_idx_w;
wire [4:0] mule5n_issue_rd_idx_w;

// Division operations take 2 - 34 cycles and stall
// the pipeline (complete out-of-pipe) until completed.
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    div_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    div_pending_q <= 1'b0;
else if (div_opcode_valid_o && issue_a_div_w)
    div_pending_q <= 1'b1;
else if (writeback_div_valid_i)
    div_pending_q <= 1'b0;

// CSR operations are infrequent - avoid any complications of pipelining them.
// These only take a 2-3 cycles anyway and may result in a pipe flush (e.g. ecall, ebreak..).
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    csr_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    csr_pending_q <= 1'b0;
else if (csr_opcode_valid_o && issue_a_csr_w)
    csr_pending_q <= 1'b1;
else if (pipe0_csr_wb_w)
    csr_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule_pending_q <= 1'b0;
else if (mule_opcode_valid_o)
    mule_pending_q <= 1'b1;
else if (writeback_mule_valid_i)
    mule_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulen_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulen_pending_q <= 1'b0;
else if (mulen_opcode_valid_o)
    mulen_pending_q <= 1'b1;
else if (mulen_writeback_safe_w)
    mulen_pending_q <= 1'b0;

// Track MULE destination register for scoreboard
reg [4:0] mule_rd_q;
reg [4:0] mulen_rd_q;
reg [4:0] mulen_wb_rd_q;
reg [31:0] mulen_wb_value_q;
reg [4:0] cbm_rd_q;
reg [4:0] mule2_rd_q;
reg [4:0] mule2n_rd_q;
reg [4:0] mule2n_wb_rd_q;
reg [31:0] mule2n_wb_value_q;
reg [4:0] mule3_rd_q;
reg [4:0] mule3n_rd_q;
reg [4:0] mule3n_wb_rd_q;
reg [31:0] mule3n_wb_value_q;
reg [4:0] mule5_rd_q;
reg [4:0] mule5n_rd_q;
reg [4:0] mule5n_wb_rd_q;
reg [31:0] mule5n_wb_value_q;
reg [4:0] mula_rd_q;
reg [4:0] mulx_rd_q;
reg [4:0] mulb_rd_q;
reg [4:0] mulr_rd_q;
reg [4:0] mulp_rd_q;
reg [4:0] mulc_rd_q;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule_rd_q <= 5'b0;
else if (mule_opcode_valid_o)
    mule_rd_q <= mule_issue_rd_idx_w;
else if (writeback_mule_valid_i)
    mule_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulen_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulen_rd_q <= 5'b0;
else if (mulen_opcode_valid_o)
    mulen_rd_q <= mulen_issue_rd_idx_w;
else if (mulen_writeback_safe_w)
    mulen_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule2n_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule2n_pending_q <= 1'b0;
else if (mule2n_opcode_valid_o)
    mule2n_pending_q <= 1'b1;
else if (mule2n_writeback_safe_w)
    mule2n_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule2n_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule2n_rd_q <= 5'b0;
else if (mule2n_opcode_valid_o)
    mule2n_rd_q <= mule2n_issue_rd_idx_w;
else if (mule2n_writeback_safe_w)
    mule2n_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule2_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule2_pending_q <= 1'b0;
else if (mule2_opcode_valid_o)
    mule2_pending_q <= 1'b1;
else if (writeback_mule2_valid_i)
    mule2_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule2_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule2_rd_q <= 5'b0;
else if (mule2_opcode_valid_o)
    mule2_rd_q <= mule2_issue_rd_idx_w;
else if (writeback_mule2_valid_i)
    mule2_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule3_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule3_pending_q <= 1'b0;
else if (mule3_opcode_valid_o)
    mule3_pending_q <= 1'b1;
else if (writeback_mule3_valid_i)
    mule3_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule3_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule3_rd_q <= 5'b0;
else if (mule3_opcode_valid_o)
    mule3_rd_q <= mule3_issue_rd_idx_w;
else if (writeback_mule3_valid_i)
    mule3_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule3n_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule3n_pending_q <= 1'b0;
else if (mule3n_opcode_valid_o)
    mule3n_pending_q <= 1'b1;
else if (mule3n_writeback_safe_w)
    mule3n_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule3n_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule3n_rd_q <= 5'b0;
else if (mule3n_opcode_valid_o)
    mule3n_rd_q <= mule3n_issue_rd_idx_w;
else if (mule3n_writeback_safe_w)
    mule3n_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule5_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule5_pending_q <= 1'b0;
else if (mule5_opcode_valid_o)
    mule5_pending_q <= 1'b1;
else if (writeback_mule5_valid_i)
    mule5_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule5_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule5_rd_q <= 5'b0;
else if (mule5_opcode_valid_o)
    mule5_rd_q <= mule5_issue_rd_idx_w;
else if (writeback_mule5_valid_i)
    mule5_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule5n_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule5n_pending_q <= 1'b0;
else if (mule5n_opcode_valid_o)
    mule5n_pending_q <= 1'b1;
else if (mule5n_writeback_safe_w)
    mule5n_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mule5n_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mule5n_rd_q <= 5'b0;
else if (mule5n_opcode_valid_o)
    mule5n_rd_q <= mule5n_issue_rd_idx_w;
else if (mule5n_writeback_safe_w)
    mule5n_rd_q <= 5'b0;

// Hold non-blocking multiplier completions until a register-file write port is free.
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    mulen_wb_pending_q <= 1'b0;
    mulen_wb_rd_q      <= 5'b0;
    mulen_wb_value_q   <= 32'b0;
end
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
begin
    mulen_wb_pending_q <= 1'b0;
    mulen_wb_rd_q      <= 5'b0;
    mulen_wb_value_q   <= 32'b0;
end
else if (mulen_writeback_safe_w)
begin
    mulen_wb_pending_q <= 1'b0;
    mulen_wb_rd_q      <= 5'b0;
    mulen_wb_value_q   <= 32'b0;
end
else if (!mulen_wb_pending_q && writeback_mulen_valid_i)
begin
    mulen_wb_pending_q <= 1'b1;
    mulen_wb_rd_q      <= writeback_mulen_rd_idx_i;
    mulen_wb_value_q   <= writeback_mulen_value_i;
end

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    mule2n_wb_pending_q <= 1'b0;
    mule2n_wb_rd_q      <= 5'b0;
    mule2n_wb_value_q   <= 32'b0;
end
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
begin
    mule2n_wb_pending_q <= 1'b0;
    mule2n_wb_rd_q      <= 5'b0;
    mule2n_wb_value_q   <= 32'b0;
end
else if (mule2n_writeback_safe_w)
begin
    mule2n_wb_pending_q <= 1'b0;
    mule2n_wb_rd_q      <= 5'b0;
    mule2n_wb_value_q   <= 32'b0;
end
else if (!mule2n_wb_pending_q && writeback_mule2n_valid_i)
begin
    mule2n_wb_pending_q <= 1'b1;
    mule2n_wb_rd_q      <= writeback_mule2n_rd_idx_i;
    mule2n_wb_value_q   <= writeback_mule2n_value_i;
end

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    mule3n_wb_pending_q <= 1'b0;
    mule3n_wb_rd_q      <= 5'b0;
    mule3n_wb_value_q   <= 32'b0;
end
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
begin
    mule3n_wb_pending_q <= 1'b0;
    mule3n_wb_rd_q      <= 5'b0;
    mule3n_wb_value_q   <= 32'b0;
end
else if (mule3n_writeback_safe_w)
begin
    mule3n_wb_pending_q <= 1'b0;
    mule3n_wb_rd_q      <= 5'b0;
    mule3n_wb_value_q   <= 32'b0;
end
else if (!mule3n_wb_pending_q && writeback_mule3n_valid_i)
begin
    mule3n_wb_pending_q <= 1'b1;
    mule3n_wb_rd_q      <= writeback_mule3n_rd_idx_i;
    mule3n_wb_value_q   <= writeback_mule3n_value_i;
end

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    mule5n_wb_pending_q <= 1'b0;
    mule5n_wb_rd_q      <= 5'b0;
    mule5n_wb_value_q   <= 32'b0;
end
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
begin
    mule5n_wb_pending_q <= 1'b0;
    mule5n_wb_rd_q      <= 5'b0;
    mule5n_wb_value_q   <= 32'b0;
end
else if (mule5n_writeback_safe_w)
begin
    mule5n_wb_pending_q <= 1'b0;
    mule5n_wb_rd_q      <= 5'b0;
    mule5n_wb_value_q   <= 32'b0;
end
else if (!mule5n_wb_pending_q && writeback_mule5n_valid_i)
begin
    mule5n_wb_pending_q <= 1'b1;
    mule5n_wb_rd_q      <= writeback_mule5n_rd_idx_i;
    mule5n_wb_value_q   <= writeback_mule5n_value_i;
end

// Single-outstanding custom multiplier tracking.
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    cbm_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    cbm_pending_q <= 1'b0;
else if (cbm_inst_opcode_valid_o)
    cbm_pending_q <= 1'b1;
else if (writeback_cbm_valid_i)
    cbm_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    cbm_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    cbm_rd_q <= 5'b0;
else if (cbm_inst_opcode_valid_o)
    cbm_rd_q <= issue_a_rd_idx_w;
else if (writeback_cbm_valid_i)
    cbm_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mula_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mula_pending_q <= 1'b0;
else if (mula_opcode_valid_o)
    mula_pending_q <= 1'b1;
else if (writeback_mula_valid_i)
    mula_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mula_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mula_rd_q <= 5'b0;
else if (mula_opcode_valid_o)
    mula_rd_q <= issue_a_rd_idx_w;
else if (writeback_mula_valid_i)
    mula_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulx_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulx_pending_q <= 1'b0;
else if (mulx_opcode_valid_o)
    mulx_pending_q <= 1'b1;
else if (writeback_mulx_valid_i)
    mulx_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulx_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulx_rd_q <= 5'b0;
else if (mulx_opcode_valid_o)
    mulx_rd_q <= issue_a_rd_idx_w;
else if (writeback_mulx_valid_i)
    mulx_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulb_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulb_pending_q <= 1'b0;
else if (mulb_opcode_valid_o)
    mulb_pending_q <= 1'b1;
else if (writeback_mulb_valid_i)
    mulb_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulb_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulb_rd_q <= 5'b0;
else if (mulb_opcode_valid_o)
    mulb_rd_q <= issue_a_rd_idx_w;
else if (writeback_mulb_valid_i)
    mulb_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulr_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulr_pending_q <= 1'b0;
else if (mulr_opcode_valid_o)
    mulr_pending_q <= 1'b1;
else if (writeback_mulr_valid_i)
    mulr_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulr_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulr_rd_q <= 5'b0;
else if (mulr_opcode_valid_o)
    mulr_rd_q <= issue_a_rd_idx_w;
else if (writeback_mulr_valid_i)
    mulr_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulp_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulp_pending_q <= 1'b0;
else if (mulp_opcode_valid_o)
    mulp_pending_q <= 1'b1;
else if (writeback_mulp_valid_i)
    mulp_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulp_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulp_rd_q <= 5'b0;
else if (mulp_opcode_valid_o)
    mulp_rd_q <= issue_a_rd_idx_w;
else if (writeback_mulp_valid_i)
    mulp_rd_q <= 5'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulc_pending_q <= 1'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulc_pending_q <= 1'b0;
else if (mulc_opcode_valid_o)
    mulc_pending_q <= 1'b1;
else if (writeback_mulc_valid_i)
    mulc_pending_q <= 1'b0;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
    mulc_rd_q <= 5'b0;
else if (pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w)
    mulc_rd_q <= 5'b0;
else if (mulc_opcode_valid_o)
    mulc_rd_q <= issue_a_rd_idx_w;
else if (writeback_mulc_valid_i)
    mulc_rd_q <= 5'b0;

assign squash_w = pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w;

//-------------------------------------------------------------
// Issue / scheduling logic
//-------------------------------------------------------------
reg [31:0] scoreboard_r;
reg        pipe1_mux_lsu_r;
reg        pipe1_mux_mul_r;
reg        pipe1_mux_mule_r;
reg        pipe1_mux_mulen_r;
reg        pipe1_mux_mule2_r;
reg        pipe1_mux_mule2n_r;
reg        pipe1_mux_mule3_r;
reg        pipe1_mux_mule3n_r;
reg        pipe1_mux_mule5_r;
reg        pipe1_mux_mule5n_r;

wire mule_writeback_safe_w = writeback_mule_valid_i &&
                              mule_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire [4:0]  mulen_wb_src_rd_w    = mulen_wb_pending_q ? mulen_wb_rd_q    : writeback_mulen_rd_idx_i;
wire [31:0] mulen_wb_src_value_w = mulen_wb_pending_q ? mulen_wb_value_q : writeback_mulen_value_i;
wire        mulen_wb_src_valid_w = mulen_wb_pending_q | writeback_mulen_valid_i;
wire mule2_writeback_safe_w = writeback_mule2_valid_i &&
                              mule2_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire [4:0]  mule2n_wb_src_rd_w    = mule2n_wb_pending_q ? mule2n_wb_rd_q    : writeback_mule2n_rd_idx_i;
wire [31:0] mule2n_wb_src_value_w = mule2n_wb_pending_q ? mule2n_wb_value_q : writeback_mule2n_value_i;
wire        mule2n_wb_src_valid_w = mule2n_wb_pending_q | writeback_mule2n_valid_i;
wire mule3_writeback_safe_w = writeback_mule3_valid_i &&
                              mule3_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire [4:0]  mule3n_wb_src_rd_w    = mule3n_wb_pending_q ? mule3n_wb_rd_q    : writeback_mule3n_rd_idx_i;
wire [31:0] mule3n_wb_src_value_w = mule3n_wb_pending_q ? mule3n_wb_value_q : writeback_mule3n_value_i;
wire        mule3n_wb_src_valid_w = mule3n_wb_pending_q | writeback_mule3n_valid_i;
wire mule5_writeback_safe_w = writeback_mule5_valid_i &&
                              mule5_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire [4:0]  mule5n_wb_src_rd_w    = mule5n_wb_pending_q ? mule5n_wb_rd_q    : writeback_mule5n_rd_idx_i;
wire [31:0] mule5n_wb_src_value_w = mule5n_wb_pending_q ? mule5n_wb_value_q : writeback_mule5n_value_i;
wire        mule5n_wb_src_valid_w = mule5n_wb_pending_q | writeback_mule5n_valid_i;
wire cbm_writeback_safe_w  = writeback_cbm_valid_i &&
                              cbm_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mula_writeback_safe_w = writeback_mula_valid_i &&
                              mula_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mulx_writeback_safe_w = writeback_mulx_valid_i &&
                              mulx_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mulb_writeback_safe_w = writeback_mulb_valid_i &&
                              mulb_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mulr_writeback_safe_w = writeback_mulr_valid_i &&
                              mulr_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mulp_writeback_safe_w = writeback_mulp_valid_i &&
                              mulp_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mulc_writeback_safe_w = writeback_mulc_valid_i &&
                              mulc_pending_q &&
                              ~(pipe0_squash_e1_e2_w || pipe1_squash_e1_e2_w);
wire mule_pending_hazard_w = mule_pending_q &&
                              mule_rd_q != 5'b0 &&
                              !(mule_writeback_safe_w && (writeback_mule_rd_idx_i == mule_rd_q));
wire mulen_pending_hazard_w = mulen_pending_q &&
                              mulen_rd_q != 5'b0 &&
                              !(mulen_writeback_safe_w && (mulen_wb_src_rd_w == mulen_rd_q));
wire mule2_pending_hazard_w = mule2_pending_q &&
                              mule2_rd_q != 5'b0 &&
                              !(mule2_writeback_safe_w && (writeback_mule2_rd_idx_i == mule2_rd_q));
wire mule2n_pending_hazard_w = mule2n_pending_q &&
                              mule2n_rd_q != 5'b0 &&
                              !(mule2n_writeback_safe_w && (mule2n_wb_src_rd_w == mule2n_rd_q));
wire mule3_pending_hazard_w = mule3_pending_q &&
                              mule3_rd_q != 5'b0 &&
                              !(mule3_writeback_safe_w && (writeback_mule3_rd_idx_i == mule3_rd_q));
wire mule3n_pending_hazard_w = mule3n_pending_q &&
                              mule3n_rd_q != 5'b0 &&
                              !(mule3n_writeback_safe_w && (mule3n_wb_src_rd_w == mule3n_rd_q));
wire mule5_pending_hazard_w = mule5_pending_q &&
                              mule5_rd_q != 5'b0 &&
                              !(mule5_writeback_safe_w && (writeback_mule5_rd_idx_i == mule5_rd_q));
wire mule5n_pending_hazard_w = mule5n_pending_q &&
                              mule5n_rd_q != 5'b0 &&
                              !(mule5n_writeback_safe_w && (mule5n_wb_src_rd_w == mule5n_rd_q));
wire cbm_pending_hazard_w  = cbm_pending_q &&
                              cbm_rd_q != 5'b0 &&
                              !(cbm_writeback_safe_w && (writeback_cbm_rd_idx_i == cbm_rd_q));
wire mula_pending_hazard_w = mula_pending_q &&
                              mula_rd_q != 5'b0 &&
                              !(mula_writeback_safe_w && (writeback_mula_rd_idx_i == mula_rd_q));
wire mulx_pending_hazard_w = mulx_pending_q &&
                              mulx_rd_q != 5'b0 &&
                              !(mulx_writeback_safe_w && (writeback_mulx_rd_idx_i == mulx_rd_q));
wire mulb_pending_hazard_w = mulb_pending_q &&
                              mulb_rd_q != 5'b0 &&
                              !(mulb_writeback_safe_w && (writeback_mulb_rd_idx_i == mulb_rd_q));
wire mulr_pending_hazard_w = mulr_pending_q &&
                              mulr_rd_q != 5'b0 &&
                              !(mulr_writeback_safe_w && (writeback_mulr_rd_idx_i == mulr_rd_q));
wire mulp_pending_hazard_w = mulp_pending_q &&
                              mulp_rd_q != 5'b0 &&
                              !(mulp_writeback_safe_w && (writeback_mulp_rd_idx_i == mulp_rd_q));
wire mulc_pending_hazard_w = mulc_pending_q &&
                              mulc_rd_q != 5'b0 &&
                              !(mulc_writeback_safe_w && (writeback_mulc_rd_idx_i == mulc_rd_q));

// Check instructions can be issued in the second execution unit
wire pipe1_ok_w      = issue_b_exec_w | issue_b_branch_w | issue_b_lsu_w | issue_b_mul_w |
                       issue_b_mule_w | issue_b_mulen_w | issue_b_mule2_w | issue_b_mule2n_w | issue_b_mule3_w | issue_b_mule3n_w | issue_b_mule5_w | issue_b_mule5n_w;

// Is this combination of instructions possible to execute concurrently.
// This excludes result dependencies which may also block secondary execution.
wire dual_issue_ok_w =   enable_dual_issue_w &&  // Second pipe switched on
                         pipe1_ok_w &&           // Instruction 2 is possible on second exec unit
                        (((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w | issue_a_any_mule_w) && issue_b_exec_w)      ||
                         ((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w | issue_a_any_mule_w) && issue_b_branch_w)    ||
                         ((issue_a_exec_w | issue_a_mul_w | issue_a_any_mule_w) && issue_b_lsu_w)                       ||
                         ((issue_a_exec_w | issue_a_lsu_w | issue_a_any_mule_w) && issue_b_mul_w)                       ||
                         ((issue_a_exec_w | issue_a_lsu_w | issue_a_mul_w) && issue_b_any_mule_w)
                         ) && ~take_interrupt_i;

always @ *
begin
    opcode_a_issue_r     = 1'b0;
    opcode_b_issue_r     = 1'b0;
    opcode_a_accept_r    = 1'b0;
    opcode_b_accept_r    = 1'b0;
    scoreboard_r         = 32'b0;
    pipe1_mux_lsu_r      = 1'b0;
    pipe1_mux_mul_r      = 1'b0;
    pipe1_mux_mule_r     = 1'b0;
    pipe1_mux_mulen_r    = 1'b0;
    pipe1_mux_mule2_r    = 1'b0;
    pipe1_mux_mule2n_r   = 1'b0;
    pipe1_mux_mule3_r    = 1'b0;
    pipe1_mux_mule3n_r   = 1'b0;
    pipe1_mux_mule5_r    = 1'b0;
    pipe1_mux_mule5n_r   = 1'b0;

    // Execution units with >= 2 cycle latency
    if (SUPPORT_LOAD_BYPASS == 0)
    begin
        if (pipe0_load_e2_w)
            scoreboard_r[pipe0_rd_e2_w] = 1'b1;
        if (pipe1_load_e2_w)
            scoreboard_r[pipe1_rd_e2_w] = 1'b1;
    end
    if (SUPPORT_MUL_BYPASS == 0)
    begin
        if (pipe0_mul_e2_w)
            scoreboard_r[pipe0_rd_e2_w] = 1'b1;
        if (pipe1_mul_e2_w)
            scoreboard_r[pipe1_rd_e2_w] = 1'b1;
    end

    // MULE is multi-cycle (5 cycles) so track in scoreboard while pending
    if (mule_pending_hazard_w)
        scoreboard_r[mule_rd_q] = 1'b1;
    if (mulen_pending_hazard_w)
        scoreboard_r[mulen_rd_q] = 1'b1;
    if (mule2_pending_hazard_w)
        scoreboard_r[mule2_rd_q] = 1'b1;
    if (mule2n_pending_hazard_w)
        scoreboard_r[mule2n_rd_q] = 1'b1;
    if (mule3_pending_hazard_w)
        scoreboard_r[mule3_rd_q] = 1'b1;
    if (mule3n_pending_hazard_w)
        scoreboard_r[mule3n_rd_q] = 1'b1;
    if (mule5_pending_hazard_w)
        scoreboard_r[mule5_rd_q] = 1'b1;
    if (mule5n_pending_hazard_w)
        scoreboard_r[mule5n_rd_q] = 1'b1;
    if (cbm_pending_hazard_w)
        scoreboard_r[cbm_rd_q] = 1'b1;
    if (mula_pending_hazard_w)
        scoreboard_r[mula_rd_q] = 1'b1;
    if (mulx_pending_hazard_w)
        scoreboard_r[mulx_rd_q] = 1'b1;
    if (mulb_pending_hazard_w)
        scoreboard_r[mulb_rd_q] = 1'b1;
    if (mulr_pending_hazard_w)
        scoreboard_r[mulr_rd_q] = 1'b1;
    if (mulp_pending_hazard_w)
        scoreboard_r[mulp_rd_q] = 1'b1;
    if (mulc_pending_hazard_w)
        scoreboard_r[mulc_rd_q] = 1'b1;

    // Execution units with >= 1 cycle latency (loads / multiply)
    if (pipe0_load_e1_w || pipe0_mul_e1_w)
        scoreboard_r[pipe0_rd_e1_w] = 1'b1;
    if (pipe1_load_e1_w || pipe1_mul_e1_w)
        scoreboard_r[pipe1_rd_e1_w] = 1'b1;

    // Do not start multiply, division or CSR operation in the cycle after a load (leaving only ALU operations and branches)
    if ((pipe0_load_e1_w || pipe0_store_e1_w || pipe1_load_e1_w || pipe1_store_e1_w ) &&
        (issue_a_mul_w || issue_a_div_w || issue_a_csr_w || issue_a_any_custom_w))
        scoreboard_r = 32'hFFFFFFFF;

    // Stall - no issues...
    if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q)
        ;
        
    // Primary slot (lsu, branch, alu, mul, div, csr, mule)
else if (opcode_a_valid_r &&
        !(scoreboard_r[issue_a_ra_idx_w] || 
          scoreboard_r[issue_a_rb_idx_w] ||
          scoreboard_r[issue_a_rd_idx_w]) &&
    ~((issue_a_mule_w     && mule_pending_q)  ||
      (issue_a_mulen_w    && mulen_pending_q) ||
      (issue_a_mule2_w    && mule2_pending_q) ||
      (issue_a_mule2n_w   && mule2n_pending_q) ||
      (issue_a_mule3_w    && mule3_pending_q) ||
      (issue_a_mule3n_w   && mule3n_pending_q) ||
      (issue_a_mule5_w    && mule5_pending_q) ||
      (issue_a_mule5n_w   && mule5n_pending_q) ||
      (issue_a_cbm_inst_w && cbm_pending_q)   ||
      (issue_a_mula_w     && mula_pending_q)  ||
      (issue_a_mulx_w     && mulx_pending_q)  ||
      (issue_a_mulb_w     && mulb_pending_q)  ||
      (issue_a_mulr_w     && mulr_pending_q)  ||
      (issue_a_mulp_w     && mulp_pending_q)  ||
      (issue_a_mulc_w     && mulc_pending_q)))
begin
        opcode_a_issue_r  = 1'b1;
        opcode_a_accept_r = 1'b1;

        if (opcode_a_accept_r && issue_a_sb_alloc_w && (|issue_a_rd_idx_w))
            scoreboard_r[issue_a_rd_idx_w] = 1'b1;
    end

    // Stall - no issues...
    if (lsu_stall_i || stall_w || div_pending_q || csr_pending_q)
        ;
    // Secondary Slot (lsu, branch, alu, mul, mule)
    else if (dual_issue_ok_w && opcode_b_valid_r && opcode_a_accept_r &&
        !(scoreboard_r[issue_b_ra_idx_w] || 
          scoreboard_r[issue_b_rb_idx_w] ||
          scoreboard_r[issue_b_rd_idx_w]) &&
    ~((issue_b_mule_w && mule_pending_q) || (issue_b_mulen_w && mulen_pending_q) ||
      (issue_b_mule2_w && mule2_pending_q) ||
      (issue_b_mule2n_w && mule2n_pending_q) ||
      (issue_b_mule3_w && mule3_pending_q) || (issue_b_mule3n_w && mule3n_pending_q) ||
      (issue_b_mule5_w && mule5_pending_q) || (issue_b_mule5n_w && mule5n_pending_q)))
    begin
        opcode_b_issue_r  = 1'b1;
        opcode_b_accept_r = 1'b1;
        pipe1_mux_lsu_r   = issue_b_lsu_w;
        pipe1_mux_mul_r   = issue_b_mul_w;
        pipe1_mux_mule_r  = issue_b_mule_w;
        pipe1_mux_mulen_r = issue_b_mulen_w;
        pipe1_mux_mule2_r = issue_b_mule2_w;
        pipe1_mux_mule2n_r = issue_b_mule2n_w;
        pipe1_mux_mule3_r = issue_b_mule3_w;
        pipe1_mux_mule3n_r = issue_b_mule3n_w;
        pipe1_mux_mule5_r = issue_b_mule5_w;
        pipe1_mux_mule5n_r = issue_b_mule5n_w;

        if (opcode_b_accept_r && issue_b_sb_alloc_w && (|issue_b_rd_idx_w))
            scoreboard_r[issue_b_rd_idx_w] = 1'b1;
    end    
end

assign lsu_opcode_valid_o   = (pipe1_mux_lsu_r ? opcode_b_issue_r : opcode_a_issue_r) & ~take_interrupt_i;
assign exec0_opcode_valid_o = opcode_a_issue_r;
assign mul_opcode_valid_o   = enable_muldiv_w & (pipe1_mux_mul_r ? opcode_b_issue_r : opcode_a_issue_r);
assign div_opcode_valid_o   = enable_muldiv_w & (opcode_a_issue_r);
assign mule_opcode_valid_o  = enable_muldiv_w & (pipe1_mux_mule_r ? (opcode_b_issue_r & issue_b_mule_w)
                                                                : (opcode_a_issue_r & issue_a_mule_w));
assign mulen_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mulen_r ? (opcode_b_issue_r & issue_b_mulen_w)
                                                                    : (opcode_a_issue_r & issue_a_mulen_w));
assign mule2_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule2_r ? (opcode_b_issue_r & issue_b_mule2_w)
                                                                    : (opcode_a_issue_r & issue_a_mule2_w));
assign mule2n_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule2n_r ? (opcode_b_issue_r & issue_b_mule2n_w)
                                                                      : (opcode_a_issue_r & issue_a_mule2n_w));
assign mule3_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule3_r ? (opcode_b_issue_r & issue_b_mule3_w)
                                                                    : (opcode_a_issue_r & issue_a_mule3_w));
assign mule3n_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule3n_r ? (opcode_b_issue_r & issue_b_mule3n_w)
                                                                      : (opcode_a_issue_r & issue_a_mule3n_w));
assign mule5_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule5_r ? (opcode_b_issue_r & issue_b_mule5_w)
                                                                    : (opcode_a_issue_r & issue_a_mule5_w));
assign mule5n_opcode_valid_o = enable_muldiv_w & (pipe1_mux_mule5n_r ? (opcode_b_issue_r & issue_b_mule5n_w)
                                                                      : (opcode_a_issue_r & issue_a_mule5n_w));
assign mula_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mula_w);
assign mulx_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mulx_w);
assign mulb_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mulb_w);
assign mulr_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mulr_w);
assign mulp_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mulp_w);
assign mulc_opcode_valid_o  = enable_muldiv_w & (opcode_a_issue_r & issue_a_mulc_w);
assign cbm_inst_opcode_valid_o = enable_muldiv_w & (opcode_a_issue_r & issue_a_cbm_inst_w);
assign interrupt_inhibit_o  = csr_pending_q || issue_a_csr_w;

assign exec1_opcode_valid_o = opcode_b_issue_r;

assign dual_issue_w         = opcode_b_issue_r & opcode_b_accept_r & ~take_interrupt_i;
assign single_issue_w       = (opcode_a_issue_r & opcode_a_accept_r) & ~dual_issue_w & ~take_interrupt_i;

assign fetch0_accept_o      = ((slot0_valid_r & opcode_a_accept_r) | slot1_valid_r) & ~take_interrupt_i;
assign fetch1_accept_o      = ((slot1_valid_r & opcode_a_accept_r) | (opcode_b_accept_r)) & ~take_interrupt_i;

assign stall_w              = pipe0_stall_raw_w | pipe1_stall_raw_w;

//-------------------------------------------------------------
// Register File
//------------------------------------------------------------- 
wire [31:0] issue_a_ra_value_w;
wire [31:0] issue_a_rb_value_w;
wire [31:0] issue_b_ra_value_w;
wire [31:0] issue_b_rb_value_w;

wire [4:0] pipe0_rd_wb_base_w =
    mule_writeback_safe_w  ? writeback_mule_rd_idx_i  :
    mule2_writeback_safe_w ? writeback_mule2_rd_idx_i :
    mule3_writeback_safe_w ? writeback_mule3_rd_idx_i :
    mule5_writeback_safe_w ? writeback_mule5_rd_idx_i :
    cbm_writeback_safe_w   ? writeback_cbm_rd_idx_i   :
    mula_writeback_safe_w  ? writeback_mula_rd_idx_i  :
    mulx_writeback_safe_w  ? writeback_mulx_rd_idx_i  :
    mulb_writeback_safe_w  ? writeback_mulb_rd_idx_i  :
    mulr_writeback_safe_w  ? writeback_mulr_rd_idx_i  :
    mulp_writeback_safe_w  ? writeback_mulp_rd_idx_i  :
    mulc_writeback_safe_w  ? writeback_mulc_rd_idx_i  :
                              pipe0_rd_wb_w;

wire [31:0] pipe0_result_wb_base_w =
    mule_writeback_safe_w  ? writeback_mule_value_i  :
    mule2_writeback_safe_w ? writeback_mule2_value_i :
    mule3_writeback_safe_w ? writeback_mule3_value_i :
    mule5_writeback_safe_w ? writeback_mule5_value_i :
    cbm_writeback_safe_w   ? writeback_cbm_value_i   :
    mula_writeback_safe_w  ? writeback_mula_value_i  :
    mulx_writeback_safe_w  ? writeback_mulx_value_i  :
    mulb_writeback_safe_w  ? writeback_mulb_value_i  :
    mulr_writeback_safe_w  ? writeback_mulr_value_i  :
    mulp_writeback_safe_w  ? writeback_mulp_value_i  :
    mulc_writeback_safe_w  ? writeback_mulc_value_i  :
                              pipe0_result_wb_w;

wire pipe0_rf_free_w = (pipe0_rd_wb_base_w == 5'b0);
wire pipe1_rf_free_w = (pipe1_rd_wb_w == 5'b0);

reg rf_p0_mulen_r;
reg rf_p0_mule2n_r;
reg rf_p0_mule3n_r;
reg rf_p0_mule5n_r;
reg rf_p1_mulen_r;
reg rf_p1_mule2n_r;
reg rf_p1_mule3n_r;
reg rf_p1_mule5n_r;

always @ *
begin
    rf_p0_mulen_r  = 1'b0;
    rf_p0_mule2n_r = 1'b0;
    rf_p0_mule3n_r = 1'b0;
    rf_p0_mule5n_r = 1'b0;
    rf_p1_mulen_r  = 1'b0;
    rf_p1_mule2n_r = 1'b0;
    rf_p1_mule3n_r = 1'b0;
    rf_p1_mule5n_r = 1'b0;

    if (pipe0_rf_free_w)
    begin
        if (mulen_wb_src_valid_w)
            rf_p0_mulen_r = 1'b1;
        else if (mule2n_wb_src_valid_w)
            rf_p0_mule2n_r = 1'b1;
        else if (mule3n_wb_src_valid_w)
            rf_p0_mule3n_r = 1'b1;
        else if (mule5n_wb_src_valid_w)
            rf_p0_mule5n_r = 1'b1;
    end

    if (pipe1_rf_free_w)
    begin
        if (mulen_wb_src_valid_w && !rf_p0_mulen_r)
            rf_p1_mulen_r = 1'b1;
        else if (mule2n_wb_src_valid_w && !rf_p0_mule2n_r)
            rf_p1_mule2n_r = 1'b1;
        else if (mule3n_wb_src_valid_w && !rf_p0_mule3n_r)
            rf_p1_mule3n_r = 1'b1;
        else if (mule5n_wb_src_valid_w && !rf_p0_mule5n_r)
            rf_p1_mule5n_r = 1'b1;
    end
end

assign mulen_writeback_safe_w  = rf_p0_mulen_r  | rf_p1_mulen_r;
assign mule2n_writeback_safe_w = rf_p0_mule2n_r | rf_p1_mule2n_r;
assign mule3n_writeback_safe_w = rf_p0_mule3n_r | rf_p1_mule3n_r;
assign mule5n_writeback_safe_w = rf_p0_mule5n_r | rf_p1_mule5n_r;

wire [4:0] rf_rd0_w =
    pipe0_rf_free_w ? (rf_p0_mulen_r  ? mulen_wb_src_rd_w  :
                       rf_p0_mule2n_r ? mule2n_wb_src_rd_w :
                       rf_p0_mule3n_r ? mule3n_wb_src_rd_w :
                       rf_p0_mule5n_r ? mule5n_wb_src_rd_w : 5'b0)
                  : pipe0_rd_wb_base_w;

wire [31:0] rf_result0_w =
    pipe0_rf_free_w ? (rf_p0_mulen_r  ? mulen_wb_src_value_w  :
                       rf_p0_mule2n_r ? mule2n_wb_src_value_w :
                       rf_p0_mule3n_r ? mule3n_wb_src_value_w :
                       rf_p0_mule5n_r ? mule5n_wb_src_value_w : 32'b0)
                  : pipe0_result_wb_base_w;

wire [4:0] rf_rd1_w =
    pipe1_rf_free_w ? (rf_p1_mulen_r  ? mulen_wb_src_rd_w  :
                       rf_p1_mule2n_r ? mule2n_wb_src_rd_w :
                       rf_p1_mule3n_r ? mule3n_wb_src_rd_w :
                       rf_p1_mule5n_r ? mule5n_wb_src_rd_w : 5'b0)
                  : pipe1_rd_wb_w;

wire [31:0] rf_result1_w =
    pipe1_rf_free_w ? (rf_p1_mulen_r  ? mulen_wb_src_value_w  :
                       rf_p1_mule2n_r ? mule2n_wb_src_value_w :
                       rf_p1_mule3n_r ? mule3n_wb_src_value_w :
                       rf_p1_mule5n_r ? mule5n_wb_src_value_w : 32'b0)
                  : pipe1_result_wb_w;

// Register file: 2W4R
biriscv_regfile
#(
     .SUPPORT_REGFILE_XILINX(SUPPORT_REGFILE_XILINX)
    ,.SUPPORT_DUAL_ISSUE(SUPPORT_DUAL_ISSUE)
)
u_regfile
(
    .clk_i(clk_i),
    .rst_i(rst_i),

    // Write ports
    .rd0_i(rf_rd0_w),
    .rd0_value_i(rf_result0_w),
    .rd1_i(rf_rd1_w),
    .rd1_value_i(rf_result1_w),

    // Read ports
    .ra0_i(issue_a_ra_idx_w),
    .rb0_i(issue_a_rb_idx_w),
    .ra0_value_o(issue_a_ra_value_w),
    .rb0_value_o(issue_a_rb_value_w),

    .ra1_i(issue_b_ra_idx_w),
    .rb1_i(issue_b_rb_idx_w),
    .ra1_value_o(issue_b_ra_value_w),
    .rb1_value_o(issue_b_rb_value_w)    
);

//-------------------------------------------------------------
// Issue Slot 0
//------------------------------------------------------------- 
assign opcode0_opcode_o = opcode_a_r;
assign opcode0_pc_o     = opcode_a_pc_r;
assign opcode0_rd_idx_o = issue_a_rd_idx_w;
assign opcode0_ra_idx_o = issue_a_ra_idx_w;
assign opcode0_rb_idx_o = issue_a_rb_idx_w;
assign opcode0_invalid_o= 1'b0; 

reg [31:0] issue_a_ra_value_r;
reg [31:0] issue_a_rb_value_r;

always @ *
begin
    // NOTE: Newest version of operand takes priority
    issue_a_ra_value_r = issue_a_ra_value_w;
    issue_a_rb_value_r = issue_a_rb_value_w;

    // Bypass - WB
    if (pipe0_rd_wb_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe0_result_wb_w;
    if (pipe0_rd_wb_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe0_result_wb_w;

    if (pipe1_rd_wb_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe1_result_wb_w;
    if (pipe1_rd_wb_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe1_result_wb_w;

    // Bypass - MULE direct writeback (highest priority with safety checks)
    // Only bypass if: valid, non-zero register, and legitimate pending operation
    if (mule_writeback_safe_w && writeback_mule_rd_idx_i == issue_a_ra_idx_w)
        issue_a_ra_value_r = writeback_mule_value_i;

    if (mule_writeback_safe_w && writeback_mule_rd_idx_i == issue_a_rb_idx_w)
        issue_a_rb_value_r = writeback_mule_value_i;

    if (mulen_writeback_safe_w && mulen_wb_src_rd_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = mulen_wb_src_value_w;

    if (mulen_writeback_safe_w && mulen_wb_src_rd_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = mulen_wb_src_value_w;

    if (mule2n_writeback_safe_w && mule2n_wb_src_rd_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = mule2n_wb_src_value_w;

    if (mule2n_writeback_safe_w && mule2n_wb_src_rd_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = mule2n_wb_src_value_w;

    if (mule3n_writeback_safe_w && mule3n_wb_src_rd_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = mule3n_wb_src_value_w;

    if (mule3n_writeback_safe_w && mule3n_wb_src_rd_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = mule3n_wb_src_value_w;

    if (mule5n_writeback_safe_w && mule5n_wb_src_rd_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = mule5n_wb_src_value_w;

    if (mule5n_writeback_safe_w && mule5n_wb_src_rd_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = mule5n_wb_src_value_w;

    // Bypass - E2
    if (pipe0_rd_e2_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe0_result_e2_w;
    if (pipe0_rd_e2_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe0_result_e2_w;

    if (pipe1_rd_e2_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = pipe1_result_e2_w;
    if (pipe1_rd_e2_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = pipe1_result_e2_w;

    // Bypass - E1
    if (pipe0_rd_e1_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = writeback_exec0_value_i;
    if (pipe0_rd_e1_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = writeback_exec0_value_i;

    if (pipe1_rd_e1_w == issue_a_ra_idx_w)
        issue_a_ra_value_r = writeback_exec1_value_i;
    if (pipe1_rd_e1_w == issue_a_rb_idx_w)
        issue_a_rb_value_r = writeback_exec1_value_i;

    // Reg 0 source
    if (issue_a_ra_idx_w == 5'b0)
        issue_a_ra_value_r = 32'b0;
    if (issue_a_rb_idx_w == 5'b0)
        issue_a_rb_value_r = 32'b0;
end

assign opcode0_ra_operand_o = issue_a_ra_value_r;
assign opcode0_rb_operand_o = issue_a_rb_value_r;

//-------------------------------------------------------------
// Issue Slot 1
//------------------------------------------------------------- 
assign opcode1_opcode_o = opcode_b_r;
assign opcode1_pc_o     = opcode_b_pc_r;
assign opcode1_rd_idx_o = issue_b_rd_idx_w;
assign opcode1_ra_idx_o = issue_b_ra_idx_w;
assign opcode1_rb_idx_o = issue_b_rb_idx_w;
assign opcode1_invalid_o= 1'b0;

reg [31:0] issue_b_ra_value_r;
reg [31:0] issue_b_rb_value_r;

always @ *
begin
    // NOTE: Newest version of operand takes priority
    issue_b_ra_value_r = issue_b_ra_value_w;
    issue_b_rb_value_r = issue_b_rb_value_w;

    // Bypass - WB
    if (pipe0_rd_wb_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe0_result_wb_w;
    if (pipe0_rd_wb_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe0_result_wb_w;

    if (pipe1_rd_wb_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe1_result_wb_w;
    if (pipe1_rd_wb_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe1_result_wb_w;

    // Bypass - MULE direct writeback (highest priority with safety checks)
    // Only bypass if: valid, non-zero register, and legitimate pending operation
    if (mule_writeback_safe_w && writeback_mule_rd_idx_i == issue_b_ra_idx_w)
        issue_b_ra_value_r = writeback_mule_value_i;

    if (mule_writeback_safe_w && writeback_mule_rd_idx_i == issue_b_rb_idx_w)
        issue_b_rb_value_r = writeback_mule_value_i;

    if (mulen_writeback_safe_w && mulen_wb_src_rd_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = mulen_wb_src_value_w;

    if (mulen_writeback_safe_w && mulen_wb_src_rd_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = mulen_wb_src_value_w;

    if (mule2n_writeback_safe_w && mule2n_wb_src_rd_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = mule2n_wb_src_value_w;

    if (mule2n_writeback_safe_w && mule2n_wb_src_rd_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = mule2n_wb_src_value_w;

    if (mule3n_writeback_safe_w && mule3n_wb_src_rd_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = mule3n_wb_src_value_w;

    if (mule3n_writeback_safe_w && mule3n_wb_src_rd_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = mule3n_wb_src_value_w;

    if (mule5n_writeback_safe_w && mule5n_wb_src_rd_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = mule5n_wb_src_value_w;

    if (mule5n_writeback_safe_w && mule5n_wb_src_rd_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = mule5n_wb_src_value_w;

    // Bypass - E2
    if (pipe0_rd_e2_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe0_result_e2_w;
    if (pipe0_rd_e2_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe0_result_e2_w;

    if (pipe1_rd_e2_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = pipe1_result_e2_w;
    if (pipe1_rd_e2_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = pipe1_result_e2_w;

    // Bypass - E1
    if (pipe0_rd_e1_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = writeback_exec0_value_i;
    if (pipe0_rd_e1_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = writeback_exec0_value_i;

    if (pipe1_rd_e1_w == issue_b_ra_idx_w)
        issue_b_ra_value_r = writeback_exec1_value_i;
    if (pipe1_rd_e1_w == issue_b_rb_idx_w)
        issue_b_rb_value_r = writeback_exec1_value_i;

    // Reg 0 source
    if (issue_b_ra_idx_w == 5'b0)
        issue_b_ra_value_r = 32'b0;
    if (issue_b_rb_idx_w == 5'b0)
        issue_b_rb_value_r = 32'b0;
end

assign opcode1_ra_operand_o = issue_b_ra_value_r;
assign opcode1_rb_operand_o = issue_b_rb_value_r;

//-------------------------------------------------------------
// Load store unit
//-------------------------------------------------------------
assign lsu_opcode_opcode_o      = pipe1_mux_lsu_r ? opcode1_opcode_o     : opcode0_opcode_o;
assign lsu_opcode_pc_o          = pipe1_mux_lsu_r ? opcode1_pc_o         : opcode0_pc_o;
assign lsu_opcode_rd_idx_o      = pipe1_mux_lsu_r ? opcode1_rd_idx_o     : opcode0_rd_idx_o;
assign lsu_opcode_ra_idx_o      = pipe1_mux_lsu_r ? opcode1_ra_idx_o     : opcode0_ra_idx_o;
assign lsu_opcode_rb_idx_o      = pipe1_mux_lsu_r ? opcode1_rb_idx_o     : opcode0_rb_idx_o;
assign lsu_opcode_ra_operand_o  = pipe1_mux_lsu_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign lsu_opcode_rb_operand_o  = pipe1_mux_lsu_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign lsu_opcode_invalid_o     = 1'b0;

//-------------------------------------------------------------
// Multiply
//-------------------------------------------------------------
assign mul_opcode_opcode_o      = pipe1_mux_mul_r ? opcode1_opcode_o     : opcode0_opcode_o;
assign mul_opcode_pc_o          = pipe1_mux_mul_r ? opcode1_pc_o         : opcode0_pc_o;
assign mul_opcode_rd_idx_o      = pipe1_mux_mul_r ? opcode1_rd_idx_o     : opcode0_rd_idx_o;
assign mul_opcode_ra_idx_o      = pipe1_mux_mul_r ? opcode1_ra_idx_o     : opcode0_ra_idx_o;
assign mul_opcode_rb_idx_o      = pipe1_mux_mul_r ? opcode1_rb_idx_o     : opcode0_rb_idx_o;
assign mul_opcode_ra_operand_o  = pipe1_mux_mul_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mul_opcode_rb_operand_o  = pipe1_mux_mul_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mul_opcode_invalid_o     = 1'b0;

//-------------------------------------------------------------
// MULE unit
//-------------------------------------------------------------
assign mule_issue_rd_idx_w      = pipe1_mux_mule_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule_opcode_opcode_o     = pipe1_mux_mule_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule_opcode_pc_o         = pipe1_mux_mule_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule_opcode_rd_idx_o     = pipe1_mux_mule_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule_opcode_ra_idx_o     = pipe1_mux_mule_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule_opcode_rb_idx_o     = pipe1_mux_mule_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule_opcode_ra_operand_o = pipe1_mux_mule_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule_opcode_rb_operand_o = pipe1_mux_mule_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule_opcode_invalid_o    = pipe1_mux_mule_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                   : (opcode_a_issue_r && issue_a_invalid_w);

assign mulen_issue_rd_idx_w      = pipe1_mux_mulen_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mulen_opcode_opcode_o     = pipe1_mux_mulen_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mulen_opcode_pc_o         = pipe1_mux_mulen_r ? opcode1_pc_o        : opcode0_pc_o;
assign mulen_opcode_rd_idx_o     = pipe1_mux_mulen_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mulen_opcode_ra_idx_o     = pipe1_mux_mulen_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mulen_opcode_rb_idx_o     = pipe1_mux_mulen_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mulen_opcode_ra_operand_o = pipe1_mux_mulen_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mulen_opcode_rb_operand_o = pipe1_mux_mulen_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mulen_opcode_invalid_o    = pipe1_mux_mulen_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                      : (opcode_a_issue_r && issue_a_invalid_w);

assign mule2_issue_rd_idx_w      = pipe1_mux_mule2_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule2_opcode_opcode_o     = pipe1_mux_mule2_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule2_opcode_pc_o         = pipe1_mux_mule2_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule2_opcode_rd_idx_o     = pipe1_mux_mule2_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule2_opcode_ra_idx_o     = pipe1_mux_mule2_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule2_opcode_rb_idx_o     = pipe1_mux_mule2_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule2_opcode_ra_operand_o = pipe1_mux_mule2_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule2_opcode_rb_operand_o = pipe1_mux_mule2_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule2_opcode_invalid_o    = pipe1_mux_mule2_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                      : (opcode_a_issue_r && issue_a_invalid_w);

assign mule2n_issue_rd_idx_w      = pipe1_mux_mule2n_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule2n_opcode_opcode_o     = pipe1_mux_mule2n_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule2n_opcode_pc_o         = pipe1_mux_mule2n_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule2n_opcode_rd_idx_o     = pipe1_mux_mule2n_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule2n_opcode_ra_idx_o     = pipe1_mux_mule2n_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule2n_opcode_rb_idx_o     = pipe1_mux_mule2n_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule2n_opcode_ra_operand_o = pipe1_mux_mule2n_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule2n_opcode_rb_operand_o = pipe1_mux_mule2n_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule2n_opcode_invalid_o    = pipe1_mux_mule2n_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                        : (opcode_a_issue_r && issue_a_invalid_w);

assign mule3_issue_rd_idx_w      = pipe1_mux_mule3_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule3_opcode_opcode_o     = pipe1_mux_mule3_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule3_opcode_pc_o         = pipe1_mux_mule3_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule3_opcode_rd_idx_o     = pipe1_mux_mule3_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule3_opcode_ra_idx_o     = pipe1_mux_mule3_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule3_opcode_rb_idx_o     = pipe1_mux_mule3_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule3_opcode_ra_operand_o = pipe1_mux_mule3_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule3_opcode_rb_operand_o = pipe1_mux_mule3_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule3_opcode_invalid_o    = pipe1_mux_mule3_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                      : (opcode_a_issue_r && issue_a_invalid_w);

assign mule3n_issue_rd_idx_w      = pipe1_mux_mule3n_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule3n_opcode_opcode_o     = pipe1_mux_mule3n_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule3n_opcode_pc_o         = pipe1_mux_mule3n_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule3n_opcode_rd_idx_o     = pipe1_mux_mule3n_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule3n_opcode_ra_idx_o     = pipe1_mux_mule3n_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule3n_opcode_rb_idx_o     = pipe1_mux_mule3n_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule3n_opcode_ra_operand_o = pipe1_mux_mule3n_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule3n_opcode_rb_operand_o = pipe1_mux_mule3n_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule3n_opcode_invalid_o    = pipe1_mux_mule3n_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                        : (opcode_a_issue_r && issue_a_invalid_w);

assign mule5_issue_rd_idx_w      = pipe1_mux_mule5_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule5_opcode_opcode_o     = pipe1_mux_mule5_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule5_opcode_pc_o         = pipe1_mux_mule5_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule5_opcode_rd_idx_o     = pipe1_mux_mule5_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule5_opcode_ra_idx_o     = pipe1_mux_mule5_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule5_opcode_rb_idx_o     = pipe1_mux_mule5_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule5_opcode_ra_operand_o = pipe1_mux_mule5_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule5_opcode_rb_operand_o = pipe1_mux_mule5_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule5_opcode_invalid_o    = pipe1_mux_mule5_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                      : (opcode_a_issue_r && issue_a_invalid_w);

assign mule5n_issue_rd_idx_w      = pipe1_mux_mule5n_r ? issue_b_rd_idx_w    : issue_a_rd_idx_w;
assign mule5n_opcode_opcode_o     = pipe1_mux_mule5n_r ? opcode1_opcode_o    : opcode0_opcode_o;
assign mule5n_opcode_pc_o         = pipe1_mux_mule5n_r ? opcode1_pc_o        : opcode0_pc_o;
assign mule5n_opcode_rd_idx_o     = pipe1_mux_mule5n_r ? opcode1_rd_idx_o    : opcode0_rd_idx_o;
assign mule5n_opcode_ra_idx_o     = pipe1_mux_mule5n_r ? opcode1_ra_idx_o    : opcode0_ra_idx_o;
assign mule5n_opcode_rb_idx_o     = pipe1_mux_mule5n_r ? opcode1_rb_idx_o    : opcode0_rb_idx_o;
assign mule5n_opcode_ra_operand_o = pipe1_mux_mule5n_r ? opcode1_ra_operand_o : opcode0_ra_operand_o;
assign mule5n_opcode_rb_operand_o = pipe1_mux_mule5n_r ? opcode1_rb_operand_o : opcode0_rb_operand_o;
assign mule5n_opcode_invalid_o    = pipe1_mux_mule5n_r ? (opcode_b_issue_r && issue_b_invalid_w)
                                                        : (opcode_a_issue_r && issue_a_invalid_w);

// Custom multiplier opcode buses (kept independent from CBM bus)
assign mula_opcode_opcode_o      = opcode0_opcode_o;
assign mula_opcode_pc_o          = opcode0_pc_o;
assign mula_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mula_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mula_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mula_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mula_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mula_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign mulx_opcode_opcode_o      = opcode0_opcode_o;
assign mulx_opcode_pc_o          = opcode0_pc_o;
assign mulx_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mulx_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mulx_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mulx_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mulx_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mulx_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign mulb_opcode_opcode_o      = opcode0_opcode_o;
assign mulb_opcode_pc_o          = opcode0_pc_o;
assign mulb_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mulb_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mulb_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mulb_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mulb_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mulb_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign mulr_opcode_opcode_o      = opcode0_opcode_o;
assign mulr_opcode_pc_o          = opcode0_pc_o;
assign mulr_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mulr_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mulr_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mulr_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mulr_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mulr_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign mulp_opcode_opcode_o      = opcode0_opcode_o;
assign mulp_opcode_pc_o          = opcode0_pc_o;
assign mulp_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mulp_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mulp_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mulp_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mulp_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mulp_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign mulc_opcode_opcode_o      = opcode0_opcode_o;
assign mulc_opcode_pc_o          = opcode0_pc_o;
assign mulc_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign mulc_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign mulc_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign mulc_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign mulc_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign mulc_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign cbm_inst_opcode_opcode_o      = opcode0_opcode_o;
assign cbm_inst_opcode_pc_o          = opcode0_pc_o;
assign cbm_inst_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign cbm_inst_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign cbm_inst_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign cbm_inst_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign cbm_inst_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign cbm_inst_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

assign cbm_opcode_valid_o      = 1'b0;
assign cbm_opcode_opcode_o     = 32'b0;
assign cbm_opcode_pc_o         = 32'b0;
assign cbm_opcode_rd_idx_o     = 5'b0;
assign cbm_opcode_ra_idx_o     = 5'b0;
assign cbm_opcode_rb_idx_o     = 5'b0;
assign cbm_opcode_ra_operand_o = 32'b0;
assign cbm_opcode_rb_operand_o = 32'b0;
assign cbm_opcode_invalid_o    = 1'b0;

//-------------------------------------------------------------
// CSR unit
//-------------------------------------------------------------
assign csr_opcode_valid_o       = opcode_a_issue_r & ~take_interrupt_i;
assign csr_opcode_opcode_o      = opcode0_opcode_o;
assign csr_opcode_pc_o          = opcode0_pc_o;
assign csr_opcode_rd_idx_o      = opcode0_rd_idx_o;
assign csr_opcode_ra_idx_o      = opcode0_ra_idx_o;
assign csr_opcode_rb_idx_o      = opcode0_rb_idx_o;
assign csr_opcode_ra_operand_o  = opcode0_ra_operand_o;
assign csr_opcode_rb_operand_o  = opcode0_rb_operand_o;
assign csr_opcode_invalid_o     = opcode_a_issue_r && issue_a_invalid_w;

//-------------------------------------------------------------
// Checker Interface
//-------------------------------------------------------------
`ifdef verilator
biriscv_trace_sim
u_pipe0_dec0_verif
(
     .valid_i(pipe0_valid_wb_w)
    ,.pc_i(pipe0_pc_wb_w)
    ,.opcode_i(pipe0_opc_wb_w)
);

wire [4:0] v_pipe0_rs1_w = pipe0_opc_wb_w[19:15];
wire [4:0] v_pipe0_rs2_w = pipe0_opc_wb_w[24:20];

function [0:0] complete_valid0; /*verilator public*/
begin
    complete_valid0 = pipe0_valid_wb_w;
end
endfunction
function [31:0] complete_pc0; /*verilator public*/
begin
    complete_pc0 = pipe0_pc_wb_w;
end
endfunction
function [31:0] complete_opcode0; /*verilator public*/
begin
    complete_opcode0 = pipe0_opc_wb_w;
end
endfunction
function [4:0] complete_ra0; /*verilator public*/
begin
    complete_ra0 = v_pipe0_rs1_w;
end
endfunction
function [4:0] complete_rb0; /*verilator public*/
begin
    complete_rb0 = v_pipe0_rs2_w;
end
endfunction
function [4:0] complete_rd0; /*verilator public*/
begin
    complete_rd0 = pipe0_rd_wb_w;
end
endfunction
function [31:0] complete_ra_val0; /*verilator public*/
begin
    complete_ra_val0 = pipe0_ra_val_wb_w;
end
endfunction
function [31:0] complete_rb_val0; /*verilator public*/
begin
    complete_rb_val0 = pipe0_rb_val_wb_w;
end
endfunction
function [31:0] complete_rd_val0; /*verilator public*/
begin
    if (|pipe0_rd_wb_w)
        complete_rd_val0 = pipe0_result_wb_w;
    else
        complete_rd_val0 = 32'b0;
end
endfunction

biriscv_trace_sim
u_pipe0_dec1_verif
(
     .valid_i(pipe1_valid_wb_w)
    ,.pc_i(pipe1_pc_wb_w)
    ,.opcode_i(pipe1_opc_wb_w)
);

wire [4:0] v_pipe1_rs1_w = pipe1_opc_wb_w[19:15];
wire [4:0] v_pipe1_rs2_w = pipe1_opc_wb_w[24:20];

function [0:0] complete_valid1; /*verilator public*/
begin
    complete_valid1 = pipe1_valid_wb_w;
end
endfunction
function [31:0] complete_pc1; /*verilator public*/
begin
    complete_pc1 = pipe1_pc_wb_w;
end
endfunction
function [31:0] complete_opcode1; /*verilator public*/
begin
    complete_opcode1 = pipe1_opc_wb_w;
end
endfunction
function [4:0] complete_ra1; /*verilator public*/
begin
    complete_ra1 = v_pipe1_rs1_w;
end
endfunction
function [4:0] complete_rb1; /*verilator public*/
begin
    complete_rb1 = v_pipe1_rs2_w;
end
endfunction
function [4:0] complete_rd1; /*verilator public*/
begin
    complete_rd1 = pipe1_rd_wb_w;
end
endfunction
function [31:0] complete_ra_val1; /*verilator public*/
begin
    complete_ra_val1 = pipe1_ra_val_wb_w;
end
endfunction
function [31:0] complete_rb_val1; /*verilator public*/
begin
    complete_rb_val1 = pipe1_rb_val_wb_w;
end
endfunction
function [31:0] complete_rd_val1; /*verilator public*/
begin
    if (|pipe1_rd_wb_w)
        complete_rd_val1 = pipe1_result_wb_w;
    else
        complete_rd_val1 = 32'b0;
end
endfunction
function [5:0] complete_exception; /*verilator public*/
begin
    complete_exception = pipe0_exception_wb_w | pipe1_exception_wb_w;
end
endfunction
`endif


endmodule
