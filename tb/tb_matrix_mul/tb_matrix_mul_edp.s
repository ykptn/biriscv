###############################################################################
# Matrix Multiply Benchmark for MUL / MULe / CBM latency + energy profiling
#
# Computes C = A x B for fixed 4x4 matrices stored in .rodata. The workload is
# repeated three times: baseline MUL, custom MULe, and Column-Bypass MUL (CBM).
# After each run, the sum of all C elements is recorded along with cycle,
# energy, and EDP metrics. PASS occurs only if every multiplier variant produces
# the expected sum.
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET,    0x130
.equ FAIL_OFFSET,    0x134
.equ UART_BASE,      0x92000000
.equ MATRIX_DIM,     4
.equ ROW_STRIDE,     MATRIX_DIM*4
.equ MATRIX_EXPECTED, 4304
.equ pJ_MUL,   35
.equ pJ_MULE,  35
.equ pJ_CBM,   35

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
    la   sp, stack_top

    jal  ra, run_matrix_mul
    li   t0, MATRIX_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mul
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_matrix_mule
    li   t0, MATRIX_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mule
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_matrix_cbm
    li   t0, MATRIX_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_cbm
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    j pass_loop

###############################################################################
# Matrix multiply runners (sum stored in s6)
###############################################################################

run_matrix_mul:
    la   s0, matrix_a
    la   s1, matrix_b
    li   s2, MATRIX_DIM
    li   s3, ROW_STRIDE
    li   s4, 0               # total sum
    li   t0, 0               # i index
    rdcycle a6

i_loop_mul:
    bge  t0, s2, finish_mul
    mul  t3, t0, s3
    add  t3, s0, t3          # row base pointer
    li   t1, 0               # j
j_loop_mul:
    bge  t1, s2, next_row_mul
    li   t4, 0               # element sum
    li   t2, 0               # k
k_loop_mul:
    bge  t2, s2, end_k_mul
    slli t5, t2, 2
    add  t6, t3, t5
    lw   a0, 0(t6)
    mul  t6, t2, s3
    slli t5, t1, 2
    add  t6, t6, t5
    add  t6, s1, t6
    lw   a1, 0(t6)
    mul  a2, a0, a1
    add  t4, t4, a2
    addi t2, t2, 1
    j    k_loop_mul
end_k_mul:
    add  s4, s4, t4
    addi t1, t1, 1
    j    j_loop_mul
next_row_mul:
    addi t0, t0, 1
    j    i_loop_mul
finish_mul:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, s4
    jal  zero, finalize_mul_metrics

run_matrix_mule:
    la   s0, matrix_a
    la   s1, matrix_b
    li   s2, MATRIX_DIM
    li   s3, ROW_STRIDE
    li   s4, 0
    li   t0, 0
    rdcycle a6

i_loop_mule:
    bge  t0, s2, finish_mule
    mul  t3, t0, s3
    add  t3, s0, t3
    li   t1, 0
j_loop_mule:
    bge  t1, s2, next_row_mule
    li   t4, 0
    li   t2, 0
k_loop_mule:
    bge  t2, s2, end_k_mule
    slli t5, t2, 2
    add  t6, t3, t5
    lw   a0, 0(t6)
    mul  t6, t2, s3
    slli t5, t1, 2
    add  t6, t6, t5
    add  t6, s1, t6
    lw   a1, 0(t6)
    .insn r 0x0B, 0x0, 0x01, a2, a0, a1
    add  t4, t4, a2
    addi t2, t2, 1
    j    k_loop_mule
end_k_mule:
    add  s4, s4, t4
    addi t1, t1, 1
    j    j_loop_mule
next_row_mule:
    addi t0, t0, 1
    j    i_loop_mule
finish_mule:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, s4
    jal  zero, finalize_mule_metrics

run_matrix_cbm:
    la   s0, matrix_a
    la   s1, matrix_b
    li   s2, MATRIX_DIM
    li   s3, ROW_STRIDE
    li   s4, 0
    li   t0, 0
    rdcycle a6

i_loop_cbm:
    bge  t0, s2, finish_cbm
    mul  t3, t0, s3
    add  t3, s0, t3
    li   t1, 0
j_loop_cbm:
    bge  t1, s2, next_row_cbm
    li   t4, 0
    li   t2, 0
k_loop_cbm:
    bge  t2, s2, end_k_cbm
    slli t5, t2, 2
    add  t6, t3, t5
    lw   a0, 0(t6)
    mul  t6, t2, s3
    slli t5, t1, 2
    add  t6, t6, t5
    add  t6, s1, t6
    lw   a1, 0(t6)
    .insn r 0x0B, 0x0, 0x04, a2, a0, a1
    add  t4, t4, a2
    addi t2, t2, 1
    j    k_loop_cbm
end_k_cbm:
    add  s4, s4, t4
    addi t1, t1, 1
    j    j_loop_cbm
next_row_cbm:
    addi t0, t0, 1
    j    i_loop_cbm
finish_cbm:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, s4
    jal  zero, finalize_cbm_metrics

###############################################################################
# Finalize helpers (populate s6..s9)
###############################################################################

finalize_mul_metrics:
    mv   s6, t3
    mv   s7, t5
    li   a0, pJ_MUL
    mul  a1, t5, a0
    li   a0, 100
    divu a1, a1, a0
    mv   s8, a1
    mul  a2, a1, t5
    mv   s9, a2
    ret

finalize_mule_metrics:
    mv   s6, t3
    mv   s7, t5
    li   a0, pJ_MULE
    mul  a1, t5, a0
    li   a0, 100
    divu a1, a1, a0
    mv   s8, a1
    mul  a2, a1, t5
    mv   s9, a2
    ret

finalize_cbm_metrics:
    mv   s6, t3
    mv   s7, t5
    li   a0, pJ_CBM
    mul  a1, t5, a0
    li   a0, 100
    divu a1, a1, a0
    mv   s8, a1
    mul  a2, a1, t5
    mv   s9, a2
    ret

###############################################################################
# UART + printing helpers
###############################################################################

uart_putc:
    li   t0, UART_BASE
    sb   a0, 0(t0)
    ret

print_str:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   t0, 8(sp)
    sw   t1, 4(sp)
    sw   t2, 0(sp)
    mv   t1, a0
print_str_loop:
    lbu  t0, 0(t1)
    beqz t0, print_str_done
    mv   a0, t0
    jal  ra, uart_putc
    addi t1, t1, 1
    j    print_str_loop
print_str_done:
    lw   t0, 8(sp)
    lw   t1, 4(sp)
    lw   t2, 0(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

print_newline:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   a0, '\r'
    jal  ra, uart_putc
    li   a0, '\n'
    jal  ra, uart_putc
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

print_u32:
    addi sp, sp, -40
    sw   ra, 36(sp)
    sw   t0, 32(sp)
    sw   t1, 28(sp)
    sw   t2, 24(sp)
    sw   t3, 20(sp)
    sw   t4, 16(sp)
    sw   t5, 12(sp)
    sw   t6, 8(sp)
    sw   a1, 4(sp)
    sw   a2, 0(sp)

    la   t0, digits_buf_end
    addi t1, t0, -1
    sb   zero, 0(t1)
    mv   t2, t1
    li   t3, 10

    beqz a0, print_u32_zero
print_u32_loop:
    remu t4, a0, t3
    divu a0, a0, t3
    addi t4, t4, '0'
    addi t2, t2, -1
    sb   t4, 0(t2)
    bnez a0, print_u32_loop
    j    print_u32_emit

print_u32_zero:
    addi t2, t2, -1
    li   t4, '0'
    sb   t4, 0(t2)

print_u32_emit:
    mv   a0, t2
    jal  ra, print_str

    lw   a2, 0(sp)
    lw   a1, 4(sp)
    lw   t6, 8(sp)
    lw   t5, 12(sp)
    lw   t4, 16(sp)
    lw   t3, 20(sp)
    lw   t2, 24(sp)
    lw   t1, 28(sp)
    lw   t0, 32(sp)
    lw   ra, 36(sp)
    addi sp, sp, 40
    ret

print_metrics:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   t0, 8(sp)
    sw   t1, 4(sp)
    sw   t2, 0(sp)

    la   a0, str_sum
    jal  ra, print_str
    mv   a0, x12
    jal  ra, print_u32
    jal  ra, print_newline

    la   a0, str_cycles
    jal  ra, print_str
    mv   a0, x20
    jal  ra, print_u32
    jal  ra, print_newline

    la   a0, str_energy
    jal  ra, print_str
    mv   a0, x21
    jal  ra, print_u32
    jal  ra, print_newline

    la   a0, str_edp
    jal  ra, print_str
    mv   a0, x22
    jal  ra, print_u32
    jal  ra, print_newline

    lw   t0, 8(sp)
    lw   t1, 4(sp)
    lw   t2, 0(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

###############################################################################
# Data
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

str_hdr_mul:
    .asciz "MUL-MATRIX"
str_hdr_mule:
    .asciz "MULE-MATRIX"
str_hdr_cbm:
    .asciz "CBM-MATRIX"

str_sum:
    .asciz "SUM="
str_cycles:
    .asciz "CYCLES="
str_energy:
    .asciz "ENERGY(pJ)="
str_edp:
    .asciz "EDP="

.section .bss
.align 4
digits_buf:
    .space 16
digits_buf_end:

.align 4
stack_space:
    .space 256
stack_top:
