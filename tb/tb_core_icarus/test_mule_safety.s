# Test MULE safety protections
.section .text
.globl _start

_start:
    # Test 1: Normal MULE operation
    li x10, 5
    li x11, 6
    .word 0x02B50633  # MULE x12, x10, x11  (expect 30)
    nop
    nop
    nop
    nop
    nop
    
    # Test 2: MULE to x0 (should be protected)
    li x13, 7
    li x14, 8
    .word 0x02E68033  # MULE x0, x13, x14   (should not write)
    nop
    nop
    nop
    nop
    nop
    
    # Test 3: Dependent MULE (scoreboard should prevent early issue)
    li x15, 3
    .word 0x02F787B3  # MULE x15, x15, x15  (3*3=9)
    # Next instruction depends on x15 - scoreboard should block until ready
    addi x16, x15, 1  # Should get 10 (9+1)
    
    # Check results
    li x17, 30
    bne x12, x17, fail_loop
    
    li x17, 9
    bne x15, x17, fail_loop
    
    li x17, 10
    bne x16, x17, fail_loop
    
pass_loop:
    j pass_loop
    
fail_loop:
    j fail_loop
