# RISC-V RV32I compliance-test environment for huntbyington/RISC-V_R32I
#
# Builds:
#   - Icarus Verilog (DUT simulation)
#   - riscv32-unknown-elf GNU toolchain, RV32I/ilp32, newlib (test compilation)
#     -- prebuilt nightly binary, downloaded, not compiled
#   - RISCOF + riscv-config (test orchestration / signature comparison)
#   - Spike (riscv-isa-sim), RV32 (golden signatures) -- built from source via
#     the well-known incoresemi/riscof-plugins "spike_simple" RISCOF plugin.
#     (Sail was tried first as the reference model, but upstream sail-riscv
#     has moved to a CMake build producing a single JSON-configured binary
#     with no accompanying RISCOF plugin/env files, so Spike is used instead.)

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Base packages: Icarus Verilog, build tooling + Boost/device-tree-compiler
# for Spike (riscv-isa-sim).
# NOTE: no autoconf/bison/flex/texinfo/gperf/libtool/etc here -- those were
# only needed to compile the RISC-V GCC/binutils toolchain from source,
# which we no longer do (see the prebuilt-toolchain download below).
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential git ca-certificates wget curl \
        python3 python3-pip python3-venv \
        pkg-config \
        device-tree-compiler libboost-regex-dev libboost-system-dev \
        iverilog \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# RISC-V GNU toolchain: prebuilt nightly binary (RV32/ELF/newlib), not a
# from-source build. Building from source means cloning binutils/gcc/newlib
# from sourceware.org and/or their GitHub mirrors, both of which have hit
# repeated, hard-to-work-around rate limiting / anonymous-clone throttling.
# A prebuilt release is a single plain HTTPS file download -- no git
# protocol involved at all, so none of that applies. Uses GitHub's
# permanent "latest release" alias so this always tracks whatever the
# current nightly is rather than a pinned date that 404s once older
# nightlies get pruned. The archive wraps everything in a top-level "riscv/"
# directory (bin/, lib/, etc. live under that), so it's extracted into /opt
# rather than /opt/riscv -- that puts the toolchain at /opt/riscv/bin/... as
# PATH below expects. The compiler prefix is riscv32-unknown-elf-*, matching
# config.ini/the RISCOF plugin already.
# ---------------------------------------------------------------------------
RUN curl -fsSL \
        "https://github.com/riscv-collab/riscv-gnu-toolchain/releases/latest/download/riscv32-elf-ubuntu-24.04-gcc.tar.xz" \
        -o /tmp/riscv-toolchain.tar.xz \
    && tar -xJf /tmp/riscv-toolchain.tar.xz -C /opt \
    && rm /tmp/riscv-toolchain.tar.xz
ENV PATH="/opt/riscv/bin:${PATH}"

# ---------------------------------------------------------------------------
# RISCOF + riscv-config (pulled in as a RISCOF dependency)
# ---------------------------------------------------------------------------
RUN pip3 install --break-system-packages riscof

# ---------------------------------------------------------------------------
# Spike (riscv-isa-sim): built from source, installed to /opt/riscv (already
# on PATH above) so the `spike` binary sits alongside the GNU toolchain.
#
# Pinned to a commit past the v1.1.0 tag, not the tag itself: v1.1.0's
# fesvr/device.h relies on <cstdint> being pulled in transitively by another
# header, which newer libstdc++ (GCC 13, as shipped by ubuntu:24.04) no
# longer does, so v1.1.0 fails to build here with "'uint64_t' does not name
# a type". Fixed on master by explicitly adding the include; pinning to a
# specific commit (rather than tracking master) keeps the build reproducible.
# ---------------------------------------------------------------------------
WORKDIR /opt
RUN git clone https://github.com/riscv-software-src/riscv-isa-sim.git \
    && cd riscv-isa-sim \
    && git checkout 38c2a30f794f26979a6e3f288bf13bacae27e225
WORKDIR /opt/riscv-isa-sim
RUN mkdir build && cd build \
    && ../configure --prefix=/opt/riscv \
    && make -j"$(nproc)" \
    && make install

# ---------------------------------------------------------------------------
# Test suite: riscv-arch-test, pre-act4 (classic RISCOF-compatible) content.
# The "master" branch predates the act4 rewrite and is what RISCOF's
# `riscof arch-test` / `riscof run --suite ... rv32i_m` flow expects
# (env/, riscv-test-suite/rv32i_m/I, etc). Pin a tag for reproducibility.
# ---------------------------------------------------------------------------
WORKDIR /work
RUN git clone --depth 1 --branch 3.9.1 \
        https://github.com/riscv-non-isa/riscv-arch-test.git
# RISCOF's dbgen reads this repo's HEAD commit via git, but it's cloned here
# as root while `make test` runs the container as the host user (so bind-
# mounted output isn't root-owned) -- git's ownership check would otherwise
# refuse to touch a repo it doesn't own. --system (not --global) so this
# applies no matter which UID runs git later, since that UID has no $HOME/
# git config of its own inside the container.
RUN git config --system --add safe.directory /work/riscv-arch-test

# Project files: DUT plugin, reference (Spike) plugin, testbench, patched
# CPU sources, config.ini
COPY config.ini /work/config.ini
COPY dut /work/dut
COPY ref /work/ref
COPY tb /work/tb
COPY patched-src /work/patched-src-reference
# Your actual src/ tree gets bind-mounted at `docker run` time (see Makefile)
# so edits on the host are picked up without rebuilding the image.

WORKDIR /work
CMD ["/bin/bash"]
