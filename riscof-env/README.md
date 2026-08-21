# RISC-V RV32I Architectural Compliance Test Environment

A self-contained Docker environment that runs the official
[`riscv-arch-test`](https://github.com/riscv-non-isa/riscv-arch-test)
`rv32i_m/I` suite against `riscv_top.sv`, using
[RISCOF](https://riscof.readthedocs.io/) to compile each test twice — once
for the DUT (this CPU, simulated with Icarus Verilog) and once for a golden
reference model ([Spike](https://github.com/riscv-software-src/riscv-isa-sim))
— and diff the two resulting signatures. Everything needed to build and run
it is captured in the Dockerfile, so results don't depend on what's
installed on your host beyond Docker itself.

## Prerequisites

- Docker, with the ability to build images and run containers.
- Nothing else. The GNU toolchain, RISCOF, Icarus Verilog, and Spike are all
  built or installed inside the image.

## Quick start

```sh
cd riscof-env
make test
```

This builds the Docker image (cached after the first run — expect the very
first build to take several minutes, mostly compiling Spike from source) and
runs the full `rv32i_m/I` suite. A per-test `Passed`/`Failed` line prints to
the terminal, and a full report opens automatically at the end.

## Directory layout

```
RISC-V_R32I/
  src/                    <- your CPU sources, bind-mounted read-only into
                             the container at build/run time (edit and
                             rerun `make test` — no image rebuild needed)
  riscof-env/
    Dockerfile             <- builds the toolchain, RISCOF, Spike, Icarus
    Makefile                <- `make test` / `make shell` / `make clean`
    config.ini               <- RISCOF plugin + test config
    dut/                    <- RISCOF plugin describing how to build/run
                               a test against the DUT (this CPU)
      riscof_riscv_top.py
      riscv_top_isa.yaml     <- declares this CPU's ISA (RV32I, no exts)
      riscv_top_platform.yaml
      env/                  <- link.ld / model_test.h for the DUT compile
    ref/                    <- RISCOF plugin for the reference model
                               (Spike), same structure as dut/
    tb/dut_tb.sv             <- testbench driving one test per invocation
    riscof_work/             <- (generated) all test output — wiped and
                               recreated by every `make test` run
```

## Interpreting results

- **`riscof_work/report.html`** — the full pass/fail report; open this
  first.
- **`riscof_work/src/<test-name>.S/dut/dut.log`** — the DUT's simulation
  log. Look for one of:
  - `HALT: tohost = 0x1 after N cycles` — the DUT ran to completion.
  - `TIMEOUT: DUT never wrote to tohost after N cycles` — the simulation
    hit its cycle budget without halting (see [Known limitations](#known-limitations)).
- **Signature files** — for any failing test, diff the DUT's output against
  the reference model's directly to see exactly which computed values
  disagree:
  ```sh
  diff riscof_work/src/<test-name>.S/dut/DUT-riscv_top.signature \
       riscof_work/src/<test-name>.S/ref/Reference-Spike.signature
  ```

## Other Make targets

- **`make shell`** — drops you into a shell inside the container with the
  same mounts as `make test` (toolchain, Icarus, Spike, and your `src/` all
  on `PATH`/mounted). Useful for compiling and running a single test by hand
  instead of the whole suite, or for iterating on a fix quickly.
- **`make clean`** — removes `riscof_work/`.

## How a test runs

RISCOF drives each test through both plugins independently:

1. **DUT side** (`dut/riscof_riscv_top.py`):
   - Compiles the test's `.S` file against `dut/env/link.ld` and
     `dut/env/model_test.h`.
   - Splits the resulting ELF into separate instruction- and data-memory
     images with `objcopy -O binary`, then hand-packs each into 32-bit
     little-endian words for `$readmemh` (not via `objcopy -O verilog
     --verilog-data-width=4`, which has a long-standing binutils
     endianness bug — [binutils PR 25202](https://sourceware.org/bugzilla/show_bug.cgi?id=25202)).
   - Reads `tohost`/`begin_signature`/`end_signature` addresses out of the
     ELF's symbol table (the linker is free to place these differently
     test-to-test, so nothing is hardcoded).
   - Runs `iverilog`/`vvp` on `tb/dut_tb.sv` plus your `src/*.sv`, passing
     the above as `+plusargs`.
2. **Reference side** (`ref/riscof_spike_simple.py`): compiles the same
   `.S` file against `ref/env/link.ld`/`model_test.h` and runs it on Spike.
3. RISCOF diffs the two resulting `.signature` files.

The DUT is pure RV32I with no CSRs, traps, or privileged modes, so the
halt/signature protocol these tests use is intentionally simplified to a
single store instruction rather than `csrw`/`ecall`/`ebreak`:
`RVMODEL_HALT` (in `dut/env/model_test.h`) writes to a `tohost` symbol, and
`tb/dut_tb.sv` watches `data_memory`'s write port (via hierarchical
reference) for that write to know when to stop and dump the signature.
`tb/dut_tb.sv` has a 200,000-cycle timeout (`+TIMEOUT=` to override) so a
DUT bug that never reaches `RVMODEL_HALT` doesn't hang the whole suite — it
dumps whatever signature data exists at timeout and moves on to the next
test.

## Known limitations

As of the last full run, **24 of 39** tests in `rv32i_m/I` pass. The
remaining failures fall into three categories:

- **Instruction memory capacity** (`beq`, `bge`, `bgeu`, `blt`, `bltu`,
  `bne`, `jal`): these tests don't fit in the DUT's declared 16KB
  instruction memory once RISCOF's full macro-expanded test content is
  compiled in. Raising `INST_MEM_SIZE` in `src/definitions.vh` (and keeping
  `dut/env/link.ld`'s `MEMORY` region in sync) is one option if you want
  these to build.
- **JALR** (`jalr`, `misalign1-jalr`): produces incorrect results for
  reasons not yet fully diagnosed.
- **Byte/halfword load-store** (`lb`, `lbu`, `lh`, `lhu`, `sb`, `sh`
  -align): `data_memory.sv` only supports whole-word access today; sub-word
  load/store isn't implemented.

## Troubleshooting

- **A run hangs indefinitely**: this shouldn't happen (the testbench's
  200,000-cycle timeout caps every test), but if you suspect it has,
  interrupt and check `riscof_work/src/<test>.S/{dut,ref}/*.log` for
  whichever test was in progress.
- **Editing `src/`**: no image rebuild is needed — it's bind-mounted, not
  copied into the image. Only edits under `riscof-env/` (Dockerfile, `dut/`,
  `ref/`, `tb/`, `config.ini`) trigger a rebuild on the next `make test`.
- **Root-owned files under `riscof_work/`**: shouldn't occur — the
  container runs as your host user (see the `Makefile`'s `DOCKER_USER`) so
  everything it writes is already host-owned and freely removable.
