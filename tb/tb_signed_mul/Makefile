###############################################################################
# Signed MUL diagnostic build rules
###############################################################################
ELF_FILE ?= tb_signed_mul.elf

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

###############################################################################
# Assemble + Link ELF
###############################################################################
tb_signed_mul.o: tb_signed_mul.s
	$(AS) -march=rv32im -mabi=ilp32 tb_signed_mul.s -o tb_signed_mul.o

$(ELF_FILE): tb_signed_mul.o link.ld
	$(LD) -m elf32lriscv -T link.ld -o $(ELF_FILE) tb_signed_mul.o

###############################################################################
# Convert ELF → binary
###############################################################################
$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

###############################################################################
# Verilog compilation
###############################################################################
$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (signed MUL diagnostics)"
	iverilog $(VFLAGS) -s tb_signed_mul -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

clean:
	rm -rf $(BUILD_DIR) *.vcd *.o $(ELF_FILE)
