`include "src/definitions.vh"

module alu (
    // INPUT
    input wire [5:0] i_alu_op,
    input wire [`DATA_WIDTH-1:0] i_a,
    input wire [`DATA_WIDTH-1:0] i_b,
    // OUTPUT
    output reg [`DATA_WIDTH-1:0] o_c
);

    always @(*) begin
        case (i_alu_op)
            `OP_ALU_ADD:  o_c = i_a + i_b;
            `OP_ALU_SUB:  o_c = i_a - i_b;
            `OP_ALU_AND:  o_c = i_a & i_b;
            `OP_ALU_OR:   o_c = i_a | i_b;
            `OP_ALU_XOR:  o_c = i_a ^ i_b;
            `OP_ALU_SLT:  o_c = ($signed(i_a) < $signed(i_b)) ? 1 : 0;
            `OP_ALU_SLTU: o_c = (i_a < i_b) ? 1 : 0;
            `OP_ALU_SLL:  o_c = i_a << (i_b[4:0]);
            `OP_ALU_SRL:  o_c = i_a >> (i_b[4:0]);
            `OP_ALU_SRA:  o_c = $signed(i_a) >>> (i_b[4:0]);
            default:      o_c = 0; // Default case
        endcase
    end

endmodule