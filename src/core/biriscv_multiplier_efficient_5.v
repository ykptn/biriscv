`include "biriscv_defs.v"

module biriscv_mule5_csa64
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

module biriscv_multiplier_efficient_5
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

// CT5-like folded feedback multiplier:
// - reuse a single 32x7 partial-product matrix over up to five folded cycles
// - keep accumulator feedback in carry-save form until the final cycle
// - prefer the operand that activates fewer folded chunks, then lower popcount
// - reorder non-zero chunks so the sparsest chunk runs first
// - preserve signed RV32 MUL semantics via magnitude multiply + sign correction

localparam [2:0] MULE5_STATE_IDLE  = 3'd0;
localparam [2:0] MULE5_STATE_CALC0 = 3'd1;
localparam [2:0] MULE5_STATE_CALC1 = 3'd2;
localparam [2:0] MULE5_STATE_CALC2 = 3'd3;
localparam [2:0] MULE5_STATE_CALC3 = 3'd4;
localparam [2:0] MULE5_STATE_CALC4 = 3'd5;

function [5:0] popcount7;
    input [6:0] value;
    integer idx;
begin
    popcount7 = 6'd0;
    for (idx = 0; idx < 7; idx = idx + 1)
        popcount7 = popcount7 + value[idx];
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

wire inst_mule5_w = ((opcode_opcode_i & `INST_MULE5_MASK) == `INST_MULE5);
wire seed_valid_w = opcode_valid_i && inst_mule5_w;

reg  [2:0] state_q;
reg        valid_q;
reg        sign_q;
reg  [4:0] rd_idx_q;
reg  [31:0] multiplicand_q;
reg  [6:0] chunk0_q;
reg  [6:0] chunk1_q;
reg  [6:0] chunk2_q;
reg  [6:0] chunk3_q;
reg  [6:0] chunk4_q;
reg  [5:0] chunk0_shift_q;
reg  [5:0] chunk1_shift_q;
reg  [5:0] chunk2_shift_q;
reg  [5:0] chunk3_shift_q;
reg  [5:0] chunk4_shift_q;
reg        chunk1_valid_q;
reg        chunk2_valid_q;
reg        chunk3_valid_q;
reg        chunk4_valid_q;
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

wire       a_chunk0_nonzero_w = (a_abs_w[6:0]   != 7'd0);
wire       a_chunk1_nonzero_w = (a_abs_w[13:7]  != 7'd0);
wire       a_chunk2_nonzero_w = (a_abs_w[20:14] != 7'd0);
wire       a_chunk3_nonzero_w = (a_abs_w[27:21] != 7'd0);
wire       a_chunk4_nonzero_w = (a_abs_w[31:28] != 4'd0);
wire       b_chunk0_nonzero_w = (b_abs_w[6:0]   != 7'd0);
wire       b_chunk1_nonzero_w = (b_abs_w[13:7]  != 7'd0);
wire       b_chunk2_nonzero_w = (b_abs_w[20:14] != 7'd0);
wire       b_chunk3_nonzero_w = (b_abs_w[27:21] != 7'd0);
wire       b_chunk4_nonzero_w = (b_abs_w[31:28] != 4'd0);
wire [2:0] a_chunk_count_w = a_chunk0_nonzero_w + a_chunk1_nonzero_w + a_chunk2_nonzero_w +
                              a_chunk3_nonzero_w + a_chunk4_nonzero_w;
wire [2:0] b_chunk_count_w = b_chunk0_nonzero_w + b_chunk1_nonzero_w + b_chunk2_nonzero_w +
                              b_chunk3_nonzero_w + b_chunk4_nonzero_w;

wire       choose_a_as_chunk_w =
    (a_chunk_count_w != b_chunk_count_w) ? (a_chunk_count_w < b_chunk_count_w) :
                                           (a_pop_w <= b_pop_w);

wire [31:0] chunk_seed_w        = choose_a_as_chunk_w ? a_abs_w : b_abs_w;
wire [31:0] multiplicand_seed_w = choose_a_as_chunk_w ? b_abs_w : a_abs_w;

wire [6:0] chunk_seed0_w = chunk_seed_w[6:0];
wire [6:0] chunk_seed1_w = chunk_seed_w[13:7];
wire [6:0] chunk_seed2_w = chunk_seed_w[20:14];
wire [6:0] chunk_seed3_w = chunk_seed_w[27:21];
wire [6:0] chunk_seed4_w = {3'b000, chunk_seed_w[31:28]};

wire        seed_valid0_w = (chunk_seed0_w != 7'd0);
wire        seed_valid1_w = (chunk_seed1_w != 7'd0);
wire        seed_valid2_w = (chunk_seed2_w != 7'd0);
wire        seed_valid3_w = (chunk_seed3_w != 7'd0);
wire        seed_valid4_w = (chunk_seed_w[31:28] != 4'd0);
wire [5:0]  seed_weight0_w = seed_valid0_w ? popcount7(chunk_seed0_w) : 6'd63;
wire [5:0]  seed_weight1_w = seed_valid1_w ? popcount7(chunk_seed1_w) : 6'd63;
wire [5:0]  seed_weight2_w = seed_valid2_w ? popcount7(chunk_seed2_w) : 6'd63;
wire [5:0]  seed_weight3_w = seed_valid3_w ? popcount7(chunk_seed3_w) : 6'd63;
wire [5:0]  seed_weight4_w = seed_valid4_w ? popcount7(chunk_seed4_w) : 6'd63;

reg  [6:0] sort_chunk_r  [0:4];
reg  [5:0] sort_shift_r  [0:4];
reg  [5:0] sort_weight_r [0:4];
reg        sort_valid_r  [0:4];
reg  [6:0] tmp_chunk_r;
reg  [5:0] tmp_shift_r;
reg  [5:0] tmp_weight_r;
reg        tmp_valid_r;
integer sort_i;
integer sort_j;

reg  [6:0] chunk0_seed_r;
reg  [6:0] chunk1_seed_r;
reg  [6:0] chunk2_seed_r;
reg  [6:0] chunk3_seed_r;
reg  [6:0] chunk4_seed_r;
reg  [5:0] chunk0_shift_seed_r;
reg  [5:0] chunk1_shift_seed_r;
reg  [5:0] chunk2_shift_seed_r;
reg  [5:0] chunk3_shift_seed_r;
reg  [5:0] chunk4_shift_seed_r;
reg        chunk0_valid_seed_r;
reg        chunk1_valid_seed_r;
reg        chunk2_valid_seed_r;
reg        chunk3_valid_seed_r;
reg        chunk4_valid_seed_r;

always @ (*) begin
    sort_chunk_r[0]  = chunk_seed0_w;
    sort_chunk_r[1]  = chunk_seed1_w;
    sort_chunk_r[2]  = chunk_seed2_w;
    sort_chunk_r[3]  = chunk_seed3_w;
    sort_chunk_r[4]  = chunk_seed4_w;
    sort_shift_r[0]  = 6'd0;
    sort_shift_r[1]  = 6'd7;
    sort_shift_r[2]  = 6'd14;
    sort_shift_r[3]  = 6'd21;
    sort_shift_r[4]  = 6'd28;
    sort_weight_r[0] = seed_weight0_w;
    sort_weight_r[1] = seed_weight1_w;
    sort_weight_r[2] = seed_weight2_w;
    sort_weight_r[3] = seed_weight3_w;
    sort_weight_r[4] = seed_weight4_w;
    sort_valid_r[0]  = seed_valid0_w;
    sort_valid_r[1]  = seed_valid1_w;
    sort_valid_r[2]  = seed_valid2_w;
    sort_valid_r[3]  = seed_valid3_w;
    sort_valid_r[4]  = seed_valid4_w;

    for (sort_i = 0; sort_i < 4; sort_i = sort_i + 1)
    begin
        for (sort_j = 0; sort_j < 4 - sort_i; sort_j = sort_j + 1)
        begin
            if ((sort_weight_r[sort_j + 1] < sort_weight_r[sort_j]) ||
                ((sort_weight_r[sort_j + 1] == sort_weight_r[sort_j]) &&
                 (sort_shift_r[sort_j + 1] < sort_shift_r[sort_j])))
            begin
                tmp_chunk_r               = sort_chunk_r[sort_j];
                tmp_shift_r               = sort_shift_r[sort_j];
                tmp_weight_r              = sort_weight_r[sort_j];
                tmp_valid_r               = sort_valid_r[sort_j];
                sort_chunk_r[sort_j]      = sort_chunk_r[sort_j + 1];
                sort_shift_r[sort_j]      = sort_shift_r[sort_j + 1];
                sort_weight_r[sort_j]     = sort_weight_r[sort_j + 1];
                sort_valid_r[sort_j]      = sort_valid_r[sort_j + 1];
                sort_chunk_r[sort_j + 1]  = tmp_chunk_r;
                sort_shift_r[sort_j + 1]  = tmp_shift_r;
                sort_weight_r[sort_j + 1] = tmp_weight_r;
                sort_valid_r[sort_j + 1]  = tmp_valid_r;
            end
        end
    end

    chunk0_seed_r       = sort_chunk_r[0];
    chunk1_seed_r       = sort_chunk_r[1];
    chunk2_seed_r       = sort_chunk_r[2];
    chunk3_seed_r       = sort_chunk_r[3];
    chunk4_seed_r       = sort_chunk_r[4];
    chunk0_shift_seed_r = sort_shift_r[0];
    chunk1_shift_seed_r = sort_shift_r[1];
    chunk2_shift_seed_r = sort_shift_r[2];
    chunk3_shift_seed_r = sort_shift_r[3];
    chunk4_shift_seed_r = sort_shift_r[4];
    chunk0_valid_seed_r = sort_valid_r[0];
    chunk1_valid_seed_r = sort_valid_r[1];
    chunk2_valid_seed_r = sort_valid_r[2];
    chunk3_valid_seed_r = sort_valid_r[3];
    chunk4_valid_seed_r = sort_valid_r[4];
end

wire       calc0_active_w   = (state_q == MULE5_STATE_CALC0);
wire       calc1_active_w   = (state_q == MULE5_STATE_CALC1);
wire       calc2_active_w   = (state_q == MULE5_STATE_CALC2);
wire       calc3_active_w   = (state_q == MULE5_STATE_CALC3);
wire       calc4_active_w   = (state_q == MULE5_STATE_CALC4);
wire       current_active_w = calc0_active_w | calc1_active_w | calc2_active_w |
                              calc3_active_w | calc4_active_w;
wire [6:0] current_chunk_w  = calc4_active_w ? chunk4_q :
                              calc3_active_w ? chunk3_q :
                              calc2_active_w ? chunk2_q :
                              calc1_active_w ? chunk1_q : chunk0_q;
wire [5:0] current_shift_w  = calc4_active_w ? chunk4_shift_q :
                              calc3_active_w ? chunk3_shift_q :
                              calc2_active_w ? chunk2_shift_q :
                              calc1_active_w ? chunk1_shift_q : chunk0_shift_q;
wire [6:0] gated_chunk_w    = current_active_w ? current_chunk_w : 7'd0;

wire [63:0] pp_w [0:6];
genvar p;
generate
    for (p = 0; p < 7; p = p + 1)
    begin : g_pp
        assign pp_w[p] = gated_chunk_w[p] ? ({32'b0, multiplicand_q} << p) : 64'd0;
    end
endgenerate

wire [63:0] ppm_sum_w   [0:7];
wire [63:0] ppm_carry_w [0:7];
assign ppm_sum_w[0]   = 64'd0;
assign ppm_carry_w[0] = 64'd0;

genvar s;
generate
    for (s = 0; s < 7; s = s + 1)
    begin : g_ppm_reduce
        biriscv_mule5_csa64
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

wire [63:0] chunk_sum_shifted_w   = ppm_sum_w[7]   << current_shift_w;
wire [63:0] chunk_carry_shifted_w = ppm_carry_w[7] << current_shift_w;

wire [63:0] fb_stage1_sum_w;
wire [63:0] fb_stage1_carry_w;
wire [63:0] acc_sum_next_w;
wire [63:0] acc_carry_next_w;

biriscv_mule5_csa64
u_feedback_csa0
(
    .a_i(acc_sum_q),
    .b_i(acc_carry_q),
    .c_i(chunk_sum_shifted_w),
    .sum_o(fb_stage1_sum_w),
    .carry_o(fb_stage1_carry_w)
);

biriscv_mule5_csa64
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
    state_q         <= MULE5_STATE_IDLE;
    valid_q         <= 1'b0;
    sign_q          <= 1'b0;
    rd_idx_q        <= 5'd0;
    multiplicand_q  <= 32'd0;
    chunk0_q        <= 7'd0;
    chunk1_q        <= 7'd0;
    chunk2_q        <= 7'd0;
    chunk3_q        <= 7'd0;
    chunk4_q        <= 7'd0;
    chunk0_shift_q  <= 6'd0;
    chunk1_shift_q  <= 6'd0;
    chunk2_shift_q  <= 6'd0;
    chunk3_shift_q  <= 6'd0;
    chunk4_shift_q  <= 6'd0;
    chunk1_valid_q  <= 1'b0;
    chunk2_valid_q  <= 1'b0;
    chunk3_valid_q  <= 1'b0;
    chunk4_valid_q  <= 1'b0;
    acc_sum_q       <= 64'd0;
    acc_carry_q     <= 64'd0;
    result_q        <= 32'd0;
end
else
begin
    valid_q <= 1'b0;

    case (state_q)
    MULE5_STATE_IDLE:
    begin
        if (seed_valid_w)
        begin
            sign_q         <= sign_seed_w;
            rd_idx_q       <= opcode_rd_idx_i;
            multiplicand_q <= multiplicand_seed_w;
            chunk0_q       <= chunk0_seed_r;
            chunk1_q       <= chunk1_seed_r;
            chunk2_q       <= chunk2_seed_r;
            chunk3_q       <= chunk3_seed_r;
            chunk4_q       <= chunk4_seed_r;
            chunk0_shift_q <= chunk0_shift_seed_r;
            chunk1_shift_q <= chunk1_shift_seed_r;
            chunk2_shift_q <= chunk2_shift_seed_r;
            chunk3_shift_q <= chunk3_shift_seed_r;
            chunk4_shift_q <= chunk4_shift_seed_r;
            chunk1_valid_q <= chunk1_valid_seed_r;
            chunk2_valid_q <= chunk2_valid_seed_r;
            chunk3_valid_q <= chunk3_valid_seed_r;
            chunk4_valid_q <= chunk4_valid_seed_r;
            acc_sum_q      <= 64'd0;
            acc_carry_q    <= 64'd0;

            if ((a_abs_w == 32'd0) || (b_abs_w == 32'd0))
            begin
                result_q <= 32'd0;
                valid_q  <= 1'b1;
            end
            else
                state_q <= MULE5_STATE_CALC0;
        end
    end

    MULE5_STATE_CALC0:
    begin
        if (chunk1_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE5_STATE_CALC1;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE5_STATE_IDLE;
        end
    end

    MULE5_STATE_CALC1:
    begin
        if (chunk2_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE5_STATE_CALC2;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE5_STATE_IDLE;
        end
    end

    MULE5_STATE_CALC2:
    begin
        if (chunk3_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE5_STATE_CALC3;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE5_STATE_IDLE;
        end
    end

    MULE5_STATE_CALC3:
    begin
        if (chunk4_valid_q)
        begin
            acc_sum_q   <= acc_sum_next_w;
            acc_carry_q <= acc_carry_next_w;
            state_q     <= MULE5_STATE_CALC4;
        end
        else
        begin
            result_q <= final_result_w;
            valid_q  <= 1'b1;
            state_q  <= MULE5_STATE_IDLE;
        end
    end

    MULE5_STATE_CALC4:
    begin
        result_q <= final_result_w;
        valid_q  <= 1'b1;
        state_q  <= MULE5_STATE_IDLE;
    end

    default:
        state_q <= MULE5_STATE_IDLE;
    endcase
end

assign writeback_valid_o  = valid_q;
assign writeback_value_o  = result_q;
assign writeback_rd_idx_o = rd_idx_q;

endmodule
