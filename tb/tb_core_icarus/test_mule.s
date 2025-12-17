###############################################################################
# MULE Custom Instruction Test Program
# * Golden reference computed via baseline MUL
# * Operands configurable via OP_A / OP_B constants
###############################################################################

.section .text
.option norelax
.globl _start

# Change operands here when trying new values
.equ OP_A, 7
.equ OP_B, 9

_start:
    j main                    # Skip over padding word for fetch alignment

.align 8
main:
    li x10, OP_A              # x10 = operand A
    li x11, OP_B              # x11 = operand B
    mul x13, x10, x11         # Golden reference using standard MUL (x13)

    ###########################################################################
    # Custom MULE instruction (multi-cycle)
    ###########################################################################
    .word 0x02B5060B          # mule x12, x10, x11

    # Allow MULE FSM to complete (5 cycles)
    nop
    nop
    nop
    nop
    nop

    # Compare actual result (x12) with expected (x13)
    bne x12, x13, fail_loop

pass_loop:
    j pass_loop

fail_loop:
    j fail_loop
