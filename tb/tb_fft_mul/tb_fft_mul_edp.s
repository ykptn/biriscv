###############################################################################
# FFT-4 Benchmark (MUL / MULe / CBM)
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET,   0x130
.equ FAIL_OFFSET,   0x134
.equ UART_BASE,     0x92000000
.equ PJ_MUL,        35
.equ PJ_MULE,       35
.equ PJ_CBM,        35

_start:
    j main

.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

###############################################################################
# Main controller
###############################################################################

.align 4
main:
    la   sp, stack_top

    jal  ra, run_fft_mul
    mv   s0, s6
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mul
    jal  ra, print_line

    jal  ra, run_fft_mule
    bne  s6, s0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_mule
    jal  ra, print_line

    jal  ra, run_fft_cbm
    bne  s6, s0, fail_loop
    mv   x12, s6
    mv   x20, s7
    mv   x21, s8
    mv   x22, s9
    la   a0, str_hdr_cbm
    jal  ra, print_line

    j pass_loop

###############################################################################
# Utility routines
###############################################################################

copy_input:
    la   t0, fft_in_real
    la   t1, fft_buf
    li   t2, 4
1:
    beqz t2, 2f
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    addi t2, t2, -1
    j    1b
2:
    ret

stage1_butterflies:
    la   t0, fft_buf
    lw   t1, 0(t0)
    lw   t2, 8(t0)
    add  t3, t1, t2
    sub  t4, t1, t2
    sw   t3, 0(t0)
    sw   t4, 8(t0)
    lw   t1, 4(t0)
    lw   t2, 12(t0)
    add  t3, t1, t2
    sub  t4, t1, t2
    sw   t3, 4(t0)
    sw   t4, 12(t0)
    ret

stage2_butterflies:
    la   t0, fft_buf
    lw   t1, 0(t0)
    lw   t2, 4(t0)
    add  t3, t1, t2
    sub  t4, t1, t2
    sw   t3, 0(t0)
    sw   t4, 4(t0)
    lw   t1, 8(t0)
    lw   t2, 12(t0)
    add  t3, t1, t2
    sub  t4, t1, t2
    sw   t3, 8(t0)
    sw   t4, 12(t0)
    ret

sum_abs:
    la   t0, fft_buf
    li   t1, 4
    li   t2, 0
1:
    beqz t1, 2f
    lw   t3, 0(t0)
    bgez t3, 3f
    neg  t3, t3
3:
    add  t2, t2, t3
    addi t0, t0, 4
    addi t1, t1, -1
    j    1b
2:
    mv   t3, t2
    ret

finalize_metrics:
    addi sp, sp, -4
    sw   ra, 0(sp)
    jal  ra, sum_abs
    mv   s6, t3
    mv   s7, t5
    mv   a1, a0
    mul  a2, s7, a1
    li   a0, 100
    divu a2, a2, a0
    mv   s8, a2
    mul  a3, a2, s7
    mv   s9, a3
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

###############################################################################
# FFT variants
###############################################################################

run_fft_mul:
    addi sp, sp, -4
    sw   ra, 0(sp)
    jal  ra, copy_input
    rdcycle t0
    jal  ra, stage1_butterflies
    jal  ra, stage2_twiddle_mul
    jal  ra, stage2_butterflies
    rdcycle t1
    sub  t5, t1, t0
    li   a0, PJ_MUL
    jal  ra, finalize_metrics
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

run_fft_mule:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   a0, 'm'
    jal  ra, uart_putc
    jal  ra, copy_input
    rdcycle t0
    jal  ra, stage1_butterflies
    jal  ra, stage2_twiddle_mule
    jal  ra, stage2_butterflies
    rdcycle t1
    sub  t5, t1, t0
    li   a0, PJ_MULE
    jal  ra, finalize_metrics
    lw   ra, 0(sp)
    li   a0, 'M'
    jal  ra, uart_putc
    addi sp, sp, 4
    ret

run_fft_cbm:
    addi sp, sp, -4
    sw   ra, 0(sp)
    li   a0, 'c'
    jal  ra, uart_putc
    jal  ra, copy_input
    rdcycle t0
    jal  ra, stage1_butterflies
    jal  ra, stage2_twiddle_cbm
    jal  ra, stage2_butterflies
    rdcycle t1
    sub  t5, t1, t0
    li   a0, PJ_CBM
    jal  ra, finalize_metrics
    lw   ra, 0(sp)
    li   a0, 'C'
    jal  ra, uart_putc
    addi sp, sp, 4
    ret

###############################################################################
# Twiddle implementations
###############################################################################

stage2_twiddle_mul:
    la   t0, fft_buf
    lw   t1, 8(t0)
    lw   t2, 12(t0)
    li   t3, 23170
    mul  t4, t1, t3
    mul  t5, t2, t3
    sub  t6, t4, t5
    srai t6, t6, 15
    add  t4, t4, t5
    srai t4, t4, 15
    sw   t6, 8(t0)
    sw   t4, 12(t0)
    ret

stage2_twiddle_mule:
    la   t0, fft_buf
    lw   t1, 8(t0)
    lw   t2, 12(t0)
    li   t3, 23170
    .insn r 0x0B, 0x0, 0x01, t4, t1, t3
    .insn r 0x0B, 0x0, 0x01, t5, t2, t3
    sub  t6, t4, t5
    srai t6, t6, 15
    add  t4, t4, t5
    srai t4, t4, 15
    sw   t6, 8(t0)
    sw   t4, 12(t0)
    ret

stage2_twiddle_cbm:
    la   t0, fft_buf
    lw   t1, 8(t0)
    lw   t2, 12(t0)
    li   t3, 23170
    .insn r 0x0B, 0x0, 0x04, t4, t1, t3
    .insn r 0x0B, 0x0, 0x04, t5, t2, t3
    sub  t6, t4, t5
    srai t6, t6, 15
    add  t4, t4, t5
    srai t4, t4, 15
    sw   t6, 8(t0)
    sw   t4, 12(t0)
    ret

###############################################################################
# Printing helpers (reused style)
###############################################################################

print_line:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   t0, 8(sp)
    sw   t1, 4(sp)
    sw   t2, 0(sp)
    jal  ra, print_str
    la   a0, str_sum
    jal  ra, print_str
    mv   a0, x12
    jal  ra, print_u32
    la   a0, str_sep
    jal  ra, print_str
    la   a0, str_cycles
    jal  ra, print_str
    mv   a0, x20
    jal  ra, print_u32
    la   a0, str_sep
    jal  ra, print_str
    la   a0, str_energy
    jal  ra, print_str
    mv   a0, x21
    jal  ra, print_u32
    la   a0, str_sep
    jal  ra, print_str
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

print_str:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   t0, 8(sp)
    sw   t1, 4(sp)
    sw   t2, 0(sp)
    mv   t1, a0
1:
    lbu  t0, 0(t1)
    beqz t0, 2f
    mv   a0, t0
    jal  ra, uart_putc
    addi t1, t1, 1
    j    1b
2:
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

uart_putc:
    li   t0, UART_BASE
    sb   a0, 0(t0)
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
1:
    remu t4, a0, t3
    divu a0, a0, t3
    addi t4, t4, '0'
    addi t2, t2, -1
    sb   t4, 0(t2)
    bnez a0, 1b
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

###############################################################################
# Data
###############################################################################

.section .rodata
.align 4
fft_in_real:
    .word 1200, 1800, 900, 600

str_hdr_mul:
    .asciz "FFT-MUL      "
str_hdr_mule:
    .asciz "FFT-MULE     "
str_hdr_cbm:
    .asciz "FFT-CBM      "
str_sum:
    .asciz "SUM="
str_cycles:
    .asciz " CYCLES="
str_energy:
    .asciz " ENERGY="
str_edp:
    .asciz " EDP="
str_sep:
    .asciz "  "

.section .bss
.align 4
fft_buf:
    .space 4 * 4
digits_buf:
    .space 16
digits_buf_end:

.align 4
stack_space:
    .space 256
stack_top:
