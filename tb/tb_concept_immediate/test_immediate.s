###############################################################################
# Concept Test: Immediate MUL vs MULE result use
#
# This focuses on back-to-back dependency:
# - MUL and MULE compute a product.
# - The very next instruction consumes the result.
# - We measure cycles for MUL (delta_mul) and MULE (delta_mule) via CSR cycle.
# Expectation: delta_mule > delta_mul, and both results equal 40.
###############################################################################

.section .text
.globl _start

_start:
    j main

.align 8
main:
    # Initialize operands for multiplication
    li x10, 5           # a0 = 5
    li x11, 8           # a1 = 8

    ###########################################################################
    # MUL: back-to-back consumer
    ###########################################################################
    csrr x5, cycle
    # mul x12, x10, x11       # x12 = 40
    .insn r 0x0B, 0x0, 0x01, x12, x10, x11
    add x13, x12, x0        # immediate consumer
    csrr x6, cycle
    sub x7, x6, x5          # delta_mul

    ###########################################################################
    # MULE (custom): back-to-back consumer
    ###########################################################################
    csrr x8, cycle
    .insn r 0x0B, 0x0, 0x01, x12, x10, x11
    add x14, x12, x0        # immediate consumer
    csrr x9, cycle
    sub x4, x9, x8          # delta_mule

    ###########################################################################
    # Correctness checks
    ###########################################################################
    li x2, 40
    bne x13, x2, fail_loop
    bne x14, x2, fail_loop

    # Latency expectation: MULE should take more cycles than MUL
    ble x4, x7, fail_loop
    
###############################################################################
# PASS/FAIL LOOPS
###############################################################################

pass_loop:
    j pass_loop          # Test passed

fail_loop:
    j fail_loop          # Test failed
