# RISC-V RV32I Architectural Compliance Test Environment

Runs the official `riscv-arch-test` `rv32i_m/I` suite against `riscv_top.sv`
using RISCOF (signature comparison against the Sail reference model), inside
Docker, driven by a single `make test`.

## Directory layout

Drop this `riscof-env/` folder inside your `RISC-V_R32I` repo, next to `src/`:

```
RISC-V_R32I/
  src/                  <- your CPU (unmodified except the 2 patches below)
  sim/
  riscof-env/           <- everything in this deliverable
    Dockerfile
    Makefile
    config.ini
    dut/                <- RISCOF DUT plugin
    tb/dut_tb.sv         <- testbench used per-test
    patched-src/         <- reference copies with the fixes applied, for diffing
```

## 1. Two changes you should apply to `src/` first

These aren't test-infrastructure choices -- they're fixes/adjustments to the
DUT itself. `patched-src/` contains full corrected copies of both files so
you can diff and apply by hand, or just copy them over `src/`.

**a) `instruction_memory`'s clock was never connected (blocking bug).**
In `riscv_top.sv`:
```systemverilog
instruction_memory u_instruction_memory (
    .addr(pc[9:0]),
    .inst(inst)
);
```
`instruction_memory` is a synchronous (`always_ff @(posedge clk)`) ROM, so
with `clk` left floating it never latches -- `inst` stays unknown forever.
This affects every simulation of `riscv_top`, not just the compliance suite.
Fixed in `patched-src/riscv_top.sv` by adding `.clk(i_clk)`.

**b) Memory is too small for most arch-test binaries.**
`INST_MEM_SIZE` / `DATA_MEM_SIZE` are 1024 bytes (256 words) each. Many
`rv32i_m/I` test files generate well over 256 words of code and/or signature
data once you include RISCOF's boilerplate + macro-generated test cases, and
will fail to link with a "region overflowed" error at that size.
`patched-src/definitions.vh` bumps both to 16KB (4096 words), and
`patched-src/riscv_top.sv` widens the two address slices (`pc[9:0]` /
`alu_result[9:0]`) to match via `$clog2(...)`. If you still hit overflow
errors on specific tests, raise these further -- just keep
`dut/env/link.ld`'s `MEMORY` region `LENGTH`s in sync.

## 2. Running it

```
cd riscof-env
make test
```

This builds the Docker image (expect 30-60 min the first time -- it builds
the RISC-V GCC toolchain and the Sail reference model from source) and then
runs the full `rv32i_m/I` suite. Results, logs, and the HTML report land in
`riscof-env/riscof_work/` on your host (bind-mounted, so nothing is lost
when the container exits). Open `riscof_work/report.html` for the pass/fail
breakdown.

`make shell` drops you into the container with everything mounted, useful
for debugging a single test manually (you can re-run the `iverilog`/`vvp`
commands from a test's log file directly).

## 3. How the pieces fit together

Your CPU has no CSRs, no traps, and no privileged modes -- it's pure RV32I.
That's actually a simplification here: the "self-checking" halt/signature
protocol these tests use is done with a single plain store instruction,
never `csrw`/`ecall`/`ebreak`, so nothing about the compliance flow needs
your core to support anything it doesn't already have. `dut/env/model_test.h`
implements this: `RVMODEL_HALT` writes to a `tohost` symbol, and
`tb/dut_tb.sv` watches `dut.u_data_memory.i_we`/`i_addr` for that write
(via hierarchical reference, the same technique your existing unit
testbenches already use for `$dumpvars`) to know when to stop and dump the
signature.

Per test, the DUT plugin (`dut/riscof_riscv_top.py`):
1. Compiles the test `.S` against `dut/env/link.ld` + `model_test.h`.
2. Splits the resulting ELF into instruction-memory and data-memory images
   using `objcopy -O binary`, then hand-packs each into 32-bit little-endian
   words itself (deliberately **not** using `objcopy -O verilog
   --verilog-data-width=4`, which has a long-standing open binutils bug
   that emits the wrong endianness regardless of target -- see
   [binutils PR 25202](https://sourceware.org/bugzilla/show_bug.cgi?id=25202)).
3. Reads `tohost`/`begin_signature`/`end_signature` addresses out of the ELF
   symbol table with `nm` (the linker is free to place these differently
   test-to-test, so nothing is hardcoded).
4. Runs `iverilog`/`vvp` on `tb/dut_tb.sv` + your `src/*.sv`, passing all of
   the above as `+plusargs`.
5. RISCOF then diffs the resulting `.signature` file against the one
   produced by the reference model for the same test.

## 4. Known risk area: the reference model plugin

Everything above (the DUT side) is exact and was written against your real
source files. The one piece that's inherently harder to pin down is wiring
up **Sail as RISCOF's reference model** (`config.ini`'s `[sail_cSim]`
section) -- `sail-riscv` upstream has been mid-restructure, moving from a
plain `ARCH=RV32 make` producing per-width binaries to a CMake-based
`build_simulator.sh` producing one JSON-configured `sail_riscv_sim`. The
`riscof-plugins/sail_cSim` directory that RISCOF's own docs point at
predates that change and may or may not still exist in the checkout the
Dockerfile clones.

The Dockerfile checks for it and prints a clear warning during `docker
build` if it's missing, rather than failing silently later. If you hit that
warning:
- Check `riscof-plugins/` in whatever commit you cloned (`docker run --rm -it
  riscv-r32i-archtest ls /opt/sail-riscv/riscof-plugins/` if it exists at
  all), or
- Follow RISCOF's current instructions directly:
  https://riscof.readthedocs.io/en/stable/arch-tests.html, or
- Swap the reference model to Spike instead (simpler build, no OCaml/opam
  needed) using a RISCOF-compatible Spike plugin such as the one at
  https://gitlab.com/incoresemi/riscof-plugins -- update `config.ini`'s
  `[RISCOF]` section (`ReferencePlugin=spike`, matching path) accordingly.

I'd rather flag this precisely than hand you a Dockerfile that pretends to
be more certain about a fast-moving upstream repo than it can be.

## 5. If a test times out instead of failing cleanly

`tb/dut_tb.sv` has a 200,000-cycle timeout (`+TIMEOUT=` to override) so a
DUT bug that never reaches `RVMODEL_HALT` doesn't hang the whole suite --
it'll dump whatever signature data exists at timeout and move on, and
you'll see `TIMEOUT: DUT never wrote to tohost` in that test's log.
