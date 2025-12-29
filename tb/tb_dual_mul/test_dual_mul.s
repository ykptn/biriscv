###############################################################################
# Dual MUL Parallel Execution Test
# Tests that two MUL instructions can execute in parallel on pipe0 and pipe1
#
# Test: Issue two independent MUL instructions back-to-back
# Expected: Both should issue in parallel and complete around the same time
###############################################################################

.section .text
.globl _start

_start:
    j main

# Align to 8-byte boundary for dual-issue fetch
.align 8

main:
    # Prepare operands for two independent multiplications
    li x10, 7           # a0 = 7
    li x11, 9           # a1 = 9
    li x12, 5           # a2 = 5
    li x13, 8           # a3 = 8
    
    # Expected results
    li x16, 63          # 7 * 9 = 63
    li x17, 40          # 5 * 8 = 40

    nop
    nop

    ###########################################################################
    # Two independent MUL instructions (should execute in parallel)
    # MUL x14, x10, x11  (7 * 9 = 63)
    # MUL x15, x12, x13  (5 * 8 = 40)
    ###########################################################################
.align 8
parallel_muls:
    .word 0x02B50733     # mul x14, x10, x11
    .word 0x02D607B3     # mul x15, x12, x13

    # Wait for both results
    nop
    nop
    nop
    nop
    nop

    # Verify first result
    bne x14, x16, fail_loop
    
    # Verify second result
    bne x15, x17, fail_loop

###############################################################################
# Test 2: Sequential MULs with dependency (should NOT be parallel)
###############################################################################
test2:
    li x10, 3           # a0 = 3
    li x11, 4           # a1 = 4
    li x16, 144         # expected: (3*4) * (3*4) = 12 * 12 = 144
    
    nop
    nop

.align 8
sequential_muls:
    .word 0x02B50633     # mul x12, x10, x11  (3 * 4 = 12)
    .word 0x02C60633     # mul x12, x12, x12  (12 * 12 = 144) - depends on previous result

    nop
    nop
    nop
    nop
    nop
    nop

    # Verify result
    bne x12, x16, fail_loop

###############################################################################
# PASS/FAIL LOOPS
###############################################################################

pass_loop:
    j pass_loop          # PC = 0x800000B4

fail_loop:
    j fail_loop          # PC = 0x800000B8
