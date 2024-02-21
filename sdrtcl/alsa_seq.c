/* -*- mode: c; tab-width: 8 -*- */

/*
  The alsa sequencer api is a discovery and buffering and sequencing
  layer on top of raw midi devices discovered by the hardware and
  sequencer ports opened by processes.

  We implement the tcl interface as a simple interface to the
  discovery layer,
	::alsa::sequencer list
  and a custom channel driver,
	::alsa::sequencer open device direction

  All other operations are deferred to the channel interface.

  The channel operations implemented are kept to the minimum and
  their implementations are (very) minimal adaptations of the file
  channel type.

  This code is a hacked up version of alsa-utils-1.0.23/seq/aseqdump/aseqdump.c

 * aseqdump.c - show the events received at an ALSA sequencer port
 *
 * Copyright (c) 2005 Clemens Ladisch <clemens@ladisch.de>
 *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <getopt.h>
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/poll.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <alsa/asoundlib.h>

#include <tcl.h>

#if 0
/*
 * aseqdump.c - show the events received at an ALSA sequencer port
 *
 * Copyright (c) 2005 Clemens Ladisch <clemens@ladisch.de>
 *
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <signal.h>
#include <getopt.h>
#include <sys/poll.h>
#include <alsa/asoundlib.h>
#include "aconfig.h"
#include "version.h"

static snd_seq_t *seq;
static int port_count;
static snd_seq_addr_t *ports;
static volatile sig_atomic_t stop = 0;


/* prints an error message to stderr, and dies */
static void fatal(const char *msg, ...)
{
  va_list ap;

  va_start(ap, msg);
  vfprintf(stderr, msg, ap);
  va_end(ap);
  fputc('\n', stderr);
  exit(EXIT_FAILURE);
}

/* memory allocation error handling */
static void check_mem(void *p)
{
  if (!p)
    fatal("Out of memory");
}

/* error handling for ALSA functions */
static void check_snd(const char *operation, int err)
{
  if (err < 0)
    fatal("Cannot %s - %s", operation, snd_strerror(err));
}

static void init_seq(void)
{
  int err;

  /* open sequencer */
  err = snd_seq_open(&seq, "default", SND_SEQ_OPEN_DUPLEX, 0);
  check_snd("open sequencer", err);

  /* set our client's name */
  err = snd_seq_set_client_name(seq, "awtcl");
  check_snd("set client name", err);
}

/* parses one or more port addresses from the string */
static void parse_ports(const char *arg)
{
  char *buf, *s, *port_name;
  int err;

  /* make a copy of the string because we're going to modify it */
  buf = strdup(arg);
  check_mem(buf);

  for (port_name = s = buf; s; port_name = s + 1) {
    /* Assume that ports are separated by commas.  We don't use
     * spaces because those are valid in client names. */
    s = strchr(port_name, ',');
    if (s)
      *s = '\0';

    ++port_count;
    ports = realloc(ports, port_count * sizeof(snd_seq_addr_t));
    check_mem(ports);

    err = snd_seq_parse_address(seq, &ports[port_count - 1], port_name);
    if (err < 0)
      fatal("Invalid port %s - %s", port_name, snd_strerror(err));
  }

  free(buf);
}

static void create_port(void)
{
  int err;

  err = snd_seq_create_simple_port(seq, "aseqdump",
				   SND_SEQ_PORT_CAP_WRITE |
				   SND_SEQ_PORT_CAP_SUBS_WRITE,
				   SND_SEQ_PORT_TYPE_MIDI_GENERIC |
				   SND_SEQ_PORT_TYPE_APPLICATION);
  check_snd("create port", err);
}

static void connect_ports(void)
{
  int i, err;

  for (i = 0; i < port_count; ++i) {
    err = snd_seq_connect_from(seq, 0, ports[i].client, ports[i].port);
    if (err < 0)
      fatal("Cannot connect from port %d:%d - %s",
	    ports[i].client, ports[i].port, snd_strerror(err));
  }
}

static void dump_event(const snd_seq_event_t *ev)
{
  printf("%3d:%-3d ", ev->source.client, ev->source.port);
  switch (ev->type) {
  case SND_SEQ_EVENT_NOTEON:
    if (ev->data.note.velocity)
      printf("Note on                %2d, note %d, velocity %d\n",
	     ev->data.note.channel, ev->data.note.note, ev->data.note.velocity);
    else
      printf("Note off               %2d, note %d\n",
	     ev->data.note.channel, ev->data.note.note);
    break;
  case SND_SEQ_EVENT_NOTEOFF:
    printf("Note off               %2d, note %d, velocity %d\n",
	   ev->data.note.channel, ev->data.note.note, ev->data.note.velocity);
    break;
  case SND_SEQ_EVENT_KEYPRESS:
    printf("Polyphonic aftertouch  %2d, note %d, value %d\n",
	   ev->data.note.channel, ev->data.note.note, ev->data.note.velocity);
    break;
  case SND_SEQ_EVENT_CONTROLLER:
    printf("Control change         %2d, controller %d, value %d\n",
	   ev->data.control.channel, ev->data.control.param, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_PGMCHANGE:
    printf("Program change         %2d, program %d\n",
	   ev->data.control.channel, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_CHANPRESS:
    printf("Channel aftertouch     %2d, value %d\n",
	   ev->data.control.channel, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_PITCHBEND:
    printf("Pitch bend             %2d, value %d\n",
	   ev->data.control.channel, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_CONTROL14:
    printf("Control change         %2d, controller %d, value %5d\n",
	   ev->data.control.channel, ev->data.control.param, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_NONREGPARAM:
    printf("Non-reg. parameter     %2d, parameter %d, value %d\n",
	   ev->data.control.channel, ev->data.control.param, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_REGPARAM:
    printf("Reg. parameter         %2d, parameter %d, value %d\n",
	   ev->data.control.channel, ev->data.control.param, ev->data.control.value);
    break;
  case SND_SEQ_EVENT_SONGPOS:
    printf("Song position pointer      value %d\n",
	   ev->data.control.value);
    break;
  case SND_SEQ_EVENT_SONGSEL:
    printf("Song select                value %d\n",
	   ev->data.control.value);
    break;
  case SND_SEQ_EVENT_QFRAME:
    printf("MTC quarter frame          %02xh\n",
	   ev->data.control.value);
    break;
  case SND_SEQ_EVENT_TIMESIGN:
    // XXX how is this encoded?
    printf("SMF time signature         (%#010x)\n",
	   ev->data.control.value);
    break;
  case SND_SEQ_EVENT_KEYSIGN:
    // XXX how is this encoded?
    printf("SMF key signature          (%#010x)\n",
	   ev->data.control.value);
    break;
  case SND_SEQ_EVENT_START:
    if (ev->source.client == SND_SEQ_CLIENT_SYSTEM &&
	ev->source.port == SND_SEQ_PORT_SYSTEM_TIMER)
      printf("Queue start                queue %d\n",
	     ev->data.queue.queue);
    else
      printf("Start\n");
    break;
  case SND_SEQ_EVENT_CONTINUE:
    if (ev->source.client == SND_SEQ_CLIENT_SYSTEM &&
	ev->source.port == SND_SEQ_PORT_SYSTEM_TIMER)
      printf("Queue continue             queue %d\n",
	     ev->data.queue.queue);
    else
      printf("Continue\n");
    break;
  case SND_SEQ_EVENT_STOP:
    if (ev->source.client == SND_SEQ_CLIENT_SYSTEM &&
	ev->source.port == SND_SEQ_PORT_SYSTEM_TIMER)
      printf("Queue stop                 queue %d\n",
	     ev->data.queue.queue);
    else
      printf("Stop\n");
    break;
  case SND_SEQ_EVENT_SETPOS_TICK:
    printf("Set tick queue pos.        queue %d\n", ev->data.queue.queue);
    break;
  case SND_SEQ_EVENT_SETPOS_TIME:
    printf("Set rt queue pos.          queue %d\n", ev->data.queue.queue);
    break;
  case SND_SEQ_EVENT_TEMPO:
    printf("Set queue tempo            queue %d\n", ev->data.queue.queue);
    break;
  case SND_SEQ_EVENT_CLOCK:
    printf("Clock\n");
    break;
  case SND_SEQ_EVENT_TICK:
    printf("Tick\n");
    break;
  case SND_SEQ_EVENT_QUEUE_SKEW:
    printf("Queue timer skew           queue %d\n", ev->data.queue.queue);
    break;
  case SND_SEQ_EVENT_TUNE_REQUEST:
    printf("Tune request\n");
    break;
  case SND_SEQ_EVENT_RESET:
    printf("Reset\n");
    break;
  case SND_SEQ_EVENT_SENSING:
    printf("Active Sensing\n");
    break;
  case SND_SEQ_EVENT_CLIENT_START:
    printf("Client start               client %d\n",
	   ev->data.addr.client);
    break;
  case SND_SEQ_EVENT_CLIENT_EXIT:
    printf("Client exit                client %d\n",
	   ev->data.addr.client);
    break;
  case SND_SEQ_EVENT_CLIENT_CHANGE:
    printf("Client changed             client %d\n",
	   ev->data.addr.client);
    break;
  case SND_SEQ_EVENT_PORT_START:
    printf("Port start                 %d:%d\n",
	   ev->data.addr.client, ev->data.addr.port);
    break;
  case SND_SEQ_EVENT_PORT_EXIT:
    printf("Port exit                  %d:%d\n",
	   ev->data.addr.client, ev->data.addr.port);
    break;
  case SND_SEQ_EVENT_PORT_CHANGE:
    printf("Port changed               %d:%d\n",
	   ev->data.addr.client, ev->data.addr.port);
    break;
  case SND_SEQ_EVENT_PORT_SUBSCRIBED:
    printf("Port subscribed            %d:%d -> %d:%d\n",
	   ev->data.connect.sender.client, ev->data.connect.sender.port,
	   ev->data.connect.dest.client, ev->data.connect.dest.port);
    break;
  case SND_SEQ_EVENT_PORT_UNSUBSCRIBED:
    printf("Port unsubscribed          %d:%d -> %d:%d\n",
	   ev->data.connect.sender.client, ev->data.connect.sender.port,
	   ev->data.connect.dest.client, ev->data.connect.dest.port);
    break;
  case SND_SEQ_EVENT_SYSEX:
    {
      unsigned int i;
      printf("System exclusive          ");
      for (i = 0; i < ev->data.ext.len; ++i)
	printf(" %02X", ((unsigned char*)ev->data.ext.ptr)[i]);
      printf("\n");
    }
    break;
  default:
    printf("Event type %d\n",  ev->type);
  }
}

static void list_ports(void)
{
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_t *pinfo;

  snd_seq_client_info_alloca(&cinfo);
  snd_seq_port_info_alloca(&pinfo);

  puts(" Port    Client name                      Port name");

  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);

    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq, pinfo) >= 0) {
      /* we need both READ and SUBS_READ */
      if ((snd_seq_port_info_get_capability(pinfo)
	   & (SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ))
	  != (SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ))
	continue;
      printf("%3d:%-3d  %-32.32s %s\n",
	     snd_seq_port_info_get_client(pinfo),
	     snd_seq_port_info_get_port(pinfo),
	     snd_seq_client_info_get_name(cinfo),
	     snd_seq_port_info_get_name(pinfo));
    }
  }
}

static void help(const char *argv0)
{
  printf("Usage: %s [options]\n"
	 "\nAvailable options:\n"
	 "  -h,--help                  this help\n"
	 "  -V,--version               show version\n"
	 "  -l,--list                  list input ports\n"
	 "  -p,--port=client:port,...  source port(s)\n",
	 argv0);
}

static void version(void)
{
	puts("aseqdump version " SND_UTIL_VERSION_STR);
}

static void sighandler(int sig)
{
	stop = 1;
}

int main(int argc, char *argv[])
{
	static const char short_options[] = "hVlp:";
	static const struct option long_options[] = {
		{"help", 0, NULL, 'h'},
		{"version", 0, NULL, 'V'},
		{"list", 0, NULL, 'l'},
		{"port", 1, NULL, 'p'},
		{ }
	};

	int do_list = 0;
	struct pollfd *pfds;
	int npfds;
	int c, err;

	init_seq();

	while ((c = getopt_long(argc, argv, short_options,
				long_options, NULL)) != -1) {
		switch (c) {
		case 'h':
			help(argv[0]);
			return 0;
		case 'V':
			version();
			return 0;
		case 'l':
			do_list = 1;
			break;
		case 'p':
			parse_ports(optarg);
			break;
		default:
			help(argv[0]);
			return 1;
		}
	}
	if (optind < argc) {
		help(argv[0]);
		return 1;
	}

	if (do_list) {
		list_ports();
		return 0;
	}

	create_port();
	connect_ports();

	err = snd_seq_nonblock(seq, 1);
	check_snd("set nonblock mode", err);
	
	if (port_count > 0)
		printf("Waiting for data.");
	else
		printf("Waiting for data at port %d:0.",
		       snd_seq_client_id(seq));
	printf(" Press Ctrl+C to end.\n");
	printf("Source  Event                  Ch  Data\n");
	
	signal(SIGINT, sighandler);
	signal(SIGTERM, sighandler);

	npfds = snd_seq_poll_descriptors_count(seq, POLLIN);
	pfds = alloca(sizeof(*pfds) * npfds);
	for (;;) {
		snd_seq_poll_descriptors(seq, pfds, npfds, POLLIN);
		if (poll(pfds, npfds, -1) < 0)
			break;
		do {
			snd_seq_event_t *event;
			err = snd_seq_event_input(seq, &event);
			if (err < 0)
				break;
			if (event)
				dump_event(event);
		} while (err > 0);
		fflush(stdout);
		if (stop)
			break;
	}

	snd_seq_close(seq);
	return 0;
}
#endif
/*
  the channel instance information structure.
*/
typedef struct {
  Tcl_Channel chan;
  int direction, fd;
  snd_seq_t *seq;
} seq_instance_t;

static int seq_close(ClientData instanceData, Tcl_Interp *interp) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  Tcl_DeleteFileHandler(sqi->fd);
  snd_seq_close(sqi->seq);
  ckfree((char *)sqi);
}
static int seq_input(ClientData instanceData, char *buf, int bufSize, int *errorCodePtr) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  int err = snd_seq_read(sqi->seq, buf, bufSize);
  if (err < 0) {
    *errorCodePtr = -err;
    return -1;
  } else {
    *errorCodePtr = 0;
    return err;
  }
}
static int seq_output(ClientData instanceData, const char *buf, int toWrite, int *errorCodePtr) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  int err = snd_seq_write(sqi->seq, buf, toWrite);
  if (err < 0) {
    *errorCodePtr = -err;
    return -1;
  } else {
    *errorCodePtr = 0;
    return err;
  }
}
/*
  this one is verbatim from FileWatchProc in
  tcl8.5.8/unix/tclUnixChan.c
*/
static void seq_watch(ClientData instanceData, int mask) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  mask &= sqi->direction;
  if (mask) {
    Tcl_CreateFileHandler(sqi->fd, mask,
			  (Tcl_FileProc *) Tcl_NotifyChannel,
			  (ClientData) sqi->chan);
  } else {
    Tcl_DeleteFileHandler(sqi->fd);
  }
}
static int seq_get_handle(ClientData instanceData, int direction, ClientData *handlePtr) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  if (direction & sqi->direction) {
    *handlePtr = (ClientData)(long)sqi->fd;
    return TCL_OK;
  }
  return TCL_ERROR;
}
static int seq_block(ClientData instanceData, int mode) {
  seq_instance_t *sqi = (seq_instance_t *)instanceData;
  return snd_seq_nonblock(sqi->seq, mode == TCL_MODE_NONBLOCKING);
}

static Tcl_ChannelType seq_channel_type = {
  "seq",			/* typename */
  TCL_CHANNEL_VERSION_5,	/* version */
  seq_close,			/* closeProc */
  seq_input,			/* inputProc */
  seq_output,			/* outputProc */
  NULL,				/* seekProc */
  NULL,				/* setOptionProc */
  NULL,				/* getOptionProc */
  seq_watch,			/* watchProc */
  seq_get_handle,		/* getHandleProc */
  NULL,				/* close2Proc */
  seq_block,			/* blockModeProc */
  NULL,				/* flushProc */
  NULL,				/* handlerProc */
  NULL,				/* wideSeekProc */
  NULL,				/* threadActionProc */
  NULL				/* truncateProc */
};

int seq_make_channel(ClientData clientData, Tcl_Interp *interp, snd_seq_t *sequencer, int direction) {
  if (snd_seq_poll_descriptors_count(sequencer) != 1) {
    Tcl_AppendResult(interp, "sequencer device needs more than one file descriptor", NULL);
    snd_seq_close(sequencer);
    return TCL_ERROR;
  }
  seq_instance_t *sqi = (seq_instance_t *)ckalloc(sizeof(seq_instance_t));
  char channel_name[256];
  snprintf(channel_name, sizeof(channel_name), "seq@%s", snd_seq_name(sequencer));
  sqi->direction = direction;
  sqi->seq = sequencer;
  struct pollfd pollfd;
  snd_seq_poll_descriptors(sqi->seq, &pollfd, 1);
  sqi->fd = pollfd.fd;
  sqi->chan = Tcl_CreateChannel(&seq_channel_type, channel_name, sqi, direction);
  if (sqi->chan == NULL) {
    ckfree((char *)sqi);
    snd_seq_close(sequencer);
    return TCL_ERROR;
  }
  Tcl_RegisterChannel(interp, sqi->chan);
  Tcl_AppendResult(interp, channel_name, NULL);
  return TCL_OK;
}
#endif

/* error handling for ALSA functions */
static int check_snd(ClientData clientData, Tcl_Interp *interp, const char *operation, int err)
{
  if (err < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("Cannot %s - %s", operation, snd_strerror(err)));
    return TCL_ERROR;
  }
  return TCL_OK;
}

/* static sequencer connection for all of our needs */
static snd_seq_t *seq = NULL;

static int init_seq(ClientData clientData, Tcl_Interp *interp)
{
  if (seq == NULL) {
    int err;

    /* open sequencer */
    err = snd_seq_open(&seq, "default", SND_SEQ_OPEN_DUPLEX, 0);
    if (check_snd(clientData, interp, "open sequencer", err) < 0) {
      return TCL_ERROR;
    }

    /* set our client's name */
    err = snd_seq_set_client_name(seq, "awtcl");
    if (check_snd(clientData, interp, "set client name", err) != TCL_OK) {
      return TCL_ERROR;
    }
  }
  return TCL_OK;
}
/*
  discover the sequencer devices currently available
*/
static int alsa_seq_list(ClientData clientData, Tcl_Interp *interp) {
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_t *pinfo;
  Tcl_Obj *result = Tcl_NewListObj(0, NULL);
  if (init_seq(clientData, interp) != TCL_OK) {
    return TCL_ERROR;
  }
  snd_seq_client_info_alloca(&cinfo);
  snd_seq_port_info_alloca(&pinfo);

  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq, pinfo) >= 0) {
      /* we need both READ and SUBS_READ */
      int capability = snd_seq_port_info_get_capability(pinfo);
      char *readable = ((capability &
			 (SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ)) ==
			(SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ)) ? "r" : "";
      char *writable = ((capability &
			 (SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE)) ==
			(SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE)) ? "w" : "";
      Tcl_Obj *element = Tcl_ObjPrintf("%3d:%-3d  %-32.32s %s %s%s",
				       snd_seq_port_info_get_client(pinfo),
				       snd_seq_port_info_get_port(pinfo),
				       snd_seq_client_info_get_name(cinfo),
				       snd_seq_port_info_get_name(pinfo),
				       readable, writable);
      Tcl_ListObjAppendElement(interp, result, element);
    }
  }
  Tcl_SetObjResult(interp, result);
  return TCL_OK;
}

/*
  sequencer device channel create for reading or writing, not both at once.
*/
static int alsa_seq_open(ClientData clientData, Tcl_Interp *interp, Tcl_Obj *port, Tcl_Obj *direction) {
  const char *port_name = Tcl_GetString(port), *direction_name = Tcl_GetString(direction);
  static snd_seq_t *input, **inputp;
  static snd_seq_t *output, **outputp;
  if (strcmp(direction_name, "r") == 0) {
    inputp = &input;
    outputp = NULL;
  } else if (strcmp(direction_name, "w") == 0) {
    inputp = NULL;
    outputp = &output;
  } else {
    Tcl_AppendResult(interp, "open direction must be r or w", NULL);
    return TCL_ERROR;
  }
  int err;
  if ((err = snd_seq_open(inputp, outputp, port_name, SND_SEQ_NONBLOCK)) < 0) {
    Tcl_AppendPrintfToObj(Tcl_GetObjResult(interp), "cannot open port \"%s\": %s", port_name, snd_strerror(err));
    return TCL_ERROR;
  }
  if (inputp) {
    snd_seq_read(input, NULL, 0); /* trigger reading */
    return seq_make_channel(clientData, interp, input, TCL_READABLE);
  }
  if (outputp) {
    if ((err = snd_seq_nonblock(output, 0)) < 0) {
      Tcl_AppendResult(interp, "cannot set blocking mode: ", snd_strerror(err), NULL);
      snd_seq_close(output);
      return TCL_ERROR;
    }
    return seq_make_channel(clientData, interp, output, TCL_WRITABLE);
  }
}

/*
  the command which enables alsa sequencer listing and channels
*/
static int alsa_seq(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc > 1) {
    const char *cmd = Tcl_GetString(objv[1]);
    if (argc == 2 && strcmp(cmd, "list") == 0) {
      return alsa_seq_list(clientData, interp);
    } else if (argc == 4 && strcmp(cmd, "open") == 0) {
      return alsa_seq_open(clientData, interp, objv[2], objv[3]);
    }
  }
  Tcl_AppendResult(interp, "usage: ", Tcl_GetString(objv[0]), " list | open port direction", NULL);
  return TCL_ERROR;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Alsa_seq_Init(Tcl_Interp *interp) {
  // tcl stubs and tk stubs are needed for dynamic loading,
  // you must have this set as a compiler option
#ifdef USE_TCL_STUBS
  if (Tcl_InitStubs(interp, TCL_VERSION, 1) == NULL) {
	Tcl_SetResult(interp, "Tcl_InitStubs failed",TCL_STATIC);
	return TCL_ERROR;
  }
#endif
#ifdef USE_TK_STUBS
  if (Tk_InitStubs(interp, TCL_VERSION, 1) == NULL) {
	Tcl_SetResult(interp, "Tk_InitStubs failed",TCL_STATIC);
	return TCL_ERROR;
  }
#endif
  Tcl_PkgProvide(interp, "alsa::seq", "0.0.1");
  Tcl_CreateObjCommand(interp, "alsa::seq", alsa_seq, NULL, NULL);
  return TCL_OK;
}

