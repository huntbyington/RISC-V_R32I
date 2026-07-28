// model_test.h for the "riscv_top" DUT (huntbyington/RISC-V_R32I)
//
// Adapted from the reference model_test.h shipped with riscv-isa-sim's
// arch_test_target/spike, simplified because this core:
//   - implements pure RV32I only (no Zicsr, no privileged modes, no traps)
//   - can therefore never take an unexpected exception mid-test
//   - halts purely via a plain store instruction to a well-known "tohost"
//     address, which the testbench (tb/dut_tb.sv) snoops on the data_memory
//     write port -- no CSR/mtvec/ecall machinery required.
//
#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

// ---------------------------------------------------------------------------
// Data section: tohost/fromhost + register-state bookkeeping expected by the
// standard riscv-arch-test env macros (RVTEST_DATA_BEGIN et al. reference
// these symbols from riscv-test-suite/env/riscv_test.h / arch_test.h).
// ---------------------------------------------------------------------------
#define RVMODEL_DATA_SECTION                                            \
        .pushsection .tohost,"aw",@progbits;                            \
        .align 8; .global tohost; tohost: .dword 0;                     \
        .align 8; .global fromhost; fromhost: .dword 0;                 \
        .popsection;                                                    \
        .align 8; .global begin_regstate; begin_regstate:                \
        .word 128;                                                      \
        .align 8; .global end_regstate; end_regstate:                   \
        .word 4;

// ---------------------------------------------------------------------------
// RVMODEL_BOOT: nothing to do. PC resets to 0 in hardware and there is no
// mtvec/CSR state to initialize for a base-I-only core.
// ---------------------------------------------------------------------------
#define RVMODEL_BOOT

// ---------------------------------------------------------------------------
// RVMODEL_HALT: signal completion using only plain loads/stores/jumps -
// deliberately avoids csrw/ecall/ebreak since the DUT decodes none of them.
// Writes 1 to `tohost`; the testbench treats any nonzero write to that
// address as "test finished" and dumps the signature region.
// ---------------------------------------------------------------------------
#define RVMODEL_HALT                                                     \
        li x1, 1;                                                        \
        la x2, tohost;                                                   \
write_tohost:                                                            \
        sw x1, 0(x2);                                                    \
        j write_tohost;

#define RVMODEL_DATA_BEGIN                                              \
        RVMODEL_DATA_SECTION                                            \
        .align 4;                                                       \
        .global begin_signature; begin_signature:

#define RVMODEL_DATA_END                                                \
        .align 4; .global end_signature; end_signature:

// ---------------------------------------------------------------------------
// No I/O, no interrupts, no floating point on this core -- all no-ops.
// ---------------------------------------------------------------------------
#define RVMODEL_IO_INIT
#define RVMODEL_IO_WRITE_STR(_R, _STR)
#define RVMODEL_IO_CHECK()
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

#define RVMODEL_SET_MSW_INT
#define RVMODEL_CLEAR_MSW_INT
#define RVMODEL_CLEAR_MTIMER_INT
#define RVMODEL_CLEAR_MEXT_INT

#endif // _COMPLIANCE_MODEL_H
