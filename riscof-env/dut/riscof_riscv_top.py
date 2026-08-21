"""
RISCOF DUT plugin for huntbyington/RISC-V_R32I ("riscv_top").

Compile flow per test:
  1. riscv32-unknown-elf-gcc assembles+links the .S test against our
     env/link.ld + env/model_test.h -> test.elf
  2. riscv32-unknown-elf-objcopy dumps two separate Intel/verilog-hex images:
       test.imem.hex  (the .text.init/.text region -> instruction_memory)
       test.dmem.hex  (the .tohost/.data/.bss region -> data_memory)
  3. Icarus Verilog compiles tb/dut_tb.sv + the DUT sources and vvp runs it,
     passing the two hex paths and a signature output path via plusargs.
  4. The testbench itself watches data_memory writes for a "tohost" store
     and dumps memory[begin_signature:end_signature) to the signature file
     in RISCOF's expected format (one 32-bit hex word per line).
"""
import os
import shutil
import subprocess
import logging

import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

# Repo-root-relative paths, fixed by the Dockerfile's COPY layout -- see
# Dockerfile / README for the expected /work tree.
REPO_ROOT = "/work"
SRC_DIR = os.path.join(REPO_ROOT, "src")
TB_FILE = os.path.join(REPO_ROOT, "tb", "dut_tb.sv")

DUT_SOURCES = [
    "riscv_top.sv",
    "instruction_memory.sv",
    "data_memory.sv",
    "decoder.sv",
    "sign_extension.sv",
    "reg_file.sv",
    "alu.sv",
    "branch_unit.sv",
]


class riscv_top(pluginTemplate):
    __model__ = "riscv_top"
    __version__ = "0.1.0"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)
        config = kwargs.get('config')
        if config is None:
            logger.error("Config node for riscv_top missing.")
            raise SystemExit(1)

        self.pluginpath = os.path.abspath(config['pluginpath'])
        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])
        self.num_jobs = str(config.get('jobs', 1))
        self.compile_cc = config.get('CC', 'riscv32-unknown-elf-gcc')
        self.objcopy = config.get('OBJCOPY', 'riscv32-unknown-elf-objcopy')
        self.iverilog = config.get('IVERILOG', 'iverilog')
        self.vvp = config.get('VVP', 'vvp')
        self.target_run = bool(int(config.get('target_run', 1)))

        return sclass

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite_dir = suite
        self.archtest_env = archtest_env

        # -mabi/-march are fixed: this DUT is RV32I only.
        #
        # -Wl,--no-check-sections: link.ld puts IMEM/DMEM at the same
        # numeric ORIGIN (0x0) since they're separate physical memories in
        # simulation -- see link.ld's own comment. GNU ld's default LMA
        # overlap check doesn't know that and rejects it regardless of
        # memory-region names, so it has to be disabled explicitly.
        #
        # -mno-relax: without it, linker relaxation pads shrunk auipc/addi
        # sequences with 2-byte c.nop filler -- fine on real RVC hardware,
        # but this DUT has no C extension/16-bit decode path at all, so a
        # stray compressed opcode landing in the instruction stream would
        # be decoded incorrectly (confirmed causing an infinite trap loop
        # on Spike when this was still enabled for the reference model).
        self.compile_cmd = (
            self.compile_cc +
            ' -march=rv32i -mabi=ilp32 -static -mcmodel=medany '
            '-fvisibility=hidden -nostdlib -nostartfiles -g -mno-relax '
            '-Wl,--no-check-sections '
            '-T ' + os.path.join(self.pluginpath, 'env', 'link.ld') +
            ' -I ' + os.path.join(self.pluginpath, 'env') +
            ' -I {0} {1} -o {2} {3}'
        )

    def build(self, isa_yaml, platform_yaml):
        # Nothing to "build" ahead of time for an interpreted-per-test flow;
        # just sanity-check the tools we need are on PATH.
        for tool in (self.compile_cc, self.objcopy, self.iverilog, self.vvp):
            if shutil.which(tool) is None:
                logger.error(f"Required tool '{tool}' not found on PATH")
                raise SystemExit(1)

    def _read_symbols(self, elf, names):
        """Return {symbol_name: 'XXXXXXXX'} (plain hex digits, no 0x prefix
        -- `$value$plusargs(..., "%h", ...)` in the testbench expects bare
        hex digits) for the requested symbols, using nm."""
        nm = self.compile_cc.replace('gcc', 'nm').replace('-gcc', '-nm') \
            if 'gcc' in self.compile_cc else 'riscv32-unknown-elf-nm'
        out = subprocess.run(
            [nm, elf], capture_output=True, text=True, check=True
        ).stdout
        result = {}
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[-1] in names:
                result[parts[-1]] = parts[0]
        missing = set(names) - set(result)
        if missing:
            raise RuntimeError(
                f"Symbol(s) {missing} not found in {elf} -- check that "
                f"model_test.h/link.ld declare them as .global"
            )
        return result

    @staticmethod
    def _bin_to_readmemh(bin_path, hex_path):
        """Pack a flat raw binary into 32-bit little-endian words, one
        8-hex-digit word per line, for `$readmemh` into a
        `reg [31:0] memory [N]` array (word-indexed, matches
        instruction_memory.sv / data_memory.sv exactly)."""
        with open(bin_path, 'rb') as f:
            data = f.read()
        if len(data) % 4:
            data += b'\x00' * (4 - len(data) % 4)
        with open(hex_path, 'w') as out:
            for i in range(0, len(data), 4):
                word = int.from_bytes(data[i:i + 4], byteorder='little')
                out.write(f"{word:08x}\n")

    def runTests(self, testList):
        for testname in testList:
            testentry = testList[testname]
            test = testentry['test_path']
            test_dir = testentry['work_dir']
            os.makedirs(test_dir, exist_ok=True)

            elf = os.path.join(test_dir, 'dut.elf')
            imem_hex = os.path.join(test_dir, 'dut.imem.hex')
            dmem_hex = os.path.join(test_dir, 'dut.dmem.hex')
            sig_file = os.path.join(test_dir, self.name[:-1] + '.signature')
            sim_out = os.path.join(test_dir, 'dut.vvp')
            log_file = os.path.join(test_dir, 'dut.log')

            macros = ' '.join(['-D' + m for m in testentry['macros']])

            # A failure at any stage below (compile, objcopy, sim build/run)
            # for ONE test must not abort the whole suite -- log it, leave
            # an empty signature (a clean mismatch rather than a missing
            # file) and move on to the next test.
            try:
                cmd = self.compile_cmd.format(
                    self.archtest_env, macros, elf, test
                )
                logger.debug("Compiling: " + cmd)
                utils.shellCommand(cmd).run(cwd=test_dir)

                # Split the ELF into two flat binary images matched to the
                # DUT's two separate physical memories, then hand-convert
                # each to a $readmemh-compatible word-hex file ourselves.
                #
                # We deliberately do NOT use `objcopy -O verilog
                # --verilog-data-width=4`: that option has long-standing,
                # still-open binutils bugs where the packed word is emitted
                # in the wrong endianness regardless of target (binutils PR
                # 25202), which would silently corrupt every multi-byte
                # instruction/word loaded into the DUT. `-O binary` + our
                # own little-endian packer avoids that entirely.
                imem_bin = os.path.join(test_dir, 'dut.imem.bin')
                dmem_bin = os.path.join(test_dir, 'dut.dmem.bin')
                objcopy_i = (
                    f"{self.objcopy} -O binary --gap-fill=0x00 "
                    f"--pad-to=0x4000 -j .text.init -j .text {elf} {imem_bin}"
                )
                objcopy_d = (
                    f"{self.objcopy} -O binary --gap-fill=0x00 "
                    f"--pad-to=0x4000 -j .tohost -j .data -j .bss "
                    f"{elf} {dmem_bin}"
                )
                utils.shellCommand(objcopy_i).run(cwd=test_dir)
                utils.shellCommand(objcopy_d).run(cwd=test_dir)
                self._bin_to_readmemh(imem_bin, imem_hex)
                self._bin_to_readmemh(dmem_bin, dmem_hex)

                # Pull the addresses the testbench needs to know out of the
                # ELF symbol table, rather than assuming fixed offsets (the
                # linker is free to place tohost/begin_signature/
                # end_signature wherever they fit given each test's own
                # code/data size).
                sym_addrs = self._read_symbols(
                    elf, ('tohost', 'begin_signature', 'end_signature')
                )

                # Compile + elaborate the DUT + testbench with Icarus Verilog.
                dut_srcs = ' '.join(
                    os.path.join(SRC_DIR, f) for f in DUT_SOURCES
                )
                # NOTE: riscv_top.sv and friends use
                # `include "src/definitions.vh"` (relative to the *repo
                # root*, not to src/ itself) -- so the include path passed
                # to iverilog must be REPO_ROOT, not SRC_DIR.
                compile_sim = (
                    f"{self.iverilog} -g2012 -I {REPO_ROOT} "
                    f"-o {sim_out} {TB_FILE} {dut_srcs}"
                )
                utils.shellCommand(compile_sim).run(cwd=test_dir)

                # dut_tb.sv unconditionally $dumpfile's to sim/out/ relative
                # to its run directory; vvp doesn't create it, so it must
                # exist first or the VCD open fails and aborts the
                # simulation before a single instruction runs (silently
                # producing no signature).
                os.makedirs(os.path.join(test_dir, 'sim', 'out'),
                            exist_ok=True)

                # Run it. dut_tb.sv reads these plusargs; see tb/dut_tb.sv.
                run_sim = (
                    f"{self.vvp} {sim_out} "
                    f"+IMEM_HEX={imem_hex} +DMEM_HEX={dmem_hex} "
                    f"+SIGNATURE={sig_file} "
                    f"+TOHOST_ADDR={sym_addrs['tohost']} "
                    f"+SIG_START_ADDR={sym_addrs['begin_signature']} "
                    f"+SIG_END_ADDR={sym_addrs['end_signature']}"
                )
                logger.debug("Running: " + run_sim)
                with open(log_file, 'w') as fh:
                    subprocess.run(
                        run_sim, shell=True, cwd=test_dir,
                        stdout=fh, stderr=subprocess.STDOUT
                    )
            except Exception as e:
                logger.error(f"{testname} failed to build/run: {e}")

            if not os.path.exists(sig_file):
                logger.error(f"No signature produced for {testname}, "
                             f"see {log_file}")
                # RISCOF expects the file to exist even on failure so the
                # comparison step reports a clean mismatch instead of a
                # missing-file exception.
                open(sig_file, 'w').close()

        if self.target_run is False:
            raise SystemExit(0)
