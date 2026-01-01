###############################################################################
# Makefile for tb_concept
###############################################################################

RISCV_PREFIX = riscv64-unknown-elf-
AS           = $(RISCV_PREFIX)as
LD           = $(RISCV_PREFIX)ld
OBJCOPY      = $(RISCV_PREFIX)objcopy
OBJDUMP      = $(RISCV_PREFIX)objdump

ASFLAGS      = -march=rv32im -mabi=ilp32
LDFLAGS      = -T link.ld -m elf32lriscv

TARGET       = test_concept
SRC          = $(TARGET).s
OBJ          = $(TARGET).o
ELF          = $(TARGET).elf
BIN          = $(TARGET).bin
DUMP         = $(TARGET).dump
BUILD_DIR    = build
TCM_BIN      = $(BUILD_DIR)/tcm.bin

.PHONY: all clean simulate

all: $(TCM_BIN) $(DUMP)

$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) -o $@ $<

$(ELF): $(OBJ) link.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

$(DUMP): $(ELF)
	$(OBJDUMP) -D $< > $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(TCM_BIN): $(BIN)
	mkdir -p $(BUILD_DIR)
	cp $(BIN) $@

simulate: $(TCM_BIN)
	iverilog -o sim -g2012 \
		-I ../../src/core \
		tb_concept.v \
		tcm_mem.v \
		tcm_mem_ram.v \
		../../src/core/riscv_core.v \
		../../src/core/biriscv_*.v
	./sim
	gtkwave waveform.vcd gtksettings.sav &

clean:
	rm -rf $(OBJ) $(ELF) $(BIN) $(DUMP) sim waveform.vcd $(BUILD_DIR)
