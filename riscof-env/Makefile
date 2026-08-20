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
# Run the container as the host user (not root) so everything it writes into
# the riscof_work/ bind mount is host-owned and can be freely rm -rf'd on
# the next run, instead of accumulating root-owned files.
DOCKER_USER := $(shell id -u):$(shell id -g)

.PHONY: build run shell test clean

build:
	docker build -t $(IMAGE_NAME) .

# Runs the full rv32i_m/I suite and writes riscof_work/ (including the
# HTML report) back out to the host.
#
# The work dir is wiped and recreated on the HOST before each run (safe --
# it's an ordinary host directory at this point, not yet a bind mount) so
# every run starts from a clean slate. --no-clean is passed to riscof itself
# because *inside* the container riscof_work IS the bind-mount point, and
# riscof's own default clean behavior calls shutil.rmtree() on the work dir,
# which fails with "Device or resource busy" on a mountpoint. A stale
# database.yaml surviving between runs also trips an unrelated RISCOF bug
# (dbgen.py compares against the builtin `list` type instead of its
# freshly-computed file list), so starting clean avoids that too.
test: build
	rm -rf $(WORK_DIR)
	mkdir -p $(WORK_DIR)
	docker run --rm \
		--user $(DOCKER_USER) \
		-v $(SRC_DIR):/work/src:ro \
		-v $(WORK_DIR):/work/riscof_work \
		-w /work \
		$(IMAGE_NAME) \
		riscof run --config=/work/config.ini \
			--suite=/work/riscv-arch-test/riscv-test-suite/rv32i_m/I \
			--env=/work/riscv-arch-test/riscv-test-suite/env \
			--work-dir=/work/riscof_work \
			--no-clean

# Drops you into a shell in the container with everything mounted, for
# debugging a single test by hand (compiling, running iverilog directly,
# inspecting hex/signature files, etc).
shell: build
	mkdir -p $(WORK_DIR)
	docker run --rm -it \
		--user $(DOCKER_USER) \
		-v $(SRC_DIR):/work/src:ro \
		-v $(WORK_DIR):/work/riscof_work \
		-w /work \
		$(IMAGE_NAME) bash

clean:
	rm -rf $(WORK_DIR)
