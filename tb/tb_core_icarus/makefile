###############################################################################
# Variables: Program ELF
###############################################################################
ELF_FILE ?= test.elf
ELF_SRC  ?= test_mule.s

AS      := riscv64-unknown-elf-as
LD      := riscv64-unknown-elf-ld
OBJCOPY ?= riscv64-unknown-elf-objcopy
ifeq ($(shell which $(OBJCOPY)),)
  ${error $(OBJCOPY) missing from PATH}
endif
ifeq ($(shell which iverilog),)
  ${error iverilog missing from PATH - Icarus Verilog required}
endif
ASFLAGS ?= -march=rv32im -mabi=ilp32
LDFLAGS ?= -m elf32lriscv -Ttext 0x80000000


###############################################################################
# Variables: Defaults
###############################################################################
TRACE          ?= 1

SRC_V_DIR      ?= ../../src/core .
SRC_DIR        ?= .

EXE            ?= output.out

###############################################################################
# Variables: Verilog
###############################################################################
SRC_V       ?= $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v))

VFLAGS      += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS      += -DTRACE=$(TRACE)
VFLAGS      += -Dverilog_sim

###############################################################################
# Variables: Lists of objects, source and deps
###############################################################################
BUILD_DIR      ?= build/
ELF_OBJ        := $(BUILD_DIR)/test_program.o

###############################################################################
# Rules
###############################################################################
all: run

$(BUILD_DIR):
	@mkdir -p $@

$(ELF_OBJ): $(ELF_SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) $< -o $@

$(ELF_FILE): $(ELF_OBJ)
	$(LD) $(LDFLAGS) $< -o $@

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $< -O binary $@

$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling verilog"
	iverilog $(VFLAGS) -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd

view:
	gtkwave waveform.vcd gtksettings.sav  

clean:
	rm -rf $(BUILD_DIR) *.vcd
