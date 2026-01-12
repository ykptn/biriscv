###############################################################################
# LATENCY HIDING DEMONSTRATION
# 
# This test shows when MULE/CBM's extra latency does NOT affect performance
# in a superscalar 2-pipeline core.
#
# KEY CONCEPT: If the multiplication result is not used immediately, and there
# are enough independent instructions between MUL and result usage, the extra
# latency is HIDDEN by parallel execution.
#
# SCENARIOS:
# 1. IMMEDIATE USE: Result used right away → MULE hurts (stall happens)
# 2. DELAYED USE: Result used after 4+ independent ops → MULE OK (no stall)
#
# Expected: MODE=1 (MUL) and MODE=2 (MULE) have SAME cycle count in scenario 2
###############################################################################

.section .text
.globl _start

# MODE: 1=MUL, 2=MULE, 3=CBM
.ifndef MODE
.set MODE, 1
.endif

.set NUM_ITERATIONS, 100

_start:
    j main

.align 8
main:
    li s0, NUM_ITERATIONS
    li s10, 0             # accumulator

test_loop:
    beqz s0, done

    # =========================================================================
    # SCENARIO 1: IMMEDIATE USE (MULE will cause stall)
    # =========================================================================
    li a0, 5
    li a1, 7
    
    .if MODE == 1
        mul t0, a0, a1        # t0 = 35 (MUL latency: ~2 cycles)
    .elseif MODE == 2
        .insn r 0x0B, 0x0, 0x01, t0, a0, a1  # MULE latency: ~4 cycles
    .elseif MODE == 3
        .insn r 0x0B, 0x0, 0x04, t0, a0, a1  # CBM latency: ~6 cycles
    .endif
    
    # IMMEDIATE USE - causes stall if latency not met
    add s10, s10, t0          # ← Uses t0 immediately! STALL if MULE/CBM
    
    # =========================================================================
    # SCENARIO 2: DELAYED USE (MULE latency HIDDEN by other work)
    # =========================================================================
    li a2, 11
    li a3, 13
    
    .if MODE == 1
        mul t1, a2, a3        # t1 = 143 (MUL latency: ~2 cycles)
    .elseif MODE == 2
        .insn r 0x0B, 0x0, 0x01, t1, a2, a3  # MULE latency: ~4 cycles
    .elseif MODE == 3
        .insn r 0x0B, 0x0, 0x04, t1, a2, a3  # CBM latency: ~6 cycles
    .endif
    
    # MANY INDEPENDENT OPERATIONS (can execute in parallel on 2-pipeline core)
    # These instructions don't depend on t1, so they execute while MUL/MULE completes
    li a4, 100
    li a5, 200
    add a6, a4, a5            # Independent work
    sub a7, a6, a4            # Independent work
    slli t2, a7, 2            # Independent work
    srli t3, t2, 1            # Independent work
    xor t4, t2, t3            # Independent work
    or t5, t4, a4             # Independent work
    
    # NOW use t1 - by this time, MULE latency is hidden!
    add s10, s10, t1          # ← t1 ready! NO STALL even with MULE/CBM
    
    # =========================================================================
    # SCENARIO 3: MULTIPLE DELAYED USES (optimal for throughput)
    # =========================================================================
    li a0, 17
    li a1, 19
    li a2, 23
    li a3, 29
    
    # Start two multiplications
    .if MODE == 1
        mul t6, a0, a1        # t6 = 323
        mul t7, a2, a3        # t7 = 667 (can execute in parallel!)
    .elseif MODE == 2
        .insn r 0x0B, 0x0, 0x01, t6, a0, a1
        .insn r 0x0B, 0x0, 0x01, t7, a2, a3
    .elseif MODE == 3
        .insn r 0x0B, 0x0, 0x04, t6, a0, a1
        .insn r 0x0B, 0x0, 0x04, t7, a2, a3
    .endif
    
    # Do other work while both multiplications complete
    li s1, 42
    li s2, 84
    add s3, s1, s2
    sub s4, s3, s1
    slli s5, s4, 1
    srli s6, s5, 1
    and s7, s6, s1
    or s8, s7, s2
    
    # Use results after sufficient delay - NO STALL
    add s10, s10, t6
    add s10, s10, t7
    
    # =========================================================================
    # SCENARIO 4: WORST CASE - immediate dependent chain (MULE loses)
    # =========================================================================
    li a4, 3
    li a5, 5
    
    .if MODE == 1
        mul a4, a4, a5        # a4 = 15
        mul a4, a4, a5        # a4 = 75 ← DEPENDS on previous, STALL
        mul a4, a4, a5        # a4 = 375 ← DEPENDS, STALL
    .elseif MODE == 2
        .insn r 0x0B, 0x0, 0x01, a4, a4, a5
        .insn r 0x0B, 0x0, 0x01, a4, a4, a5  # LONGER stall with MULE
        .insn r 0x0B, 0x0, 0x01, a4, a4, a5  # LONGER stall with MULE
    .elseif MODE == 3
        .insn r 0x0B, 0x0, 0x04, a4, a4, a5
        .insn r 0x0B, 0x0, 0x04, a4, a4, a5  # WORST stall with CBM
        .insn r 0x0B, 0x0, 0x04, a4, a4, a5  # WORST stall with CBM
    .endif
    
    add s10, s10, a4

    addi s0, s0, -1
    j test_loop

done:
    mv a0, s10
    j done

###############################################################################
# SUMMARY OF EXPECTED RESULTS:
#
# Scenario 1 (Immediate Use):
#   MUL:  Fast (minimal stall)
#   MULE: Slower (longer stall)
#   CBM:  Slowest (longest stall)
#
# Scenario 2 (Delayed Use with independent work):
#   MUL:  Baseline
#   MULE: SAME CYCLES (latency hidden by parallel work!)
#   CBM:  SAME CYCLES if enough independent ops (latency hidden!)
#
# Scenario 3 (Multiple parallel multiplications):
#   MUL:  Good throughput
#   MULE: SAME throughput (both execute in parallel)
#   CBM:  SAME throughput (both execute in parallel)
#
# Scenario 4 (Dependent chain):
#   MUL:  Fast
#   MULE: Slower (cumulative stalls)
#   CBM:  Slowest (worst cumulative stalls)
#
# KEY INSIGHT: MULE/CBM extra latency is FREE when:
#   - Result not used immediately
#   - Enough independent work exists (4-6+ instructions)
#   - Superscalar pipeline can execute other ops in parallel
###############################################################################
