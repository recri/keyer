#ifndef OSC_H
#define OSC_H

/*
** oscillator.
** uses a recursive filter which will oscillate up to 1/4 sample rate
*/
typedef struct {
  float xi, c, x, y;
} osc_t;

static float squaref(float x) { return x * x; }

static void osc_set_hertz(osc_t *o, float hertz, int samples_per_second, int init) {
  const float pi = 3.14159265358979323846;
  float current_xi = o->xi;
  float wps = hertz / samples_per_second;
  float rps = wps * 2 * pi;
  o->c = sqrtf(1.0 / (1.0 + squaref(tanf(rps))));
  o->xi = sqrtf((1.0 - o->c) / (1.0 + o->c));
  if (init) {
    o->x = o->xi;
    o->y = 0;
  } else {
    o->x *=  o->xi / current_xi;
  }
}

static void osc_init(osc_t *o, float hertz, int samples_per_second) {
  osc_set_hertz(o, hertz, samples_per_second, 1);
}

static void osc_update(osc_t *o, float hertz, int samples_per_second) {
  osc_set_hertz(o, hertz, samples_per_second, 0);
}

static void osc_reset(osc_t *o) {
  o->x = o->xi;
  o->y = 0;
}

static void osc_next_xy(osc_t *o, float *x, float *y) {
  float t = (o->x + o->y) * o->c;
  float nx = t-o->y;
  float ny = t+o->x;
  *x = (o->x = nx) / o->xi;	/* check if keeping 1/xi is worth while */
  *y = o->y = ny;
}

#endif
