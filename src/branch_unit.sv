`include "src/definitions.vh"

module branch_unit (
    // INPUT
    input wire i_branch,
    input wire [2:0] i_branch_op,
    input wire [`DATA_WIDTH-1:0] i_a,
    input wire [`DATA_WIDTH-1:0] i_b,
    // OUTPUT
    output reg o_take
);

    always_comb begin
        o_take = 1'b0; // Default to not taking the branch

        if (i_branch) begin
            case (i_branch_op)
                `BRANCH_BEQ:      o_take = (i_a == i_b); // Branch if equal
                `BRANCH_BNE:      o_take = (i_a != i_b); // Branch if not equal
                `BRANCH_BLT:      o_take = ($signed(i_a) < $signed(i_b)); // Branch if less than (signed)
                `BRANCH_BGE:      o_take = ($signed(i_a) >= $signed(i_b)); // Branch if greater than or equal (signed)
                `BRANCH_BLTU:     o_take = (i_a < i_b); // Branch if less than (unsigned)
                `BRANCH_BGEU:     o_take = (i_a >= i_b); // Branch if greater than or equal (unsigned)
                `BRANCH_JAL_JALR: o_take = 1'b1; // Always take for JAL and JALR
                default:          o_take = 1'b0; // Default to not taking the branch for safety
            endcase
        end
    end

endmodule