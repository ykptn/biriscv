###############################################################################
# MULE Custom Instruction Test Program
# Tests the custom mule (fast multiply) instruction implementation
# 
# Test: Multiply 7 × 9 and verify result is 63
# Expected: PC reaches pass_loop at 0x8000012C
###############################################################################

.section .text
.globl _start

_start:
    # Jump to main to skip over potential RAM fetch latency issues
    # The synchronous RAM has 1-cycle read latency which can affect
    # the first few instruction fetches
    j main
    
# Align to 8-byte boundary for the dual-issue pipeline
# The biRISC-V core fetches 64-bit instruction bundles
.align 8

main:
    # Test case: 7 × 9 = 63
    li x10, 7           # a0 = 7 (first operand)
    li x11, 9           # a1 = 9 (second operand)
    li x13, 63          # a3 = 63 (expected result)
    
    # Ensure operands are ready before MULE
    nop
    nop
    
    ###########################################################################
    # Custom MULE instruction
    # Encoding: 0x02B5060B
    # 
    # Bit fields:
    #   [31:25] funct7 = 0x01 (0000001)
    #   [24:20] rs2    = 0x0B (x11/a1)
    #   [19:15] rs1    = 0x0A (x10/a0)
    #   [14:12] funct3 = 0x0
    #   [11:7]  rd     = 0x0C (x12/a2)
    #   [6:0]   opcode = 0x0B (custom-0)
    #
    # Operation: x12 = x10 * x11 (multi-cycle)
    # FSM: IDLE(0) → CALC0(1) → CALC1(2) → CALC2(3) → DONE(4) → IDLE(0)
    # Latency: 5 cycles
    ###########################################################################
    .word 0x02B5060B    # mule x12, x10, x11
    
    # Insert NOPs to allow the multi-cycle mule to complete
    # The mule instruction takes 5 cycles to execute:
    #   Cycle 1 (CALC0): Compute A_low × B_low → p0
    #   Cycle 2 (CALC1): Compute A_low × B_high → p1  
    #   Cycle 3 (CALC2): Compute A_high × B_low → p2
    #   Cycle 4 (DONE):  Combine partial products → result
    #   Cycle 5 (IDLE):  Assert writeback_valid
    nop
    nop
    nop
    nop
    nop
    
    # Compare actual result (x12) with expected (x13)
    bne x12, x13, fail_loop
    
###############################################################################
# Test result loops
###############################################################################

pass_loop:
    # Test PASSED: x12 contains correct result (63)
    # Simulator monitors PC and exits with success when reaching 0x8000012C
    j pass_loop         # Infinite loop at 0x8000012C
    
fail_loop:
    # Test FAILED: x12 does not match expected value
    # Simulator monitors PC and exits with failure when reaching 0x80000130
    j fail_loop         # Infinite loop at 0x80000130

###############################################################################
# Notes:
# 
# 1. Memory Layout:
#    0x80000000: _start (jump to main)
#    0x80000100: main (test code)
#    0x8000012C: pass_loop
#    0x80000130: fail_loop
#
# 2. MULE Implementation:
#    - Uses 16×16 multiplier building block
#    - Computes 32-bit result via 3 partial products:
#      Result = (A[15:0] × B[15:0]) + 
#               (A[15:0] × B[31:16]) << 16 +
#               (A[31:16] × B[15:0]) << 16
#    - For small operands like 7 and 9, only p0 is non-zero
#
# 3. Pipeline Considerations:
#    - biRISC-V is dual-issue superscalar (can issue 2 instructions/cycle)
#    - MULE stalls the pipeline until completion
#    - NOPs ensure dependent instructions don't execute prematurely
#
# 4. Testbench Monitoring:
#    - Tracks FSM state transitions
#    - Monitors partial products (p0, p1, p2)
#    - Verifies writeback signals (valid, value)
#    - Checks final register values
###############################################################################
