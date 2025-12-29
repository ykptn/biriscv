###############################################################################
# ELF and Toolchain
###############################################################################
ELF_FILE ?= test_dual_mul.elf

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

###############################################################################
# Defaults
###############################################################################
TRACE ?= 1

SRC_V_DIR ?= ../../src/core ../../src/tcm
EXE       ?= output.out
BUILD_DIR ?= build/

###############################################################################
# Verilog sources
###############################################################################
SRC_V = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v))
SRC_V += tb_dual_mul.v

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
# Assemble + Link ELF using link.ld
###############################################################################
test_dual_mul.o: test_dual_mul.s
	$(AS) -march=rv32im -mabi=ilp32 test_dual_mul.s -o test_dual_mul.o

$(ELF_FILE): test_dual_mul.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) test_dual_mul.o

###############################################################################
# Convert ELF → TCM binary
###############################################################################
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

###############################################################################
# Verilog compilation
###############################################################################
$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (Dual MUL test)"
	iverilog $(VFLAGS) -o $@ tb_dual_mul.v $(filter-out tb_dual_mul.v, $(SRC_V))

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)

.PHONY: all run clean
