###############################################################################
# MUL vs MULE comparison test
# Runs 1000 different operand pairs and ensures both units match.
###############################################################################

.section .text
.globl _start

# -----------------------------------------------------------------------------
# MODE controls which instruction runs:
#   0 = all (MUL + MULE + CBM, compare results)
#   1 = MUL only  (x12 is result, x13/x14 mirror x12 to avoid stalls)
#   2 = MULE only (x13 is result, x12/x14 mirror)
#   3 = CBM only  (x14 is result, x12/x13 mirror)
# Override at assemble time: e.g. MODE=1 make VCD_FILE=mul.vcd
# -----------------------------------------------------------------------------
.ifndef MODE
.set MODE, 0
.endif

.set MODE_ALL,      0
.set MODE_MUL_ONLY, 1
.set MODE_MULE_ONLY,2
.set MODE_CBM_ONLY, 3

.set NUM_TESTS, 1000

_start:
    j main

.align 8
main:
    li s0, NUM_TESTS         # Remaining test count
    li s1, 0                 # Completed count
    li s2, 0x13579bdf        # Operand generator state A
    li s3, 0x2468ace0        # Operand generator state B
    li t0, 0x9e3779b9        # Increment A
    li t1, 0x7f4a7c15        # Increment B
    li t2, 0x0000ffff        # Mask for operand A
    li t3, 0x0001ffff        # Mask for operand B

test_loop:
    beqz s0, pass_loop

    mv x12, x0
    mv x13, x0
    mv x14, x0

    add s2, s2, t0
    add s3, s3, t1

    and x10, s2, t2          # operand A in range [1, 65536]
    and x11, s3, t3          # operand B in range [1, 131072]
    addi x10, x10, 1
    addi x11, x11, 1

    mv x16, x10              # expose operands to the testbench for tracing
    mv x17, x11

    addi s1, s1, 1
    mv x15, s1               # current iteration (1-based) for debug

    .if MODE == MODE_ALL
        mul x12, x10, x11
        .insn r 0x0B, 0x0, 0x01, x13, x10, x11
        .insn r 0x0B, 0x0, 0x04, x14, x10, x11
    .elseif MODE == MODE_MUL_ONLY
        mul x12, x10, x11
        mv  x13, x12
        mv  x14, x12
    .elseif MODE == MODE_MULE_ONLY
        .insn r 0x0B, 0x0, 0x01, x13, x10, x11
        mv  x12, x13
        mv  x14, x13
    .elseif MODE == MODE_CBM_ONLY
        .insn r 0x0B, 0x0, 0x04, x14, x10, x11
        mv  x12, x14
        mv  x13, x14
    .else
        # Invalid mode: park in fail
        j fail_loop
    .endif

wait_loop:
    .if MODE == MODE_ALL
        beq x12, x0, wait_loop
        beq x13, x0, wait_loop
        beq x14, x0, wait_loop
        bne x12, x13, fail_loop
        bne x12, x14, fail_loop
    .else
        beq x12, x0, wait_loop
    .endif

    mv x18, x12              # expected result for the testbench

    addi s0, s0, -1
    j test_loop

pass_loop:
    j pass_loop

fail_loop:
    j fail_loop
