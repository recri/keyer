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

#define OSCILLATOR_Z 1		/* use complex rotor */
#define OSCILLATOR_D 1		/* use double precision */

#include "../sdrkit/dmath.h"
#include "../sdrkit/oscillator.h"

#include <stdio.h>
#include <sys/times.h>
#include <unistd.h>

typedef enum {
  OSC8K, OSC16K, OSC24K, OSC32K, OSC48K, OSC96K, OSC192K, NOSC
} oscs_t;

static int speed[NOSC] = {
  8000, 16000, 24000, 32000, 48000, 96000, 192000
};

static oscillator_t osc[NOSC];

typedef struct {
  long int n;			/* number of samples */
  double mu, sigma;		/* mean of samples, stddev of samples */
  long double sum, sum2;	/* sum of samples, sum^2 of samples */
} summary_t;

typedef struct {
  int n;
  float complex prev;
  double samples;
  summary_t mag, dphi;
} results_t;

static results_t res[NOSC];


void test_mag(summary_t *r, float complex z, float hertz, int sample_rate) {
  double mag = cabs(z)-1.0;
  r->n += 1;
  r->sum += mag;
  r->sum2 += mag*mag;
}

void test_dphi(summary_t *r, float complex z, float complex zp, float hertz, int sample_rate) {
  static const double pi = atan2(0, -1);
  static const double two_pi = 2*pi;
  double dphi = atan2(cimagf(z),crealf(z))-atan2(cimagf(zp),crealf(zp));
  if (hertz > 0 && dphi < 0)
    dphi += two_pi;
  else if (hertz < 0 && dphi > 0)
    dphi -= two_pi;
  dphi -= two_pi * hertz / sample_rate; /* expected value */
  r->n += 1;
  r->sum += dphi;
  r->sum2 += dphi*dphi;
}

void compute_summary(summary_t *r) {
  r->mu = r->sum / r->n;
  r->sigma = sqrt(fabs(r->sum2/r->n - r->mu * r->mu));
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

void test(int spd, float complex z, float hertz, int sample_rate) {
  test_mag(&res[spd].mag, z, hertz, sample_rate);
  if (res[spd].n > 0)
    test_dphi(&res[spd].dphi, z, res[spd].prev, hertz, sample_rate);
  res[spd].prev = z;
  res[spd].n += 1;
}

void print_results(int speed, results_t *v) {
  double t = v->samples / (speed*60.0*60.0);	/* samples converted into hours */
  char *u = "h";
  if (t >= 24) {
    t /= 24.0;
    u = "d";			/* converted to days */
    if (t >= 100) {
      t /= 365.0;
      u = "y";			/* converted to years */
    }
  }
  fprintf(stdout, "%3dk %7.3f %s %18e %18e %18e %18e\n", speed/1000, t, u, v->mag.mu, v->mag.sigma, v->dphi.mu, v->dphi.sigma);
}

void summarize(int spd) {
  compute_summary(&res[spd].mag);
  compute_summary(&res[spd].dphi);
  print_results(speed[spd], &res[spd]);
}

void reset(int spd) {
  reset_summary(&res[spd].mag);
  reset_summary(&res[spd].dphi);
}

int main(int argc, char *argv[]) {
  float hertz = argc > 1 ? atof(argv[1]) : 440.0f;

  // AVOID_DENORMALS;

  for (int spd = OSC8K; spd <= OSC192K; spd += 1)
    oscillator_init(&osc[spd], hertz, 0.0f, speed[spd]);

  int trun = 60*60;		/* one hour */
  int tsmp = 60;		/* one minute */
  
  for (;;) {
    for (int spd = OSC8K; spd <= OSC192K; spd += 1) {
      int nrun = trun * speed[spd];
      int nsmp = tsmp * speed[spd];
      for (int j = 0; j < nrun-nsmp; j += 1) {
	float z = oscillator_process(&osc[spd]);
      }
      for (int j = 0; j < nsmp; j += 1) {
	test(spd, oscillator_process(&osc[spd]), hertz, speed[spd]);
      }
      res[spd].samples += nrun;
      summarize(spd);
      reset(spd);
    }
  }
  return 0;
}

