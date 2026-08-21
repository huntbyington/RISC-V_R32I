`include "src/definitions.vh"

module data_memory (
    // INPUT
    input wire i_clk,
    input wire i_we,
    input wire [1:0] i_size, // 2'b00=byte, 2'b01=halfword, 2'b10=word
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

    reg [3:0] byte_we;
    always_comb begin
        byte_we = 4'b0000;
        if (i_we) begin
            case (i_size)
                2'b00:   byte_we = 4'b0001 << i_addr[1:0];
                2'b01:   byte_we = i_addr[1] ? 4'b1100 : 4'b0011;
                default: byte_we = 4'b1111; // word
            endcase
        end
    end

    wire [`DATA_WIDTH-1:0] shifted_data = i_data << {i_addr[1:0], 3'b000};

    always_ff @(posedge i_clk) begin
        if (byte_we[0]) memory[shifted_addr][7:0]   <= shifted_data[7:0];
        if (byte_we[1]) memory[shifted_addr][15:8]  <= shifted_data[15:8];
        if (byte_we[2]) memory[shifted_addr][23:16] <= shifted_data[23:16];
        if (byte_we[3]) memory[shifted_addr][31:24] <= shifted_data[31:24];
    end

endmodule