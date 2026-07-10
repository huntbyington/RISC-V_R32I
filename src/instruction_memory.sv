`include "src/definitions.vh"

module instruction_memory (
    // INPUT
    input wire clk,
    input wire [$clog2(`INST_MEM_SIZE)-1:0] addr,
    // OUTPUT
    output reg [`INST_WIDTH-1:0] inst
);

    // Instruction Memory Array Declaration
    reg [`INST_WIDTH-1:0] memory [`INST_MEM_SIZE / 4];

    // Synchronous Read Operation
    always_ff @(posedge clk) begin
        inst <= memory[addr[$clog2(`INST_MEM_SIZE)-1:2]]; // Shift right by 2 bits for word addressing
    end
  
endmodule