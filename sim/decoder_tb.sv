`timescale 1ns/1ps
`include "src/definitions.vh"

module decoder_tb;

    // Signal Declarations
    logic [`INST_WIDTH-1:0] i_inst;
    
    wire [`OPCODE-1:0] o_opcode;
    wire o_branch;
    wire [1:0] o_result_mux;
    wire [2:0] o_branch_op;
    wire o_mem_write;
    wire o_alu_src_a;
    wire o_alu_src_b;
    wire o_reg_write;
    wire [5:0] o_alu_op;
    wire [$clog2(`NUM_REGISTER) - 1: 0] o_rs1_addr;
    wire [$clog2(`NUM_REGISTER) - 1: 0] o_rs2_addr;
    wire [$clog2(`NUM_REGISTER) - 1: 0] o_rd_addr;

    integer error_count = 0;

    // Device Under Test (DUT) Instantiation
    decoder DUT (
        .i_inst(i_inst),
        .o_opcode(o_opcode),
        .o_branch(o_branch),
        .o_result_mux(o_result_mux),
        .o_branch_op(o_branch_op),
        .o_mem_write(o_mem_write),
        .o_alu_src_a(o_alu_src_a),
        .o_alu_src_b(o_alu_src_b),
        .o_reg_write(o_reg_write),
        .o_alu_op(o_alu_op),
        .o_rs1_addr(o_rs1_addr),
        .o_rs2_addr(o_rs2_addr),
        .o_rd_addr(o_rd_addr)
    );

    // Test Vector Pipeline
    initial begin
        $dumpfile("sim/out/decoder_waves.vcd");
        $dumpvars(0, decoder_tb);

        $display("==================================================");
        $display("STARTING AUTOMATED DECODER VERIFICATION");
        $display("==================================================");

        // ------------------------------------------------
        // TEST 1: All Instruction Fields Zero -> Static Outputs
        // ------------------------------------------------
        i_inst = 32'h00000000; #10;

        if (o_opcode !== 7'b0000000) begin
            $display("FAIL: Static Opcode Mismatch! Expected 0000000, Got %b", o_opcode);
            error_count++;
        end
        if (o_rs1_addr !== 5'd0 || o_rs2_addr !== 5'd0 || o_rd_addr !== 5'd0) begin
            $display("FAIL: Static Address Routing Mismatch! rs1=%d, rs2=%d, rd=%d", o_rs1_addr, o_rs2_addr, o_rd_addr);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 2: R-Type Instruction -> add x3, x1, x2
        // ------------------------------------------------
        i_inst = 32'h002081B3; #10;
        
        if (o_opcode !== 7'b0110011) begin
            $display("FAIL: R-Type Opcode Mismatch! Got %b", o_opcode);
            error_count++;
        end
        if (o_reg_write !== 1'b1 || o_alu_src_a !== 1'b0 || o_alu_src_b !== 1'b0 || o_mem_write !== 1'b0 || o_result_mux !== 2'b00 || o_branch !== 1'b0) begin
            $display("FAIL: R-Type Control Path Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP (Should be 4'b0000 zero-extended to 6 bits -> 6'b000000)
        if (o_alu_op !== 6'b000000) begin
            $display("FAIL: R-Type ADD alu_op Mismatch! Expected 6'b000000, Got %b", o_alu_op);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 3: I-Type Instruction -> lw x5, 8(x4)
        // ------------------------------------------------
        i_inst = 32'h00822283; #10;

        if (o_opcode !== 7'b0000011) begin
            $display("FAIL: Load Opcode Mismatch! Got %b", o_opcode);
            error_count++;
        end
        if (o_reg_write !== 1'b1 || o_alu_src_b !== 1'b1 || o_result_mux !== 2'b10) begin
            $display("FAIL: Load Control Path Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP (Loads use address additions)
        if (o_alu_op !== `OP_ALU_ADD) begin
            $display("FAIL: Load Address Calculation alu_op Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 4: S-Type Instruction -> sw x6, 12(x7)
        // ------------------------------------------------
        i_inst = 32'h0063A623; #10;

        if (o_opcode !== 7'b0100011) begin
            $display("FAIL: Store Opcode Mismatch!");
            error_count++;
        end
        if (o_reg_write !== 1'b0 || o_mem_write !== 1'b1 || o_alu_src_b !== 1'b1) begin
            $display("FAIL: Store Control Path Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP
        if (o_alu_op !== `OP_ALU_ADD) begin
            $display("FAIL: Store Address Calculation alu_op Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 5: B-Type Instruction -> beq x8, x9, offset
        // ------------------------------------------------
        i_inst = 32'h00940063; #10;

        if (o_branch !== 1'b1 || o_reg_write !== 1'b0 || o_mem_write !== 1'b0) begin
            $display("FAIL: Branch Control Assertions Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 6: I-Type Arithmetic -> addi x10, x11, 15
        // ------------------------------------------------
        i_inst = 32'h00F58513; #10;

        if (o_reg_write !== 1'b1 || o_alu_src_b !== 1'b1 || o_result_mux !== 2'b00) begin
            $display("FAIL: ADDI Control Path Configuration Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP (Funct3 is 3'b000 -> 6'b000000)
        if (o_alu_op !== 6'b000000) begin
            $display("FAIL: ADDI alu_op Mismatch! Got %b", o_alu_op);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 7: U-Type Instruction -> auipc x12, 0x12345
        // ------------------------------------------------
        i_inst = 32'h12345617; #10;

        if (o_reg_write !== 1'b1 || o_alu_src_a !== 1'b1 || o_alu_src_b !== 1'b1) begin
            $display("FAIL: AUIPC Control Path Configuration Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP
        if (o_alu_op !== `OP_ALU_ADD) begin
            $display("FAIL: AUIPC Target Calculation alu_op Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 8: J-Type Unconditional Jump -> jal x1, offset
        // ------------------------------------------------
        i_inst = 32'h004000EF; #10;

        if (o_reg_write !== 1'b1 || o_result_mux !== 2'b01) begin
            $display("FAIL: JAL Control Path Configuration Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP
        if (o_alu_op !== `OP_ALU_ADD) begin
            $display("FAIL: JAL Target Calculation alu_op Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 9: Indirect Jump Register -> jalr x0, 0(x1)
        // ------------------------------------------------
        i_inst = 32'h00008067; #10;

        if (o_reg_write !== 1'b1 || o_alu_src_b !== 1'b1 || o_result_mux !== 2'b01) begin
            $display("FAIL: JALR Control Path Configuration Mismatch!");
            error_count++;
        end
        // ADDED VERIFICATION FOR ALU_OP
        if (o_alu_op !== `OP_ALU_ADD) begin
            $display("FAIL: JALR Target Calculation alu_op Mismatch!");
            error_count++;
        end

        // ------------------------------------------------
        // NEW TEST 10: Immediate Shift Bit-30 Differentiation Check (SRAI)
        // Fields: imm=010000000100 (Bit 30 is 1), rs1=00010, funct3=101, rd=00011, opcode=0010011
        // Hex: 40415193 (srai x3, x2, 4)
        // ------------------------------------------------
        i_inst = 32'h40415193; #10;

        // Verify that bit 30 successfully passes through into the alu_op bus
        // {inst[30], funct3} = {1'b1, 3'b101} = 4'b1101 (Implicitly zero-extended to 6'b001101)
        if (o_alu_op !== 6'b001101) begin
            $display("FAIL: Immediate Shift SRAI bit-30 extraction failed! Got %b", o_alu_op);
            error_count++;
        end

        // ------------------------------------------------
        // Final Status Banner
        // ------------------------------------------------
        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: 100%% DECODER COVERAGE VALIDATED!");
        end else begin
            $display("  FAILURE: %0d control path anomalies detected.", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule