`include "biriscv_defs.v"

module biriscv_mule2_csa64
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

module biriscv_multiplier_efficient_2
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

// Paper-like folded feedback multiplier tuned for low switching in generic RTL:
// - reuse a single 32x16 partial-product matrix over folded cycles
// - keep the feedback accumulator in carry-save form across cycles
// - perform the wide carry-propagate add only once, at completion
// - choose the sparsest magnitude operand as the chunked operand
// - reorder chunks so a single non-zero 16-bit half completes early
// - preserve RV32 MUL semantics via magnitude multiply + final sign correction

localparam [1:0] MULE2_STATE_IDLE  = 2'd0;
localparam [1:0] MULE2_STATE_CALC0 = 2'd1;
localparam [1:0] MULE2_STATE_CALC1 = 2'd2;

function [5:0] popcount16;
    input [15:0] value;
    integer idx;
begin
    popcount16 = 6'd0;
    for (idx = 0; idx < 16; idx = idx + 1)
        popcount16 = popcount16 + value[idx];
end
endfunction

function [5:0] popcount32;
    input [31:0] value;
    integer idx;
begin
    popcount32 = 6'd0;
    for (idx = 0; idx < 32; idx = idx + 1)
        popcount32 = popcount32 + value[idx];
end
endfunction

wire inst_mule2_w = ((opcode_opcode_i & `INST_MULE2_MASK) == `INST_MULE2);
wire seed_valid_w = opcode_valid_i && inst_mule2_w;

reg  [1:0]  state_q;
reg         valid_q;
reg         sign_q;
reg         chunk1_valid_q;
reg  [4:0]  rd_idx_q;
reg  [31:0] multiplicand_q;
reg  [15:0] chunk0_q;
reg  [15:0] chunk1_q;
reg         chunk0_shift_q;
reg         chunk1_shift_q;
reg  [63:0] acc_sum_q;
reg  [63:0] acc_carry_q;
reg  [31:0] result_q;

wire [31:0] op_a_seed_w = seed_valid_w ? opcode_ra_operand_i : 32'd0;
wire [31:0] op_b_seed_w = seed_valid_w ? opcode_rb_operand_i : 32'd0;
wire [31:0] a_abs_w = op_a_seed_w[31] ? (~op_a_seed_w + 32'd1) : op_a_seed_w;
wire [31:0] b_abs_w = op_b_seed_w[31] ? (~op_b_seed_w + 32'd1) : op_b_seed_w;
wire        sign_seed_w = op_a_seed_w[31] ^ op_b_seed_w[31];

wire [5:0]  a_pop_w = popcount32(a_abs_w);
wire [5:0]  b_pop_w = popcount32(b_abs_w);
wire        a_low_nonzero_w  = (a_abs_w[15:0]  != 16'd0);
wire        a_high_nonzero_w = (a_abs_w[31:16] != 16'd0);
wire        b_low_nonzero_w  = (b_abs_w[15:0]  != 16'd0);
wire        b_high_nonzero_w = (b_abs_w[31:16] != 16'd0);
wire        a_single_chunk_w = ~(a_low_nonzero_w & a_high_nonzero_w);
wire        b_single_chunk_w = ~(b_low_nonzero_w & b_high_nonzero_w);

wire choose_a_as_chunk_w =
    (a_single_chunk_w != b_single_chunk_w) ? a_single_chunk_w :
    (a_pop_w <= b_pop_w);

wire [31:0] chunk_seed_w        = choose_a_as_chunk_w ? a_abs_w : b_abs_w;
wire [31:0] multiplicand_seed_w = choose_a_as_chunk_w ? b_abs_w : a_abs_w;
wire [15:0] chunk_low_seed_w    = chunk_seed_w[15:0];
wire [15:0] chunk_high_seed_w   = chunk_seed_w[31:16];
wire        low_nonzero_seed_w  = (chunk_low_seed_w  != 16'd0);
wire        high_nonzero_seed_w = (chunk_high_seed_w != 16'd0);
wire [5:0]  low_pop_seed_w      = popcount16(chunk_low_seed_w);
wire [5:0]  high_pop_seed_w     = popcount16(chunk_high_seed_w);

wire choose_high_first_w =
    high_nonzero_seed_w &&
    (~low_nonzero_seed_w || (high_pop_seed_w < low_pop_seed_w));

wire [15:0] chunk0_seed_w      = choose_high_first_w ? chunk_high_seed_w : chunk_low_seed_w;
wire        chunk0_shift_seed_w= choose_high_first_w;
wire [15:0] chunk1_seed_w      = choose_high_first_w ? chunk_low_seed_w  : chunk_high_seed_w;
wire        chunk1_shift_seed_w= ~choose_high_first_w;
wire        chunk1_valid_seed_w= low_nonzero_seed_w & high_nonzero_seed_w;

wire        calc0_active_w     = (state_q == MULE2_STATE_CALC0);
wire        calc1_active_w     = (state_q == MULE2_STATE_CALC1);
wire        current_active_w   = calc0_active_w | calc1_active_w;
wire [15:0] current_chunk_w    = calc1_active_w ? chunk1_q       : chunk0_q;
wire        current_shift_w    = calc1_active_w ? chunk1_shift_q : chunk0_shift_q;
wire [15:0] gated_chunk_w      = current_active_w ? current_chunk_w : 16'd0;

wire [63:0] pp_w [0:15];
genvar p;
generate
    for (p = 0; p < 16; p = p + 1)
    begin : g_pp
        assign pp_w[p] = gated_chunk_w[p] ? ({32'b0, multiplicand_q} << p) : 64'd0;
    end
endgenerate

wire [63:0] ppm_sum_w   [0:16];
wire [63:0] ppm_carry_w [0:16];
assign ppm_sum_w[0]   = 64'd0;
assign ppm_carry_w[0] = 64'd0;

genvar s;
generate
    for (s = 0; s < 16; s = s + 1)
    begin : g_ppm_reduce
        biriscv_mule2_csa64
        u_ppm_csa
        (
            .a_i(ppm_sum_w[s]),
            .b_i(ppm_carry_w[s]),
            .c_i(pp_w[s]),
            .sum_o(ppm_sum_w[s + 1]),
            .carry_o(ppm_carry_w[s + 1])
        );
    end
endgenerate

wire [63:0] chunk_sum_shifted_w =
    current_shift_w ? (ppm_sum_w[16] << 16) : ppm_sum_w[16];
wire [63:0] chunk_carry_shifted_w =
    current_shift_w ? (ppm_carry_w[16] << 16) : ppm_carry_w[16];

wire [63:0] fb_stage1_sum_w;
wire [63:0] fb_stage1_carry_w;
wire [63:0] acc_sum_next_w;
wire [63:0] acc_carry_next_w;

biriscv_mule2_csa64
u_feedback_csa0
(
    .a_i(acc_sum_q),
    .b_i(acc_carry_q),
    .c_i(chunk_sum_shifted_w),
    .sum_o(fb_stage1_sum_w),
    .carry_o(fb_stage1_carry_w)
);

biriscv_mule2_csa64
u_feedback_csa1
(
    .a_i(fb_stage1_sum_w),
    .b_i(fb_stage1_carry_w),
    .c_i(chunk_carry_shifted_w),
    .sum_o(acc_sum_next_w),
    .carry_o(acc_carry_next_w)
);

wire [63:0] final_product_w = acc_sum_next_w + acc_carry_next_w;
wire [31:0] final_result_w  = sign_q ? (~final_product_w[31:0] + 32'd1) : final_product_w[31:0];

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    state_q        <= MULE2_STATE_IDLE;
    valid_q        <= 1'b0;
    sign_q         <= 1'b0;
    chunk1_valid_q <= 1'b0;
    rd_idx_q       <= 5'd0;
    multiplicand_q <= 32'd0;
    chunk0_q       <= 16'd0;
    chunk1_q       <= 16'd0;
    chunk0_shift_q <= 1'b0;
    chunk1_shift_q <= 1'b0;
    acc_sum_q      <= 64'd0;
    acc_carry_q    <= 64'd0;
    result_q       <= 32'd0;
end
else
begin
    valid_q <= 1'b0;

    case (state_q)
    MULE2_STATE_IDLE:
    begin
        if (seed_valid_w)
        begin
            sign_q         <= sign_seed_w;
            rd_idx_q       <= opcode_rd_idx_i;
            multiplicand_q <= multiplicand_seed_w;
            chunk0_q       <= chunk0_seed_w;
            chunk1_q       <= chunk1_seed_w;
            chunk0_shift_q <= chunk0_shift_seed_w;
            chunk1_shift_q <= chunk1_shift_seed_w;
            chunk1_valid_q <= chunk1_valid_seed_w;
            acc_sum_q      <= 64'd0;
            acc_carry_q    <= 64'd0;

            if ((a_abs_w == 32'd0) || (b_abs_w == 32'd0))
            begin
                result_q <= 32'd0;
                valid_q  <= 1'b1;
            end
            else
                state_q <= MULE2_STATE_CALC0;
        end
    end

    MULE2_STATE_CALC0:
    begin
        if (chunk1_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE2_STATE_CALC1;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE2_STATE_IDLE;
        end
    end

    MULE2_STATE_CALC1:
    begin
        result_q <= final_result_w;
        valid_q  <= 1'b1;
        state_q  <= MULE2_STATE_IDLE;
    end

    default:
        state_q <= MULE2_STATE_IDLE;
    endcase
end

assign writeback_valid_o  = valid_q;
assign writeback_value_o  = result_q;
assign writeback_rd_idx_o = rd_idx_q;

endmodule
