`include "biriscv_defs.v"

module biriscv_mule3n_csa64
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

module biriscv_multiplier_efficient_3_n
(
    input           clk_i,
    input           rst_i,
    input           opcode_valid_i,
    input  [31:0]   opcode_opcode_i,
    input  [31:0]   opcode_pc_i,
    input           opcode_invalid_i,
    input  [4:0]    opcode_rd_idx_i,
    input  [4:0]    opcode_ra_idx_i,
    input  [4:0]    opcode_rb_idx_i,
    input  [31:0]   opcode_ra_operand_i,
    input  [31:0]   opcode_rb_operand_i,

    output          writeback_valid_o,
    output [31:0]   writeback_value_o,
    output [4:0]    writeback_rd_idx_o
);

// CT3-like folded feedback multiplier:
// - reuse a single 32x11 partial-product matrix over up to three folded cycles
// - keep accumulator feedback in carry-save form until the final cycle
// - choose the sparsest magnitude operand as the chunked operand
// - reorder the three chunks to process the sparsest non-zero chunk first
// - preserve signed RV32 MUL semantics via magnitude multiply + sign correction

localparam [1:0] MULE3_STATE_IDLE  = 2'd0;
localparam [1:0] MULE3_STATE_CALC0 = 2'd1;
localparam [1:0] MULE3_STATE_CALC1 = 2'd2;
localparam [1:0] MULE3_STATE_CALC2 = 2'd3;

function [5:0] popcount11;
    input [10:0] value;
    integer idx;
begin
    popcount11 = 6'd0;
    for (idx = 0; idx < 11; idx = idx + 1)
        popcount11 = popcount11 + value[idx];
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

wire inst_mule3n_w = ((opcode_opcode_i & `INST_MULE3N_MASK) == `INST_MULE3N);
wire seed_valid_w = opcode_valid_i && inst_mule3n_w;

reg  [1:0] state_q;
reg        valid_q;
reg        sign_q;
reg        chunk1_valid_q;
reg        chunk2_valid_q;
reg  [4:0] rd_idx_q;
reg  [31:0] multiplicand_q;
reg  [10:0] chunk0_q;
reg  [10:0] chunk1_q;
reg  [10:0] chunk2_q;
reg  [5:0]  chunk0_shift_q;
reg  [5:0]  chunk1_shift_q;
reg  [5:0]  chunk2_shift_q;
reg  [63:0] acc_sum_q;
reg  [63:0] acc_carry_q;
reg  [31:0] result_q;

wire [31:0] op_a_seed_w = seed_valid_w ? opcode_ra_operand_i : 32'd0;
wire [31:0] op_b_seed_w = seed_valid_w ? opcode_rb_operand_i : 32'd0;
wire [31:0] a_abs_w = op_a_seed_w[31] ? (~op_a_seed_w + 32'd1) : op_a_seed_w;
wire [31:0] b_abs_w = op_b_seed_w[31] ? (~op_b_seed_w + 32'd1) : op_b_seed_w;
wire        sign_seed_w = op_a_seed_w[31] ^ op_b_seed_w[31];

wire [5:0] a_pop_w = popcount32(a_abs_w);
wire [5:0] b_pop_w = popcount32(b_abs_w);
wire       a_low_nonzero_w  = (a_abs_w[10:0]  != 11'd0);
wire       a_mid_nonzero_w  = (a_abs_w[21:11] != 11'd0);
wire       a_high_nonzero_w = (a_abs_w[31:22] != 10'd0);
wire       b_low_nonzero_w  = (b_abs_w[10:0]  != 11'd0);
wire       b_mid_nonzero_w  = (b_abs_w[21:11] != 11'd0);
wire       b_high_nonzero_w = (b_abs_w[31:22] != 10'd0);
wire [1:0] a_chunk_count_w  = a_low_nonzero_w + a_mid_nonzero_w + a_high_nonzero_w;
wire [1:0] b_chunk_count_w  = b_low_nonzero_w + b_mid_nonzero_w + b_high_nonzero_w;

// Prefer the operand that will activate fewer folded chunks. If both touch the
// same number of chunks, fall back to raw bit sparsity as in MULE2.
wire       choose_a_as_chunk_w =
    (a_chunk_count_w != b_chunk_count_w) ? (a_chunk_count_w < b_chunk_count_w) :
                                           (a_pop_w <= b_pop_w);

wire [31:0] chunk_seed_w        = choose_a_as_chunk_w ? a_abs_w : b_abs_w;
wire [31:0] multiplicand_seed_w = choose_a_as_chunk_w ? b_abs_w : a_abs_w;

wire [10:0] chunk_low_seed_w  = chunk_seed_w[10:0];
wire [10:0] chunk_mid_seed_w  = chunk_seed_w[21:11];
wire [10:0] chunk_high_seed_w = {1'b0, chunk_seed_w[31:22]};

wire        low_nonzero_seed_w  = (chunk_low_seed_w  != 11'd0);
wire        mid_nonzero_seed_w  = (chunk_mid_seed_w  != 11'd0);
wire        high_nonzero_seed_w = (chunk_high_seed_w != 11'd0);

wire [5:0] low_pop_seed_w  = popcount11(chunk_low_seed_w);
wire [5:0] mid_pop_seed_w  = popcount11(chunk_mid_seed_w);
wire [5:0] high_pop_seed_w = popcount11(chunk_high_seed_w);

reg  [10:0] chunk0_seed_r;
reg  [10:0] chunk1_seed_r;
reg  [10:0] chunk2_seed_r;
reg  [5:0]  chunk0_shift_seed_r;
reg  [5:0]  chunk1_shift_seed_r;
reg  [5:0]  chunk2_shift_seed_r;
reg         chunk0_valid_seed_r;
reg         chunk1_valid_seed_r;
reg         chunk2_valid_seed_r;

reg  [10:0] sort_chunk0_r;
reg  [10:0] sort_chunk1_r;
reg  [10:0] sort_chunk2_r;
reg  [5:0]  sort_shift0_r;
reg  [5:0]  sort_shift1_r;
reg  [5:0]  sort_shift2_r;
reg  [5:0]  sort_weight0_r;
reg  [5:0]  sort_weight1_r;
reg  [5:0]  sort_weight2_r;
reg         sort_valid0_r;
reg         sort_valid1_r;
reg         sort_valid2_r;
reg  [10:0] tmp_chunk_r;
reg  [5:0]  tmp_shift_r;
reg  [5:0]  tmp_weight_r;
reg         tmp_valid_r;

always @ (*) begin
    sort_chunk0_r  = chunk_low_seed_w;
    sort_chunk1_r  = chunk_mid_seed_w;
    sort_chunk2_r  = chunk_high_seed_w;
    sort_shift0_r  = 6'd0;
    sort_shift1_r  = 6'd11;
    sort_shift2_r  = 6'd22;
    sort_weight0_r = low_nonzero_seed_w  ? low_pop_seed_w  : 6'd63;
    sort_weight1_r = mid_nonzero_seed_w  ? mid_pop_seed_w  : 6'd63;
    sort_weight2_r = high_nonzero_seed_w ? high_pop_seed_w : 6'd63;
    sort_valid0_r  = low_nonzero_seed_w;
    sort_valid1_r  = mid_nonzero_seed_w;
    sort_valid2_r  = high_nonzero_seed_w;

    if ((sort_weight1_r < sort_weight0_r) ||
        ((sort_weight1_r == sort_weight0_r) && (sort_shift1_r < sort_shift0_r))) begin
        tmp_chunk_r   = sort_chunk0_r;
        tmp_shift_r   = sort_shift0_r;
        tmp_weight_r  = sort_weight0_r;
        tmp_valid_r   = sort_valid0_r;
        sort_chunk0_r = sort_chunk1_r;
        sort_shift0_r = sort_shift1_r;
        sort_weight0_r= sort_weight1_r;
        sort_valid0_r = sort_valid1_r;
        sort_chunk1_r = tmp_chunk_r;
        sort_shift1_r = tmp_shift_r;
        sort_weight1_r= tmp_weight_r;
        sort_valid1_r = tmp_valid_r;
    end

    if ((sort_weight2_r < sort_weight1_r) ||
        ((sort_weight2_r == sort_weight1_r) && (sort_shift2_r < sort_shift1_r))) begin
        tmp_chunk_r   = sort_chunk1_r;
        tmp_shift_r   = sort_shift1_r;
        tmp_weight_r  = sort_weight1_r;
        tmp_valid_r   = sort_valid1_r;
        sort_chunk1_r = sort_chunk2_r;
        sort_shift1_r = sort_shift2_r;
        sort_weight1_r= sort_weight2_r;
        sort_valid1_r = sort_valid2_r;
        sort_chunk2_r = tmp_chunk_r;
        sort_shift2_r = tmp_shift_r;
        sort_weight2_r= tmp_weight_r;
        sort_valid2_r = tmp_valid_r;
    end

    if ((sort_weight1_r < sort_weight0_r) ||
        ((sort_weight1_r == sort_weight0_r) && (sort_shift1_r < sort_shift0_r))) begin
        tmp_chunk_r   = sort_chunk0_r;
        tmp_shift_r   = sort_shift0_r;
        tmp_weight_r  = sort_weight0_r;
        tmp_valid_r   = sort_valid0_r;
        sort_chunk0_r = sort_chunk1_r;
        sort_shift0_r = sort_shift1_r;
        sort_weight0_r= sort_weight1_r;
        sort_valid0_r = sort_valid1_r;
        sort_chunk1_r = tmp_chunk_r;
        sort_shift1_r = tmp_shift_r;
        sort_weight1_r= tmp_weight_r;
        sort_valid1_r = tmp_valid_r;
    end

    chunk0_seed_r       = sort_chunk0_r;
    chunk1_seed_r       = sort_chunk1_r;
    chunk2_seed_r       = sort_chunk2_r;
    chunk0_shift_seed_r = sort_shift0_r;
    chunk1_shift_seed_r = sort_shift1_r;
    chunk2_shift_seed_r = sort_shift2_r;
    chunk0_valid_seed_r = sort_valid0_r;
    chunk1_valid_seed_r = sort_valid1_r;
    chunk2_valid_seed_r = sort_valid2_r;
end

wire       calc0_active_w      = (state_q == MULE3_STATE_CALC0);
wire       calc1_active_w      = (state_q == MULE3_STATE_CALC1);
wire       calc2_active_w      = (state_q == MULE3_STATE_CALC2);
wire       current_active_w    = calc0_active_w | calc1_active_w | calc2_active_w;
wire [10:0] current_chunk_w    = calc2_active_w ? chunk2_q :
                                 calc1_active_w ? chunk1_q : chunk0_q;
wire [5:0]  current_shift_w    = calc2_active_w ? chunk2_shift_q :
                                 calc1_active_w ? chunk1_shift_q : chunk0_shift_q;
wire [10:0] gated_chunk_w      = current_active_w ? current_chunk_w : 11'd0;

wire [63:0] pp_w [0:10];
genvar p;
generate
    for (p = 0; p < 11; p = p + 1)
    begin : g_pp
        assign pp_w[p] = gated_chunk_w[p] ? ({32'b0, multiplicand_q} << p) : 64'd0;
    end
endgenerate

wire [63:0] ppm_sum_w   [0:11];
wire [63:0] ppm_carry_w [0:11];
assign ppm_sum_w[0]   = 64'd0;
assign ppm_carry_w[0] = 64'd0;

genvar s;
generate
    for (s = 0; s < 11; s = s + 1)
    begin : g_ppm_reduce
        biriscv_mule3n_csa64
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

wire [63:0] chunk_sum_shifted_w   = ppm_sum_w[11]   << current_shift_w;
wire [63:0] chunk_carry_shifted_w = ppm_carry_w[11] << current_shift_w;
wire [63:0] fb_stage1_sum_w;
wire [63:0] fb_stage1_carry_w;
wire [63:0] acc_sum_next_w;
wire [63:0] acc_carry_next_w;

biriscv_mule3n_csa64
u_feedback_csa0
(
    .a_i(acc_sum_q),
    .b_i(acc_carry_q),
    .c_i(chunk_sum_shifted_w),
    .sum_o(fb_stage1_sum_w),
    .carry_o(fb_stage1_carry_w)
);

biriscv_mule3n_csa64
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
    state_q         <= MULE3_STATE_IDLE;
    valid_q         <= 1'b0;
    sign_q          <= 1'b0;
    chunk1_valid_q  <= 1'b0;
    chunk2_valid_q  <= 1'b0;
    rd_idx_q        <= 5'd0;
    multiplicand_q  <= 32'd0;
    chunk0_q        <= 11'd0;
    chunk1_q        <= 11'd0;
    chunk2_q        <= 11'd0;
    chunk0_shift_q  <= 6'd0;
    chunk1_shift_q  <= 6'd0;
    chunk2_shift_q  <= 6'd0;
    acc_sum_q       <= 64'd0;
    acc_carry_q     <= 64'd0;
    result_q        <= 32'd0;
end
else
begin
    valid_q <= 1'b0;

    case (state_q)
    MULE3_STATE_IDLE:
    begin
        if (seed_valid_w)
        begin
            sign_q         <= sign_seed_w;
            rd_idx_q       <= opcode_rd_idx_i;
            multiplicand_q <= multiplicand_seed_w;
            chunk0_q       <= chunk0_seed_r;
            chunk1_q       <= chunk1_seed_r;
            chunk2_q       <= chunk2_seed_r;
            chunk0_shift_q <= chunk0_shift_seed_r;
            chunk1_shift_q <= chunk1_shift_seed_r;
            chunk2_shift_q <= chunk2_shift_seed_r;
            chunk1_valid_q <= chunk1_valid_seed_r;
            chunk2_valid_q <= chunk2_valid_seed_r;
            acc_sum_q      <= 64'd0;
            acc_carry_q    <= 64'd0;

            if ((a_abs_w == 32'd0) || (b_abs_w == 32'd0))
            begin
                result_q <= 32'd0;
                valid_q  <= 1'b1;
            end
            else
                state_q <= MULE3_STATE_CALC0;
        end
    end

    MULE3_STATE_CALC0:
    begin
        if (chunk1_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE3_STATE_CALC1;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE3_STATE_IDLE;
        end
    end

    MULE3_STATE_CALC1:
    begin
        if (chunk2_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE3_STATE_CALC2;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE3_STATE_IDLE;
        end
    end

    MULE3_STATE_CALC2:
    begin
        result_q <= final_result_w;
        valid_q  <= 1'b1;
        state_q  <= MULE3_STATE_IDLE;
    end

    default:
        state_q <= MULE3_STATE_IDLE;
    endcase
end

assign writeback_valid_o  = valid_q;
assign writeback_value_o  = result_q;
assign writeback_rd_idx_o = rd_idx_q;

endmodule
