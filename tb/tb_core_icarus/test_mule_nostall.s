.section .text
.globl _start

_start:
    # Initialize registers
    li x11, 7      # Load 7 into x11 (multiplicand)
    li x13, 9      # Load 9 into x13 (multiplier)
    
    # Perform MULE operation (x12 = x11 * x13)
    # Custom instruction encoding: 0x02D585B3
    .word 0x02D585B3  # MULE x12, x11, x13
    
    # Only need 5 NOPs for 5-cycle MULE (no stall, pipelined)
    nop
    nop
    nop
    nop
    nop
    
    # Check result (should be 63)
    li x14, 63     # Expected result
    bne x12, x14, fail_loop
    
pass_loop:
    j pass_loop
    
fail_loop:
    j fail_loop
