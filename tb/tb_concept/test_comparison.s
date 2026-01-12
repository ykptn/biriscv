###############################################################################
# SIDE-BY-SIDE COMPARISON: When MULE latency matters vs doesn't matter
#
# This creates a MINIMAL example for report/presentation showing:
# - BAD CASE: Extra latency hurts
# - GOOD CASE: Extra latency hidden (no performance impact)
###############################################################################

.section .text
.globl _start

.ifndef MODE
.set MODE, 1
.endif

_start:
    j main

.align 8
main:
    li s0, 50                 # iterations

test_loop:
    beqz s0, done

    # =========================================================================
    # BAD CASE: Result used immediately → MULE adds stall cycles
    # =========================================================================
    li a0, 7
    li a1, 9
    
    .if MODE == 1
        mul t0, a0, a1        # MUL: latency ~2 cycles
    .else
        .insn r 0x0B, 0x0, 0x01, t0, a0, a1  # MULE: latency ~4 cycles
    .endif
    
    add a2, t0, a0            # ← IMMEDIATE USE: waits for t0
                              # MUL:  small stall
                              # MULE: longer stall (HURTS PERFORMANCE)
    
    # =========================================================================
    # GOOD CASE: Result used after delay → MULE latency absorbed
    # =========================================================================
    li a3, 11
    li a4, 13
    
    .if MODE == 1
        mul t1, a3, a4        # MUL: latency ~2 cycles
    .else
        .insn r 0x0B, 0x0, 0x01, t1, a3, a4  # MULE: latency ~4 cycles
    .endif
    
    # Independent work (executes in parallel in 2-pipe superscalar)
    li t2, 100
    li t3, 200
    add t4, t2, t3            # doesn't need t1
    sub t5, t4, t2            # doesn't need t1
    slli t6, t5, 1            # doesn't need t1
    srli t7, t6, 1            # doesn't need t1
    
    add a5, t1, a3            # ← DELAYED USE: t1 is ready!
                              # MUL:  no stall
                              # MULE: no stall (SAME PERFORMANCE!)
    
    # Combine results
    add a6, a2, a5
    
    addi s0, s0, -1
    j test_loop

done:
    mv a0, a6
    j done

###############################################################################
# FOR PRESENTATION:
#
# Show VCD waveforms side by side:
#   MODE=1 make run VCD_FILE=mul.vcd
#   MODE=2 make run VCD_FILE=mule.vcd
#
# In VCD viewer, you will see:
#
# BAD CASE timeline:
#   MUL:  [mul 2cy][stall 0cy][add executes]         ← 2 cycles total
#   MULE: [mule 4cy][stall 0cy][add executes]        ← 4 cycles total (slower!)
#
# GOOD CASE timeline:
#   MUL:  [mul 2cy][independent ops 4cy][add exec]   ← 6 cycles total
#   MULE: [mule 4cy hidden by parallel ops][add exec] ← 6 cycles total (same!)
#
# CONCLUSION: MULE's extra 2 cycles only matter when result is used immediately.
# When there's independent work, the superscalar pipeline hides the latency.
###############################################################################
