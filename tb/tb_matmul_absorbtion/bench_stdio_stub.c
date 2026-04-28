#include <stdarg.h>
#include <stdio.h>

int printf(const char *format, ...)
{
    (void)format;
    return 0;
}

int puts(const char *s)
{
    (void)s;
    return 0;
}

int putchar(int c)
{
    return c;
}