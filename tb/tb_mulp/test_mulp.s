###############################################################################
# MULP Instruction Test Program
# Tests the deep-pipelined MULP custom instruction
#
# MULP encoding: funct7=0x01, funct3=0x1, opcode=0x0B (custom-0)
# Test: Multiply 7 × 9 and verify result is 63
# Expected: PC reaches pass_loop at 0x80000154
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
    # Deep-Pipelined MULP instruction (custom-0)
    #
    # Encoding: 0x02B5160B
    #
    #   funct7 = 0x01      (0000001)
    #   rs2    = x11       (01011)
    #   rs1    = x10       (01010)
    #   funct3 = 0x1       (001)
    #   rd     = x12       (01100)
    #   opcode = 0x0B      (0001011)  custom-0
    #
    ###########################################################################
    .word 0x02B5160B     # mulp x12, x10, x11

    # Insert extra NOPs to allow 6-stage pipeline writeback
    nop
    nop
    nop
    nop
    nop
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
    j pass_loop          # PC = 0x80000144

fail_loop:
    j fail_loop          # PC = 0x80000148
