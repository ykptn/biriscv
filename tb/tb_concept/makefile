###############################################################################
# Makefile for tb_concept - Latency Hiding Demonstration
###############################################################################

# Test selection
TEST ?= comparison
TEST_FILE = test_$(TEST).s
ELF_FILE = test_$(TEST).elf

# Toolchain
AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

# Defaults
TRACE ?= 1
MODE ?= 1
VCD_FILE ?= waveform.vcd

SRC_V_DIR ?= ../../src/core ../../src/tcm ../../src/top ../../src/icache ../../src/dcache
EXE       ?= output.out
BUILD_DIR ?= build/

# Verilog sources
SRC_V = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v))

VFLAGS  += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS  += -DTRACE=$(TRACE)
VFLAGS  += -Dverilog_sim

###############################################################################
# Rules
###############################################################################
.PHONY: all run clean compare help

all: run

$(BUILD_DIR):
	@mkdir -p $@

###############################################################################
# Assemble + Link
###############################################################################
%.o: %.s
	$(AS) -march=rv32im -mabi=ilp32 --defsym MODE=$(MODE) $< -o $@

$(ELF_FILE): test_$(TEST).o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $@ $<

%.dump: %.elf
	$(OBJDUMP) -D $< > $@

###############################################################################
# Convert ELF → TCM binary
###############################################################################
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

###############################################################################
# Verilog compilation
###############################################################################
$(BUILD_DIR)/$(EXE): $(SRC_V) tb_concept.v | $(BUILD_DIR)
	@echo "# Compiling Verilog (test=$(TEST), mode=$(MODE))"
	iverilog $(VFLAGS) -o $@ $(SRC_V) tb_concept.v

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	@echo "# Running test=$(TEST), MODE=$(MODE), VCD=$(VCD_FILE)"
	vvp $(BUILD_DIR)/$(EXE) +dumpfile=$(VCD_FILE)

###############################################################################
# Comparison runs
###############################################################################
compare:
	@echo "==================================================================="
	@echo "Running COMPARISON test with MUL (MODE=1) vs MULE (MODE=2)"
	@echo "==================================================================="
	@echo ""
	@echo "--- MUL (standard multiplier) ---"
	@$(MAKE) clean
	@$(MAKE) run TEST=comparison MODE=1 VCD_FILE=comparison_mul.vcd
	@echo ""
	@echo "--- MULE (efficient multiplier) ---"
	@$(MAKE) clean
	@$(MAKE) run TEST=comparison MODE=2 VCD_FILE=comparison_mule.vcd
	@echo ""
	@echo "==================================================================="
	@echo "VCD files generated:"
	@echo "  - comparison_mul.vcd  (MODE=1 - standard MUL)"
	@echo "  - comparison_mule.vcd (MODE=2 - efficient MULE)"
	@echo ""
	@echo "Open both in GTKWave to compare timing:"
	@echo "  gtkwave comparison_mul.vcd comparison_mule.vcd"
	@echo "==================================================================="

latency:
	@echo "==================================================================="
	@echo "Running LATENCY HIDING test"
	@echo "==================================================================="
	@echo ""
	@echo "--- MUL (MODE=1) ---"
	@$(MAKE) clean
	@$(MAKE) run TEST=latency_hiding MODE=1 VCD_FILE=latency_mul.vcd
	@echo ""
	@echo "--- MULE (MODE=2) ---"
	@$(MAKE) clean
	@$(MAKE) run TEST=latency_hiding MODE=2 VCD_FILE=latency_mule.vcd
	@echo ""
	@echo "--- CBM (MODE=3) ---"
	@$(MAKE) clean
	@$(MAKE) run TEST=latency_hiding MODE=3 VCD_FILE=latency_cbm.vcd
	@echo ""
	@echo "VCD files: latency_mul.vcd, latency_mule.vcd, latency_cbm.vcd"
	@echo "==================================================================="

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o *.elf *.dump

help:
	@echo "Usage:"
	@echo "  make run TEST=<test> MODE=<mode> VCD_FILE=<file>"
	@echo ""
	@echo "Tests:"
	@echo "  comparison     - Side-by-side bad vs good case"
	@echo "  latency_hiding - Comprehensive latency hiding demo"
	@echo ""
	@echo "Modes:"
	@echo "  MODE=1 - MUL  (standard multiplier)"
	@echo "  MODE=2 - MULE (efficient multiplier)"
	@echo "  MODE=3 - CBM  (column bypass multiplier)"
	@echo ""
	@echo "Quick commands:"
	@echo "  make compare  - Run comparison test with MUL and MULE"
	@echo "  make latency  - Run all three modes for latency hiding test"
	@echo ""
	@echo "Examples:"
	@echo "  make run TEST=comparison MODE=1 VCD_FILE=mul.vcd"
	@echo "  make run TEST=comparison MODE=2 VCD_FILE=mule.vcd"
