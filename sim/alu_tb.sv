`timescale 1ns/1ps

module alu_tb;
    logic [5:0] i_alu_op;
    logic [31:0] i_a, i_b;
    logic [31:0] o_c;

    logic [31:0] expected_c;
    integer error_count = 0;

    alu DUT (
        .i_alu_op(i_alu_op),
        .i_a(i_a),
        .i_b(i_b),
        .o_c(o_c)
    );

    // RISC-V ALU Operations
    localparam [5:0] OP_ALU_ADD    = 6'b011001; // Add
    localparam [5:0] OP_ALU_SUB    = 6'b011011; // Subtract
    localparam [5:0] OP_ALU_AND    = 6'b011101; // Bitwise AND
    localparam [5:0] OP_ALU_OR     = 6'b011111; // Bitwise OR
    localparam [5:0] OP_ALU_XOR    = 6'b100001; // Bitwise XOR
    localparam [5:0] OP_ALU_SLT    = 6'b100011; // Set Less Than (signed)
    localparam [5:0] OP_ALU_SLTU   = 6'b100101; // Set Less Than (unsigned)
    localparam [5:0] OP_ALU_SLL    = 6'b100111; // Shift Left Logical
    localparam [5:0] OP_ALU_SRL    = 6'b101001; // Shift Right Logical
    localparam [5:0] OP_ALU_SRA    = 6'b101011; // Shift Right Arithmetic

    initial begin
        $dumpfile("alu_waves.vcd");
        $dumpvars(0, alu_tb);

        $display("==================================================");
        $display("STARTING AUTOMATED ALU TESTS");
        $display("==================================================");

        // ADD
        i_a = 32'h0000000F; i_b = 32'h00000001; i_alu_op = OP_ALU_ADD; expected_c = 32'h00000010; #10;
        if (o_c !== expected_c) begin $display("FAIL: ADD -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // SUB
        i_a = 32'h0000000F; i_b = 32'h00000001; i_alu_op = OP_ALU_SUB; expected_c = 32'h0000000E; #10;
        if (o_c !== expected_c) begin $display("FAIL: SUB -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // AND
        i_a = 32'h0000000F; i_b = 32'h00000001; i_alu_op = OP_ALU_AND; expected_c = 32'h00000001; #10;
        if (o_c !== expected_c) begin $display("FAIL: AND -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // OR
        i_a = 32'h0000000F; i_b = 32'h00000001; i_alu_op = OP_ALU_OR; expected_c = 32'h0000000F; #10;
        if (o_c !== expected_c) begin $display("FAIL: OR -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // XOR
        i_a = 32'h0000000F; i_b = 32'h00000001; i_alu_op = OP_ALU_XOR; expected_c = 32'h0000000E; #10;
        if (o_c !== expected_c) begin $display("FAIL: XOR -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // Edge Cases (Zero, Overflow)        
        // Zero Check
        i_a = 32'h0; i_b = 32'h0; i_alu_op = OP_ALU_ADD; expected_c = 32'h0; #10;
        if (o_c !== expected_c) begin $display("FAIL: Zero -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // Overflow Wrap-around Check
        i_a = 32'hFFFFFFFF; i_b = 32'h1; i_alu_op = OP_ALU_ADD; expected_c = 32'h0; #10;
        if (o_c !== expected_c) begin $display("FAIL: Overflow -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // Completing Coverage (Shifts & Comparisons)
        // SLL (Shift Left Logical): 0xF << 4 = 0xF0
        i_a = 32'h0000000F; i_b = 32'd4; i_alu_op = OP_ALU_SLL; expected_c = 32'h000000F0; #10;
        if (o_c !== expected_c) begin $display("FAIL: SLL -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // SRL (Shift Right Logical): 0xF0 >> 4 = 0xF
        i_a = 32'h000000F0; i_b = 32'd4; i_alu_op = OP_ALU_SRL; expected_c = 32'h0000000F; #10;
        if (o_c !== expected_c) begin $display("FAIL: SRL -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // SRA (Shift Right Arithmetic): MSB is preserved (Sign extension)
        // 0x80000000 >>> 4 = 0xF8000000
        i_a = 32'h80000000; i_b = 32'd4; i_alu_op = OP_ALU_SRA; expected_c = 32'hF8000000; #10;
        if (o_c !== expected_c) begin $display("FAIL: SRA -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // SLT (Set Less Than - Signed): Is -5 < 10? Yes (Result = 1)
        i_a = 32'hFFFFFFFB; i_b = 32'd10; i_alu_op = OP_ALU_SLT; expected_c = 32'h1; #10;
        if (o_c !== expected_c) begin $display("FAIL: SLT -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        // SLTU (Set Less Than - Unsigned): Is 0xFFFFFFFF < 10? No (Result = 0)
        i_a = 32'hFFFFFFFF; i_b = 32'd10; i_alu_op = OP_ALU_SLTU; expected_c = 32'h0; #10;
        if (o_c !== expected_c) begin $display("FAIL: SLTU -> Expected %h, Got %h", expected_c, o_c); error_count++; end

        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: ALL ALU TESTS PASSED COMPLETELY!");
        end else begin
            $display("  FAILURE: %0d ALU test cases failed. Check logs.", error_count);
        end
        $display("==================================================");
        
        $finish;
    end
endmodule