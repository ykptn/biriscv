//-----------------------------------------------------------------
// Deep-Pipelined Multiplier (MULP)
//
// Energy-efficient 32-bit multiplier using deep pipelining with
// the Verilog `*` operator, designed for synthesis retiming.
//
// Strategy:
//   1. Use the `*` operator — let the synthesis tool (Cadence Genus)
//      decompose it into an optimal partial-product tree.
//   2. Place MULT_STAGES pipeline register stages AFTER the
//      combinational multiply.
//   3. Enable retiming in Genus (set_db root: / .retime true) —
//      this redistributes pipeline registers backward through the
//      multiplication logic, automatically balancing pipeline stages.
//
// Why this saves energy:
//   - Shorter combinational paths per stage → less glitching
//   - Reduced switching activity per clock cycle
//   - Enables lower supply voltage (P ∝ V²)
//   - Genus optimises partial-product compression for ASAP7
//   - Input gating zeros operands when idle → no toggling
//
// Genus TCL for retiming:
//   set_db / .retime true
//   set_db "design:biriscv_multiplier_pipelined" .retime true
//   set_db "design:biriscv_multiplier_pipelined" .retime_effort high
//
// Interface matches MULE/CBM style: writeback_valid_o pulse with
// writeback_rd_idx_o when result is ready (after MULT_STAGES cycles).
//
// Parameter MULT_STAGES controls the pipeline depth (default 6).
// Recommended range: 4–8.  More stages = more retiming freedom
// but higher latency.
//-----------------------------------------------------------------

module biriscv_multiplier_pipelined
#(
    parameter MULT_STAGES = 6   // Total pipeline depth (4–8 recommended)
)
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
// Instruction decode — identical to biriscv_multiplier
//-------------------------------------------------------------
wire mult_inst_w = ((opcode_opcode_i & `INST_MULP_MASK) == `INST_MULP);

//-------------------------------------------------------------
// Operand preparation
// MULP only computes low-32 bits (like MUL), so both operands
// are zero-extended to 33 bits.  The product[31:0] is the result.
//-------------------------------------------------------------
wire [32:0] operand_a_w = {1'b0, opcode_ra_operand_i};
wire [32:0] operand_b_w = {1'b0, opcode_rb_operand_i};

//-------------------------------------------------------------
// Stage 0 — Register inputs (gate to zero when idle to
// suppress switching in the multiply tree)
//-------------------------------------------------------------
reg [32:0]  pipe0_a_q;
reg [32:0]  pipe0_b_q;
reg         pipe0_valid_q;
reg [ 4:0]  pipe0_rd_idx_q;

always @(posedge clk_i or posedge rst_i)
if (rst_i) begin
    pipe0_a_q      <= 33'b0;
    pipe0_b_q      <= 33'b0;
    pipe0_valid_q  <= 1'b0;
    pipe0_rd_idx_q <= 5'b0;
end
else if (opcode_valid_i && mult_inst_w) begin
    pipe0_a_q      <= operand_a_w;
    pipe0_b_q      <= operand_b_w;
    pipe0_valid_q  <= 1'b1;
    pipe0_rd_idx_q <= opcode_rd_idx_i;
end
else begin
    // Zero inputs when no valid multiply — prevents pipeline toggling
    pipe0_a_q      <= 33'b0;
    pipe0_b_q      <= 33'b0;
    pipe0_valid_q  <= 1'b0;
    pipe0_rd_idx_q <= 5'b0;
end

//-------------------------------------------------------------
// Combinational multiply — synthesis tool decomposes this
// into an optimal partial-product tree.  Retiming will push
// the pipeline registers (below) backward into this logic.
//-------------------------------------------------------------
wire [65:0] mult_full_w = {{33{pipe0_a_q[32]}}, pipe0_a_q}
                        * {{33{pipe0_b_q[32]}}, pipe0_b_q};

// Select low 32 bits (MUL semantics)
wire [31:0] mult_result_w = mult_full_w[31:0];

//-------------------------------------------------------------
// Pipeline registers for retiming
//
// These N-1 register stages sit AFTER the combinational
// multiply. During synthesis retiming, Genus moves registers
// backward through the multiply tree to create balanced
// pipeline stages with minimal combinational depth each.
//
// Data signals are NOT gated with valid inside the pipeline —
// gating would prevent retiming.  Instead, the input stage
// zeros the operands when idle, so zeros propagate naturally.
//
// Implementation uses packed (flat) shift registers to ensure
// correct behaviour across all Verilog simulators (including
// Icarus Verilog which has issues with unpacked reg arrays
// in generate blocks with async reset).
//-------------------------------------------------------------

// Number of pipeline stages between multiply output and final output
localparam PIPE_DEPTH = MULT_STAGES - 1;  // 5 stages for MULT_STAGES=6

// Packed shift registers – MSB is newest, LSB is oldest (output)
reg [PIPE_DEPTH-1:0]      valid_sr;
reg [PIPE_DEPTH*32-1:0]   result_sr;
reg [PIPE_DEPTH*5-1:0]    rd_idx_sr;

always @(posedge clk_i or posedge rst_i)
if (rst_i) begin
    valid_sr   <= {PIPE_DEPTH{1'b0}};
    result_sr  <= {PIPE_DEPTH*32{1'b0}};
    rd_idx_sr  <= {PIPE_DEPTH*5{1'b0}};
end
else begin
    // Shift left: new data enters MSB side, old data exits LSB
    valid_sr   <= {pipe0_valid_q,  valid_sr[PIPE_DEPTH-1:1]};
    result_sr  <= {mult_result_w,  result_sr[PIPE_DEPTH*32-1:32]};
    rd_idx_sr  <= {pipe0_rd_idx_q, rd_idx_sr[PIPE_DEPTH*5-1:5]};
end

//-------------------------------------------------------------
// Output — from the oldest pipeline stage (LSB)
//-------------------------------------------------------------
assign writeback_valid_o  = valid_sr[0];
assign writeback_value_o  = result_sr[31:0];
assign writeback_rd_idx_o = rd_idx_sr[4:0];

endmodule
