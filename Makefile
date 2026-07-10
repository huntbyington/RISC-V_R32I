VC = iverilog
VVP = vvp
FLAGS = -g2012

SRC_DIR = src
SIM_DIR = sim
OUT_DIR = sim/out

# Module Definitions
ALU_SRC = $(SRC_DIR)/alu.sv
ALU_TB  = $(SIM_DIR)/alu_tb.sv
ALU_OUT = $(OUT_DIR)/alu_sim.exe

IMAGE_SRC = $(SRC_DIR)/sign_extension.sv
IMAGE_TB  = $(SIM_DIR)/sign_extension_tb.sv
IMAGE_OUT = $(OUT_DIR)/sign_ext_sim.exe

REG_SRC = $(SRC_DIR)/reg_file.sv
REG_TB  = $(SIM_DIR)/reg_file_tb.sv
REG_OUT = $(OUT_DIR)/reg_file_sim.exe

DM_SRC  = $(SRC_DIR)/data_memory.sv
DM_TB   = $(SIM_DIR)/data_memory_tb.sv
DM_OUT  = $(OUT_DIR)/data_mem_sim.exe

DECODER_SRC = $(SRC_DIR)/decoder.sv
DECODER_TB  = $(SIM_DIR)/decoder_tb.sv
DECODER_OUT = $(OUT_DIR)/decoder_sim.exe

BRANCH_SRC = $(SRC_DIR)/branch_unit.sv
BRANCH_TB  = $(SIM_DIR)/branch_unit_tb.sv
BRANCH_OUT = $(OUT_DIR)/branch_unit_sim.exe

all: alu image reg dm decoder branch

# Dynamic cross-platform folder creation
$(OUT_DIR):
	@mkdir -p $(OUT_DIR) 2>/dev/null || mkdir "$(OUT_DIR)"

alu: $(ALU_SRC) $(ALU_TB) | $(OUT_DIR)
	@echo "Compiling and Running ALU Testbench..."
	$(VC) $(FLAGS) -o $(ALU_OUT) $(ALU_SRC) $(ALU_TB)
	$(VVP) $(ALU_OUT)

image: $(IMAGE_SRC) $(IMAGE_TB) | $(OUT_DIR)
	@echo "Compiling and Running Sign Extension Testbench..."
	$(VC) $(FLAGS) -o $(IMAGE_OUT) $(IMAGE_SRC) $(IMAGE_TB)
	$(VVP) $(IMAGE_OUT)

reg: $(REG_SRC) $(REG_TB) | $(OUT_DIR)
	@echo "Compiling and Running Register File Testbench..."
	$(VC) $(FLAGS) -o $(REG_OUT) $(REG_SRC) $(REG_TB)
	$(VVP) $(REG_OUT)

dm: $(DM_SRC) $(DM_TB) | $(OUT_DIR)
	@echo "Compiling and Running Data Memory Testbench..."
	$(VC) $(FLAGS) -o $(DM_OUT) $(DM_SRC) $(DM_TB)
	$(VVP) $(DM_OUT)

decoder: $(DECODER_SRC) $(DECODER_TB) | $(OUT_DIR)
	@echo "Compiling and Running Decoder Testbench..."
	$(VC) $(FLAGS) -o $(DECODER_OUT) $(DECODER_SRC) $(DECODER_TB)
	$(VVP) $(DECODER_OUT)

branch: $(BRANCH_SRC) $(BRANCH_TB) | $(OUT_DIR)
	@echo "Compiling and Running Branch Unit Testbench..."
	$(VC) $(FLAGS) -o $(BRANCH_OUT) $(BRANCH_SRC) $(BRANCH_TB)
	$(VVP) $(BRANCH_OUT)

clean:
	@echo "Cleaning up project directory..."
	@rm -rf $(OUT_DIR) *.vvp *_sim *_sim.exe *.vcd 2>/dev/null || (if exist "sim\out" rmdir /s /q "sim\out")

.PHONY: all alu image reg dm decoder branch clean