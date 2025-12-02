//-----------------------------------------------------------------
// Column Bypass Multiplier (CBM)
// Sequential 32x32 unsigned multiplier with fixed latency:
//  - Cycle 0: start_i asserted in IDLE to capture operands
//  - Cycles 1..32: process each bit of op_a_i (RUN state)
//  - Cycle 33: DONE state asserts result_valid_o for one cycle
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
    output reg      result_valid_o,
    output reg [31:0] result_o,
    output reg [4:0]  result_rd_idx_o
);

localparam CBM_STATE_IDLE = 2'd0;
localparam CBM_STATE_RUN  = 2'd1;
localparam CBM_STATE_DONE = 2'd2;

reg [1:0]  state_q;
reg [31:0] multiplicand_q;
reg [31:0] multiplier_q;
reg [63:0] accumulator_q;
reg [5:0]  bit_idx_q;
reg [4:0]  rd_idx_q;

assign busy_o = (state_q != CBM_STATE_IDLE);

always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    state_q          <= CBM_STATE_IDLE;
    multiplicand_q   <= 32'b0;
    multiplier_q     <= 32'b0;
    accumulator_q    <= 64'b0;
    bit_idx_q        <= 6'd0;
    rd_idx_q         <= 5'b0;
    result_valid_o   <= 1'b0;
    result_o         <= 32'b0;
    result_rd_idx_o  <= 5'b0;
end
else
begin
    result_valid_o <= 1'b0;

    case (state_q)
    CBM_STATE_IDLE:
    begin
        if (start_i)
        begin
            multiplicand_q <= op_a_i;
            multiplier_q   <= op_b_i;
            accumulator_q  <= 64'd0;
            bit_idx_q      <= 6'd0;
            rd_idx_q       <= rd_idx_i;
            state_q        <= CBM_STATE_RUN;
        end
    end

    CBM_STATE_RUN:
    begin
        if (multiplicand_q[bit_idx_q])
            accumulator_q <= accumulator_q + ({32'b0, multiplier_q} << bit_idx_q);

        bit_idx_q <= bit_idx_q + 1'b1;

        if (bit_idx_q == 6'd31)
            state_q <= CBM_STATE_DONE;
    end

    CBM_STATE_DONE:
    begin
        result_valid_o   <= 1'b1;
        result_o         <= accumulator_q[31:0];
        result_rd_idx_o  <= rd_idx_q;
        state_q          <= CBM_STATE_IDLE;
    end

    default:
        state_q <= CBM_STATE_IDLE;
    endcase
end

endmodule
