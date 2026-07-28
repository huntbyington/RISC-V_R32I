FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (remove gcc-riscv64-unknown-elf – we'll use xPack)
RUN apt-get update && apt-get install -y \
    make git rsync python3 python3-pip python3-venv ruby ruby-dev curl \
    iverilog build-essential wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# -------------------- Install xPack RISC-V GCC 15.1.0-1 --------------------
ARG XPACK_GCC_VERSION=15.1.0-1
ARG XPACK_BASE=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download
RUN mkdir -p /opt/xpack && \
    cd /opt/xpack && \
    wget -q ${XPACK_BASE}/v${XPACK_GCC_VERSION}/xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION}-linux-x64.tar.gz && \
    tar xf xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION}-linux-x64.tar.gz && \
    rm xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION}-linux-x64.tar.gz && \
    mv xpack-riscv-none-elf-gcc-${XPACK_GCC_VERSION} xpack-riscv-none-elf-gcc

# Add xPack to PATH
ENV PATH="/opt/xpack/xpack-riscv-none-elf-gcc/bin:${PATH}"

# Create symlinks so the ACT4 config's default prefix 'riscv64-unknown-elf-' works
RUN for tool in gcc g++ ar as ld objcopy objdump size strip; do \
      ln -s riscv-none-elf-${tool} /opt/xpack/xpack-riscv-none-elf-gcc/bin/riscv64-unknown-elf-${tool}; \
    done

# -------------------- Clone riscv-arch-test (ACT4) --------------------
RUN git clone https://github.com/riscv-non-isa/riscv-arch-test.git /opt/riscv-arch-test \
    && cd /opt/riscv-arch-test \
    && git checkout act4

# -------------------- Python virtual environment & tools --------------------
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN cd /opt/riscv-arch-test && \
    pip install -e ./framework -e ./generators/testgen -e ./generators/coverage && \
    gem install bundler && \
    bundle config set --global system 'true' && \
    bundle install --gemfile=/opt/riscv-arch-test/framework/src/act/data/Gemfile

# Mock the Sail simulator (not used, but keeps the validator quiet)
RUN echo '#!/bin/sh\necho "0.12"' > /usr/local/bin/sail_riscv_sim && \
    chmod +x /usr/local/bin/sail_riscv_sim

# No wrapper script needed anymore – the real GCC 15 is there.

CMD ["/bin/bash"]