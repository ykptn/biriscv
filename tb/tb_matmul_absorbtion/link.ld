ENTRY(_start)

SECTIONS
{
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
        *(.sbss*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
    }
}