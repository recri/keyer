#ifndef KEYER_RAMP_H
#define KEYER_RAMP_H

#include "keyer_osc.h"

/*
** sine attack/decay ramp
** uses 1/4 of an oscillator period to generate a sine
*/
typedef struct {
  int target;			/* sample length of ramp */
  int current;			/* current sample point in ramp */
  osc_t ramp;			/* ramp oscillator */
} ramp_t;

static void ramp_init(ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000);
  r->current = 0;
  osc_init(&r->ramp, 1000/(4*ms), samples_per_second);
}

static void ramp_update(ramp_t *r, float ms, int samples_per_second) {
  r->target = samples_per_second * (ms / 1000);
  osc_update(&r->ramp, 1000/(4*ms), samples_per_second);
}

static void ramp_reset(ramp_t *r) {
  r->current = 0;
  osc_reset(&r->ramp);
}

static float ramp_next(ramp_t *r) {
  float x, y;
  r->current += 1;
  osc_next_xy(&r->ramp, &x, &y);
  return y;
}

static int ramp_done(ramp_t *r) {
  return r->current == r->target;
}

#endif
