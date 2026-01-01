###############################################################################
# 1000 MULE operations test
# Runs 1000 different operand pairs and accumulates checksum.
###############################################################################

.section .text
.globl _start

.set NUM_ITERS, 1000

_start:
    j main

.align 8
main:
    li s0, NUM_ITERS       # remaining iterations
    li s1, 0               # checksum accumulator
    li s2, 0x01234567      # seed A
    li s3, 0x089abcde      # seed B
    li t0, 0x9e3779b9      # increment A
    li t1, 0x7f4a7c15      # increment B
    li t2, 0x0000ffff      # mask for operand A
    li t3, 0x0001ffff      # mask for operand B

loop:
    beqz s0, done

    add s2, s2, t0
    add s3, s3, t1

    and a0, s2, t2
    and a1, s3, t3
    addi a0, a0, 1
    addi a1, a1, 1

    # MULE: multicycle, energy-efficient multiply
    .insn r 0x0B, 0x0, 0x01, t2, a0, a1

wait_loop:
    beqz t2, wait_loop

    add s1, s1, t2         # accumulate checksum

    mv x12, t2             # expose last product
    mv x13, s1             # expose checksum

    addi s0, s0, -1
    j loop

done:
    mv x5, s1              # final checksum
    li x30, 1              # done flag for testbench

halt:
    j halt
