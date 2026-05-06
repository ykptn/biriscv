#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

enum
{
    BENCH_OUTPUT_NONE = 0,
    BENCH_OUTPUT_LITERAL = 1,
    BENCH_OUTPUT_SIGNED = 2,
    BENCH_OUTPUT_STRING = 3,
};

char bench_format_prefix[96];
char bench_format_suffix[96];
char bench_literal_text[128];
char bench_string_value[128];
long long bench_last_signed_value;
unsigned int bench_output_kind;
unsigned int bench_output_overflow;

static void bench_clear_buffer(char *buffer, size_t buffer_size)
{
    if (buffer_size != 0)
        buffer[0] = '\0';
}

static void bench_reset_capture(void)
{
    bench_clear_buffer(bench_format_prefix, sizeof(bench_format_prefix));
    bench_clear_buffer(bench_format_suffix, sizeof(bench_format_suffix));
    bench_clear_buffer(bench_literal_text, sizeof(bench_literal_text));
    bench_clear_buffer(bench_string_value, sizeof(bench_string_value));
    bench_last_signed_value = 0;
    bench_output_kind = BENCH_OUTPUT_NONE;
    bench_output_overflow = 0;
}

static void bench_copy_text(char *buffer, size_t buffer_size, const char *text)
{
    size_t index = 0;

    if (!text)
        text = "(null)";

    if (buffer_size == 0)
    {
        bench_output_overflow = 1;
        return;
    }

    while (text[index] != '\0')
    {
        if (index + 1 >= buffer_size)
        {
            bench_output_overflow = 1;
            buffer[buffer_size - 1] = '\0';
            return;
        }

        buffer[index] = text[index];
        index++;
    }

    buffer[index] = '\0';
}

static void bench_copy_range(char *buffer, size_t buffer_size, const char *start, const char *end)
{
    size_t index = 0;

    if (buffer_size == 0)
    {
        bench_output_overflow = 1;
        return;
    }

    while (start < end)
    {
        if (index + 1 >= buffer_size)
        {
            bench_output_overflow = 1;
            buffer[buffer_size - 1] = '\0';
            return;
        }

        buffer[index++] = *start++;
    }

    buffer[index] = '\0';
}

__attribute__((weak)) int bench_verify_output(void)
{
    return 0;
}

int printf(const char *format, ...)
{
    va_list args;
    const char *cursor;
    const char *format_start;

    bench_reset_capture();
    va_start(args, format);

    if (!format)
    {
        bench_output_overflow = 1;
        va_end(args);
        return 0;
    }

    format_start = format;
    cursor = format;
    while (*cursor && *cursor != '%')
        cursor++;

    if (*cursor == '\0')
    {
        bench_output_kind = BENCH_OUTPUT_LITERAL;
        bench_copy_text(bench_literal_text, sizeof(bench_literal_text), format_start);
        va_end(args);
        return 0;
    }

    bench_copy_range(bench_format_prefix, sizeof(bench_format_prefix), format_start, cursor);
    cursor++;

    if (*cursor == '%')
    {
        bench_output_kind = BENCH_OUTPUT_LITERAL;
        bench_copy_text(bench_literal_text, sizeof(bench_literal_text), format_start);
        va_end(args);
        return 0;
    }

    unsigned int long_count = 0;
    while (*cursor == 'l')
    {
        long_count++;
        cursor++;
    }

    switch (*cursor)
    {
    case 'd':
    case 'i':
        bench_output_kind = BENCH_OUTPUT_SIGNED;
        if (long_count >= 2)
            bench_last_signed_value = va_arg(args, long long);
        else
            bench_last_signed_value = (long long)va_arg(args, int);
        break;
    case 's':
        bench_output_kind = BENCH_OUTPUT_STRING;
        bench_copy_text(bench_string_value, sizeof(bench_string_value), va_arg(args, const char *));
        break;
    default:
        bench_output_overflow = 1;
        bench_output_kind = BENCH_OUTPUT_NONE;
        break;
    }

    if (*cursor != '\0')
        cursor++;
    bench_copy_text(bench_format_suffix, sizeof(bench_format_suffix), cursor);

    va_end(args);
    return 0;
}

int puts(const char *s)
{
    bench_reset_capture();
    bench_output_kind = BENCH_OUTPUT_LITERAL;
    bench_copy_text(bench_literal_text, sizeof(bench_literal_text), s);
    if (!bench_output_overflow)
        bench_copy_text(bench_format_suffix, sizeof(bench_format_suffix), "\n");
    return 0;
}

int putchar(int c)
{
    char text[2];

    bench_reset_capture();
    bench_output_kind = BENCH_OUTPUT_LITERAL;
    text[0] = (char)c;
    text[1] = '\0';
    bench_copy_text(bench_literal_text, sizeof(bench_literal_text), text);
    return c;
}