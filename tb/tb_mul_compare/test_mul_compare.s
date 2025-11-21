###############################################################################
# MUL vs MULE comparison test
# Executes both the default MUL and the custom MULE instruction
# and compares their results for operands 7 x 9.
###############################################################################

.section .text
.globl _start

_start:
    j main

.align 8
main:
    li x10, 7            # Operand A
    li x11, 9            # Operand B
    li x15, 63           # Expected product

    nop
    nop

    # Standard MUL (writes into x12)
    mul x12, x10, x11
    nop
    nop
    mv  x14, x12         # Save MUL result

    # Custom MULE instruction (writes result into x13)
    .insn r 0x0B, 0x0, 0x01, x13, x10, x11

    # Allow custom unit to finish
    nop
    nop
    nop
    nop
    nop

    # Compare results
    bne x12, x13, fail_loop
    bne x12, x14, fail_loop
    bne x12, x15, fail_loop

pass_loop:
    j pass_loop

fail_loop:
    j fail_loop
