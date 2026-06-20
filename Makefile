# ==============================================================================
# RISC-V CPU Development Makefile (True Windows Native)
# ==============================================================================

VC = iverilog
VVP = vvp
FLAGS = -g2012

SRC_DIR = src
SIM_DIR = sim
OUT_DIR = sim/out

# Module Definitions
# Arithmetic Logic Unit (ALU)
ALU_SRC = $(SRC_DIR)/alu.sv
ALU_TB  = $(SIM_DIR)/alu_tb.sv
ALU_OUT = $(OUT_DIR)/alu_sim.exe
ALU_VCD = $(OUT_DIR)/alu_waves.vcd

# Sign Extension Unit (SEU)
SEU_SRC = $(SRC_DIR)/sign_extension.sv
SEU_TB  = $(SIM_DIR)/sign_extension_tb.sv
SEU_OUT = $(OUT_DIR)/sign_ext_sim.exe
SEU_VCD = $(OUT_DIR)/sign_ext_waves.vcd

# Register File (REG)
REG_SRC = $(SRC_DIR)/reg_file.sv
REG_TB  = $(SIM_DIR)/reg_file_tb.sv
REG_OUT = $(OUT_DIR)/reg_file_sim.exe
REG_VCD = $(OUT_DIR)/reg_file_waves.vcd

# Data Memory (DM)
DM_SRC = $(SRC_DIR)/data_memory.sv
DM_TB  = $(SIM_DIR)/data_memory_tb.sv
DM_OUT = $(OUT_DIR)/data_mem_sim.exe
DM_VCD = $(OUT_DIR)/data_mem_waves.vcd

# Decoder (DECODER)
DECODER_SRC = $(SRC_DIR)/decoder.sv
DECODER_TB  = $(SIM_DIR)/decoder_tb.sv
DECODER_OUT = $(OUT_DIR)/decoder_sim.exe
DECODER_VCD = $(OUT_DIR)/decoder_waves.vcd

# Branch Unit (BRANCH)
BRANCH_SRC = $(SRC_DIR)/branch_unit.sv
BRANCH_TB  = $(SIM_DIR)/branch_unit_tb.sv
BRANCH_OUT = $(OUT_DIR)/branch_unit_sim.exe
BRANCH_VCD = $(OUT_DIR)/branch_unit_waves.vcd

all: alu seu reg dm decoder branch

# --- ALU Targets ---
alu: $(ALU_SRC) $(ALU_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running ALU Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(ALU_OUT) $(ALU_SRC) $(ALU_TB)
	$(VVP) $(ALU_OUT)

alu-waves: alu
	gtkwave $(ALU_VCD) &

# --- SEU Targets ---
seu: $(SEU_SRC) $(SEU_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running Sign Extension Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(SEU_OUT) $(SEU_SRC) $(SEU_TB)
	$(VVP) $(SEU_OUT)

seu-waves: seu
	gtkwave $(SEU_VCD) &

# --- Register File Targets ---
reg: $(REG_SRC) $(REG_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running Register File Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(REG_OUT) $(REG_SRC) $(REG_TB)
	$(VVP) $(REG_OUT)

reg-waves: reg
	gtkwave $(REG_VCD) &

# --- Data Memory Targets ---
dm: $(DM_SRC) $(DM_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running Data Memory Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(DM_OUT) $(DM_SRC) $(DM_TB)
	$(VVP) $(DM_OUT)

dm-waves: dm
	gtkwave $(DM_VCD) &

# --- Decoder Targets ---
decoder: $(DECODER_SRC) $(DECODER_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running Decoder Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(DECODER_OUT) $(DECODER_SRC) $(DECODER_TB)
	$(VVP) $(DECODER_OUT)

decoder-waves: decoder
	gtkwave $(DECODER_VCD) &

# --- Branch Unit Targets ---
branch: $(BRANCH_SRC) $(BRANCH_TB)
	@echo --------------------------------------------------
	@echo Compiling and Running Branch Unit Testbench...
	@echo --------------------------------------------------
	@if not exist "sim\out" mkdir "sim\out"
	$(VC) $(FLAGS) -o $(BRANCH_OUT) $(BRANCH_SRC) $(BRANCH_TB)
	$(VVP) $(BRANCH_OUT)

branch-waves: branch
	gtkwave $(BRANCH_VCD) &

clean:
	@echo Cleaning up project directory...
	@if exist "sim\out" rmdir /s /q "sim\out"
	@del /f /q *.vvp *_sim *_sim.exe *.vcd 2>nul || exit 0

.PHONY: all alu alu-waves seu seu-waves reg reg-waves dm dm-waves decoder decoder-waves branch branch-waves clean