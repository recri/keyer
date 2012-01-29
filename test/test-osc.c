/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/
#include "../sdrkit/dmath.h"

#ifdef OSC_MAKE
#ifdef OSCILLATOR_D
#ifdef OSCILLATOR_F
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_fd_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_fd_process() { return oscillator_process(&osc); }
#endif
#ifdef OSCILLATOR_T
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_td_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_td_process() { return oscillator_process(&osc); }
#endif
#ifdef OSCILLATOR_Z
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_zd_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_zd_process() { return oscillator_process(&osc); }
#endif
#else
#ifdef OSCILLATOR_F
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_f_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_f_process() { return oscillator_process(&osc); }
#endif
#ifdef OSCILLATOR_T
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_t_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_t_process() { return oscillator_process(&osc); }
#endif
#ifdef OSCILLATOR_Z
#include "../sdrkit/oscillator.h"
static oscillator_t osc;
void osc_z_init(float hertz, float radians, int sample_rate) { oscillator_init(&osc, hertz, radians, sample_rate); }
float complex osc_z_process() { return oscillator_process(&osc); }
#endif
#endif
#else
extern void osc_fd_init(float hertz, float radians, int sample_rate);
extern float complex osc_fd_process();
extern void osc_td_init(float hertz, float radians, int sample_rate);
extern float complex osc_td_process();
extern void osc_zd_init(float hertz, float radians, int sample_rate);
extern float complex osc_zd_process();
extern void osc_f_init(float hertz, float radians, int sample_rate);
extern float complex osc_f_process();
extern void osc_t_init(float hertz, float radians, int sample_rate);
extern float complex osc_t_process();
extern void osc_z_init(float hertz, float radians, int sample_rate);
extern float complex osc_z_process();

#include <stdio.h>
#include <sys/times.h>
#include <unistd.h>

static char *var_name[] = { "fd", "td", "zd", "f", "t", "z" };

typedef struct {
  long int n;
  double mu, sigma;
  long double sum, sum2;
} summary_t;

typedef struct {
  int n;
  float complex prev;
  double time;
  summary_t mag, phi, dphi;
} results_t;

static results_t variants[6];

void test_mag(summary_t *r, float complex z, int frame, float hertz, int sample_rate) {
  double mag = cabs(z)-1.0;
  r->n += 1;
  r->sum += mag;
  r->sum2 += mag*mag;
}
// this one really doesn't work very well
void test_phi(summary_t *r, float complex z, float complex zp, int frame, float hertz, int sample_rate) {
  double pi = atan2(0, -1);
  double half_pi = pi/2;
  double phi0 = atan2(cimagf(z), crealf(z));
  double phi1 = acosf(crealf(z));
  double phi2 = asinf(cimagf(z));
  if (isnan(phi1) || isnan(phi2)) {
    if (isnan(phi1)) fprintf(stderr, "acosf(%f) is a NaN\n", crealf(z));
    if (isnan(phi2)) fprintf(stderr, "asinf(%f) is a NaN\n", cimagf(z));
    return;
  }
  if (phi0 <= -half_pi) {
    phi1 = -phi1;
    phi2 = -pi - phi2;
  } else if (phi0 <= 0) {
    phi1 = -phi1;
  } else if (phi0 <= half_pi) {

  } else if (phi0 <= pi) {
    phi2 = pi - phi2;
  } else {
    fprintf(stderr, "atan2(%f, %f) -> %f radians is in no quadrant!\n", cimag(z), creal(z), phi0);
  }
  fprintf(stdout, "phi0 %f, phi1 %f, phi2 %f\n", phi0, phi1, phi2);
  double d = phi1-phi2;
  if (fabs(d) > 0.001)
  r->n += 1;
  r->sum += d;
  r->sum2 += d*d;
}
void test_dphi(summary_t *r, float complex z, float complex zp, int frame, float hertz, int sample_rate) {
  const double pi = atan2(0, -1);
  const double two_pi = 2*pi;
  double dphi = atan2(cimagf(z),crealf(z))-atan2(cimagf(zp),crealf(zp));
  if (hertz > 0 && dphi < 0)
    dphi += two_pi;
  else if (hertz < 0 && dphi > 0)
    dphi -= two_pi;
  dphi -= two_pi * hertz / sample_rate;
  r->n += 1;
  r->sum += dphi;
  r->sum2 += dphi*dphi;
}
void compute_summary(summary_t *r) {
  r->mu = r->sum / r->n;
  r->sigma = sqrt(r->sum2/r->n - r->mu * r->mu);
}
void print_summary(char *s1, char *s2, summary_t *r) {
  compute_summary(r);
  fprintf(stdout, "%2s %4s n %10ld mu %18e sigma %18e\n", s1, s2, r->n, r->mu, r->sigma);
}
void reset_summary(summary_t *r) {
  r->n = 0;
  r->mu = 0;
  r->sigma = 0;
  r->sum = 0;
  r->sum2 = 0;
}

void test(int var, float complex z, int frame, float hertz, int sample_rate) {
  test_mag(&variants[var].mag, z, frame, hertz, sample_rate);
  if (variants[var].n > 0) {
    // test_phi(&variants[var].phi, z, variants[var].prev, frame, hertz, sample_rate);
    test_dphi(&variants[var].dphi, z, variants[var].prev, frame, hertz, sample_rate);
  }
  variants[var].prev = z;
  variants[var].n += 1;
}
void print_results(char *name, results_t *v) {
  fprintf(stdout, "%2s %5.2f ns %10ld %18e %18e %10ld %18e %18e\n", name, v->time*1e9, v->mag.n, v->mag.mu, v->mag.sigma, v->dphi.n, v->dphi.mu, v->dphi.sigma);
}
void summarize(int var) {
  // fprintf(stdout, "%2s time %.2f nsecs/sample\n", var_name[var], variants[var].time*1e9);
  // print_summary(var_name[var], "mag", &variants[var].mag);
  // print_summary(var_name[var], "phi", &variants[var].phi);
  // print_summary(var_name[var], "dphi", &variants[var].dphi);
  compute_summary(&variants[var].mag);
  // compute_summary(&variants[var].phi);
  compute_summary(&variants[var].dphi);
  print_results(var_name[var], &variants[var]);
}
void time(int var, float complex (*func)(), int n) {
  struct tms start, finish;
  times(&start);
  for (int i = n; --i >= 0; ) { volatile float z = func(); }
  times(&finish);
  variants[var].time = (double)(finish.tms_utime-start.tms_utime) / (n * sysconf(_SC_CLK_TCK));
}
void reset(int var) {
  reset_summary(&variants[var].mag);
  // reset_summary(&variants[var].phi);
  reset_summary(&variants[var].dphi);
}
int main(int argc, char *argv[]) {
  int n = argc > 1 ? atoi(argv[1]) : 1000;
  float hertz = argc > 2 ? atof(argv[2]) : 440.0f;
  float radians = argc > 3 ? atof(argv[3]) : 0.0f;
  int sample_rate = argc > 4 ? atoi(argv[4]) : 96000;
  long int frame = 0;
  AVOID_DENORMALS;
  osc_fd_init(hertz, radians, sample_rate);
  osc_td_init(hertz, radians, sample_rate);
  osc_zd_init(hertz, radians, sample_rate);
  // osc_f_init(hertz, radians, sample_rate);
  // osc_t_init(hertz, radians, sample_rate);
  // osc_z_init(hertz, radians, sample_rate);
  while (1) {
    reset(0);
    reset(1);
    reset(2);
    // reset(3);
    // reset(4);
    // reset(5);
    for (int i = 0; i < n; i += 1) {
      test(0, osc_fd_process(), frame, hertz, sample_rate);
      test(1, osc_td_process(), frame, hertz, sample_rate);
      test(2, osc_zd_process(), frame, hertz, sample_rate);
      // test(3, osc_f_process(), frame, hertz, sample_rate);
      // test(4, osc_t_process(), frame, hertz, sample_rate);
      // test(5, osc_z_process(), frame, hertz, sample_rate);
      frame += 1;
    }
    // time(0, osc_fd_process, n);
    // time(1, osc_td_process, n);
    // time(2, osc_zd_process, n);
    // time(3, osc_f_process, n);
    // time(4, osc_t_process, n);
    // time(5, osc_z_process, n);
    summarize(0);
    summarize(1);
    summarize(2);
    //summarize(3);
    //summarize(4);
    //summarize(5);
  }
  return 0;
}
#endif
