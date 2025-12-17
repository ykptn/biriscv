###############################################################################
# Signed MUL diagnostics for MUL / MULe / CBM
# NOTE: Do NOT load operands from .rodata/.data (lw) on this platform.
#       Use immediates (li) instead.
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET,   0x130
.equ FAIL_OFFSET,   0x134
.equ UART_BASE,     0x92000000

# Change test operands here
.equ OP_A,          -12345
.equ OP_B,          23170

_start:
    j main

.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

###############################################################################
# Main entry
###############################################################################
.align 4
main:
    la   sp, stack_top

    # -------------------------------------------------------------------------
    # Print header
    # -------------------------------------------------------------------------
    la   a0, str_hdr
    jal  ra, print_str
    jal  ra, print_newline

    # -------------------------------------------------------------------------
    # Print A and B (to confirm actual values)
    # -------------------------------------------------------------------------
    la   a0, str_a
    jal  ra, print_str
    li   a0, OP_A
    jal  ra, print_i32
    jal  ra, print_newline

    la   a0, str_b
    jal  ra, print_str
    li   a0, OP_B
    jal  ra, print_i32
    jal  ra, print_newline

    # -------------------------------------------------------------------------
    # Print MUL
    # -------------------------------------------------------------------------
    la   a0, str_mul
    jal  ra, print_str
    li   t1, OP_A
    li   t2, OP_B
    mul  t3, t1, t2
    mv   a0, t3
    jal  ra, print_i32
    jal  ra, print_newline

    # -------------------------------------------------------------------------
    # Print MULE
    # -------------------------------------------------------------------------
    la   a0, str_mule
    jal  ra, print_str
    li   t1, OP_A
    li   t2, OP_B
    .insn r 0x0B, 0x0, 0x01, t3, t1, t2
    mv   a0, t3
    jal  ra, print_i32
    jal  ra, print_newline

    # -------------------------------------------------------------------------
    # Print CBM
    # -------------------------------------------------------------------------
    la   a0, str_cbm
    jal  ra, print_str
    li   t1, OP_A
    li   t2, OP_B
    .insn r 0x0B, 0x0, 0x04, t3, t1, t2
    mv   a0, t3
    jal  ra, print_i32
    jal  ra, print_newline

    j pass_loop

###############################################################################
# Printing helpers
###############################################################################

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

print_i32:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   t0, 4(sp)
    sw   t1, 0(sp)
    mv   t1, a0
    bgez t1, 1f
    li   a0, '-'
    jal  ra, uart_putc
    neg  t1, t1
1:
    mv   a0, t1
    jal  ra, print_u32
    lw   t1, 0(sp)
    lw   t0, 4(sp)
    lw   ra, 8(sp)
    addi sp, sp, 12
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

###############################################################################
# Data (strings only; no operand loads!)
###############################################################################

.section .rodata
.align 4
str_hdr:
    .asciz "SIGNED MUL DEBUG"
str_a:
    .asciz "A = "
str_b:
    .asciz "B = "
str_mul:
    .asciz "MUL = "
str_mule:
    .asciz "MULE = "
str_cbm:
    .asciz "CBM = "

.section .bss
.align 4
digits_buf:
    .space 16
digits_buf_end:

.align 4
stack_space:
    .space 256
stack_top:
