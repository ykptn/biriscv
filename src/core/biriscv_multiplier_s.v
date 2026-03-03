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

module biriscv_multiplier_s
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

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "biriscv_defs.v"

//-------------------------------------------------------------
// Instruction decode
//-------------------------------------------------------------
wire mult_inst_w = ((opcode_opcode_i & `INST_MULS_MASK) == `INST_MULS);

//-------------------------------------------------------------
// Operand pipeline (same mul logic as biriscv_multiplier for MUL)
//-------------------------------------------------------------
reg [32:0] operand_a_e1_q;
reg [32:0] operand_b_e1_q;
reg [4:0]  rd_idx_e1_q;
reg        valid_e1_q;

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    operand_a_e1_q <= 33'b0;
    operand_b_e1_q <= 33'b0;
    rd_idx_e1_q    <= 5'b0;
    valid_e1_q     <= 1'b0;
end
else if (opcode_valid_i && mult_inst_w)
begin
    operand_a_e1_q <= {1'b0, opcode_ra_operand_i};
    operand_b_e1_q <= {1'b0, opcode_rb_operand_i};
    rd_idx_e1_q    <= opcode_rd_idx_i;
    valid_e1_q     <= 1'b1;
end
else
begin
    operand_a_e1_q <= 33'b0;
    operand_b_e1_q <= 33'b0;
    rd_idx_e1_q    <= 5'b0;
    valid_e1_q     <= 1'b0;
end

wire [64:0] mult_result_w = {{32{operand_a_e1_q[32]}}, operand_a_e1_q} *
                            {{32{operand_b_e1_q[32]}}, operand_b_e1_q};

wire [31:0] result_w = mult_result_w[31:0];

//-------------------------------------------------------------
// Result pipeline
//-------------------------------------------------------------
reg [31:0] result_e2_q;
reg [4:0]  rd_idx_e2_q;
reg        valid_e2_q;

always @(posedge clk_i or posedge rst_i)
if (rst_i)
begin
    result_e2_q <= 32'b0;
    rd_idx_e2_q <= 5'b0;
    valid_e2_q  <= 1'b0;
end
else
begin
    result_e2_q <= result_w;
    rd_idx_e2_q <= rd_idx_e1_q;
    valid_e2_q  <= valid_e1_q;
end

assign writeback_valid_o  = valid_e2_q;
assign writeback_value_o  = result_e2_q;
assign writeback_rd_idx_o = rd_idx_e2_q;

endmodule
