###############################################################################
# CBM Instruction Test Program
# Compares standard MUL against the custom CBM (.insn r 0x0B, 0x0, 0x04)
# using a single 7 × 9 multiplication. PASS/FAIL loops indicate result.
###############################################################################

.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134

_start:
    la   t0, operands        # Pointer inside .text so it loads with code
    lw   x10, 0(t0)          # multiplicand = 7
    lw   x11, 4(t0)          # multiplier   = 9
    nop
    nop

    mul  x12, x10, x11       # Reference result
    nop
    nop
    .insn r 0x0B, 0x0, 0x04, x13, x10, x11   # CBM result into x13
    nop
    nop

    beq  x12, x13, pass_loop
    j    fail_loop

# Pad out to PASS_OFFSET (0x80000130 absolute) so the testbench can detect success.
.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

# Pad out to FAIL_OFFSET (0x80000134 absolute).
.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

.align 8
operands:
    .word 7
    .word 9
