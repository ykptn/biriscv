`include "biriscv_defs.v"

module biriscv_multiplier_cyclic
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

localparam MULC_IDLE      = 3'd0;
localparam MULC_RUN_ADD   = 3'd1;
localparam MULC_RUN_SHIFT = 3'd2;
localparam MULC_DONE      = 3'd3;

wire inst_mulc_w = ((opcode_opcode_i & `INST_MULC_MASK) == `INST_MULC);

reg [2:0]  state_q;
reg [63:0] acc_q;
reg [63:0] mcand_q;
reg [31:0] mplier_q;
reg [5:0]  iter_q;
reg        sign_q;
reg [4:0]  rd_idx_q;
reg        valid_q;
reg [31:0] result_q;

wire [31:0] a_abs_w = opcode_ra_operand_i[31] ? (~opcode_ra_operand_i + 32'd1) : opcode_ra_operand_i;
wire [31:0] b_abs_w = opcode_rb_operand_i[31] ? (~opcode_rb_operand_i + 32'd1) : opcode_rb_operand_i;
wire        sign_seed_w = opcode_ra_operand_i[31] ^ opcode_rb_operand_i[31];

// No early-out: perform exactly 32 iterations for maximum switching activity.
wire [63:0] addend_w = mplier_q[0] ? mcand_q : 64'd0;
wire [63:0] acc_next_w = acc_q + addend_w;

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    state_q   <= MULC_IDLE;
    acc_q     <= 64'd0;
    mcand_q   <= 64'd0;
    mplier_q  <= 32'd0;
    iter_q    <= 6'd0;
    sign_q    <= 1'b0;
    rd_idx_q  <= 5'd0;
    valid_q   <= 1'b0;
    result_q  <= 32'd0;
end
else
begin
    valid_q <= 1'b0;

    case (state_q)
    MULC_IDLE:
    begin
        if (opcode_valid_i && inst_mulc_w)
        begin
            acc_q    <= 64'd0;
            mcand_q  <= {32'd0, a_abs_w};
            mplier_q <= b_abs_w;
            iter_q   <= 6'd0;
            sign_q   <= sign_seed_w;
            rd_idx_q <= opcode_rd_idx_i;
            state_q  <= MULC_RUN_ADD;
        end
    end

    MULC_RUN_ADD:
    begin
        // Phase-1: add partial product (if current multiplier bit is 1).
        acc_q    <= acc_next_w;
        state_q  <= MULC_RUN_SHIFT;
    end

    MULC_RUN_SHIFT:
    begin
        // Phase-2: shift datapath registers. No early-out, fixed 32 bits.
        mcand_q  <= mcand_q << 1;
        mplier_q <= {1'b0, mplier_q[31:1]};
        iter_q   <= iter_q + 6'd1;

        if (iter_q == 6'd31)
            state_q <= MULC_DONE;
        else
            state_q <= MULC_RUN_ADD;
    end

    MULC_DONE:
    begin
        // Signed low-32 result, same semantic as MUL.
        result_q <= sign_q ? (~acc_q[31:0] + 32'd1) : acc_q[31:0];
        valid_q  <= 1'b1;
        state_q  <= MULC_IDLE;
    end

    default:
        state_q <= MULC_IDLE;
    endcase
end

assign writeback_valid_o  = valid_q;
assign writeback_value_o  = result_q;
assign writeback_rd_idx_o = rd_idx_q;

endmodule
