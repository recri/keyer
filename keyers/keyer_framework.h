#ifndef KEYER_FRAMEWORK_H
#define KEYER_FRAMEWORK_H

#include "jack/jack.h"

#include "keyer_options.h"

enum {
  require_midi_in = 1,
  require_midi_out = 2,
  require_out_i = 4,
  require_out_q = 8
};

typedef struct {
  keyer_options_t opts;
  jack_client_t *client;
  jack_port_t *midi_in;
  jack_port_t *midi_out;
  jack_port_t *out_i;
  jack_port_t *out_q;
  int argc;
  char **argv;
  char *default_client_name;
  unsigned ports_required;
  int (*process_callback)(jack_nframes_t nframes, void *arg);
  void (*receive_input_char)(char c);
} keyer_framework_t;

extern void keyer_framework_main(keyer_framework_t *kfp, int argc, char **argv,
				 char *default_client_name, unsigned ports_required,
				 void (*init)(),
				 int (*process_callback)(jack_nframes_t nframes, void *arg),
				 void (*receive_input_char)(char c));

#endif
