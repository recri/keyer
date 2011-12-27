
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <jack/jack.h>

#include "keyer_framework.h"

/*
** The main framework for as an application:
** 1) Specify it's default jack client name.
** 2) Parse arguments
** 3) Open jack client
** 4) Set the sample rate and initialize client code
** 5) Set the jack callbacks
** 6) Register the jack ports
** 7) Activate the client
** 8) Install signal handler
** 9) Read input until done
** 10) Close the jack client
** 11) Exit.
**
** The differences between applications are:
** 1) jack client name
** 2) jack ports
** 3) initialization code
** 4) input reader beyond parsing commands
**
** As a Tcl plugin the framework would be:
** 1) Specify default jack client name.
** 2) Parse arguments (using -opt rather than --opt)
** 3) Open jack client
** 4) Set the sample rate and initialize client code
** 5) Set the jack callbacks
** 6) Register the jack ports
** 7) Activate the client
**
** The tcl plugin would receive command updates and input
** text through the tcl command, and would terminate the
** client through the same mechanism.
**
** So a framework would allow us to specify:
** 1) default client name
** 2) jack ports required: MIDI_IN|MIDI_OUT|AUDIO_OUT_I|AUDIO_OUT_Q
** 3?) initialization function pointer (might be autocalled).
** 4) jack process callback function pointer
** 5) set sample rate function pointer
*/

static keyer_framework_t *_kfp;

static int jack_sample_rate_callback(jack_nframes_t nframes, void *arg) {
  set_sample_rate(&_kfp->opts, nframes);
  return 0;
}


static void jack_shutdown_callback(void *arg) {
  exit(1);
}

static void signal_handler(int sig) {
  jack_client_close(_kfp->client);
  exit(0);
}

void keyer_framework_main(keyer_framework_t *kfp, int argc, char **argv) {
  _kfp = kfp;
  strncpy(kfp->opts.client, kfp->default_client_name, sizeof(kfp->opts.client));
  main_parse_options(&kfp->opts, argc, argv);

  if((kfp->client = jack_client_open(kfp->opts.client, JackServerName, NULL, kfp->opts.server)) == 0) {
    fprintf(stderr, "JACK server not running?\n");
    exit(1);
  }

  set_sample_rate(&kfp->opts, jack_get_sample_rate(kfp->client));
  if (kfp->init) kfp->init();

  jack_set_process_callback(kfp->client, kfp->process_callback, 0);
  jack_set_sample_rate_callback(kfp->client, jack_sample_rate_callback, 0);
  jack_on_shutdown(kfp->client, jack_shutdown_callback, 0);

  if (kfp->ports_required & require_midi_in)
    kfp->midi_in = jack_port_register(kfp->client, "midi_in", JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
  if (kfp->ports_required & require_midi_out)
    kfp->midi_out = jack_port_register(kfp->client, "midi_out", JACK_DEFAULT_MIDI_TYPE, JackPortIsOutput, 0);
  if (kfp->ports_required & require_out_i)
    kfp->out_i = jack_port_register(kfp->client, "out_i", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);
  if (kfp->ports_required & require_out_q)
    kfp->out_q = jack_port_register(kfp->client, "out_q", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

  if (jack_activate (kfp->client)) {
    fprintf(stderr, "cannot activate client");
    exit(1);
  }

  /* install a signal handler to properly quits jack client */
  signal(SIGQUIT, signal_handler);
  signal(SIGTERM, signal_handler);
  signal(SIGHUP, signal_handler);
  signal(SIGINT, signal_handler);

  /* run until interrupted */
  /* while read bytes, queue for transmission */
  char c;
  while ((c = getchar()) != EOF) {
    if (c == '<') {
      /* command escape */
      char buff[128];
      int i = 0;
      while ((c = getchar()) != EOF && c != '>' && i < sizeof(buff)-1)
	buff[i++] = c;
      buff[i] = 0;
      main_parse_command(&kfp->opts, buff);
    } else if (kfp->receive_input_char) {
      kfp->receive_input_char(c);
    }
  }

  jack_client_close(kfp->client);
  exit(0);
}
