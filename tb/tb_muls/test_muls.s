###############################################################################
# MULS Instruction Test Program
# Tests the custom MULS instruction (default MUL logic)
#
# Test: Multiply 7 × 9 and verify result is 63
# Expected: PC reaches pass_loop at 0x8000012C
###############################################################################

.section .text
.globl _start

_start:
    # Jump to main to avoid initial RAM read latency
    j main

# Align to 8-byte boundary for biRISC-V dual-issue fetch bundles
.align 8

main:
    # Test case: 7 × 9 = 63
    li x10, 7           # a0 = 7
    li x11, 9           # a1 = 9
    li x13, 63          # a3 = expected result

    nop
    nop

    ###########################################################################
    # Custom MULS instruction
    #
    # Encoding: 0x04B5060B
    #
    #   funct7 = 0x02
    #   rs2    = x11
    #   rs1    = x10
    #   funct3 = 0x0
    #   rd     = x12
    #   opcode = 0x0B   (custom-0)
    #
    ###########################################################################
    .word 0x04B5060B     # muls x12, x10, x11

    # Insert NOPs to allow writeback
    nop
    nop
    nop
    nop
    nop

    # Compare actual result (x12) with expected (x13)
    bne x12, x13, fail_loop

###############################################################################
# PASS/FAIL LOOPS
###############################################################################

pass_loop:
    j pass_loop          # PC = 0x8000012C

fail_loop:
    j fail_loop          # PC = 0x80000130
