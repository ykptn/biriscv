###############################################################################
# Generic benchmark runner build rules
###############################################################################
ELF_FILE ?= matmul_absorbtion.elf

CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy

TRACE ?= 1

SRC_V_DIR ?= ../../src/core .
SRC_V_EXTRA = ../tb_mul/tcm_mem.v ../tb_mul/tcm_mem_ram.v
SRC_V = $(foreach src,$(SRC_V_DIR),$(wildcard $(src)/*.v)) $(SRC_V_EXTRA)
EXE ?= output.out
BUILD_DIR ?= build/

BENCH_SRC ?= ../matmul_absorbtion\ test/matmul.c
STARTUP_SRC ?= start.S
SUPPORT_SRC ?= bench_stdio_stub.c

CFLAGS ?= -march=rv32im -mabi=ilp32 -O2 -ffreestanding -fno-builtin -fno-common -msmall-data-limit=0 -I. -DMATMUL_DISABLE_STDIO
LDFLAGS ?= -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -Wl,-Tlink.ld -Wl,--gc-sections

VFLAGS += $(patsubst %,-I%,$(SRC_V_DIR))
VFLAGS += -DTRACE=$(TRACE)
VFLAGS += -Dverilog_sim

all: run

$(BUILD_DIR):
	@mkdir -p $@

$(BUILD_DIR)/start.o: $(STARTUP_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@


$(BUILD_DIR)/bench_main.o: $(BENCH_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c "$<" -o $@

$(BUILD_DIR)/bench_support.o: $(SUPPORT_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c "$<" -o $@

$(ELF_FILE): $(BUILD_DIR)/start.o $(BUILD_DIR)/bench_main.o $(BUILD_DIR)/bench_support.o link.ld
	$(CC) $(LDFLAGS) -o $@ $(BUILD_DIR)/start.o $(BUILD_DIR)/bench_main.o $(BUILD_DIR)/bench_support.o -lgcc

$(BUILD_DIR)/tcm.bin: $(ELF_FILE) | $(BUILD_DIR)
	$(OBJCOPY) $(ELF_FILE) -O binary $@

$(BUILD_DIR)/$(EXE): $(SRC_V) | $(BUILD_DIR)
	@echo "# Compiling Verilog (MATMUL absorbtion benchmark)"
	iverilog $(VFLAGS) -o $@ $(SRC_V)

run: $(BUILD_DIR)/$(EXE) $(BUILD_DIR)/tcm.bin
	vvp $(BUILD_DIR)/$(EXE) -vcd | tee run.log

clean:
	rm -rf $(BUILD_DIR) *.vcd $(ELF_FILE) run.log