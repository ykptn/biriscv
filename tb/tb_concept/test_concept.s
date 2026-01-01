###############################################################################
# Concept Test: MUL with delayed result usage
# 
# This test performs:
# 1. A multiplication (5 × 8 = 40)
# 2. 20 unrelated instructions
# 3. Uses the mul result in an addition
#
# Expected: Final result in x15 = 40 + 100 = 140 (0x8C)
###############################################################################

.section .text
.globl _start

_start:
    j main

.align 8
main:
    # Initialize operands for multiplication
    li x10, 5           # a0 = 5
    li x11, 8           # a1 = 8
    
    # Perform multiplication using MULE: x12 = 5 × 8 = 40
    .insn r 0x0B, 0x0, 0x01, x12, x10, x11
    
    ###########################################################################
    # 20 unrelated instructions that don't touch x12
    ###########################################################################
    
    # 1-5: Arithmetic operations
    li x13, 10
    li x14, 20
    add x16, x13, x14       # x16 = 30
    sub x17, x14, x13       # x17 = 10
    addi x18, x16, 5        # x18 = 35
    
    # 6-10: Logical operations
    li x19, 0xFF
    li x20, 0xF0
    and x21, x19, x20       # x21 = 0xF0
    or x22, x19, x20        # x22 = 0xFF
    xor x23, x19, x20       # x23 = 0x0F
    
    # 11-15: Shift operations
    li x24, 8
    slli x25, x24, 2        # x25 = 32
    srli x26, x24, 1        # x26 = 4
    li x27, -16
    srai x28, x27, 2        # x28 = -4
    
    # 16-20: More arithmetic and data movement
    li x29, 77
    addi x30, x29, 23       # x30 = 100
    mv x31, x30             # x31 = 100
    add x5, x16, x17        # x5 = 40 (30 + 10)
    sub x6, x18, x17        # x6 = 25 (35 - 10)
    
    ###########################################################################
    # Use the multiplication result in an addition
    ###########################################################################
    
    # x15 = x12 + x30 = 40 + 100 = 140
    add x15, x12, x30
    
    # Verify result
    li x7, 140              # Expected result
    bne x15, x7, fail_loop
    
###############################################################################
# PASS/FAIL LOOPS
###############################################################################

pass_loop:
    j pass_loop          # Test passed

fail_loop:
    j fail_loop          # Test failed
