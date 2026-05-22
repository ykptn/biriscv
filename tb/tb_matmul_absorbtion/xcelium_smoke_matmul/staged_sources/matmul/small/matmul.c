#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 16
#endif

static int32_t A[N][N];
static int32_t B[N][N];
static int32_t C[N][N];

static void init() {
  for (int i=0;i<N;i++)
    for (int j=0;j<N;j++) {
      A[i][j] = (i + 3*j) % 17;
      B[i][j] = (2*i - j) % 19;
      C[i][j] = 0;
    }
}

static long long checksum() {
  long long s = 0;
  for (int i=0;i<N;i++)
    for (int j=0;j<N;j++)
      s += C[i][j];
  return s;
}

int main() {
  init();

  for (int i=0;i<N;i++) {
    for (int k=0;k<N;k++) {
      int32_t aik = A[i][k];
      for (int j=0;j<N;j++) {
        C[i][j] += aik * B[k][j];
      }
    }
  }

  printf("checksum=%lld\n", checksum());
  return 0;
}
