#ifndef KEYER_OPTIONS_H
#define KEYER_OPTIONS_H

typedef struct {
  int modified;			/* indication of modifications */
  /* all layers */
  int verbose;			/* level of verbosity */
  int chan;			/* midi channel used for keyer */
  int note;			/* base midi note used for keyer */
  /* keyer tone parameters */
  float freq;			/* frequency of tone in hertz */
  float gain;			/* level of tone in decibels */
  float rise;			/* rise time in milliseconds */
  float fall;			/* fall time in milliseconds */
  /* keyer timer parameters */
  float word;			/* dits in a word */
  float wpm;			/* mark words per minute */
  float dah;			/* dah length in dits */
  float ies;			/* inter-element space length in dits */
  float ils;			/* inter-letter space length in dits */
  float iws;			/* inter-word space length in dits */
  /* iambic keyer parameters */
  char mode;			/* A|B */
  int alsp;			/* auto letter spacing */
  int awsp;			/* auto word spacing */
  int swap;			/* swap dit and dah paddles */
  
  /* jack client parameters */
  char server[128];		/* jack server name */
  char client[128];		/* jack client name */
  /* jack supplied information used everywhere */
  jack_nframes_t sample_rate;
} keyer_options_t;

extern void main_parse_options(keyer_options_t *kp, int argc, char **argv);
extern void main_parse_command(keyer_options_t *kp, char *p);
static void set_sample_rate(keyer_options_t *kp, jack_nframes_t sample_rate) {
  kp->sample_rate = sample_rate;
  kp->modified = 1;
}

#endif
