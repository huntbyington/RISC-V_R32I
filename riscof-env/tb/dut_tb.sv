`timescale 1ns/1ps
`include "src/definitions.vh"

// ============================================================================
// dut_tb: RISCOF-driven testbench for riscv_top.
//
// Invoked per-test by dut/riscof_riscv_top.py as:
//   vvp dut.vvp +IMEM_HEX=... +DMEM_HEX=... +SIGNATURE=... \
//               +TOHOST_ADDR=0x... +SIG_START_ADDR=0x... +SIG_END_ADDR=0x...
//
// It never modifies riscv_top.sv/instruction_memory.sv/data_memory.sv --
// instead it reaches into the DUT's memory arrays via hierarchical
// reference (dut.u_instruction_memory.memory / dut.u_data_memory.memory),
// exactly like the unit testbenches in sim/ already do with $dumpvars.
// ============================================================================
module dut_tb;

    logic i_clk;
    logic i_rst;
    wire  [`DATA_WIDTH-1:0] debug;

    // Plusarg-driven parameters
    string imem_hex_file;
    string dmem_hex_file;
    string sig_file;
    int    tohost_addr;
    int    sig_start_addr;
    int    sig_end_addr;
    int    timeout_cycles;

    localparam IMEM_WORDS = `INST_MEM_SIZE / 4;
    localparam DMEM_WORDS = `DATA_MEM_SIZE / 4;

    riscv_top dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .debug(debug)
    );

    // ------------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------------
    initial i_clk = 0;
    always #10 i_clk = ~i_clk; // 50MHz, matches existing unit testbenches

    // ------------------------------------------------------------------
    // Load memories + run
    // ------------------------------------------------------------------
    integer halted;
    integer cycle_count;

    initial begin
        if (!$value$plusargs("IMEM_HEX=%s", imem_hex_file)) begin
            $display("ERROR: +IMEM_HEX not given"); $finish;
        end
        if (!$value$plusargs("DMEM_HEX=%s", dmem_hex_file)) begin
            $display("ERROR: +DMEM_HEX not given"); $finish;
        end
        if (!$value$plusargs("SIGNATURE=%s", sig_file)) begin
            $display("ERROR: +SIGNATURE not given"); $finish;
        end
        if (!$value$plusargs("TOHOST_ADDR=%h", tohost_addr)) begin
            $display("ERROR: +TOHOST_ADDR not given"); $finish;
        end
        if (!$value$plusargs("SIG_START_ADDR=%h", sig_start_addr)) begin
            $display("ERROR: +SIG_START_ADDR not given"); $finish;
        end
        if (!$value$plusargs("SIG_END_ADDR=%h", sig_end_addr)) begin
            $display("ERROR: +SIG_END_ADDR not given"); $finish;
        end
        if (!$value$plusargs("TIMEOUT=%d", timeout_cycles)) begin
            timeout_cycles = 200000;
        end

        $readmemh(imem_hex_file, dut.u_instruction_memory.memory);
        $readmemh(dmem_hex_file, dut.u_data_memory.memory);

        halted = 0;
        cycle_count = 0;

        i_rst = 1;
        repeat (4) @(posedge i_clk);
        i_rst = 0;

        // Run until the DUT writes to `tohost`, or we time out.
        while (!halted && cycle_count < timeout_cycles) begin
            @(posedge i_clk);
            cycle_count = cycle_count + 1;
            if (dut.u_data_memory.i_we &&
                (dut.u_data_memory.i_addr == (tohost_addr[$clog2(`DATA_MEM_SIZE)-1:0])) &&
                (dut.u_data_memory.i_data != 0)) begin
                halted = 1;
            end
        end

        if (!halted) begin
            $display("TIMEOUT: DUT never wrote to tohost (addr 0x%0h) after %0d cycles",
                      tohost_addr, timeout_cycles);
        end else begin
            $display("HALT: tohost = 0x%0h after %0d cycles",
                      dut.u_data_memory.i_data, cycle_count);
        end

        dump_signature();
        $finish;
    end

    // ------------------------------------------------------------------
    // Signature dump: memory[sig_start_addr : sig_end_addr) as one 8-hex-
    // digit word per line, the format RISCOF expects for comparison
    // against the reference model's signature.
    // ------------------------------------------------------------------
    task dump_signature;
        integer fd;
        integer word_idx;
        integer start_word;
        integer end_word;
        begin
            start_word = sig_start_addr >> 2;
            end_word   = sig_end_addr   >> 2;

            fd = $fopen(sig_file, "w");
            if (fd == 0) begin
                $display("ERROR: could not open signature file %s", sig_file);
                disable dump_signature;
            end

            for (word_idx = start_word; word_idx < end_word; word_idx = word_idx + 1) begin
                if (word_idx >= 0 && word_idx < DMEM_WORDS)
                    $fwrite(fd, "%08x\n", dut.u_data_memory.memory[word_idx]);
                else
                    $fwrite(fd, "%08x\n", 32'h00000000);
            end

            $fclose(fd);
        end
    endtask

    // ------------------------------------------------------------------
    // Optional waveform dump, consistent with the existing unit testbenches
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("sim/out/dut_tb_waves.vcd");
        $dumpvars(0, dut_tb);
    end

endmodule
