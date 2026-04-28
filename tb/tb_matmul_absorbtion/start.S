.section .text
.align 4
.globl _start

.option norelax
.equ PASS_OFFSET, 0x130
.equ FAIL_OFFSET, 0x134

_start:
    j boot_main

.space PASS_OFFSET - (. - _start)
pass_loop:
    j pass_loop

.space FAIL_OFFSET - (. - _start)
fail_loop:
    j fail_loop

.align 4
boot_main:
    la   sp, stack_top
    call main

    la   t0, g_default_checksum
    lw   x12, 0(t0)
    la   t0, g_all_mule_checksum
    lw   x13, 0(t0)
    la   t0, g_default_cycles
    lw   x20, 0(t0)
    la   t0, g_all_mule_cycles
    lw   x21, 0(t0)
    sub  x22, x21, x20

    bnez a0, fail_loop
    j    pass_loop

.section .bss
.align 4
stack_space:
    .space 4096
stack_top: