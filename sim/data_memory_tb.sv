`timescale 1ns/1ps

module data_memory_tb;

    localparam MEM_SIZE = 1024;
    localparam DATA_WIDTH = 32;

    logic                    i_clk;
    logic                    i_we;
    logic [DATA_WIDTH-1:0]   i_data;
    logic [9:0]              i_addr; // $clog2(1024) = 10 bits
    logic [DATA_WIDTH-1:0]   o_data;

    integer error_count = 0;

    // Instantiate the Device Under Test (DUT)
    data_memory #(
        .MEM_SIZE(MEM_SIZE)
    ) DUT (
        .i_clk(i_clk),
        .i_we(i_we),
        .i_data(i_data),
        .i_addr(i_addr),
        .o_data(o_data)
    );

    // Clock Generation (50MHz -> 20ns period)
    always begin
        i_clk = 0; #10;
        i_clk = 1; #10;
    end

    // Verification Pipeline
    initial begin
        // Waveform configuration for GTKWave
        $dumpfile("sim/out/data_mem_waves.vcd");
        $dumpvars(0, data_memory_tb);

        $display("==================================================");
        $display("STARTING BEHAVIORAL DATA MEMORY VERIFICATION");
        $display("==================================================");

        // Initialize ports
        i_we   = 0;
        i_data = 32'h0;
        i_addr = 10'h0;
        #25; // Let clock initialize and pass the first positive edge

        // ------------------------------------------------
        // TEST 1: Standard Word Write & Read Back
        // Behavior: Data should hit memory at address 4 (Word 1).
        // ------------------------------------------------
        @(negedge i_clk);
        i_we   = 1;
        i_addr = 10'd4; // Byte address 4 -> Word 1
        i_data = 32'hA1B2C3D4;

        @(posedge i_clk); // Captured here
        #5; // Let output register settle
        
        // Disable write, keep address fixed to check synchronous output
        i_we = 0;
        if (o_data !== 32'hA1B2C3D4) begin
            $display("FAIL: Synchronous Write/Read Mismatch at Addr 4! Expected A1B2C3D4, Got %h", o_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 2: Consecutive Word Boundary Isolation
        // Behavior: Writing to address 8 (Word 2) must not overwrite address 4 (Word 1).
        // ------------------------------------------------
        @(negedge i_clk);
        i_we   = 1;
        i_addr = 10'd8; // Next sequential word boundary (Byte 8 -> Word 2)
        i_data = 32'h11223344;

        @(posedge i_clk);
        #5;
        
        // Drop write enable, point address back to our original Test 1 slot (Byte 4)
        i_we   = 0;
        i_addr = 10'd4; 
        
        @(posedge i_clk); // Memory requires a clock edge to update output to the new address
        #5;
        if (o_data !== 32'hA1B2C3D4) begin
            $display("FAIL: Memory Overwrite/Crosstalk! Word 1 was corrupted by Word 2 write. Got %h", o_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 3: Write Disable & Data Line Isolation
        // Behavior: When i_we = 0, memory must ignore incoming data lines completely.
        // ------------------------------------------------
        @(negedge i_clk);
        i_we   = 0; // DISABLED
        i_addr = 10'd8; // Pointing to Word 2 slot
        i_data = 32'hFFFFFFFF; // Poison data line with junk values

        @(posedge i_clk);
        #5;
        // Verify that the memory did NOT overwrite its old value (11223344) with FFFFFFFF
        if (o_data === 32'hFFFFFFFF) begin
            $display("FAIL: Memory Protection Breach! Data written while i_we was LOW.");
            error_count++;
        end else if (o_data !== 32'h11223344) begin
            $display("FAIL: Read mismatch during write disable test. Expected 11223344, Got %h", o_data);
            error_count++;
        end

        // ------------------------------------------------
        // TEST 4: Byte-Offset Truncation Check
        // Behavior: Since the design only processes 32-bit words, passing 
        // byte addresses 4, 5, 6, or 7 should all resolve to the exact same Word 1.
        // ------------------------------------------------
        @(negedge i_clk);
        i_we   = 0;
        i_addr = 10'd7; // 7 drops its lower bits (7 >> 2 = 1), pointing back to Word 1
        
        @(posedge i_clk);
        #5;
        if (o_data !== 32'hA1B2C3D4) begin
            $display("FAIL: Word-Alignment Alignment Error! Addr 7 should map to Word 1. Got %h", o_data);
            error_count++;
        end

        // ------------------------------------------------
        // Final Status Evaluation
        // ------------------------------------------------
        $display("==================================================");
        if (error_count == 0) begin
            $display("  SUCCESS: DATA MEMORY ARCHITECTURE IS VALID!");
        end else begin
            $display("  FAILURE: %0d test failures detected. Review traces.", error_count);
        end
        $display("==================================================");

        $finish;
    end

endmodule