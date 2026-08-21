`ifndef DEFINITIONS_VH
`define DEFINITIONS_VH

// Global System Core Configuration Parameters
`define INST_WIDTH      32  // Fixed bit-width for RISC-V instructions
`define DATA_WIDTH      32  // Standard 32-bit architectural datapath width
`define DATA_MEM_SIZE   16384  // Size of Data Memory in bytes (4096 words)
// 2MB: the riscv-arch-test branch/jump tests (beq/bge/bgeu/blt/bltu/bne/jal)
// compile to ~220KB-1.72MB once RISCOF's full macro-expanded coverage
// content is included, well beyond the original 16KB (jal-01 alone needs
// ~1.72MB). Must stay a power of two -- $clog2(INST_MEM_SIZE) sizes
// instruction_memory's address port, and a non-power-of-two would leave
// part of the declared range unreachable. Keep riscof-env/dut/env/link.ld's
// IMEM LENGTH and riscv_top.sv's `.addr(pc[...])` slice width in sync with
// this.
`define INST_MEM_SIZE   2097152 // Size of Instruction Memory in bytes (524288 words)
`define NUM_REGISTER    32  // Number of elements in the physical Register File
`define OPCODE          7   // Dedicated width of the hardware base opcode field

// RISC-V ALU Operations
`define OP_ALU_ADD    6'b011001 // Add
`define OP_ALU_SUB    6'b011011 // Subtract
`define OP_ALU_AND    6'b011101 // Bitwise AND
`define OP_ALU_OR     6'b011111 // Bitwise OR
`define OP_ALU_XOR    6'b100001 // Bitwise XOR
`define OP_ALU_SLT    6'b100011 // Set Less Than (signed)
`define OP_ALU_SLTU   6'b100101 // Set Less Than (unsigned)
`define OP_ALU_SLL    6'b100111 // Shift Left Logical
`define OP_ALU_SRL    6'b101001 // Shift Right Logical
`define OP_ALU_SRA    6'b101011 // Shift Right Arithmetic

// RISC-V Base Instruction Set Opcodes
`define OP_LUI     7'b0110111 // Load Upper Immediate - U-Type
`define OP_AUIPC   7'b0010111 // Add Upper Immediate to PC - U-Type
`define OP_JAL     7'b1101111 // Jump and Link - J-Type 
`define OP_BRANCH  7'b1100011 // Branch Instructions (BEQ, BNE, BLT, etc.)- B-Type
`define OP_STORE   7'b0100011 // Store Instructions (SB, SH, SW) - S-Type
`define OP_ALU     7'b0110011 // ALU Instructions (ADD, SUB, AND, OR, XOR, etc.) - R-Type
`define OP_JALR    7'b1100111 // Jump and Link Register - I-Type
`define OP_LOAD    7'b0000011 // Load Instructions (LB, LH, LW, LBU, LHU) - I-Type
`define OP_ALUI    7'b0010011 // ALU Immediate Instructions (ADDI, ANDI, ORI, XORI, etc.) - I-Type

// Branch Unit Operation Codes
`define BRANCH_BEQ      3'b000 // Branch Equal
`define BRANCH_BNE      3'b001 // Branch Not Equal
`define BRANCH_BLT      3'b100 // Branch Less Than
`define BRANCH_BGE      3'b101 // Branch Greater Than Or Equal
`define BRANCH_BLTU     3'b110 // Branch Less Than Unsigned
`define BRANCH_BGEU     3'b111 // Branch Greater Than Or Equal Unsigned
`define BRANCH_JAL_JALR 3'b010 // Jump in case of JAL or JALR instrucion

`endif // DEFINITIONS_VH
