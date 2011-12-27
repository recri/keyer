/*
** unified options for keyer executables and tcl plugins.
** define all the options;
** define the functions for handling them;
** define the structure that they get stored into;
** code to process them as command line --options values
** code to process them as tcl command -options value
** code to process them as inline <option=value>
** code to process them as sysex F0 7D option=value F7
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jack/jack.h>

#include "keyer_options.h"

static void handle_atoi(keyer_options_t *kp, char *p, int *ip) {
  if (*p == '?')
    fprintf(stderr, "%d\n", *ip);
  else {
    *ip = atoi(p);
    kp->modified = 1;
  }
}
static void handle_atof(keyer_options_t *kp, char *p, float *ip) {
  if (*p == '?')
    fprintf(stderr, "%f\n", *ip);
  else {
    *ip = atof(p);
    kp->modified = 1;
  }
}
static void handle_char(keyer_options_t *kp, char *p, char *ip) {
  if (*p == '?')
    fprintf(stderr, "%c\n", *ip);
  else {
    *ip = *p;
    kp->modified = 1;
  }
}
static void handle_string(keyer_options_t *kp, char *p, char *ip, size_t size) {
  if (*p == '?')
    fprintf(stderr, "%s\n", ip);
  else {
    strncpy(ip, p, size);
    kp->modified = 1;
  }
}
  
static void handle_verbose(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->verbose); }
static void handle_chan(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->chan); }
static void handle_note(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->note); }

static void handle_freq(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->freq); }
static void handle_gain(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->gain); }
static void handle_rise(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->rise); }
static void handle_fall(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->fall); }
static void handle_ramp(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->rise); }

static void handle_word(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->word); }
static void handle_wpm(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->wpm); }
static void handle_dah(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->dah); }
static void handle_ies(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->ies); }
static void handle_ils(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->ils); }
static void handle_iws(keyer_options_t *kp, char *p) { handle_atof(kp, p, &kp->iws); }

static void handle_swap(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->swap); }
static void handle_alsp(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->alsp); }
static void handle_awsp(keyer_options_t *kp, char *p) { handle_atoi(kp, p, &kp->awsp); }
static void handle_mode(keyer_options_t *kp, char *p) { handle_char(kp, p, &kp->mode); }

static void handle_server(keyer_options_t *kp, char *p) { handle_string(kp, p, kp->server, sizeof(kp->server)); }
static void handle_client(keyer_options_t *kp, char *p) { handle_string(kp, p, kp->client, sizeof(kp->client)); }

struct option {
  char *name;
  char *usage;
  char *default_value;
  void (*handler)(keyer_options_t *, char *);
} options[] = {
  { "verbose", "amount of diagnostic output", "0", handle_verbose },

  { "chan", "midi channel used for keyer", "1", handle_chan },
  { "note", "base midi note used for keyer", "0", handle_note },

  { "freq", "frequency of tone in hertz", "700", handle_freq },
  { "gain", "level of tone in decibels", "-3", handle_gain },
  { "rise", "rise time in milliseconds", "5", handle_rise },
  { "fall", "fall time in milliseconds", "5", handle_fall },
  { "ramp", "rise/fall time in milliseconds", "5", handle_ramp },

  { "word", "dits in a word", "50", handle_word },
  { "wpm", "words per minute", "18", handle_wpm },
  { "dah", "dah length in dits", "3", handle_dah },
  { "ies", "inter-element space in dits", "1", handle_ies },
  { "ils", "inter-letter space in dits", "3", handle_ils },
  { "iws", "inter-word space in dits", "7", handle_iws },

  { "swap", "swap the dit and dah paddles", "0", handle_swap },
  { "alsp", "auto letter spacing", "0", handle_alsp },
  { "awsp", "auto word spacing", "0", handle_awsp },
  { "mode", "iambic keyer mode", "A", handle_mode },

  { "server", "jack server name", "default", handle_server },
  { "client", "jack client name", NULL, handle_client },
};

static void main_usage(char *argv0) {
  fprintf(stderr, "usage: %s [--option value] ... < text\n", argv0);
  fprintf(stderr, "options:");
  for (int i = 0; i < sizeof(options)/sizeof(options[0]); i += 1)
    fprintf(stderr, "%c--%s", i?'|':' ', options[i].name);
  fprintf(stderr, "\n");
  for (int i = 0; i < sizeof(options)/sizeof(options[0]); i += 1)
    fprintf(stderr, "  --%s <%s> [default %s]\n", options[i].name, options[i].usage, options[i].default_value?options[i].default_value:"none");
  exit(1);
}

void main_parse_options(keyer_options_t *kp, int argc, char **argv) {
  if (getenv("JACK_DEFAULT_SERVER") != NULL)
    handle_server(kp, getenv("JACK_DEFAULT_SERVER"));
  for (int j = 0; j < sizeof(options)/sizeof(options[0]); j += 1)
    if (options[j].default_value != NULL)
      options[j].handler(kp, options[j].default_value);
  for (int i = 1; i < argc; i += 2) {
    if (argv[i][0] != '-' || argv[i][1] != '-' || argv[i+1] == NULL) 
      main_usage(argv[0]);
    for (int j = 0; j < sizeof(options)/sizeof(options[0]); j += 1) {
      if (strcmp(argv[i]+2, options[j].name) == 0) {
	options[j].handler(kp, argv[i+1]);
	goto next_i;
      }
    }
    main_usage(argv[0]);
  next_i:
    continue;
  }
}

void main_parse_command(keyer_options_t *kp, char *p) {
  for (int j = 0; j < sizeof(options)/sizeof(options[0]); j += 1) {
    int n = strlen(options[j].name);
    if (strncmp(p, options[j].name, n) == 0) {
      options[j].handler(kp, p+n);
      return;
    }
  }
  if (strcmp(p, "exit") == 0) {
    exit(0);
  }
  fprintf(stderr, "unrecognized keyer command: %s\n", p);
}
