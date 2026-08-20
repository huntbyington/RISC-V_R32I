`include "src/definitions.vh"

module data_memory (
    // INPUT
    input wire i_clk,
    input wire i_we,
    input wire [`DATA_WIDTH-1:0] i_data,
    input wire [$clog2(`DATA_MEM_SIZE)-1:0] i_addr,
    // OUTPUT
    output wire [`DATA_WIDTH-1:0] o_data
);

    reg [`DATA_WIDTH-1:0] memory [`DATA_MEM_SIZE / 4];
    wire [$clog2(`DATA_MEM_SIZE)-3:0] shifted_addr;

    assign shifted_addr = i_addr[$clog2(`DATA_MEM_SIZE)-1:2]; // Shift right by 2 bits for word addressing

    // Updates o_data with the value stored in memory at the shifted address for single-cycle read access
    assign o_data = memory[shifted_addr];

    always_ff @(posedge i_clk) begin
        if (i_we) begin
            memory[shifted_addr] <= i_data; // Update memory at the address with the input data
        end
    end

endmodule