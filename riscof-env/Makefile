# Orchestrates the Docker image build and RISCOF run.
#
# Expected layout (see README.md):
#   RISC-V_R32I/                <- your repo checkout
#     src/                      <- your CPU sources (bind-mounted into the
#                                  container at /work/src; NOT copied into
#                                  the image, so you don't need to rebuild
#                                  the image every time you edit your CPU)
#     riscof-env/               <- this directory
#       Dockerfile
#       Makefile                <- (this file)
#       config.ini
#       dut/
#       tb/
#       patched-src/            <- see README: apply these two patches to
#                                  your real src/ before running tests
#       riscof_work/            <- (created) RISCOF's output/report directory

IMAGE_NAME := riscv-r32i-archtest
SRC_DIR    := $(abspath ../src)
WORK_DIR   := $(abspath ./riscof_work)

.PHONY: build run shell test clean

build:
	docker build -t $(IMAGE_NAME) .

# Runs the full rv32i_m/I suite and writes riscof_work/ (including the
# HTML report) back out to the host.
test: build
	mkdir -p $(WORK_DIR)
	docker run --rm \
		-v $(SRC_DIR):/work/src:ro \
		-v $(WORK_DIR):/work/riscof_work \
		-w /work \
		$(IMAGE_NAME) \
		riscof run --config=/work/config.ini \
			--suite=/work/riscv-arch-test/riscv-test-suite/rv32i_m/I \
			--env=/work/riscv-arch-test/riscv-test-suite/env \
			--work-dir=/work/riscof_work

# Drops you into a shell in the container with everything mounted, for
# debugging a single test by hand (compiling, running iverilog directly,
# inspecting hex/signature files, etc).
shell: build
	mkdir -p $(WORK_DIR)
	docker run --rm -it \
		-v $(SRC_DIR):/work/src:ro \
		-v $(WORK_DIR):/work/riscof_work \
		-w /work \
		$(IMAGE_NAME) bash

clean:
	rm -rf $(WORK_DIR)
