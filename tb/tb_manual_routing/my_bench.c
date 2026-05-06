/*
 * Manual mul / mule routing testbench
 *
 * Write your kernel here.
 * Use  mul  rd, rs1, rs2   for the standard fast multiplier path.
 * Use  mule rd, rs1, rs2   for the low-power multi-cycle path.
 *   (encoded as:  .word 0x0200000B | (rd<<7) | (rs1<<15) | (rs2<<20)
 *    or use the MULE(rd,rs1,rs2) inline-asm macro below)
 *
 * The testbench passes when main() returns 0, fails otherwise.
 */

#define MULE(rd_str, rs1_str, rs2_str) \
    __asm__ volatile( \
        ".insn r 0x0B, 0x0, 0x01, " rd_str ", " rs1_str ", " rs2_str \
        : "=r"(rd_str) : "r"(rs1_str), "r"(rs2_str))

/* 
 * Alternatively, write the raw encoding in a wrapper:
 *
 *   static inline int mule(int a, int b) {
 *       int result;
 *       asm volatile(
 *           ".word (0x0200000B | (%1 << 15) | (%2 << 20))\n\t"
 *           : "=r"(result) : "r"(a), "r"(b));
 *       return result;
 *   }
 *
 * Or just inline manually as shown below via the helper.
 */

static inline int mul_fast(int a, int b) {
    int r;
    asm volatile("mul %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static inline int mul_slow(int a, int b) {
    /* MULE opcode: funct7=0x01, funct3=0x0, opcode=0x0B (custom-0)
       Encoding: INST_MULE = 0x0200000B → bits 31:25 = 0000001 = funct7=1 */
    int r;
    asm volatile(".insn r 0x0B, 0x0, 0x01, %0, %1, %2"
                 : "=r"(r) : "r"(a), "r"(b));
    return r;
}

/* ------------------------------------------------------------------ */
/* YOUR KERNEL: edit freely between the dashed lines                   */
/* ------------------------------------------------------------------ */

#define N 8

int kernel(int *a, int *b) {
    int acc = 0;
    for (int i = 0; i < N; i++) {
        /*
         * Route multiplies manually:
         *   - use mul_fast() for results needed in the next 1-2 cycles
         *   - use mul_slow() when the result is not consumed until 4+ cycles later
         *
         * Example: safe to use mule here because acc is only read at
         * the loop-carried add, which is several instructions away.
         */
        acc += mul_slow(a[i], b[i]);
    }
    return acc;
}

/* ------------------------------------------------------------------ */

int main(void) {
    int a[N] = {1, 2, 3, 4, 5, 6, 7, 8};
    int b[N] = {8, 7, 6, 5, 4, 3, 2, 1};

    /* Reference: compute with fast mul */
    int ref = 0;
    for (int i = 0; i < N; i++)
        ref += mul_fast(a[i], b[i]);

    /* Test: run your kernel */
    int got = kernel(a, b);

    /* Return 0 = pass, non-zero = fail */
    return (got == ref) ? 0 : 1;
}
