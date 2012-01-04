#ifndef OPTIONS_H
#define OPTIONS_H

#ifdef __cplusplus
extern "C"
{
#endif

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
#include <stddef.h>
#include <string.h>
#include <jack/jack.h>

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
} options_t;

  typedef enum {
    option_int,
    option_nframes_t,
    option_float,
    option_char,
    option_bool,
    option_string
  } option_type_t;

static void options_set_sample_rate(options_t *kp, jack_nframes_t sample_rate) {
  kp->sample_rate = sample_rate;
  kp->modified = 1;
}

static void options_handle_atoi(options_t *kp, char *p, int *ip) {
  if (*p == '?')
    fprintf(stdout, "%d\n", *ip);
  else {
    *ip = atoi(p);
    kp->modified = 1;
  }
}
static void options_handle_atof(options_t *kp, char *p, float *ip) {
  if (*p == '?')
    fprintf(stdout, "%f\n", *ip);
  else {
    *ip = atof(p);
    kp->modified = 1;
  }
}
static void options_handle_char(options_t *kp, char *p, char *ip) {
  if (*p == '?')
    fprintf(stdout, "%c\n", *ip);
  else {
    *ip = *p;
    kp->modified = 1;
  }
}
static void options_handle_string(options_t *kp, char *p, char *ip, size_t size) {
  if (*p == '?')
    fprintf(stdout, "%s\n", ip);
  else {
    strncpy(ip, p, size);
    kp->modified = 1;
  }
}

static void options_handle_verbose(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->verbose); }
static void options_handle_chan(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->chan); }
static void options_handle_note(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->note); }

static void options_handle_freq(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->freq); }
static void options_handle_gain(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->gain); }
static void options_handle_rise(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->rise); }
static void options_handle_fall(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->fall); }

static void options_handle_word(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->word); }
static void options_handle_wpm(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->wpm); }
static void options_handle_dah(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->dah); }
static void options_handle_ies(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->ies); }
static void options_handle_ils(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->ils); }
static void options_handle_iws(options_t *kp, char *p) { options_handle_atof(kp, p, &kp->iws); }

static void options_handle_swap(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->swap); }
static void options_handle_alsp(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->alsp); }
static void options_handle_awsp(options_t *kp, char *p) { options_handle_atoi(kp, p, &kp->awsp); }
static void options_handle_mode(options_t *kp, char *p) { options_handle_char(kp, p, &kp->mode); }

static void options_handle_server(options_t *kp, char *p) { options_handle_string(kp, p, kp->server, sizeof(kp->server)); }
static void options_handle_client(options_t *kp, char *p) {
#if AS_BIN
  options_handle_string(kp, p, kp->client, sizeof(kp->client));
#endif
#if AS_TCL
  // strip off namespace
  options_handle_string(kp, strrchr(p, ':') ? strrchr(p, ':')+1 : p, kp->client, sizeof(kp->client));
#endif
}

typedef struct {
  const char *name;
  const char *usage;
  const char *default_value;
  void (*handler)(options_t *, char *);
  const option_type_t type;
  const size_t offset;
  const char *doc;
} option_table_t;

option_table_t options_table[] = {
#include "options_common.h"
#if OPTIONS_TONE
#include "options_tone.h"  
#endif
#if OPTIONS_TIMING
#include "options_timing.h"
#endif
#if OPTIONS_KEYER
#include "options_keyer.h"
#endif
};

static option_table_t *options_find_option(char *name) {
  for (int i = 0; i < sizeof(options_table)/sizeof(options_table[0]); i += 1)
    if (strcmp(name, options_table[i].name) == 0)
      return &options_table[i];
  return NULL;
}

#if AS_BIN
static void options_usage(char *argv0) {
  fprintf(stderr, "usage: %s [--option value] ... < text\n", argv0);
  fprintf(stderr, "options:");
  for (int i = 0; i < sizeof(options_table)/sizeof(options_table[0]); i += 1)
    fprintf(stderr, "%c--%s", i?'|':' ', options_table[i].name);
  fprintf(stderr, "\n");
  for (int i = 0; i < sizeof(options_table)/sizeof(options_table[0]); i += 1)
    fprintf(stderr, "  --%s <%s> [default %s]\n", options_table[i].name, options_table[i].usage, options_table[i].default_value?options_table[i].default_value:"none");
  exit(1);
}

static void options_parse_options(options_t *kp, int argc, char **argv) {
  if (getenv("JACK_DEFAULT_SERVER") != NULL)
    options_handle_server(kp, getenv("JACK_DEFAULT_SERVER"));
  for (int j = 0; j < sizeof(options_table)/sizeof(options_table[0]); j += 1)
    if (options_table[j].default_value != NULL)
      options_table[j].handler(kp, (char *)options_table[j].default_value);
  for (int i = 1; i < argc; i += 2) {
    if (argv[i][0] != '-' || argv[i][1] != '-' || argv[i+1] == NULL) 
      options_usage(argv[0]);
    option_table_t *op = options_find_option(argv[i]+2);
    if (op != NULL)
      op->handler(kp, argv[i+1]);
    else
      options_usage(argv[0]);
  }
}
#endif

#if AS_TCL
static int options_usage(Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  Tcl_Obj *result = Tcl_ObjPrintf("usage: %s name [-option value ...]", Tcl_GetString(objv[0]));
  Tcl_AppendPrintfToObj(result, "options:");
  for (int i = 0; i < sizeof(options_table)/sizeof(options_table[0]); i += 1)
    Tcl_AppendPrintfToObj(result, "%c-%s", i?'|':' ', options_table[i].name);
  Tcl_AppendPrintfToObj(result, "\n");
  for (int i = 0; i < sizeof(options_table)/sizeof(options_table[0]); i += 1)
    Tcl_AppendPrintfToObj(result, "  -%s <%s> [default %s]\n", options_table[i].name, options_table[i].usage, options_table[i].default_value?options_table[i].default_value:"none");
  Tcl_SetObjResult(interp, result);
  return TCL_ERROR;
}

static int options_parse_options(options_t *kp, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  options_t save = *kp;
  if (argc < 2)
    return options_usage(interp, argc, objv);
  // default server name from environment
  if (getenv("JACK_DEFAULT_SERVER") != NULL)
    options_handle_server(kp, getenv("JACK_DEFAULT_SERVER"));
  // default client name == command
  options_handle_client(kp, Tcl_GetString(objv[1]));
  // default rest of options
  for (int j = 0; j < sizeof(options_table)/sizeof(options_table[0]); j += 1)
    if (options_table[j].default_value != NULL)
      options_table[j].handler(kp, (char *)options_table[j].default_value);
  // process arguments
  for (int i = 2; i < argc; i += 2) {
    char *arg = Tcl_GetString(objv[i]);
    option_table_t *op;
    if (arg[0] != '-' || (op = options_find_option(arg+1)) == NULL) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("unknown option: \"%s\"", arg));
      *kp = save;
      return TCL_ERROR;
    }
    if (objv[i+1] == NULL) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("missing option value for \"%s\"", arg));
      *kp = save;
      return TCL_ERROR;
    } 
    op->handler(kp, Tcl_GetString(objv[i+1]));
  }
  return TCL_OK;
}

static Tcl_Obj *options_get_tcl_value(options_t *kp, option_table_t *op) {
  switch (op->type) {
  case option_bool:
  case option_int:
    return Tcl_NewIntObj(*(int *)(((char *)kp)+op->offset));
  case option_nframes_t:
    return Tcl_NewIntObj(*(jack_nframes_t *)(((char *)kp)+op->offset));
  case option_float:
    return Tcl_NewDoubleObj(*(float *)(((char *)kp)+op->offset));
  case option_char:
    return Tcl_NewStringObj((char *)(((char *)kp)+op->offset), 1);
  case option_string:
    return Tcl_NewStringObj((char *)(((char *)kp)+op->offset), -1);
  default:
    return Tcl_ObjPrintf("unknown option type %d for \"-%s\"", op->type, op->name);
  }
}

static int options_parse_config(options_t *kp, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 2) {
    // dump config
    Tcl_Obj *result = Tcl_NewObj();
    for (int j = 0; j < sizeof(options_table)/sizeof(options_table[0]); j += 1) {
      Tcl_Obj *item = Tcl_NewObj();
      Tcl_ListObjAppendElement(interp, item, Tcl_ObjPrintf("%s", options_table[j].name));
      Tcl_ListObjAppendElement(interp, item, options_get_tcl_value(kp, options_table+j));
      Tcl_ListObjAppendElement(interp, result, item);
    }
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
  }
  // process arguments
  for (int i = 2; i < argc; i += 2) {
    char *arg = Tcl_GetString(objv[i]);
    if (arg[0] != '-' || objv[i+1] == NULL) 
      return options_usage(interp, argc, objv);
    option_table_t *op = options_find_option(arg+1);
    if (op != NULL)
      op->handler(kp, Tcl_GetString(objv[i+1]));
    else
      return options_usage(interp, argc, objv);
  }
  return TCL_OK;
}

static int options_parse_cget(options_t *kp, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 2) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("wrong # args: should be \"%s cget option\"", Tcl_GetString(objv[0])));
    return TCL_ERROR;
  }
  char *arg = Tcl_GetString(objv[2]);
  option_table_t *op = options_find_option(arg[0] != '-' ? arg : arg+1);
  if (op != NULL) {
    Tcl_SetObjResult(interp, options_get_tcl_value(kp, op));
    return TCL_OK;
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("unknown option \"%s\"", arg));
  return TCL_ERROR;
}

static int options_parse_cdoc(options_t *kp, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc == 2) {
    Tcl_Obj *result = Tcl_NewObj();
    for (int j = 0; j < sizeof(options_table)/sizeof(options_table[0]); j += 1)
      if (options_table[j].usage != NULL)
	Tcl_AppendPrintfToObj(result, "-%s : %s\n", options_table[j].name, options_table[j].usage);
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
  }
  char *arg = Tcl_GetString(objv[2]);
  option_table_t *op;
  if (arg[0] != '-')
    op = options_find_option(arg);
  else
    op = options_find_option(arg+1);
  if (op != NULL) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s", op->usage));
    return TCL_OK;
  }
  Tcl_SetObjResult(interp, Tcl_ObjPrintf("unknown option \"%s\"", arg));
  return TCL_ERROR;
}
#endif

static void options_parse_command(options_t *kp, char *p) {
  for (int j = 0; j < sizeof(options_table)/sizeof(options_table[0]); j += 1) {
    int n = strlen(options_table[j].name);
    if (strncmp(p, options_table[j].name, n) == 0) {
      options_table[j].handler(kp, p+n);
      return;
    }
  }
  if (strcmp(p, "exit") == 0) {
    exit(0);
  }
  fprintf(stderr, "unrecognized keyer command: %s\n", p);
}

#ifdef __cplusplus
}
#endif

#endif
