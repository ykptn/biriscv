###############################################################################
# Manual mul/mule routing testbench
# Usage:
#   make              - compile C, compile RTL, run simulation
#   make disasm       - show disassembly of the compiled binary (see mul / mule)
#   make clean        - remove build artefacts
#
# Variables you can override on the command line:
#   BENCH_SRC=my_bench.c   source file for your kernel (default: my_bench.c)
#   TRACE=1                enable retire-trace prints per instruction
#   TRACE_VCD=1            dump full waveform to waveform.vcd
###############################################################################

CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

BENCH_SRC    ?= my_bench.c
ELF_FILE      = bench.elf
BUILD_DIR     = build

TRACE     ?= 0
TRACE_VCD ?= 0

# RTL sources -- reuse the same core as the rest of the testbenches
RTL_DIRS = ../../src/core
SRC_V    = $(foreach d,$(RTL_DIRS),$(wildcard $(d)/*.v))
SRC_V   += ../../tb/tb_mul/tcm_mem.v ../../tb/tb_mul/tcm_mem_ram.v

VFLAGS  = $(patsubst %,-I%,$(RTL_DIRS)) -I.
VFLAGS += -DTRACE=$(TRACE)
VFLAGS += -DTRACE_VCD=$(TRACE_VCD)
VFLAGS += -Dverilog_sim

CFLAGS  = -march=rv32im -mabi=ilp32 -O2 -ffreestanding -fno-builtin \
          -fno-common -msmall-data-limit=0 -I.
LDFLAGS = -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
          -Wl,-T../tb_matmul_absorbtion/link.ld -Wl,--gc-sections

EXE     = $(BUILD_DIR)/sim.out

.PHONY: all run disasm clean

all: run

$(BUILD_DIR):
	@mkdir -p $@

# ── firmware ──────────────────────────────────────────────────────────────────
$(BUILD_DIR)/start.o: ../tb_matmul_absorbtion/start_bench.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/bench_main.o: $(BENCH_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/bench_support.o: ../tb_matmul_absorbtion/bench_stdio_stub.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -I../tb_matmul_absorbtion -c $< -o $@

$(ELF_FILE): $(BUILD_DIR)/start.o $(BUILD_DIR)/bench_main.o \
             $(BUILD_DIR)/bench_support.o
	$(CC) $(LDFLAGS) -o $@ $^ -lgcc

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $< -O binary $@

# ── RTL simulator ─────────────────────────────────────────────────────────────
$(EXE): $(SRC_V) tb_manual_routing.v | $(BUILD_DIR)
	@echo "# Compiling Verilog"
	iverilog $(VFLAGS) -o $@ $(SRC_V) tb_manual_routing.v

# ── run ───────────────────────────────────────────────────────────────────────
run: $(EXE) $(BUILD_DIR)/tcm.bin
	@echo ""
	@echo "============================================================"
	@echo " Running simulation"
	@echo "============================================================"
	cd $(BUILD_DIR) && vvp sim.out

# ── disassembly ───────────────────────────────────────────────────────────────
disasm: $(ELF_FILE)
	$(OBJDUMP) -d -M no-aliases $<

clean:
	rm -rf $(BUILD_DIR) $(ELF_FILE)
