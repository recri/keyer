#include <stdio.h>
#include <jack/jack.h>

int main(int argc, char *argv[]) {
  fprintf(stderr, "sizeof(jack_nframes_t) == %ld\n", sizeof(jack_nframes_t));
  fprintf(stderr, "rollover in %.1f hours @ 48k\n", (0xffffffffl/48000)/(60.0*60.0));
  fprintf(stderr, "rollover in %.1f hours @ 96k\n", (0xffffffffl/96000)/(60.0*60.0));
  fprintf(stderr, "rollover in %.1f hours @ 192k\n", (0xffffffffl/192000)/(60.0*60.0));
  return 0;
}
