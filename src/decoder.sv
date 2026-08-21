`include "src/definitions.vh"

module decoder (    
    // INPUT
    input wire [`INST_WIDTH-1:0] i_inst,
    // OUTPUT
    output wire [`OPCODE-1:0] o_opcode,
    output reg o_branch,
    output reg [1:0] o_result_mux,  // ALU = 2'b00, PC+4 = 2'b01, DATA_MEM = 2'b10
    output reg [2:0] o_branch_op,
    output reg o_mem_write,
    output reg o_alu_src_a,         // 1'b1 = REG_A, 1'b0 = PC
    output reg o_alu_src_b,         // 1'b1 = REG_B, 1'b0 = IMME
    output reg o_reg_write,    
    output reg [5:0] o_alu_op,
    output wire [$clog2(`NUM_REGISTER) - 1: 0] o_rs1_addr,
    output wire [$clog2(`NUM_REGISTER) - 1: 0] o_rs2_addr,
    output wire [$clog2(`NUM_REGISTER) - 1: 0] o_rd_addr    
);

    assign o_opcode = i_inst[6:0];
    assign o_rd_addr = i_inst[11:7];    
    assign o_rs1_addr = (o_opcode == `OP_LUI) ? 5'b0 : i_inst[19:15];
    assign o_rs2_addr = i_inst[24:20];
    assign o_branch = (o_opcode == `OP_BRANCH || o_opcode == `OP_JAL || o_opcode == `OP_JALR) ? 1'b1 : 1'b0;

    // Pulling these out as wires to avoid repeated indexing of i_inst in multiple always_comb blocks
    wire [2:0] funct3 = i_inst[14:12];
    wire       funct7_bit30 = i_inst[30];

    always_comb begin
        o_result_mux = 2'b00; // Default to ALU result

        if (o_opcode == `OP_JAL || o_opcode == `OP_JALR) begin
            o_result_mux = 2'b01; // PC + 4 for JAL and JALR
        end else if (o_opcode == `OP_LOAD) begin
            o_result_mux = 2'b10; // Data Memory for LOAD instructions
        end
    end

    always_comb begin
        o_branch_op = 3'b000; // Default to BEQ

        if (o_opcode == `OP_BRANCH) begin
            case (funct3) // Used the wire here
                3'b000:  o_branch_op = `BRANCH_BEQ;
                3'b001:  o_branch_op = `BRANCH_BNE;
                3'b100:  o_branch_op = `BRANCH_BLT;
                3'b101:  o_branch_op = `BRANCH_BGE;
                3'b110:  o_branch_op = `BRANCH_BLTU;
                3'b111:  o_branch_op = `BRANCH_BGEU;
                default: o_branch_op = `BRANCH_BEQ; // Default to BEQ for safety
            endcase
        end else if (o_opcode == `OP_JAL || o_opcode == `OP_JALR) begin
            o_branch_op = `BRANCH_JAL_JALR;
        end
    end

    assign o_mem_write = (o_opcode == `OP_STORE) ? 1'b1 : 1'b0;
    assign o_alu_src_a = (o_opcode == `OP_BRANCH || o_opcode == `OP_AUIPC || o_opcode == `OP_JAL) ? 1'b0 : 1'b1;
    assign o_alu_src_b = (o_opcode == `OP_ALU) ? 1'b1 : 1'b0;
    assign o_reg_write = (o_opcode == `OP_ALU   || 
                          o_opcode == `OP_ALUI  || 
                          o_opcode == `OP_LOAD  || 
                          o_opcode == `OP_LUI   || 
                          o_opcode == `OP_AUIPC || 
                          o_opcode == `OP_JAL   || 
                          o_opcode == `OP_JALR) ? 1'b1 : 1'b0;

    always_comb begin
        o_alu_op = `OP_ALU_ADD; // Default to ADD for safety

        if (o_opcode == `OP_ALU || o_opcode == `OP_ALUI) begin
            case (funct3)
                3'b000:  o_alu_op = (o_opcode == `OP_ALU && funct7_bit30) ? `OP_ALU_SUB : `OP_ALU_ADD; // ADD/ADDI vs SUB (SUB is R-type only)
                3'b001:  o_alu_op = `OP_ALU_SLL;
                3'b010:  o_alu_op = `OP_ALU_SLT;
                3'b011:  o_alu_op = `OP_ALU_SLTU;
                3'b100:  o_alu_op = `OP_ALU_XOR;
                3'b101:  o_alu_op = funct7_bit30 ? `OP_ALU_SRA : `OP_ALU_SRL; // SRL/SRLI vs SRA/SRAI
                3'b110:  o_alu_op = `OP_ALU_OR;
                3'b111:  o_alu_op = `OP_ALU_AND;
                default: o_alu_op = `OP_ALU_ADD;
            endcase
        end else if (o_opcode == `OP_AUIPC || o_opcode == `OP_JAL || o_opcode == `OP_JALR) begin
            o_alu_op = `OP_ALU_ADD; 
        end else if (o_opcode == `OP_LOAD || o_opcode == `OP_STORE || o_opcode == `OP_LUI) begin
            o_alu_op = `OP_ALU_ADD; 
        end
    end

endmodule