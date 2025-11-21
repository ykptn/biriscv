###############################################################################
# MUL vs MULE comparison test
###############################################################################

.section .text
.globl _start

_start:
    j main

.align 8
main:
    li x10, 7            # operand A
    li x11, 9            # operand B
    li x14, 63           # expected product

    nop
    nop

    # Standard MUL -> x12
    mul x12, x10, x11

    # Custom MULE instruction (writes into x13)
    .insn r 0x0B, 0x0, 0x01, x13, x10, x11

wait_loop:
    beq x12, x0, wait_loop
    beq x13, x0, wait_loop
    bne x12, x13, wait_loop

pass_loop:
    j pass_loop

fail_loop:
    j fail_loop
