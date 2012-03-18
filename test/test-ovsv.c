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

#include <stdio.h>
#include <sys/times.h>
#include <unistd.h>

#include "../sdrkit/filter_overlap_save.h"

filter_overlap_save_options_t opts;
filter_overlap_save_t ovsv;

int main(int argc, char *argv[]) {
  const int n = argc>1 ? atoi(argv[1]) : 32*1024;
  opts.length = 8192;
  opts.planbits = 0;
  opts.low_frequency = -5000.0f;
  opts.high_frequency = 5000.0f;
  opts.sample_rate = 192000;
  void *e = filter_overlap_save_init(&ovsv, &opts); if (e != &ovsv) {
    fprintf(stderr, "init returned \"%s\"\n", (char *)e);
    return 1;
  }
  struct tms start, finish;
  times(&start);
  for (int i = 0; i < n; i += 1) {
    float complex y = filter_overlap_save_process(&ovsv, 0.0f);
  }
  times(&finish);
  fprintf(stdout, "%g\n", 192000*(double)(finish.tms_utime-start.tms_utime) / (n * sysconf(_SC_CLK_TCK)));
}

