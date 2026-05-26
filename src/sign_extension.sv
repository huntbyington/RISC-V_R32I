// RISC-V Base Instruction Set Opcodes
`define OPCODE 7
`define OP_LUI     7'b0110111 // Load Upper Immediate - U-Type
`define OP_AUIPC   7'b0010111 // Add Upper Immediate to PC - U-Type
`define OP_JAL     7'b1101111 // Jump and Link - J-Type 
`define OP_BRANCH  7'b1100011 // Branch Instructions (BEQ, BNE, BLT, etc.)- B-Type
`define OP_STORE   7'b0100011 // Store Instructions (SB, SH, SW) - S-Type
`define OP_ALU     7'b0110011 // ALU Instructions (ADD, SUB, AND, OR, XOR, etc.) - R-Type
`define OP_JALR    7'b1100111 // Jump and Link Register - I-Type
`define OP_LOAD    7'b0000011 // Load Instructions (LB, LH, LW, LBU, LHU) - I-Type
`define OP_ALUI    7'b0010011 // ALU Immediate Instructions (ADDI, ANDI, ORI, XORI, etc.) - I-Type

module sign_extension #(parameter INST_WIDTH = 32) (
    // INPUT
    input wire [INST_WIDTH-1:0]    i_inst,       
    input wire [`OPCODE-1:0]        i_opcode,
    // OUTPUT
    output reg [INST_WIDTH-1:0]    o_immediate_extended
);

    always @(*) begin
        case (i_opcode)
            `OP_ALU: begin
                // R-Type: No immediate, so output is zero-extended
                o_immediate_extended = 0;
            end
            `OP_JALR, `OP_LOAD, `OP_ALUI: begin
                // I-Type: Immediate is bits [31:20], sign-extended
                o_immediate_extended = {{20{i_inst[31]}}, i_inst[31:20]};
            end
            `OP_STORE: begin
                // S-Type: Immediate is bits [31:25] and [11:7], sign-extended
                o_immediate_extended = {{20{i_inst[31]}}, i_inst[31:25], i_inst[11:7]};
            end
            `OP_BRANCH: begin
                // B-Type: Immediate is bits [31], [7], [30:25], [11:8], sign-extended
                o_immediate_extended = {{20{i_inst[31]}}, i_inst[31], i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0};
            end
            `OP_LUI, `OP_AUIPC: begin
                // U-Type: Immediate is bits [31:12], sign-extended
                o_immediate_extended = {i_inst[31:12], 12'b0};
            end
            `OP_JAL: begin
                // J-Type: Immediate is bits [31], [19:12], [20], [30:21], sign-extended
                o_immediate_extended = {{11{i_inst[31]}}, i_inst[31], i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0};
            end
            default: begin
                // For other opcodes, the immediate is sign-extended based on the instruction format
                o_immediate_extended = 0; // Default case, will be overridden in the next always block
            end
        endcase
    end

endmodule