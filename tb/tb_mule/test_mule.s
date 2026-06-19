###############################################################################
# MULE Instruction Test Program
# - Includes an aligned slot0/slot1 pair to force pipe1 custom dispatch
###############################################################################

.section .text
.option norelax
.globl _start

.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134

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
    # Case 1: force custom MULE into slot1 / pipe1 while slot0 does ALU work.
    li   x10, 7
    li   x11, 9
    mul  x13, x10, x11
    .align 3
    addi x14, x0, 5
    .insn r 0x0B, 0x0, 0x01, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop
    li   x18, 5
    bne  x14, x18, fail_loop

    # Case 2: negative x positive
    li   x10, -7
    li   x11, 9
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x01, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    beq  x12, x13, pass_loop
    j    fail_loop
