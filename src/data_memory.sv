`define DATA_WIDTH 32

module data_memory #(
    parameter MEM_SIZE = 1024
) (
    // INPUT
    input wire i_clk,
    input wire i_we,
    input wire [`DATA_WIDTH-1:0] i_data,
    input wire [$clog2(MEM_SIZE)-1:0] i_addr,
    // OUTPUT
    output logic [`DATA_WIDTH-1:0] o_data
);

    logic [`DATA_WIDTH-1:0] memory [MEM_SIZE / 4];
    logic [$clog2(MEM_SIZE)-3:0] shifted_addr;

    assign shifted_addr = i_addr[$clog2(MEM_SIZE)-1:2]; // Shift right by 2 bits for word addressing

    always_ff @(posedge i_clk) begin
        if (i_we) begin
            memory[shifted_addr] <= i_data; // Update memory at the address with the input data
        end
    end

    always_ff @(posedge i_clk) begin
        if (i_we) begin
            o_data <= i_data; // Output the data being written
        end
        else begin
            o_data <= memory[shifted_addr]; // Output the data at the address
        end
    end

endmodule