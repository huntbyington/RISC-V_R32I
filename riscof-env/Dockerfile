# RISC-V RV32I compliance-test environment for huntbyington/RISC-V_R32I
#
# Builds:
#   - Icarus Verilog (DUT simulation)
#   - riscv32-unknown-elf GNU toolchain, RV32I/ilp32, newlib (test compilation)
#   - RISCOF + riscv-config (test orchestration / signature comparison)
#   - Sail RISC-V reference model, RV32 (golden signatures)
#
# This build compiles the RISC-V toolchain and the Sail reference model from
# source, which is the slow but version-agnostic path -- expect ~30-60
# minutes on a modern machine, mostly for the GCC/binutils build. See the
# README for faster alternatives (prebuilt toolchain / prebuilt Sail
# release) if you want to speed this up.

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Base packages: Icarus Verilog, build tooling for riscv-gnu-toolchain and
# for the Sail C++ emulator (CMake/Ninja), plus opam to install the Sail
# compiler itself.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates wget curl \
        python3 python3-pip python3-venv \
        autoconf automake autotools-dev python3-dev \
        libmpc-dev libmpfr-dev libgmp-dev gawk bison flex texinfo gperf \
        libtool patchutils bc zlib1g-dev libexpat1-dev \
        cmake ninja-build libboost-all-dev pkg-config \
        iverilog \
        opam \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# RISC-V GNU toolchain: RV32I / ilp32, newlib (bare-metal ELF) flow.
# This is the "make" (not "make linux") target -- no glibc, no Linux kernel
# headers, much faster than the Linux-hosted build.
# ---------------------------------------------------------------------------
WORKDIR /opt
RUN git clone --recursive --depth 1 \
        https://github.com/riscv-collab/riscv-gnu-toolchain.git
WORKDIR /opt/riscv-gnu-toolchain
RUN ./configure --prefix=/opt/riscv --with-arch=rv32i --with-abi=ilp32 \
    && make -j"$(nproc)"
ENV PATH="/opt/riscv/bin:${PATH}"

# ---------------------------------------------------------------------------
# RISCOF + riscv-config (pulled in as a RISCOF dependency)
# ---------------------------------------------------------------------------
RUN pip3 install --break-system-packages riscof

# ---------------------------------------------------------------------------
# Sail compiler (via opam) + Sail RISC-V model (reference simulator)
#
# NOTE: sail-riscv has recently moved from a plain-Makefile build producing
# per-XLEN binaries (riscv_sim_RV32/riscv_sim_RV64) to a CMake-based
# build_simulator.sh producing a single JSON-configurable sail_riscv_sim.
# The `riscof-plugins/sail_cSim` directory referenced by config.ini (and by
# RISCOF's own official docs) predates that restructure and may or may not
# still exist in the current repo -- this is flagged as a non-fatal check
# below rather than something this Dockerfile can guarantee. See the
# README's "if the Sail reference plugin path is missing" section.
# ---------------------------------------------------------------------------
RUN opam init -y --disable-sandboxing --bare \
    && opam switch create default ocaml-base-compiler \
    && eval $(opam env) \
    && opam install -y sail

WORKDIR /opt
RUN git clone --depth 1 https://github.com/riscv/sail-riscv.git
WORKDIR /opt/sail-riscv
RUN eval $(opam env) && ./build_simulator.sh
ENV PATH="/opt/sail-riscv/build/c_emulator:${PATH}"
RUN if [ -d /opt/sail-riscv/riscof-plugins/sail_cSim ]; then \
        echo "sail_cSim RISCOF plugin found OK"; \
    else \
        echo "*************************************************************"; \
        echo "WARNING: riscof-plugins/sail_cSim not found in sail-riscv."; \
        echo "sail-riscv's build system/layout has changed upstream; see"; \
        echo "README.md 'Reference model plugin' section for how to adapt"; \
        echo "config.ini to whatever this checkout actually ships, or how"; \
        echo "to switch the reference model to Spike instead."; \
        echo "*************************************************************"; \
    fi

# ---------------------------------------------------------------------------
# Test suite: riscv-arch-test, pre-act4 (classic RISCOF-compatible) content.
# The "master" branch predates the act4 rewrite and is what RISCOF's
# `riscof arch-test` / `riscof run --suite ... rv32i_m` flow expects
# (env/, riscv-test-suite/rv32i_m/I, etc). Pin a tag for reproducibility.
# ---------------------------------------------------------------------------
WORKDIR /work
RUN git clone --depth 1 --branch v3.9.1 \
        https://github.com/riscv-non-isa/riscv-arch-test.git

# Project files: DUT plugin, testbench, patched CPU sources, config.ini
COPY config.ini /work/config.ini
COPY dut /work/dut
COPY tb /work/tb
COPY patched-src /work/patched-src-reference
# Your actual src/ tree gets bind-mounted at `docker run` time (see Makefile)
# so edits on the host are picked up without rebuilding the image.

WORKDIR /work
CMD ["/bin/bash"]
