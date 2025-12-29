OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
  tcm : ORIGIN = 0x80000000, LENGTH = 128K
}

SECTIONS
{
  .text :
  {
    *(.text)
    *(.text.*)
  } > tcm

  .data :
  {
    *(.data)
    *(.data.*)
  } > tcm

  .bss :
  {
    *(.bss)
    *(.bss.*)
  } > tcm
}
