# Latency Hiding Demonstration for RISC-V Custom Extensions

This directory contains test cases demonstrating when alternative multiplication units (MULE, CBM) affect performance vs. when their extra latency is hidden by the superscalar pipeline.

## Key Concept

In a **2-way superscalar pipeline**, extra latency from MULE/CBM does NOT affect overall performance IF:
- The multiplication result is not used immediately
- There are sufficient independent instructions between the multiply and its use
- The pipeline can execute other operations in parallel while waiting for the result

## Test Files

### 1. `test_comparison.s` - Simple Side-by-Side Demo
**Best for presentations** - Shows the two key scenarios in minimal code:
- **Bad Case**: Result used immediately → MULE adds stall cycles
- **Good Case**: Result used after 4+ independent ops → MULE latency hidden

### 2. `test_latency_hiding.s` - Comprehensive Demo
Detailed demonstration with 4 scenarios:
1. Immediate use (MULE loses)
2. Delayed use with independent work (MULE same as MUL)
3. Multiple parallel multiplications (MULE same as MUL)
4. Dependent chain (MULE worst case)

## Running Tests

### Quick Comparison
```bash
make compare
```
This runs the comparison test with both MUL and MULE, generating:
- `comparison_mul.vcd` - Standard MUL timing
- `comparison_mule.vcd` - MULE timing

### Individual Test Runs
```bash
# Run with standard MUL
make run TEST=comparison MODE=1 VCD_FILE=mul.vcd

# Run with MULE
make run TEST=comparison MODE=2 VCD_FILE=mule.vcd

# Run with CBM
make run TEST=comparison MODE=3 VCD_FILE=cbm.vcd
```

### Latency Hiding Test (All Modes)
```bash
make latency
```
Generates: `latency_mul.vcd`, `latency_mule.vcd`, `latency_cbm.vcd`

## Analyzing Results

### Using GTKWave
```bash
# View both side-by-side
gtkwave comparison_mul.vcd comparison_mule.vcd &
```

### What to Look For in Waveforms

1. **BAD CASE (Immediate Use)**:
   - Look at the multiplication instruction
   - Count cycles until the ADD that uses the result executes
   - MUL: shorter stall
   - MULE: longer stall (noticeable performance impact)

2. **GOOD CASE (Delayed Use)**:
   - Multiplication starts
   - Independent instructions execute in parallel (visible in pipeline)
   - ADD that uses result executes
   - MUL and MULE: SAME total cycles (latency hidden!)

### Key Signals to Monitor
- `pc_q` - Program counter (shows instruction progression)
- `opcode_q` - Current instruction opcode
- Pipeline stages (fetch, decode, execute)
- Register file write-backs

## For Report/Presentation

### Recommended Visualization

1. **Code Snippet Comparison**:
```assembly
; BAD CASE - MULE hurts
mul  t0, a0, a1    ; latency = N cycles
add  a2, t0, a0    ; WAITS for t0 (stall!)

; GOOD CASE - MULE OK
mul  t1, a3, a4    ; latency = N cycles
li   t2, 100       ; independent
add  t3, t2, t2    ; independent  
slli t4, t3, 1     ; independent (parallel execution)
add  a5, t1, a3    ; t1 is ready! No stall
```

2. **Timing Diagram**:
```
BAD CASE:
  MUL:  [mul 2cy][wait][add] = 3 cycles
  MULE: [mule 4cy][wait][add] = 5 cycles (SLOWER)

GOOD CASE:
  MUL:  [mul 2cy][4 ops in parallel][add] = 6 cycles
  MULE: [mule 4cy][4 ops in parallel][add] = 6 cycles (SAME!)
```

3. **VCD Waveform Screenshot**:
   - Capture the pipeline activity during GOOD CASE
   - Show how independent ops fill the pipeline while MULE completes
   - Highlight that final instruction timing is identical

### Key Takeaways for Report

1. **When MULE Helps**: Dependent multiplication chains
2. **When MULE Neutral**: Independent work available to hide latency
3. **When MULE Hurts**: Immediate result use with no parallel work
4. **Design Implication**: Compiler/programmer should schedule code to avoid immediate dependencies

## Expected Cycle Counts

### Comparison Test (MODE=1 vs MODE=2)
- **Bad case difference**: MULE ~2 cycles slower per iteration
- **Good case difference**: SAME cycles (latency hidden)

### Latency Hiding Test
Scenario-by-scenario breakdown documented in assembly comments.

## Troubleshooting

If tests don't run:
```bash
make clean
make run TEST=comparison MODE=1
```

If VCD files are empty, check `TRACE=1` is set in makefile.

## Architecture Details

- **Core**: 2-way superscalar RISC-V (biriscv)
- **MUL latency**: ~2 cycles
- **MULE latency**: ~4 cycles (estimated)
- **CBM latency**: ~6 cycles (estimated)
- **Pipeline**: Fetch, Decode, Execute, Writeback
- **Key**: Independent ops can execute in parallel on second pipeline

---

**For questions**: Check assembly comments for detailed explanations of each scenario.
