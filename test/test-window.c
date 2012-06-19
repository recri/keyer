
#include <stdio.h>

#include "../dspmath/window.h"

#define SIZE 4097

float buffer[SIZE];

int main(int argc, char *argv[]) {
  for (int i = 0; window_names[i] != NULL; i += 1) {
    int mismatches = 0;
    window_make(i, SIZE, buffer);
    for (int k = 0; k < SIZE; k += 1) {
      float get = window_get(i, SIZE, k);
      if (get != buffer[k]) mismatches += 1;
    }
    if (mismatches != 0) fprintf(stderr, "%4d mismatches in %s\n", mismatches, window_names[i]);
  }
  return 0;
}
