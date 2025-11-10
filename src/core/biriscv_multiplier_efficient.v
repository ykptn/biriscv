module biriscv_multiplier_efficient
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

//-----------------------------------------------------------------
// Local Params
//-----------------------------------------------------------------
localparam [2:0] MULE_STATE_IDLE  = 3'd0;
localparam [2:0] MULE_STATE_CALC0 = 3'd1;
localparam [2:0] MULE_STATE_CALC1 = 3'd2;
localparam [2:0] MULE_STATE_CALC2 = 3'd3;
localparam [2:0] MULE_STATE_DONE  = 3'd4;

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
reg [  2:0]  state_q;
reg          valid_r, valid_q;   // new
//reg          valid_r;    old
//reg [ 31:0]  result_r;   old

// Latched Operands
reg [ 31:0]  a_q;
reg [ 31:0]  b_q;
reg [  4:0]  rd_idx_q;  // Store rd index for writeback

// Partial results from the 16x16 multiplier
reg [ 31:0]  p0_q; // (A_l * B_l)
reg [ 31:0]  p1_q; // (A_l * B_h)
reg [ 31:0]  p2_q; // (A_h * B_l)

// 16x16 multiplier inputs
wire [ 15:0] mult_a_in_w;
wire [ 15:0] mult_b_in_w;
wire [ 31:0] mult_out_w;

// Single 16x16 multiplier core
assign mult_out_w = mult_a_in_w * mult_b_in_w;

//-----------------------------------------------------------------
// Sequential
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    state_q  <= MULE_STATE_IDLE;
    valid_r  <= 1'b0;
    valid_q <= 1'b0;      // NEW
    a_q      <= 32'b0;
    b_q      <= 32'b0;
    rd_idx_q <= 5'b0;     // Initialize rd index
    p0_q     <= 32'b0;
    p1_q     <= 32'b0;
    p2_q     <= 32'b0;
end
else
begin
    // Default: clear valid signal
    valid_r <= 1'b0;

    case (state_q)
    MULE_STATE_IDLE:
    begin
        if (opcode_valid_i) // New instruction from issue
        begin
            a_q     <= opcode_ra_operand_i;
            b_q     <= opcode_rb_operand_i;
            rd_idx_q <= opcode_rd_idx_i;  // Latch rd index
            state_q <= MULE_STATE_CALC0;
        end
    end
    
    MULE_STATE_CALC0: // P0 = A_l * B_l
    begin
        p0_q    <= mult_out_w; // Latch result computed in THIS cycle
        state_q <= MULE_STATE_CALC1;
    end
    
    MULE_STATE_CALC1: // P1 = A_l * B_h
    begin
        p1_q    <= mult_out_w; // Latch result computed in THIS cycle
        state_q <= MULE_STATE_CALC2;
    end
    
    MULE_STATE_CALC2: // P2 = A_h * B_l
    begin
        p2_q    <= mult_out_w; // Latch result computed in THIS cycle
        state_q <= MULE_STATE_DONE;
    end

    MULE_STATE_DONE:
    begin
        // Calculate final 32-bit result
        // Result = (A_l*B_l) + (A_l*B_h << 16) + (A_h*B_l << 16)
        // result_r <= p0_q + (p1_q << 16) + (p2_q << 16);   NEW GONE
        
        valid_r <= 1'b1; // Signal completion to issue stage
        state_q <= MULE_STATE_IDLE;
    end

    default:
    begin
        state_q <= MULE_STATE_IDLE;
    end
    endcase
    valid_q <= valid_r; //  NEW
end

//-----------------------------------------------------------------
// Combinatorial
//-----------------------------------------------------------------

// FSM controls the inputs to the 16x16 multiplier
assign mult_a_in_w = (state_q == MULE_STATE_CALC0) ? a_q[15:0] : // A_l
                     (state_q == MULE_STATE_CALC1) ? a_q[15:0] : // A_l
                     (state_q == MULE_STATE_CALC2) ? a_q[31:16] : // A_h
                     16'b0;

assign mult_b_in_w = (state_q == MULE_STATE_CALC0) ? b_q[15:0] : // B_l
                     (state_q == MULE_STATE_CALC1) ? b_q[31:16] : // B_h
                     (state_q == MULE_STATE_CALC2) ? b_q[15:0] : // B_l
                     16'b0;

// Combinational final product from partials
wire [31:0] result_w;                            // NEW
assign result_w = p0_q + (p1_q << 16) + (p2_q << 16);  // NEW

// Outputs
assign writeback_valid_o = valid_q;              // NEW
assign writeback_value_o = result_w;             // NEW
assign writeback_rd_idx_o = rd_idx_q;            // NEW

// Outputs to issue stage
//assign writeback_valid_o = valid_r;   old
//assign writeback_value_o = result_r;   old

endmodule
