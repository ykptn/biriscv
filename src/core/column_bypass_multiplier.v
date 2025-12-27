//-----------------------------------------------------------------
// Column Bypass Multiplier (CBM)
//
// Sequential 32-bit multiplier with column-bypass. To maximize energy
// efficiency, the operand with fewer set bits becomes the column mask,
// and absolute values are used to make signed operands sparse when
// possible. The final result is sign-corrected to match MUL/MULE
// semantics (low 32 bits of signed product).
//-----------------------------------------------------------------
module column_bypass_multiplier
(
    input           clk_i,
    input           rst_i,

    input           start_i,
    input  [31:0]   op_a_i,
    input  [31:0]   op_b_i,
    input  [4:0]    rd_idx_i,

    output          busy_o,
    output          done_o,
    output [31:0]   result_o,
    output [4:0]    result_rd_idx_o
);

localparam CBM_STATE_IDLE = 2'd0;
localparam CBM_STATE_RUN  = 2'd1;
localparam CBM_STATE_DONE = 2'd2;

reg [1:0]  state_q, state_d;
reg [31:0] multiplicand_q, multiplicand_d;   // op_b_i
reg [31:0] column_mask_q, column_mask_d;     // remaining op_a_i bits
reg [31:0] accumulator_q, accumulator_d;     // Reduced from 64 to 32 bits for energy efficiency
reg [4:0]  rd_idx_q, rd_idx_d;
reg        sign_q, sign_d;
reg        done_q, done_d;
reg [31:0] result_q, result_d;
reg [4:0]  result_rd_idx_q, result_rd_idx_d;

assign busy_o            = (state_q == CBM_STATE_RUN);
assign done_o            = done_q;
assign result_o          = result_q;
assign result_rd_idx_o   = result_rd_idx_q;

// Lowest set-bit encoder enables us to skip zero columns entirely.
function automatic [5:0] lowest_index(input [31:0] value);
    integer idx;
begin
    lowest_index = 6'd0;
    begin : lsb_scan
        for (idx = 0; idx < 32; idx = idx + 1)
        begin
            if (value[idx])
            begin
                lowest_index = idx[5:0];
                disable lsb_scan;
            end
        end
    end
end
endfunction

// Popcount used to pick the sparsest operand as the column mask.
function automatic [5:0] popcount32(input [31:0] value);
    integer idx;
begin
    popcount32 = 6'd0;
    for (idx = 0; idx < 32; idx = idx + 1)
        popcount32 = popcount32 + value[idx];
end
endfunction

wire        seed_valid_w = (state_q == CBM_STATE_IDLE) && start_i;
wire [31:0] op_a_seed_w = seed_valid_w ? op_a_i : 32'd0;
wire [31:0] op_b_seed_w = seed_valid_w ? op_b_i : 32'd0;
wire        op_a_neg_w = op_a_seed_w[31];
wire        op_b_neg_w = op_b_seed_w[31];
wire [31:0] op_a_abs_w = op_a_neg_w ? (~op_a_seed_w + 32'd1) : op_a_seed_w;
wire [31:0] op_b_abs_w = op_b_neg_w ? (~op_b_seed_w + 32'd1) : op_b_seed_w;
wire [5:0]  popcnt_a_w = popcount32(op_a_abs_w);
wire [5:0]  popcnt_b_w = popcount32(op_b_abs_w);
wire        use_a_as_mask_w = (popcnt_a_w <= popcnt_b_w);
wire [31:0] mask_seed_w = use_a_as_mask_w ? op_a_abs_w : op_b_abs_w;
wire [31:0] multiplicand_seed_w = use_a_as_mask_w ? op_b_abs_w : op_a_abs_w;
wire        sign_seed_w = op_a_neg_w ^ op_b_neg_w;

wire columns_empty_q     = (column_mask_q == 32'd0);
wire [5:0] active_col_idx_w = lowest_index(column_mask_q);
wire process_column_w    = (state_q == CBM_STATE_RUN) && !columns_empty_q;
wire [31:0] active_col_mask_w = 32'h1 << active_col_idx_w;
// Energy optimization: compute only the 32-bit partial product needed
wire [31:0] shifted_multiplicand_w = multiplicand_q << active_col_idx_w;
wire [31:0] column_mask_after_w =
    process_column_w ? (column_mask_q & ~active_col_mask_w) : column_mask_q;
wire columns_empty_after_w = (column_mask_after_w == 32'd0);

always @ (*) begin
    state_d           = state_q;
    multiplicand_d    = multiplicand_q;
    column_mask_d     = column_mask_q;
    accumulator_d     = accumulator_q;
    rd_idx_d          = rd_idx_q;
    sign_d            = sign_q;
    done_d            = 1'b0;
    result_d          = result_q;
    result_rd_idx_d   = result_rd_idx_q;

    case (state_q)
    CBM_STATE_IDLE:
    begin
        if (start_i)
        begin
            multiplicand_d  = multiplicand_seed_w;
            column_mask_d   = mask_seed_w;
            accumulator_d   = 32'd0;
            rd_idx_d        = rd_idx_i;
            sign_d          = sign_seed_w;
            state_d         = ((mask_seed_w == 32'd0) || (multiplicand_seed_w == 32'd0)) ?
                              CBM_STATE_DONE : CBM_STATE_RUN;
        end
    end

    CBM_STATE_RUN:
    begin
        if (process_column_w)
        begin
            accumulator_d = accumulator_q + shifted_multiplicand_w;
            column_mask_d = column_mask_after_w;
        end

        if (columns_empty_after_w)
            state_d = CBM_STATE_DONE;
    end

    CBM_STATE_DONE:
    begin
        done_d            = 1'b1;
        result_d          = sign_q ? (~accumulator_q + 32'd1) : accumulator_q;
        result_rd_idx_d   = rd_idx_q;
        state_d           = CBM_STATE_IDLE;
    end

    default:
        state_d = CBM_STATE_IDLE;
    endcase
end

always @ (posedge clk_i or posedge rst_i)
begin
    if (rst_i)
    begin
        state_q           <= CBM_STATE_IDLE;
        multiplicand_q    <= 32'd0;
        column_mask_q     <= 32'd0;
        accumulator_q     <= 32'd0;
        rd_idx_q          <= 5'd0;
        sign_q            <= 1'b0;
        done_q            <= 1'b0;
        result_q          <= 32'd0;
        result_rd_idx_q   <= 5'd0;
    end
    else
    begin
        state_q           <= state_d;
        multiplicand_q    <= multiplicand_d;
        column_mask_q     <= column_mask_d;
        accumulator_q     <= accumulator_d;
        rd_idx_q          <= rd_idx_d;
        sign_q            <= sign_d;
        done_q            <= done_d;
        result_q          <= result_d;
        result_rd_idx_q   <= result_rd_idx_d;
    end
end

endmodule
