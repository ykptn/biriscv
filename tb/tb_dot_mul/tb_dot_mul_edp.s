###############################################################################
# DOT Product Benchmark for MUL / MULe / CBM latency and energy profiling
#
# Computes DOT = Σ(A[i] * B[i]) with strict LW→MUL→ADD dependencies so that
# multiplier latency is fully exposed. The workload is repeated three times:
#   1) Standard MUL
#   2) Efficient MULe (.insn r 0x0B, 0x0, 0x01)
#   3) Column-Bypass MUL (.insn r 0x0B, 0x0, 0x04)
#
# Each run records cycles via rdcycle, converts to energy assuming 0.35pJ/cycle,
# and reports energy-delay-product. Results are printed in decimal via UART-like
# MMIO writes before jumping to the usual PASS/FAIL loops.
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134
.equ UART_BASE, 0x92000000
.equ DOT_EXPECTED, 120
.equ DOT_LEN, 8
.equ pJ_MUL,   35
.equ pJ_MULE,  35
.equ pJ_CBM,   35

_start:
    j main

# Fixed PASS/FAIL locations so the testbench can detect completion.
.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

.align 4
main:
    la   sp, stack_top

    jal  ra, run_dot_mul
    li   t0, DOT_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mul
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_dot_mule
    li   t0, DOT_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mule
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    jal  ra, run_dot_cbm
    li   t0, DOT_EXPECTED
    bne  s6, t0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_cbm
    jal  ra, print_str
    jal  ra, print_newline
    jal  ra, print_metrics

    j    pass_loop

###############################################################################
# Dot-product runners
###############################################################################

# All runners write their metrics into s6..s9
#   s6 = DOT, s7 = cycles, s8 = energy, s9 = EDP

run_dot_mul:
    la   t0, array_a
    la   t1, array_b
    li   t2, DOT_LEN
    li   t3, 0
    li   t4, 0
    rdcycle t5
    mv   t6, t5
dot_mul_loop:
    lw   a0, 0(t0)
    lw   a1, 0(t1)
    mul  a2, a0, a1
    add  t3, t3, a2
    addi t0, t0, 4
    addi t1, t1, 4
    addi t4, t4, 1
    blt  t4, t2, dot_mul_loop
    rdcycle t5
    sub  t5, t5, t6
    jal  zero, finalize_mul_metrics
    ret

run_dot_mule:
    la   t0, array_a
    la   t1, array_b
    li   t2, DOT_LEN
    li   t3, 0
    li   t4, 0
    rdcycle t5
    mv   t6, t5
dot_mule_loop:
    lw   a0, 0(t0)
    lw   a1, 0(t1)
    .insn r 0x0B, 0x0, 0x01, a2, a0, a1
    add  t3, t3, a2
    addi t0, t0, 4
    addi t1, t1, 4
    addi t4, t4, 1
    blt  t4, t2, dot_mule_loop
    rdcycle t5
    sub  t5, t5, t6
    jal  zero, finalize_mule_metrics
    ret

run_dot_cbm:
    la   t0, array_a
    la   t1, array_b
    li   t2, DOT_LEN
    li   t3, 0
    li   t4, 0
    rdcycle t5
    mv   t6, t5
dot_cbm_loop:
    lw   a0, 0(t0)
    lw   a1, 0(t1)
    .insn r 0x0B, 0x0, 0x04, a2, a0, a1
    add  t3, t3, a2
    addi t0, t0, 4
    addi t1, t1, 4
    addi t4, t4, 1
    blt  t4, t2, dot_cbm_loop
    rdcycle t5
    sub  t5, t5, t6
    jal  zero, finalize_cbm_metrics
    ret

# Helper: finalize metrics and stash into s6..s9.
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
# UART + Printing Helpers
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

    la   a0, str_dot
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
# Data sections
###############################################################################

.section .rodata
.align 4
array_a:
    .word 1,2,3,4,5,6,7,8
array_b:
    .word 8,7,6,5,4,3,2,1

str_hdr_mul:
    .asciz "MUL"
str_hdr_mule:
    .asciz "MULE"
str_hdr_cbm:
    .asciz "CBM"

str_dot:
    .asciz "DOT="
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
