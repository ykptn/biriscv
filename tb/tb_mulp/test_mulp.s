###############################################################################
# MULP Instruction Test Program
# - Braun full-array 32x32 with slow ripple-style final adder
# - Golden reference derived from baseline MUL
###############################################################################

.section .text
.option norelax
.globl _start

.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134

.equ OP_A, 7
.equ OP_B, 9

_start:
    j main

.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

.align 4
main:
    li   x10, OP_A
    li   x11, OP_B

    mul  x13, x10, x11                      # Golden MUL reference
    .insn r 0x0B, 0x0, 0x02, x12, x10, x11  # MULP custom result

    nop
    nop
    nop
    nop

    beq  x12, x13, pass_loop
    j    fail_loop
