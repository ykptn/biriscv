###############################################################################
# Horner Polynomial Benchmark for MUL / MULe / CBM
#
# Evaluates P(x) = 1 + 2x + 3x^2 + 4x^3 + 5x^4 + 6x^5 at x = 2 using Horner's
# method. Runs the workload three times (MUL, MULe, CBM) to capture latency,
# energy, and EDP for each multiplier implementation.
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET,     0x130
.equ FAIL_OFFSET,     0x134
.equ UART_BASE,       0x92000000
.equ POLY_LEN,        6
.equ POLY_X,          2
.equ POLY_EXPECTED,   321
.equ pJ_MUL,          35
.equ pJ_MULE,         35
.equ pJ_CBM,          35

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

    jal  ra, run_poly_mul
    li   t0, POLY_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mul
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_poly_mule
    li   t0, POLY_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mule
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_poly_cbm
    li   t0, POLY_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_cbm
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics
    li   t0, 64
delay_after_cbm:
    addi t0, t0, -1
    bnez t0, delay_after_cbm

    j pass_loop

###############################################################################
# Horner polynomial runners
###############################################################################

run_poly_mul:
    la   s0, poly_coeffs
    li   s1, POLY_LEN
    li   s2, POLY_X
    lw   t1, 0(s0)
    li   t0, 1
    rdcycle a6
poly_mul_loop:
    bge  t0, s1, poly_mul_done
    slli t2, t0, 2
    add  t3, s0, t2
    lw   a0, 0(t3)
    mul  t1, t1, s2
    add  t1, t1, a0
    addi t0, t0, 1
    j    poly_mul_loop
poly_mul_done:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, t1
    jal  zero, finalize_mul_metrics

run_poly_mule:
    la   s0, poly_coeffs
    li   s1, POLY_LEN
    li   s2, POLY_X
    lw   t1, 0(s0)
    li   t0, 1
    rdcycle a6
poly_mule_loop:
    bge  t0, s1, poly_mule_done
    slli t2, t0, 2
    add  t3, s0, t2
    lw   a0, 0(t3)
    .insn r 0x0B, 0x0, 0x01, a2, t1, s2
    add  t1, a2, a0
    addi t0, t0, 1
    j    poly_mule_loop
poly_mule_done:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, t1
    jal  zero, finalize_mule_metrics

run_poly_cbm:
    la   s0, poly_coeffs
    li   s1, POLY_LEN
    li   s2, POLY_X
    lw   t1, 0(s0)
    li   t0, 1
    rdcycle a6
poly_cbm_loop:
    bge  t0, s1, poly_cbm_done
    slli t2, t0, 2
    add  t3, s0, t2
    lw   a0, 0(t3)
    .insn r 0x0B, 0x0, 0x04, a2, t1, s2
    add  t1, a2, a0
    addi t0, t0, 1
    j    poly_cbm_loop
poly_cbm_done:
    rdcycle a7
    sub  t5, a7, a6
    mv   t3, t1
    jal  zero, finalize_cbm_metrics

###############################################################################
# Metric finalization helpers
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

    la   a0, str_val
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
poly_coeffs:
    .word 6, 5, 4, 3, 2, 1

str_hdr_mul:
    .asciz "MUL-HORNER"
str_hdr_mule:
    .asciz "MULE-HORNER"
str_hdr_cbm:
    .asciz "CBM-HORNER"

str_val:
    .asciz "VAL="
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
