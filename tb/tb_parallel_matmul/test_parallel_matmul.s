###############################################################################
# Parallel Matrix Multiply - FULLY UNROLLED for dual MUL issue
# 4x4 C = A x B, column loop unrolled, repeated 20 times for VCD trace
###############################################################################
.section .text
.align 4
.globl _start

.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134
.equ MATRIX_EXPECTED, 4304
.equ REPEAT_COUNT, 20

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
    li   x30, REPEAT_COUNT

.p2align 3
repeat_loop:
    beqz x30, done_all
    addi x30, x30, -1
    la   x8,  matrix_a
    la   x9,  matrix_b
    la   x4,  matrix_c
    li   x29, 0
    li   x23, 0

.p2align 3
row_loop:
    li   x5, 4
    bge  x23, x5, row_done

    # Load A[i][0..3]
    slli x5, x23, 4
    add  x5, x8, x5
    lw   x10, 0(x5)
    lw   x11, 4(x5)
    lw   x12, 8(x5)
    lw   x13, 12(x5)

    #===== Column j=0 ========================================================
    lw   x14, 0(x9)
    lw   x15, 16(x9)
    lw   x16, 32(x9)
    lw   x17, 48(x9)
    nop
    nop
    .p2align 3
    mul  x18, x10, x14
    mul  x19, x11, x15
    mul  x20, x12, x16
    mul  x21, x13, x17
    nop
    nop
    add  x22, x18, x19
    add  x22, x22, x20
    add  x22, x22, x21
    slli x5, x23, 4
    add  x5, x4, x5
    sw   x22, 0(x5)
    add  x29, x29, x22

    #===== Column j=1 ========================================================
    lw   x14, 4(x9)
    lw   x15, 20(x9)
    lw   x16, 36(x9)
    lw   x17, 52(x9)
    nop
    nop
    .p2align 3
    mul  x18, x10, x14
    mul  x19, x11, x15
    mul  x20, x12, x16
    mul  x21, x13, x17
    nop
    nop
    add  x22, x18, x19
    add  x22, x22, x20
    add  x22, x22, x21
    slli x5, x23, 4
    add  x5, x4, x5
    sw   x22, 4(x5)
    add  x29, x29, x22

    #===== Column j=2 ========================================================
    lw   x14, 8(x9)
    lw   x15, 24(x9)
    lw   x16, 40(x9)
    lw   x17, 56(x9)
    nop
    nop
    .p2align 3
    mul  x18, x10, x14
    mul  x19, x11, x15
    mul  x20, x12, x16
    mul  x21, x13, x17
    nop
    nop
    add  x22, x18, x19
    add  x22, x22, x20
    add  x22, x22, x21
    slli x5, x23, 4
    add  x5, x4, x5
    sw   x22, 8(x5)
    add  x29, x29, x22

    #===== Column j=3 ========================================================
    lw   x14, 12(x9)
    lw   x15, 28(x9)
    lw   x16, 44(x9)
    lw   x17, 60(x9)
    nop
    nop
    .p2align 3
    mul  x18, x10, x14
    mul  x19, x11, x15
    mul  x20, x12, x16
    mul  x21, x13, x17
    nop
    nop
    add  x22, x18, x19
    add  x22, x22, x20
    add  x22, x22, x21
    slli x5, x23, 4
    add  x5, x4, x5
    sw   x22, 12(x5)
    add  x29, x29, x22

    addi x23, x23, 1
    j    row_loop

row_done:
    li   x5, MATRIX_EXPECTED
    bne  x29, x5, fail_loop
    j    repeat_loop

done_all:
    j    pass_loop

###############################################################################
.section .rodata
.align 4
matrix_a:
    .word 1, 2, 3, 4
    .word 5, 6, 7, 8
    .word 9, 10, 11, 12
    .word 13, 14, 15, 16
matrix_b:
    .word 16, 15, 14, 13
    .word 12, 11, 10, 9
    .word 8, 7, 6, 5
    .word 4, 3, 2, 1

.section .bss
.align 4
matrix_c:
    .space 64
