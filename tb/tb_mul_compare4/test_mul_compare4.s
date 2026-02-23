###############################################################################
# 4-Multiplier Comparison Test
# Runs 1000 identical operand pairs through all four multiplier units
# (MUL, MULE, CBM, MULP) and verifies they produce the same results.
#
# MODE selects which multiplier(s) run:
#   0 = ALL four (compare results)
#   1 = MUL  only
#   2 = MULE only
#   3 = CBM  only
#   4 = MULP only
#
# Register usage:
#   x10 (a0)  = operand A
#   x11 (a1)  = operand B
#   x12 (a2)  = MUL  result
#   x13 (a3)  = MULE result
#   x14 (a4)  = CBM  result
#   x20 (s4)  = MULP result
#   x15       = iteration count (1-based)
#   x16       = operand A trace
#   x17       = operand B trace
#   x18 (s2)  = PRNG state A / expected result
#   x19 (s3)  = PRNG state B
#   x8  (s0)  = remaining test count
#   x9  (s1)  = completed count
#   x5-x7,x28 = constants
###############################################################################

.section .text
.globl _start

.ifndef MODE
.set MODE, 0
.endif

.set MODE_ALL,       0
.set MODE_MUL_ONLY,  1
.set MODE_MULE_ONLY, 2
.set MODE_CBM_ONLY,  3
.set MODE_MULP_ONLY, 4

.set NUM_TESTS, 1000

_start:
    j main

.align 8
main:
    li s0, NUM_TESTS
    li s1, 0
    li s2, 0x13579bdf
    li s3, 0x2468ace0
    li t0, 0x9e3779b9
    li t1, 0x7f4a7c15
    li t2, 0x0000ffff
    li t3, 0x0001ffff

test_loop:
    beqz s0, pass_loop

    # clear result registers
    mv x12, x0
    mv x13, x0
    mv x14, x0
    mv x20, x0

    # advance PRNG
    add s2, s2, t0
    add s3, s3, t1

    # derive operands
    and x10, s2, t2
    and x11, s3, t3
    addi x10, x10, 1
    addi x11, x11, 1

    mv x16, x10
    mv x17, x11

    addi s1, s1, 1
    mv x15, s1

    # ---------- dispatch multiply instructions ----------------------------
    .if MODE == MODE_ALL
        mul x12, x10, x11                         # MUL  -> x12
        nop                                        # pipeline spacer
        .insn r 0x0B, 0x0, 0x01, x13, x10, x11   # MULE -> x13
        nop
        .insn r 0x0B, 0x0, 0x04, x14, x10, x11   # CBM  -> x14
        nop
        .insn r 0x0B, 0x1, 0x01, x20, x10, x11   # MULP -> x20

    .elseif MODE == MODE_MUL_ONLY
        mul x12, x10, x11
        mv  x13, x12
        mv  x14, x12
        mv  x20, x12

    .elseif MODE == MODE_MULE_ONLY
        .insn r 0x0B, 0x0, 0x01, x13, x10, x11
        mv  x12, x13
        mv  x14, x13
        mv  x20, x13

    .elseif MODE == MODE_CBM_ONLY
        .insn r 0x0B, 0x0, 0x04, x14, x10, x11
        mv  x12, x14
        mv  x13, x14
        mv  x20, x14

    .elseif MODE == MODE_MULP_ONLY
        .insn r 0x0B, 0x1, 0x01, x20, x10, x11
        mv  x12, x20
        mv  x13, x20
        mv  x14, x20

    .else
        j fail_loop
    .endif

    # ---- wait for results ------------------------------------------------
    .align 3                       # ensure wait_loop is 8-byte aligned
wait_loop:
    .if MODE == MODE_ALL
        beq x12, x0, wait_loop
        beq x13, x0, wait_loop
        beq x14, x0, wait_loop
        beq x20, x0, wait_loop
        # cross-compare
        bne x12, x13, fail_loop
        bne x12, x14, fail_loop
        bne x12, x20, fail_loop
    .else
        beq x12, x0, wait_loop
    .endif

    mv x18, x12

    addi s0, s0, -1
    j test_loop

# ---- pass/fail at fixed addresses ----
    .align 4                       # 16-byte align for safe spacing
pass_loop:
    j pass_loop

    .align 4
fail_loop:
    j fail_loop
