###############################################################################
# MULE3 Instruction Test Program
# - Directed regression over multiple operand pairs
# - Golden reference derived from baseline MUL
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
    # Case 1: aligned slot0/slot1 pair, forcing MULE3 onto pipe1
    li   x10, 7
    li   x11, 9
    mul  x13, x10, x11
    .align 3
    addi x14, x0, 5
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
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
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 3: negative x negative
    li   x10, -13
    li   x11, -11
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 4: zero bypass path
    li   x10, 0
    li   x11, 12345
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 5: INT_MIN x 1
    lui  x10, 0x80000
    li   x11, 1
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 6: dense bit-pattern operands
    li   x10, -1
    lui  x11, 0x12345
    addi x11, x11, 0x678
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 7: upper-half-only chunk, exercises single folded cycle after reordering
    lui  x10, 0x12340
    li   x11, 3
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 8: sparse-vs-dense operand pair, exercises chunk-operand selection
    li   x10, 0x10001
    li   x11, -1
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 9: all three 11-bit folded chunks active in the selected operand
    li   x10, 0x00400801
    li   x11, 0x00E00C03
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    # Case 10: upper folded chunk only
    li   x10, 0x40000000
    li   x11, -5
    mul  x13, x10, x11
    .insn r 0x0B, 0x0, 0x0A, x12, x10, x11
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    bne  x12, x13, fail_loop

    beq  x12, x13, pass_loop
    j    fail_loop
