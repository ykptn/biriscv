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

    bnez a0, fail_loop
    j    pass_loop

.section .bss
.align 4
stack_space:
    .space 4096
stack_top: