###############################################################################
# MULE2N Instruction Test Program
# - Non-blocking custom multiplier regression
# - Confirms baseline MUL match and independent ALU forward progress
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
    li   x10, 0x00010007
    li   x11, 0x00010009

    # Golden reference on standard pipelined MUL
    mul  x13, x10, x11

    # Force MULE2N into slot1 / pipe1 while slot0 performs ALU work.
    .align 3
    addi x14, x0, 5

    # MULE2N: funct7=13, funct3=0, opcode=custom-0
    .insn r 0x0B, 0x0, 0x0D, x12, x10, x11

    # Independent ALU work must keep moving while MULE2N is pending.
    addi x15, x14, 3
    xori x16, x15, 7
    addi x17, x16, 1

    # Give MULE2N enough time to complete before final compare.
    nop
    nop
    nop
    nop
    nop
    nop

    bne  x12, x13, fail_loop

    li   x18, 8
    bne  x15, x18, fail_loop
    li   x18, 15
    bne  x16, x18, fail_loop
    li   x18, 16
    bne  x17, x18, fail_loop

    beq  x12, x13, pass_loop
    j    fail_loop
