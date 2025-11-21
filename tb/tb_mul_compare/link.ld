ENTRY(_start)

SECTIONS
{
    /* Instruction memory starts at 0x80000000 */
    . = 0x80000000;

    .text ALIGN(256) : {
        *(.text*)
        *(.rodata*)
    }

    . = ALIGN(4);
    .data : {
        *(.data*)
        *(.sdata*)
        *(.bss*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
    }
}
