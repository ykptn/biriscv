###############################################################################
# DOT MUL EDP Benchmark Build Rules
###############################################################################
ELF_FILE ?= tb_dot_mul_edp.elf

AS      = riscv64-unknown-elf-as
LD      = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy

TRACE ?= 1

SRC_V_DIR ?= ../../src/core .
SRC_V_EXTRA = ../tb_mul/tcm_mem.v ../tb_mul/tcm_mem_ram.v
SRC_V      = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v)) $(SRC_V_EXTRA)
EXE       ?= output.out
BUILD_DIR ?= build/

VFLAGS  += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS  += -DTRACE=$(TRACE)
VFLAGS  += -Dverilog_sim

all: run

$(BUILD_DIR):
	@mkdir -p $@

tb_dot_mul_edp.o: tb_dot_mul_edp.s
	$(AS) -march=rv32im -mabi=ilp32 $< -o $@

$(ELF_FILE): tb_dot_mul_edp.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $@ tb_dot_mul_edp.o

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (DOT MUL EDP benchmark)"
	iverilog $(VFLAGS) -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)
