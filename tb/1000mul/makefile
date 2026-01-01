###############################################################################
# 1000 MULE operations testbench
###############################################################################

ELF_FILE ?= test_1000mul.elf
EXE      ?= output_1000mul.out
BUILD_DIR ?= build/
TRACE ?= 1

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

SRC_V_DIR ?= ../../src/core
SRC_V = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v))
SRC_V += tb_1000mul.v tcm_mem.v tcm_mem_ram.v

VFLAGS  += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS  += -DTRACE=$(TRACE)
VFLAGS  += -Dverilog_sim

all: run

$(BUILD_DIR):
	@mkdir -p $@

# Assemble + link
$(ELF_FILE:.elf=.o): test_1000mul.s
	$(AS) -march=rv32im -mabi=ilp32 test_1000mul.s -o $(ELF_FILE:.elf=.o)

$(ELF_FILE): $(ELF_FILE:.elf=.o) link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) $(ELF_FILE:.elf=.o)

# Convert ELF to binary
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

# Compile Verilog
$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (1000mul testbench)"
	iverilog $(VFLAGS) -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o *.elf

.PHONY: all run clean
