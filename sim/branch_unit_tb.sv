`timescale 1ns/1ps
`include "src/definitions.vh"

module branch_unit_tb;

    // Signal Declarations
    logic        i_branch;
    logic [2:0]  i_branch_op;
    logic [31:0] i_a;
    logic [31:0] i_b;
    wire         o_take;

    integer error_count = 0;

    // Instantiate Device Under Test (DUT)
    branch_unit DUT (
        .i_branch(i_branch),
        .i_branch_op(i_branch_op),
        .i_a(i_a),
        .i_b(i_b),
        .o_take(o_take)
    );

    initial begin
        $dumpfile("sim/out/branch_unit_waves.vcd");
        $dumpvars(0, branch_unit_tb);

        $display("==================================================");
        $display("STARTING AUTOMATED BRANCH UNIT VERIFICATION");
        $display("==================================================");

        // ------------------------------------------------
        // TEST 1: Absolute Deactivation Gating (i_branch = 0)
        // Behavior: o_take must stay 0 even if conditions match
        // ------------------------------------------------
        i_branch    = 1'b0;
        i_branch_op = `BRANCH_BEQ; // Used macro from definitions.vh
        i_a         = 32'd10;
        i_b         = 32'd10; // Values match perfectly
        #10;
        if (o_take !== 1'b0) begin
            $display("FAIL: Branch unit active while i_branch is LOW!");
            error_count++;
        end

        // Enable Branch evaluations for the remaining tests
        i_branch = 1'b1;

        // ------------------------------------------------
        // TEST 2: Conditional Equal (BEQ)
        // ------------------------------------------------
        i_branch_op = `BRANCH_BEQ; 
        i_a         = 32'd55;
        i_b         = 32'd55; #10; // Match
        if (o_take !== 1'b1) begin
            $display("FAIL: BEQ true match failed!"); error_count++;
        end

        i_a         = 32'd55;
        i_b         = 32'd99; #10; // Mismatch
        if (o_take !== 1'b0) begin
            $display("FAIL: BEQ false match leaked a branch take!"); error_count++;
        end

        // ------------------------------------------------
        // TEST 3: Unconditional Jumps (JAL/JALR)
        // Behavior: Always takes branch regardless of values
        // ------------------------------------------------
        i_branch_op = `BRANCH_JAL_JALR; 
        i_a         = 32'hDEAD_BEEF;
        i_b         = 32'h0000_0000; #10;
        if (o_take !== 1'b1) begin
            $display("FAIL: JAL/JALR unconditional jump failed!"); error_count++;
        end

        // ------------------------------------------------
        // TEST 4: Signed Comparisons (BLT / BGE)
        // Inputs: i_a = -5 (32'hFFFF_FFFB), i_b = 2 (32'h0000_0002)
        // ------------------------------------------------
        i_a = 32'hFFFF_FFFB; // -5
        i_b = 32'h0000_0002; //  2

        i_branch_op = `BRANCH_BLT; #10; // BLT (Less Than) -> True (-5 < 2)
        if (o_take !== 1'b1) begin
            $display("FAIL: Signed BLT failed with negative value!"); error_count++;
        end

        i_branch_op = `BRANCH_BGE; #10; // BGE (Greater/Equal) -> False (-5 >= 2)
        if (o_take !== 1'b0) begin
            $display("FAIL: Signed BGE leaked on negative value evaluation!"); error_count++;
        end

        // Test both conditions when values are equal (edge case)
        i_a = 32'h0000_0002; // 2
        i_b = 32'h0000_0002; // 2

        i_branch_op = `BRANCH_BLT; #10; // BLT (Less Than) -> False (2 < 2)
        if (o_take !== 1'b0) begin
            $display("FAIL: Signed BLT erroneously marked true on equal values!"); error_count++;
        end

        i_branch_op = `BRANCH_BGE; #10; // BGE (Greater/Equal) -> True (2 >= 2)
        if (o_take !== 1'b1) begin
            $display("FAIL: Signed BGE failed on equal values evaluation!"); error_count++;
        end

        // ------------------------------------------------
        // TEST 5: Unsigned Comparisons (BLTU / BGEU)
        // Inputs: Same hex values as Test 4, but parsed as unsigned integers
        // i_a = 4,294,967,291, i_b = 2
        // ------------------------------------------------
        i_branch_op = `BRANCH_BLTU; #10; // BLTU (Less Than Unsigned) -> False (4.2B < 2)
        if (o_take !== 1'b0) begin
            $display("FAIL: Unsigned BLTU erroneously marked true on overflow bounds!"); error_count++;
        end

        i_branch_op = `BRANCH_BGEU; #10; // BGEU (Greater/Equal Unsigned) -> True (4.2B >= 2)
        if (o_take !== 1'b1) begin
            $display("FAIL: Unsigned BGEU failed on upper bounds evaluation!"); error_count++;
        end

        // Test both conditions when values are equal (edge case)
        i_a = 32'h0000_0002; // 2
        i_b = 32'h0000_0002; // 2

        i_branch_op = `BRANCH_BLTU; #10; // BLTU (Less Than Unsigned) -> False (2 < 2)
        if (o_take !== 1'b0) begin
            $display("FAIL: Unsigned BLTU erroneously marked true on equal values!"); error_count++;
        end

        i_branch_op = `BRANCH_BGEU; #10; // BGEU (Greater/Equal Unsigned) -> True (2 >= 2)
        if (o_take !== 1'b1) begin
            $display("FAIL: Unsigned BGEU failed on equal values evaluation!"); error_count++;
        end

        // ------------------------------------------------
        // TEST 7: Extreme Two's Complement Boundaries (Max Positive vs. Min Negative)
        // Inputs: i_a = INT_MAX (32'h7FFF_FFFF), i_b = INT_MIN (32'h8000_0000)
        // Signed interpretation:   2,147,483,647  vs  -2,147,483,648
        // Unsigned interpretation: 2,147,483,647  vs   2,147,483,648
        // ------------------------------------------------
        i_a = 32'h7FFF_FFFF; 
        i_b = 32'h8000_0000; 

        // Signed Evaluation Check
        i_branch_op = `BRANCH_BGE; #10; // Signed BGE -> True (Max Positive >= Min Negative)
        if (o_take !== 1'b1) begin
            $display("FAIL: Signed BGE overflow boundary evaluation failed at extreme margins!");
            error_count++;
        end

        // Unsigned Evaluation Check
        i_branch_op = `BRANCH_BLTU; #10; // Unsigned BLTU -> True (2.14B < 2.14B + 1)
        if (o_take !== 1'b1) begin
            $display("FAIL: Unsigned BLTU boundary verification failed at midpoint split!");
            error_count++;
        end

        // ------------------------------------------------
        // Final Summary Evaluation
        // ------------------------------------------------
        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: BRANCH UNIT PASSED VERIFICATION!");
        end else begin
            $display("  FAILURE: %0d functional bugs found in Branch Unit.", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule