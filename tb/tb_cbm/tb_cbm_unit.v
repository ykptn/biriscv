`timescale 1ns / 1ps

module tb_cbm_unit;

// Configuration knobs
localparam DO_USER_VECTOR      = 1;
localparam [31:0] USER_OP_A    = 32'sd7;
localparam [31:0] USER_OP_B    = 32'sd9;
localparam DO_PRESET_VECTORS   = 0;
localparam NUM_RANDOM_TESTS    = 0;

reg clk;
reg rst;
reg start;
reg [31:0] op_a;
reg [31:0] op_b;
wire busy;
wire done;
wire [31:0] cbm_result;

column_bypass_multiplier u_cbm (
    .clk_i(clk),
    .rst_i(rst),
    .start_i(start),
    .op_a_i(op_a),
    .op_b_i(op_b),
    .rd_idx_i(5'd0),
    .busy_o(busy),
    .done_o(done),
    .result_o(cbm_result),
    .result_rd_idx_o()
);

integer vector_idx;
integer failure_count;

integer total_vectors;

initial begin
    $dumpfile("cbm_compare.vcd");
    $dumpvars(0, tb_cbm_unit);

    clk           = 1'b0;
    rst           = 1'b1;
    start         = 1'b0;
    op_a          = 32'd0;
    op_b          = 32'd0;
    failure_count = 0;

    total_vectors = 0;

    repeat (5) @(posedge clk);
    rst = 1'b0;

    if (DO_USER_VECTOR) begin
        $display("\nRunning user-specified CBM vector (a=%0d, b=%0d)\n",
                 USER_OP_A, USER_OP_B);
        run_vector(USER_OP_A, USER_OP_B);
        total_vectors = total_vectors + 1;
    end

    if (DO_PRESET_VECTORS) begin
        run_vector(32'd0, 32'd12345);
        run_vector(32'hFFFF0000, 32'd3);
        run_vector(32'h8000_0000, 32'd7);
        run_vector(32'h0000_0001, 32'hDEADBEEF);
        total_vectors = total_vectors + 4;
    end

    if (NUM_RANDOM_TESTS > 0) begin
        for (vector_idx = 0; vector_idx < NUM_RANDOM_TESTS; vector_idx = vector_idx + 1) begin
            run_vector($urandom, $urandom);
        end
        total_vectors = total_vectors + NUM_RANDOM_TESTS;
    end

    if (failure_count == 0)
        $display("\nAll %0d CBM comparisons against standard MUL passed.", total_vectors);
    else
        $display("\nCompleted with %0d mismatch(es).", failure_count);

    $finish;
end

task run_vector(input [31:0] a, input [31:0] b);
    integer active_bits;
    integer busy_cycles;
    reg [63:0] expected_full;
begin
    expected_full = a * b;
    active_bits   = popcount(a);

    wait (!busy);
    @(posedge clk);
    op_a  <= a;
    op_b  <= b;
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    busy_cycles = 0;

    while (!done) begin
        @(posedge clk);
        if (busy)
            busy_cycles = busy_cycles + 1;
    end

    if (cbm_result !== expected_full[31:0]) begin
        $display("Result mismatch: a=0x%08h b=0x%08h CBM=0x%08h expected=0x%08h",
                 a, b, cbm_result, expected_full[31:0]);
        failure_count = failure_count + 1;
    end

    if (busy_cycles !== active_bits) begin
        $display("Latency mismatch: a=0x%08h b=0x%08h active_bits=%0d busy_cycles=%0d",
                 a, b, active_bits, busy_cycles);
    end

    $display("CBM vector: a=0x%08h b=0x%08h active_bits=%0d busy_cycles=%0d result=0x%08h",
             a, b, active_bits, busy_cycles, cbm_result);
end
endtask

function integer popcount(input [31:0] value);
    integer idx;
begin
    popcount = 0;
    for (idx = 0; idx < 32; idx = idx + 1)
        if (value[idx])
            popcount = popcount + 1;
end
endfunction

always #5 clk = ~clk;

endmodule
