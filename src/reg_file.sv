`define NUM_REGISTER 32

module register_file #(parameter DATA_WIDTH = 32) (
	// INPUT
    input wire i_clk,
    input wire i_rst,
    input wire i_we,
	input wire [DATA_WIDTH-1:0] i_rd,
    input wire [$clog2(`NUM_REGISTER)-1:0] i_rd_addr,
    input wire [$clog2(`NUM_REGISTER)-1:0] i_rs1_addr,     
    input wire [$clog2(`NUM_REGISTER)-1:0] i_rs2_addr,
	// OUTPUT
    output wire [DATA_WIDTH-1:0] o_rs1,     
    output wire [DATA_WIDTH-1:0] o_rs2
);

    // Register file: 32 registers, each 32 bits wide
    reg [31:0] registers [31:0];

    // Write to register file on asynchronously
    assign o_rs1 = (i_rs1_addr == 0) ? 32'h0 : registers[i_rs1_addr];
    assign o_rs2 = (i_rs2_addr == 0) ? 32'h0 : registers[i_rs2_addr];

    always @(posedge i_clk) begin
        if (!i_rst) begin
            // Reset all registers to zero
            integer i;
            for (i = 0; i < `NUM_REGISTER; i = i + 1) begin
                registers[i] <= 32'h0;
            end
        end else if (i_we && i_rd_addr != 0) begin
            // Write to register file (except x0 which is always zero)
            registers[i_rd_addr] <= i_rd;
        end
    end

endmodule