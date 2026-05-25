# ==============================================================================
# RISC-V CPU Development Makefile (Module-Specific)
# ==============================================================================

# Compiler and simulator engines
VC = iverilog
VVP = vvp
FLAGS = -g2012

# Directories
SRC_DIR = src
SIM_DIR = sim

# ==============================================================================
# MODULE DEFINITIONS
# ==============================================================================
# As you create new modules, define their source and testbench files here.

# Arithmetic Logic Unit (ALU)
ALU_SRC = $(SRC_DIR)/alu.sv
ALU_TB  = $(SIM_DIR)/alu_tb.sv
ALU_OUT = alu_sim
ALU_VCD = sim/alu_waves.vcd

# Example placeholder for your next module (ImmGen)
# IMM_SRC = $(SRC_DIR)/imm_gen.sv
# IMM_TB  = $(SIM_DIR)/imm_gen_tb.sv
# IMM_OUT = imm_sim

# ==============================================================================
# TARGET RULES
# ==============================================================================

# Default target if you just type 'make'
all: alu

# --- ALU Targets ---
# Typing 'make alu' will compile and run the automated ALU testbench
alu: $(ALU_SRC) $(ALU_TB)
	@echo "--------------------------------------------------"
	@echo "Compiling and Running ALU Testbench..."
	@echo "--------------------------------------------------"
	$(VC) $(FLAGS) -o $(ALU_OUT) $(ALU_SRC) $(ALU_TB)
	$(VVP) $(ALU_OUT)

# Typing 'make alu-waves' will run the tests and launch GTKWave
alu-waves: alu
	@echo "Opening ALU visual waveform viewer..."
	gtkwave $(ALU_VCD) &


# --- UTILITY TARGETS ---

# Clean up all compiled simulation binaries and wave logs
clean:
	@echo "Cleaning up project directory..."
	rm -f *_sim
	rm -f sim/*.vcd
	rm -f *.vcd

.PHONY: all alu alu-waves clean