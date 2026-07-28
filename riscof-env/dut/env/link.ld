/*
 * link.ld for the "riscv_top" DUT (huntbyington/RISC-V_R32I)
 *
 * riscv_top is a Harvard architecture: instruction_memory and data_memory
 * are two SEPARATE 16KB arrays, each independently indexed by the low
 * address bits ($clog2(INST_MEM_SIZE)-1:0 / $clog2(DATA_MEM_SIZE)-1:0).
 * Both are modeled here as MEMORY regions based at 0x0 -- this is fine for
 * ld even though their address ranges numerically overlap, since code and
 * data live in genuinely separate physical arrays in simulation.
 *
 * NOTE: the standard riscv-arch-test link.ld uses `. = ALIGN(0x1000);`
 * between sections. That 4KB alignment alone would blow through this DUT's
 * entire 16KB budget after just a couple of sections, so those alignments
 * are reduced to word alignment here to keep everything tightly packed.
 *
 * If you change INST_MEM_SIZE / DATA_MEM_SIZE in src/definitions.vh, update
 * the LENGTH values below to match.
 */

OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rw)  : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text.init : { *(.text.init) }                       > IMEM

    . = ALIGN(4);
    .tohost    : { *(.tohost) }                          > DMEM

    . = ALIGN(4);
    .text : { *(.text) *(.text.*) }                      > IMEM

    . = ALIGN(4);
    .data : { *(.data) *(.data.*) *(.rodata) *(.rodata.*) } > DMEM

    . = ALIGN(4);
    .bss : { *(.bss) *(.bss.*) *(COMMON) }               > DMEM

    _end = .;

    /DISCARD/ : { *(.riscv.attributes) *(.comment) }
}
