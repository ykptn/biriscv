###############################################################################
# 4-Multiplier Compare Testbench
###############################################################################
ELF_FILE ?= test_mul_compare4.elf

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump
NM      = riscv64-unknown-elf-nm

###############################################################################
# Defaults
###############################################################################
TRACE   ?= 1
MODE    ?= 0
VCD_FILE ?= waveform.vcd

SRC_V_DIR ?= ../../src/core .
EXE       ?= output.out
BUILD_DIR ?= build/

###############################################################################
# Verilog sources
###############################################################################
SRC_V = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v))

VFLAGS  += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS  += -DTRACE=$(TRACE)
VFLAGS  += -Dverilog_sim

###############################################################################
# Rules
###############################################################################
all: run

$(BUILD_DIR):
	@mkdir -p $@

###############################################################################
# Assemble + Link
###############################################################################
test_mul_compare4.o: test_mul_compare4.s
	$(AS) -march=rv32im -mabi=ilp32 --defsym MODE=$(MODE) test_mul_compare4.s -o test_mul_compare4.o

$(ELF_FILE): test_mul_compare4.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) test_mul_compare4.o

###############################################################################
# Disassemble
###############################################################################
dis: $(ELF_FILE)
	$(OBJDUMP) -d $(ELF_FILE)

###############################################################################
# Convert ELF -> TCM binary
###############################################################################
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

###############################################################################
# Verilog Compilation
###############################################################################
$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (4-MUL compare)"
	iverilog $(VFLAGS) -o $@ $(SRC_V)

###############################################################################
# Run – auto-extract PASS_PC / FAIL_PC from ELF symbol table
###############################################################################
run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	$(eval PASS_PC_HEX := $(shell $(NM) $(ELF_FILE) | grep ' pass_loop' | cut -d' ' -f1))
	$(eval FAIL_PC_HEX := $(shell $(NM) $(ELF_FILE) | grep ' fail_loop' | cut -d' ' -f1))
	@echo "PASS_PC = 0x$(PASS_PC_HEX), FAIL_PC = 0x$(FAIL_PC_HEX)"
	vvp $(BUILD_DIR)/$(EXE) -vcd +dumpfile=$(VCD_FILE) +passpc=$(PASS_PC_HEX) +failpc=$(FAIL_PC_HEX)

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)

.PHONY: all run dis clean
