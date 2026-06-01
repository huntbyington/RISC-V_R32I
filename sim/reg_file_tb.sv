`timescale 1ns/1ps

module register_file_tb;

    // Signals and Interface Connections
    logic        clk;
    logic        rst_n;
    
    logic [4:0]  i_rs1_addr;
    logic [31:0] o_rs1_data;
    
    logic [4:0]  i_rs2_addr;
    logic [31:0] o_rs2_data;
    
    logic        i_reg_write;
    logic [4:0]  i_rd_addr;
    logic [31:0] i_rd_data;

    integer error_count = 0;

    // Instantiate the Device Under Test (DUT)
    register_file DUT (
        .i_clk(clk),
        .i_rst(rst_n),
        .i_we(i_reg_write),
        .i_rd(i_rd_data),
        .i_rd_addr(i_rd_addr),
        .i_rs1_addr(i_rs1_addr),
        .i_rs2_addr(i_rs2_addr),
        .o_rs1(o_rs1_data),
        .o_rs2(o_rs2_data)
    );

    // Clock Generation (50MHz -> 20ns period)
    always begin
        clk = 0; #10;
        clk = 1; #10;
    end

    // Test Stimulus Pipeline
    initial begin
        // Waveform configuration
        $dumpfile("sim/out/regfile_waves.vcd");
        $dumpvars(0, register_file_tb);

        $display("==================================================");
        $display("STARTING AUTOMATED REGISTER FILE TESTS");
        $display("==================================================");

        // ------------------------------------------------
        // TEST 1: System Reset Validation
        // ------------------------------------------------
        rst_n = 0;
        i_reg_write = 0;
        i_rs1_addr = 5'd5;
        i_rs2_addr = 5'd10;
        i_rd_addr = 5'd0;
        i_rd_data = 32'h0;
        #25; // Hold reset across a clock edge
        
        rst_n = 1; // Release reset
        #5;
        
        // Verify registers read back 0 after a reset
        if (o_rs1_data !== 32'h0 || o_rs2_data !== 32'h0) begin
            $display("FAIL: Reset state is corrupt! Expected 0, Got rs1=%h, rs2=%h", o_rs1_data, o_rs2_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 2: Basic Synchronous Write & Asynchronous Read
        // ------------------------------------------------
        @(negedge clk); // Setup data safely on the negative edge
        i_reg_write = 1;
        i_rd_addr = 5'd5;      // Target register x5
        i_rd_data = 32'hDEADBEEF;
        
        @(posedge clk); // Data hits memory on this edge
        #5;
        
        // Set read address to x5
        i_rs1_addr = 5'd5;
        #1;
        if (o_rs1_data !== 32'hDEADBEEF) begin
            $display("FAIL: Basic Write/Read -> Expected DEADBEEF, Got %h", o_rs1_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 3: Proving the Hardcoded Register x0 Rule
        // ------------------------------------------------
        @(negedge clk);
        i_reg_write = 1;
        i_rd_addr = 5'd0;      // Attempting to write into architectural x0
        i_rd_data = 32'hDEADBEEF;
        
        @(posedge clk);
        #5;
        
        i_rs1_addr = 5'd0;     // Point read port 1 to x0
        #1;
        if (o_rs1_data !== 32'h0) begin
            $display("FAIL: x0 Guardrail Breach! Expected 0, Got %h", o_rs1_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 4: Write Disable Verification
        // ------------------------------------------------
        @(negedge clk);
        i_reg_write = 0;       // TURN WRITE OFF
        i_rd_addr = 5'd5;      // Target x5 again
        i_rd_data = 32'h12345678;
        
        @(posedge clk);
        #5;
        
        i_rs1_addr = 5'd5;
        #1;
        if (o_rs1_data === 32'h12345678) begin
            $display("FAIL: Write Enable Ignored! Data updated when write was disabled.");
            error_count++;
        end

        // ------------------------------------------------
        // TEST 5: Multi-Port Structural Dual-Read Test
        // ------------------------------------------------
        // Let's write a unique value into register x10 first
        @(negedge clk);
        i_reg_write = 1;
        i_rd_addr = 5'd10;
        i_rd_data = 32'h00ABCDEF;
        
        @(posedge clk);
        #5;
        
        // Read x5 via Port 1 and x10 via Port 2 simultaneously
        i_rs1_addr = 5'd5;
        i_rs2_addr = 5'd10;
        #1;
        if (o_rs1_data !== 32'hDEADBEEF || o_rs2_data !== 32'h00ABCDEF) begin
            $display("FAIL: Dual Read Verification Mismatch! Port1=%h, Port2=%h", o_rs1_data, o_rs2_data);
            error_count++;
        end

        // ------------------------------------------------
        // Final Status Evaluation Banner
        // ------------------------------------------------
        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: ALL REGISTER FILE TESTS PASSED!");
        end else begin
            $display("  FAILURE: %0d test cases flagged errors. Check traces.", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule