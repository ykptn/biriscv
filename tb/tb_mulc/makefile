###############################################################################
# ELF and Toolchain
###############################################################################
ELF_FILE ?= test_mulc.elf

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

###############################################################################
# Defaults
###############################################################################
TRACE ?= 1
TOP   ?= tb_mulc

SRC_V_DIR ?= ../../src/core .
SRC_V_EXTRA = ../tb_mul/tcm_mem.v ../tb_mul/tcm_mem_ram.v
SRC_V      = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v)) $(SRC_V_EXTRA)
EXE       ?= output.out
BUILD_DIR ?= build/

###############################################################################
# Verilog compile flags
###############################################################################
VFLAGS  += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS  += -DTRACE=$(TRACE)
VFLAGS  += -Dverilog_sim

###############################################################################
# Rules
###############################################################################
all: run

$(BUILD_DIR):
	@mkdir -p $@

test_mulc.o: test_mulc.s
	$(AS) -march=rv32im -mabi=ilp32 test_mulc.s -o test_mulc.o

$(ELF_FILE): test_mulc.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) test_mulc.o

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (MULC test)"
	iverilog $(VFLAGS) -s $(TOP) -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)
