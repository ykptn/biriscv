###############################################################################
# ELF and Toolchain
###############################################################################
ELF_FILE ?= test_mule_only.elf

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

###############################################################################
# Defaults
###############################################################################
TRACE ?= 1

SRC_V_DIR ?= ../../src/core .
EXE       ?= output_mule_only.out
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
# Assemble + Link ELF using link.ld (correct memory layout)
###############################################################################
test_mule_only.o: test_mule_only.s
	$(AS) -march=rv32im -mabi=ilp32 test_mule_only.s -o test_mule_only.o

$(ELF_FILE): test_mule_only.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) test_mule_only.o

###############################################################################
# Convert ELF → TCM binary
###############################################################################
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

###############################################################################
# Verilog compilation
###############################################################################
$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (MULE-only test)"
	iverilog $(VFLAGS) -s tb_mule_only -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)
