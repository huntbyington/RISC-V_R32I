`timescale 1ns/1ps

// Ensure macros are pulled in cleanly
`define OP_LUI_M     7'b0110111
`define OP_AUIPC_M   7'b0010111
`define OP_JAL_M     7'b1101111
`define OP_BRANCH_M  7'b1100011
`define OP_STORE_M   7'b0100011
`define OP_ALU_M     7'b0110011
`define OP_JALR_M    7'b1100111
`define OP_LOAD_M    7'b0000011
`define OP_ALUI_M    7'b0010011

module sign_extension_tb;
    localparam INST_WIDTH = 32;
    
    logic [INST_WIDTH-1:0] i_inst;
    logic [6:0]            i_opcode; 
    logic [INST_WIDTH-1:0] o_immediate_extended;
    
    logic [INST_WIDTH-1:0] expected_imm;
    integer error_count = 0;

    // Instantiates the Device Under Test (DUT)
    sign_extension DUT (
        .i_inst(i_inst),
        .i_opcode(i_opcode),
        .o_immediate_extended(o_immediate_extended)
    );

    initial begin
        $dumpfile("sim/out/sign_ext_waves.vcd");
        $dumpvars(0, sign_extension_tb);

        $display("==================================================");
        $display("STARTING AUTOMATED SIGN EXTENSION TESTS");
        $display("==================================================");

        // --- R-Type ---
        i_inst = 32'h003100B3; i_opcode = `OP_ALU_M; expected_imm = 32'h0; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: R-Type -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- I-Type (Negative) ---
        i_inst = 32'hFFB10093; i_opcode = `OP_ALUI_M; expected_imm = 32'hFFFFFFFB; #9; 
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: I-Type (Negative) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- I-Type (Positive) ---
        i_inst = 32'h00510093; i_opcode = `OP_ALUI_M; expected_imm = 32'h00000005; #9; 
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: I-Type (Positive) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- S-Type (Positive) ---
        i_inst = 32'h00102423; i_opcode = `OP_STORE_M; expected_imm = 32'h00000008; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: S-Type (Positive) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- S-Type (Negative) ---
        i_inst = 32'hFE102C23; i_opcode = `OP_STORE_M; expected_imm = 32'hFFFFFFF8; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: S-Type (Negative) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- B-Type (Negative) ---
        i_inst = 32'hFE209CE3; i_opcode = `OP_BRANCH_M; expected_imm = 32'hFFFFFFF8; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: B-Type (Negative) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- B-Type (Positive) ---
        i_inst = 32'h00209463; i_opcode = `OP_BRANCH_M; expected_imm = 32'h00000008; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: B-Type (Positive) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- U-Type (MSB 0) ---
        i_inst = 32'h123450B7; i_opcode = `OP_LUI_M; expected_imm = 32'h12345000; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: U-Type (MSB 0) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- U-Type (MSB 1) ---
        i_inst = 32'h800000B7; i_opcode = `OP_LUI_M; expected_imm = 32'h80000000; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: U-Type (MSB 1) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- J-Type (Positive) ---
        i_inst = 32'h000000EF; i_opcode = `OP_JAL_M; expected_imm = 32'h00000000; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: J-Type (Positive) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        // --- J-Type (Negative) ---
        i_inst = 32'hFFF000EF; i_opcode = `OP_JAL_M; expected_imm = 32'hFFF00FFE; #9;
        #1; if (o_immediate_extended !== expected_imm) begin
            $display("FAIL: J-Type (Negative) -> Expected %h, Got %h", expected_imm, o_immediate_extended);
            error_count++;
        end

        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: ALL SIGN EXTENSION TESTS PASSED!");
        end else begin
            $display("  FAILURE: %0d test cases failed. Review logs.", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule