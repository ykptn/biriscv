//-----------------------------------------------------------------
// Column Bypass Multiplier (CBM)
//
// Sequential 32-bit unsigned multiplier. Only columns (bits of op_a_i)
// that are logic 1 are processed, allowing latency and switching to
// track operand sparsity. Compared to the fixed-latency shift-add
// implementation, this design keeps a mask of outstanding columns and
// uses a lowest-set-bit encoder so that zero columns never reach the
// partial-product shifter or adder.
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
reg [63:0] accumulator_q, accumulator_d;
reg [4:0]  rd_idx_q, rd_idx_d;
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

wire columns_empty_q     = (column_mask_q == 32'd0);
wire [5:0] active_col_idx_w = lowest_index(column_mask_q);
wire process_column_w    = (state_q == CBM_STATE_RUN) && !columns_empty_q;
wire [31:0] active_col_mask_w = 32'h1 << active_col_idx_w;
wire [63:0] shifted_multiplicand_w =
    {32'b0, multiplicand_q} << active_col_idx_w;
wire [31:0] column_mask_after_w =
    process_column_w ? (column_mask_q & ~active_col_mask_w) : column_mask_q;
wire columns_empty_after_w = (column_mask_after_w == 32'd0);

always @ (*) begin
    state_d           = state_q;
    multiplicand_d    = multiplicand_q;
    column_mask_d     = column_mask_q;
    accumulator_d     = accumulator_q;
    rd_idx_d          = rd_idx_q;
    done_d            = 1'b0;
    result_d          = result_q;
    result_rd_idx_d   = result_rd_idx_q;

    case (state_q)
    CBM_STATE_IDLE:
    begin
        if (start_i)
        begin
            multiplicand_d  = op_b_i;
            column_mask_d   = op_a_i;
            accumulator_d   = 64'd0;
            rd_idx_d        = rd_idx_i;
            state_d         = (op_a_i == 32'd0) ? CBM_STATE_DONE : CBM_STATE_RUN;
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
        result_d          = accumulator_q[31:0];
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
        accumulator_q     <= 64'd0;
        rd_idx_q          <= 5'd0;
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
        done_q            <= done_d;
        result_q          <= result_d;
        result_rd_idx_q   <= result_rd_idx_d;
    end
end

endmodule
