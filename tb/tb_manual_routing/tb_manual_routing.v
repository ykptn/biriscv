`include "biriscv_defs.v"

// ─────────────────────────────────────────────────────────────────────────────
// Manual mul/mule routing testbench
//
// Pass/fail reporting mirrors the rest of the benchmark suite:
//   - PC 0x80000130  →  PASS  (main() returned 0)
//   - PC 0x80000134  →  FAIL  (main() returned non-zero)
//   - Timeout after TIMEOUT_CYCLES  →  FAIL
//
// The simulation prints at finish:
//   sim_total_cycles, retired_total_instructions,
//   retired_plain_mul, retired_mule
// ─────────────────────────────────────────────────────────────────────────────

module tb_manual_routing;

reg clk;
reg rst;

localparam PASS_PC        = 32'h80000130;
localparam FAIL_PC        = 32'h80000134;
localparam TIMEOUT_CYCLES = 64'd250_000;

// ── load firmware ─────────────────────────────────────────────────────────────
reg [7:0] mem [131072:0];
integer   i, f;

initial begin
    $display("tb_manual_routing: loading firmware");

    if (`TRACE_VCD) begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_manual_routing);
    end

    clk = 0;
    rst = 1;

    // Load firmware before releasing reset so the CPU starts in a clean state
    for (i = 0; i < 131072; i = i+1)
        mem[i] = 8'h00;

    f = $fopenr("tcm.bin");
    i = $fread(mem, f);
    $display("Loaded %0d bytes", i);
    for (i = 0; i < 131072; i = i+1)
        u_mem.write(i, mem[i]);

    // Hold reset a few more cycles then let the CPU run
    repeat (5) @(posedge clk);
    rst = 0;
end


// ── counters ──────────────────────────────────────────────────────────────────
reg [63:0] cycle_count;
reg [63:0] retired_total;
reg [63:0] retired_plain_mul;
reg [63:0] retired_mule;
reg        pass_reported;
reg        fail_reported;

// ── wire connections from DUT ─────────────────────────────────────────────────
wire        pipe0_retire_w  = u_dut.u_issue.pipe0_valid_wb_w;
wire        pipe1_retire_w  = u_dut.u_issue.pipe1_valid_wb_w;
wire [31:0] pipe0_pc_w      = u_dut.u_issue.pipe0_pc_wb_w;
wire [31:0] pipe1_pc_w      = u_dut.u_issue.pipe1_pc_wb_w;
wire [31:0] pipe0_opc_w     = u_dut.u_issue.pipe0_opc_wb_w;
wire [31:0] pipe1_opc_w     = u_dut.u_issue.pipe1_opc_wb_w;
wire [31:0] mem_i_pc_w;

function is_plain_mul;  input [31:0] opc; is_plain_mul = ((opc & `INST_MUL_MASK)  == `INST_MUL);  endfunction
function is_mule;       input [31:0] opc; is_mule      = ((opc & `INST_MULE_MASK) == `INST_MULE); endfunction

wire [1:0] retire_count_w =
    {1'b0, pipe0_retire_w} + {1'b0, pipe1_retire_w};
wire [1:0] mul_count_w =
    {1'b0, pipe0_retire_w & is_plain_mul(pipe0_opc_w)} +
    {1'b0, pipe1_retire_w & is_plain_mul(pipe1_opc_w)};
wire [1:0] mule_count_w =
    {1'b0, pipe0_retire_w & is_mule(pipe0_opc_w)} +
    {1'b0, pipe1_retire_w & is_mule(pipe1_opc_w)};

// ── simulation control ────────────────────────────────────────────────────────
initial begin
    cycle_count    = 0;
    retired_total  = 0;
    retired_plain_mul = 0;
    retired_mule   = 0;
    pass_reported  = 1'b0;
    fail_reported  = 1'b0;
end

task report;
begin
    $display("");
    $display("sim_total_cycles              = %0d", cycle_count);
    $display("retired_total_instructions    = %0d", retired_total);
    $display("retired_plain_mul             = %0d", retired_plain_mul);
    $display("retired_mule                  = %0d", retired_mule);
end
endtask

always @(posedge clk) begin
    if (rst) begin
        cycle_count    <= 0;
        retired_total  <= 0;
        retired_plain_mul <= 0;
        retired_mule   <= 0;
        pass_reported  <= 0;
        fail_reported  <= 0;
    end else begin
        cycle_count    <= cycle_count + 1;
        retired_total  <= retired_total + retire_count_w;
        retired_plain_mul <= retired_plain_mul + mul_count_w;
        retired_mule   <= retired_mule + mule_count_w;

        if (`TRACE) begin
            if (pipe0_retire_w)
                $display("retire slot=0 cycle=%0d pc=0x%08h opc=0x%08h",
                         cycle_count, pipe0_pc_w, pipe0_opc_w);
            if (pipe1_retire_w)
                $display("retire slot=1 cycle=%0d pc=0x%08h opc=0x%08h",
                         cycle_count, pipe1_pc_w, pipe1_opc_w);
        end

        if (!pass_reported && mem_i_pc_w == PASS_PC) begin
            pass_reported <= 1'b1;
            $display("*** PASS ***");
            report;
            $finish;
        end else if (!fail_reported && mem_i_pc_w == FAIL_PC) begin
            fail_reported <= 1'b1;
            $display("*** FAIL ***");
            report;
            $finish;
        end else if (cycle_count >= TIMEOUT_CYCLES && !pass_reported && !fail_reported) begin
            fail_reported <= 1'b1;
            $display("*** TIMEOUT after %0d cycles ***", cycle_count);
            report;
            $finish;
        end
    end
end

initial forever clk = #5 ~clk;

// ── DUT wiring ────────────────────────────────────────────────────────────────
wire          mem_i_rd_w;
wire          mem_i_flush_w;
wire          mem_i_invalidate_w;
wire [ 31:0]  mem_d_addr_w;
wire [ 31:0]  mem_d_data_wr_w;
wire          mem_d_rd_w;
wire [  3:0]  mem_d_wr_w;
wire          mem_d_cacheable_w;
wire [ 10:0]  mem_d_req_tag_w;
wire          mem_d_invalidate_w;
wire          mem_d_writeback_w;
wire          mem_d_flush_w;
wire          mem_i_accept_w;
wire          mem_i_valid_w;
wire          mem_i_error_w;
wire [ 63:0]  mem_i_inst_w;
wire [ 31:0]  mem_d_data_rd_w;
wire          mem_d_accept_w;
wire          mem_d_ack_w;
wire          mem_d_error_w;
wire [ 10:0]  mem_d_resp_tag_w;

riscv_core u_dut (
     .clk_i(clk)
    ,.rst_i(rst)

    ,.reset_vector_i(32'h80000000)

    ,.mem_i_rd_o(mem_i_rd_w)
    ,.mem_i_flush_o(mem_i_flush_w)
    ,.mem_i_invalidate_o(mem_i_invalidate_w)
    ,.mem_i_pc_o(mem_i_pc_w)

    ,.mem_d_addr_o(mem_d_addr_w)
    ,.mem_d_data_wr_o(mem_d_data_wr_w)
    ,.mem_d_rd_o(mem_d_rd_w)
    ,.mem_d_wr_o(mem_d_wr_w)
    ,.mem_d_cacheable_o(mem_d_cacheable_w)
    ,.mem_d_req_tag_o(mem_d_req_tag_w)
    ,.mem_d_invalidate_o(mem_d_invalidate_w)
    ,.mem_d_writeback_o(mem_d_writeback_w)
    ,.mem_d_flush_o(mem_d_flush_w)

    ,.mem_i_accept_i(mem_i_accept_w)
    ,.mem_i_valid_i(mem_i_valid_w)
    ,.mem_i_error_i(mem_i_error_w)
    ,.mem_i_inst_i(mem_i_inst_w)

    ,.mem_d_data_rd_i(mem_d_data_rd_w)
    ,.mem_d_accept_i(mem_d_accept_w)
    ,.mem_d_ack_i(mem_d_ack_w)
    ,.mem_d_error_i(mem_d_error_w)
    ,.mem_d_resp_tag_i(mem_d_resp_tag_w)
);

tcm_mem u_mem (
     .clk_i(clk)
    ,.rst_i(rst)

    ,.mem_i_rd_i(mem_i_rd_w)
    ,.mem_i_flush_i(mem_i_flush_w)
    ,.mem_i_invalidate_i(mem_i_invalidate_w)
    ,.mem_i_pc_i(mem_i_pc_w)
    ,.mem_i_accept_o(mem_i_accept_w)
    ,.mem_i_valid_o(mem_i_valid_w)
    ,.mem_i_error_o(mem_i_error_w)
    ,.mem_i_inst_o(mem_i_inst_w)

    ,.mem_d_addr_i(mem_d_addr_w)
    ,.mem_d_data_wr_i(mem_d_data_wr_w)
    ,.mem_d_rd_i(mem_d_rd_w)
    ,.mem_d_wr_i(mem_d_wr_w)
    ,.mem_d_cacheable_i(mem_d_cacheable_w)
    ,.mem_d_req_tag_i(mem_d_req_tag_w)
    ,.mem_d_invalidate_i(mem_d_invalidate_w)
    ,.mem_d_writeback_i(mem_d_writeback_w)
    ,.mem_d_flush_i(mem_d_flush_w)
    ,.mem_d_data_rd_o(mem_d_data_rd_w)
    ,.mem_d_accept_o(mem_d_accept_w)
    ,.mem_d_ack_o(mem_d_ack_w)
    ,.mem_d_error_o(mem_d_error_w)
    ,.mem_d_resp_tag_o(mem_d_resp_tag_w)
);

endmodule
