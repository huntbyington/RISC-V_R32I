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

all: alu seu reg

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

clean:
	@echo Cleaning up project directory...
	@if exist "sim\out" rmdir /s /q "sim\out"
	@del /f /q *.vvp *_sim *_sim.exe *.vcd 2>nul || exit 0

.PHONY: all alu alu-waves seu seu-waves reg reg-waves clean