# MUL Pipeline Behavior Testbench

## Overview

This testbench compares the pipeline behavior of multiplication operations under two scenarios:

1. **MUL with Independent Instructions** (x12): 
   - Multiply followed by 5 independent instructions (add, sub, xor, and, or)
   - These independent instructions keep the pipeline busy
   - The result of the multiplication should be available after the normal latency
   - Expected behavior: Pipeline stalls are minimized

2. **MUL with Dependent Instruction** (x13):
   - Multiply followed immediately by an instruction that depends on the result
   - The dependent instruction (add x25, x13, x20) stalls until x13 is ready
   - Expected behavior: Pipeline stalls when waiting for the result

## Expected Outcome

**Both tests should produce results in the same number of cycles** because:
- In test 1, the MUL result is not used until after the independent instructions complete
- In test 2, the dependent instruction stalls, causing the same overall latency
- The multiply latency is identical in both cases; the pipeline scheduling differs but total cycles match

## Files

- **test_mul_pipeline.s**: RISC-V assembly program with 100 test iterations
- **tb_mul_pipeline.v**: Verilog testbench module that monitors MUL operations
- **link.ld**: Linker script defining memory layout (text at 0x80000000)
- **makefile**: Build and run instructions
- **tcm_mem.v**: Tightly-Coupled Memory module
- **tcm_mem_ram.v**: Dual-port RAM for TCM

## Building and Running

```bash
cd /home/ziyx/Masaüstü/Şükrü/cs401/riscv-extension/biriscv/tb/mulvsmule
make clean
make run
```

## Test Analysis

The testbench tracks:
- **Issue cycle**: When each MUL instruction is dispatched to the execution pipeline
- **Writeback cycle**: When the result becomes available in the register file
- **Latency**: Difference between writeback and issue cycles
- **Average latency**: Total latency divided by number of completed operations

The output will display:
- Individual latency for each test iteration
- Overall statistics comparing both paths
- Pass/Fail indication based on result correctness

## Success Criteria

1. Both x12 and x13 contain the correct multiplication results
2. Average cycle count should be similar (dependent test might be slightly higher due to stalls, but within 1-2 cycles)
3. Program completes 100 test iterations and reaches PASS_PC (0x80000190)
