#include <stdint.h>

#if !defined(MATMUL_DISABLE_STDIO)
#include <stdio.h>
#endif

#ifndef N
#define N 32
#endif

/*
 * Benchmarks the same matrix multiply kernel in two modes:
 *  1) default C '*' behavior, which maps to normal MUL on rv32im
 *  2) forced MULE for every timed 32-bit matrix product
 *
 * The goal is to compare total kernel cycle count, not just single-op latency.
 */

typedef struct {
  uint32_t cycles;
  long long checksum;
} matmul_result_t;

static int32_t A[N][N];
static int32_t B[N][N];
static int32_t C[N][N];

volatile uint32_t g_default_cycles;
volatile uint32_t g_all_mule_cycles;
volatile long long g_default_checksum;
volatile long long g_all_mule_checksum;

static inline uint32_t read_cycle(void) {
#if defined(__riscv)
  uint32_t value;
  __asm__ volatile ("rdcycle %0" : "=r"(value));
  return value;
#else
  return 0u;
#endif
}

static inline int32_t mule32(int32_t lhs, int32_t rhs) {
#if defined(__riscv)
  int32_t result;
  __asm__ volatile (
      ".insn r 0x0B, 0x0, 0x01, %0, %1, %2"
      : "=r"(result)
      : "r"(lhs), "r"(rhs));
  return result;
#else
  return lhs * rhs;
#endif
}

static void init_inputs(void) {
  for (int i = 0; i < N; ++i) {
    for (int j = 0; j < N; ++j) {
      A[i][j] = (int32_t)((i + 3 * j) % 17);
      B[i][j] = (int32_t)((2 * i - j) % 19);
    }
  }
}

static void clear_output(void) {
  for (int i = 0; i < N; ++i) {
    for (int j = 0; j < N; ++j) {
      C[i][j] = 0;
    }
  }
}

static long long checksum_matrix(void) {
  long long sum = 0;

  for (int i = 0; i < N; ++i) {
    for (int j = 0; j < N; ++j) {
      sum += C[i][j];
    }
  }

  return sum;
}

static __attribute__((noinline)) void matmul_default(void) {
  for (int i = 0; i < N; ++i) {
    int32_t *c_row = C[i];

    for (int k = 0; k < N; ++k) {
      int32_t aik = A[i][k];
      int32_t *b_row = B[k];

      for (int j = 0; j < N; ++j) {
        c_row[j] += aik * b_row[j];
      }
    }
  }
}

static __attribute__((noinline)) void matmul_all_mule(void) {
  for (int i = 0; i < N; ++i) {
    int32_t *c_row = C[i];

    for (int k = 0; k < N; ++k) {
      int32_t aik = A[i][k];
      int32_t *b_row = B[k];

      for (int j = 0; j < N; ++j) {
        c_row[j] += mule32(aik, b_row[j]);
      }
    }
  }
}

#if !defined(MATMUL_DISABLE_STDIO)
static void print_result(const char *label,
                         const matmul_result_t *result,
                         unsigned long long mul_ops) {
  unsigned long long milli_cycles_per_mul = 0;

  if (mul_ops != 0) {
    milli_cycles_per_mul =
        ((unsigned long long)result->cycles * 1000ull) / mul_ops;
  }

  printf("%s checksum=%lld cycles=%u cycles_per_mul=%llu.%03llu\n",
         label,
         result->checksum,
         (unsigned)result->cycles,
         milli_cycles_per_mul / 1000ull,
         milli_cycles_per_mul % 1000ull);
}
#endif

int main(void) {
  const unsigned long long mul_ops =
      (unsigned long long)N * (unsigned long long)N * (unsigned long long)N;
  matmul_result_t default_result;
  matmul_result_t all_mule_result;
  uint32_t start_cycle;
  uint32_t stop_cycle;

  init_inputs();

  clear_output();
  start_cycle = read_cycle();
  matmul_default();
  stop_cycle = read_cycle();
  default_result.cycles = stop_cycle - start_cycle;
  default_result.checksum = checksum_matrix();

  clear_output();
  start_cycle = read_cycle();
  matmul_all_mule();
  stop_cycle = read_cycle();
  all_mule_result.cycles = stop_cycle - start_cycle;
  all_mule_result.checksum = checksum_matrix();

  g_default_cycles = default_result.cycles;
  g_all_mule_cycles = all_mule_result.cycles;
  g_default_checksum = default_result.checksum;
  g_all_mule_checksum = all_mule_result.checksum;

#if !defined(MATMUL_DISABLE_STDIO)
#if !defined(__riscv)
  printf("note: non-RISC-V build falls back to '*' for MULE and reports 0 cycles\n");
#endif
  printf("N=%d mul_ops=%llu\n", N, mul_ops);
  print_result("default", &default_result, mul_ops);
  print_result("all-mule", &all_mule_result, mul_ops);

  if (default_result.checksum == all_mule_result.checksum) {
    long long cycle_delta =
        (long long)all_mule_result.cycles - (long long)default_result.cycles;

    printf("delta_cycles=%lld\n", cycle_delta);

    if (default_result.cycles != 0u) {
      unsigned long long slowdown_pct =
          ((unsigned long long)all_mule_result.cycles * 100ull) /
          (unsigned long long)default_result.cycles;
      printf("all-mule_vs_default=%llu%%\n", slowdown_pct);
    }
  } else {
    printf("checksum mismatch: default=%lld all-mule=%lld\n",
           default_result.checksum,
           all_mule_result.checksum);
  }
#endif

  return (default_result.checksum == all_mule_result.checksum) ? 0 : 1;
}