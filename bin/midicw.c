/* -*- mode: c++; tab-width: 8 -*- */
/*
  Copyright (C) 2016 by Roger E Critchlow Jr, Charlestown, MA, USA.

  Modified to use the dspmath keyed_tone module to generate a shaped key tone
  with no calls to transcendental functions.

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
 
/*
    Copyright 2011 Glen Overby

    This program implements a straight-key tone oscillator for use with a
    Software Defined Radio and transmiter controls for use with the
    "usbsoftrock" or "sdr-shell" programs.

    The code in this file is derivied from "midisine.c" by Ian Esten, obtained
    from:
	http://trac.jackaudio.org/wiki/WalkThrough/Dev/SimpleMidiClient
    That program is released under the GPL, it's copyright appears below.

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License version 2
    as published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software Foundation,
    Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
    (A copy of the GNU General Public License is available in the file COPYING)

    The author can be reached by email at gpoverby@gmail.com

    Copyright (C) 2004 Ian Esten
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <signal.h>
#include <semaphore.h>
#include <time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include <jack/jack.h>
#include <jack/midiport.h>

jack_port_t *input_port;
jack_port_t *output_port;
unsigned char cwnote = 60;	/* note value for CW tone */
unsigned char cwpitch = 0x3c;	/* pitch value from MIDI device for CW key */
unsigned char pttpitch = 0x3b;	/* pitch value from MIDI device for PTT button */
jack_default_audio_sample_t note_frqs[128];

/* tone implementation */

#include "../dspmath/keyed_tone.h"

keyed_tone_t tone;
struct {
  int	freq;	/* frequency of keyed tone */
  int	gain;	/* gain in decibels of keyed tone */
  int	rise;	/* rise time in milliseconds */
  int	fall;	/* fall time in milliseconds */
  int	srate;	/* samples per second */
} tone_opts = {
  600, -30, 5, 5, 48000
};

char running = 1;

/* ptt implementation */

int pttstate = 0;		/* PTT state: 0x01 = key, 0x02 = ptt-button */
#define PTT_KEY 0x01
#define PTT_PTT 0x02
int ptton = 0;			/* Set if PTT has turned on */
int pttdelay = 100;		/* Delay from last off to PTT off (key only) */
int pttrecipient = 0;		/* PTT Target: usbsoftrock = 1, sdr-shell = 2 */
#define PTT_SOFTROCK 1
#define PTT_SHELL 2
char *remotehost = "localhost";	/* name of remote host */
int remoteport = 0;		/* port number of remote, if not the default */
sem_t ptt_run;			/* semaphore that ptt thread blocks on */
pthread_t ptt_pthread;

/* Signal Handler

 Common signals are trapped to this handler which will shut down the program as cleanly as possible
 */

void sig_handler()
{
	running = 0;
	sem_post(&ptt_run);
}

/* PTT control for usbsoftrock or sdr-shell.

There is a background thread that communicates with either usbsoftrock or sdr-shell to control the PTT
output to the SoftRock SDR.  There can be a delay from the internal PTT signal turning off to sending the
command to turn off.

The main process and JACK callback communicate with the thread using the ptt_run (pthreads) semaphore,
and the global variables pttstate and ptton.  The ptt thread reads but does not modify pttstate, and
it clears ptton every time it waits for the ptt_run semaphore.

When the key turns off, the thread waits for some time before turning off PTT.  This is to prevent needless
switching of transmit/receive relays when sending morse code.  At the end of the delay, the pttstate and ptton
flags are checked.  If either is set, it cancels turning off PTT.

The purpose of the ptton flag is to keep from turning off PTT without waiting a full delay.  This could occur
if the delay timeout just happens to coincide with the key being "up" (off), even though the operator is in the
middle of sending a message.  There is an unfortunate downside of this algorithm: if two short characters are
sent, say, a morse code "I", the "off" of the first dit starts a delay, the second dit sets the ptton flag.  At
the end of the delay, the key state will be off, but there will have been a second (short) key-down event.  The
result is that PTT is held for two delays, instead of one.

	wait for release semaphore
	pttstate == 0n & current state != on
		set PTT on
	pttstate == off & current state != off
		key?
			nanosleep() for it to expire
			check pttstate and ptton again.  If not set, set PTT off
		button?
			 set PTT off
	clear ptton

usbsoftrock:
	Listens to UDP port 19004
	set ptt on
	set ptt off

sdr-shell (rigctl.cpp):
	Listens to TCP port 19090
	Uses hamlib-compatible commands
	f		get frequency
	F value		set frequency
	m		get mode
	v		get vfo
	j		get rit
	s		get split-vfo
	T value		set PTT
	q		quit
	M		set mode {USB LSB AM FM SAM CW CWR
	dump_state
 */

/*
 It's easier to put this info in a few globals than, say, pass it around in a data structure.
 */
struct addrinfo *addr;		/* address of remote host */
int sockfd;			/* file descriptor form socket */
#define BUFSIZE	1024

/*
 Look up the remote host (localhost) using getaddrinfo(3) and open a UDP socket to it.

Uses:
  Globals remoteport, remotehost
Sets:
  Globals sockfd, addr
 */
int udpopen()
{
	struct addrinfo hints;
	char service[8];
	int rc;
	char *cmd;
	int len;

	/* Open a UDP port to usbsoftrock */
	if (!remoteport)
		remoteport = 19004;
	sethostent(0);
	memset(&hints, 0, sizeof(struct addrinfo));
	snprintf(service, 8, "%d", remoteport);
	hints.ai_flags = AI_NUMERICSERV;
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_protocol = IPPROTO_UDP;
	if ((rc = getaddrinfo(remotehost, service, &hints, &addr)) != 0) {
		fprintf(stderr, "getaddrinfo(localhost, %s) = rc %d\n", service, rc);
		return -1;
	}

	if ((sockfd=socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
		perror("Can't create socket");
		return -1;
	}
}

/*
 Send a command to a remote host, with the assumption that it is usbsoftrock. Wait for an 'ok' ack back.

Uses:
  Globals sockfd, addr
Returns:
  -1 for system call errors
  0 if "ok" is received
  1 if "ok" is not received
 */
int udpcmd(char *cmd)
{
	int len, rc;
	char buf[BUFSIZE];

	len = strlen(cmd);
	if ((rc=sendto(sockfd, cmd, len, 0, addr->ai_addr, addr->ai_addrlen)) != len) {
		fprintf(stderr, "sendto(%d) = %d\n", len, rc);
		return -1;
	}

	/* call poll with a timeout? */

	if ((rc=recvfrom(sockfd, buf, BUFSIZE, 0, addr->ai_addr, &addr->ai_addrlen)) == -1) {
		perror("recvfrom");
		return -1;
	}
	/*printf("udpcmd: got back %d '%s'\n", rc, buf);*/
	if (!strncmp(buf, "ok", 2))
		return 0;
	return 1;
}

/*
 Look up the remote host (localhost) using getaddrinfo(3) and open/connect a socket to it.

Uses:
  Globals remoteport, remotehost
Sets:
  Globals sockfd, addr
 */
int tcpopen()
{
	struct addrinfo	hints;
	int		rc;
	char		service[8];

	sethostent(0);
	memset(&hints, 0, sizeof(struct addrinfo));
	snprintf(service, 8, "%d", remoteport);
	hints.ai_flags = AI_NUMERICSERV;
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	if ( (rc = getaddrinfo(remotehost, service, &hints, &addr)) != 0 ) {
		fprintf(stderr, "getaddrinfo(localhost, %s) = rc %d\n", service, rc);
		return -1;
	}
	if ((sockfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0) {
		perror("Couldn't create TCP socket");
		return -1;
	}
	if (connect(sockfd, addr->ai_addr, addr->ai_addrlen) < 0) {
		perror("Failed to connect to sdr-shell");
		return -1;
	}
	return 0;
}

/*
 Send a command to a remote host, with the assumption that it is sdr-shell.

Uses:
  Globals sockfd, addr
Returns:
  -1 for system call errors
  0 if "ok" is received
  1 if "ok" is not received
 */
int tcpcmd(char *cmd)
{
	int len, rc;
	char buf[BUFSIZE];

	len = strlen(cmd);
	if ((rc=write(sockfd, cmd, len)) == -1) {
		perror("write to remote");
		return -1;
	}
	if (rc != len) {
		fprintf(stderr, "write(%d) = %d\n", len, rc);
		return -1;
	}

	if ((rc=read(sockfd, buf, BUFSIZE)) == -1) {
		perror("read from remote");
		return -1;
	}
	printf("udpcmd: got back %d '%s'\n", rc, buf);
	if (!strncmp(buf, "ok", 2))
		return 0;
	return 1;
}

/*
 Open a remote socket, based on pttrecipient
 */
int remote_open()
{
	switch (pttrecipient) {
	case PTT_SOFTROCK:	return udpopen();
	case PTT_SHELL:		return tcpopen();
	}
}

/*
  Turn remote PTT on (1) or off (0)
  It uses UDP or TCP, based on pttrecipient
 */
int remote_ptt(int state)
{
	switch (pttrecipient) {
	case PTT_SOFTROCK:	return udpcmd(state ? "set ptt on" : "set ptt off");
	case PTT_SHELL:		return tcpcmd(state ? "T 1" : "T 0");
	}
}


void ptt_thread(void)
{
	int state = 0;
	struct timespec delaytime;

	delaytime.tv_sec = pttdelay / 1000;
	delaytime.tv_nsec = (pttdelay % 1000) * 1000000;
#ifdef DEBUG
	printf("delay: %d = %d s %d ns\n", pttdelay, delaytime.tv_sec, delaytime.tv_nsec);
#endif

	remote_open();

	while (running) {
#ifdef DEBUG
		printf("ptt_thread: state 0x%x on 0x%x\n", pttstate, ptton);
#endif
		ptton = 0;

		if (pttstate && (!state)) {
#ifdef DEBUG
			printf("ptt goes on\n");
#endif
			remote_ptt(1);
			state = pttstate;
		} else if ((!pttstate) && state) {
			if (state & PTT_KEY) {
#ifdef DEBUG
				printf("ptt off delay\n");
#endif
				nanosleep(&delaytime, NULL);
			}
			if (!pttstate && !ptton) {
#ifdef DEBUG
				printf("ptt goes off\n");
#endif
				remote_ptt(0);
				state = pttstate;
			} else {
#ifdef DEBUG
				printf("ptt off skipped\n");
#endif
			}
		}
		/* sem_wait is at the bottom of the loop, not the top of the loop, so the signal handler can stop
		 the thread gracefully */
		sem_wait(&ptt_run);
	}
	pthread_exit(0);
}

/*
JACK Callback, to process events and audio.
 */

int process(jack_nframes_t nframes, void *arg)
{
	int i;
	void* port_buf = jack_port_get_buffer(input_port, nframes);
	jack_default_audio_sample_t *out = (jack_default_audio_sample_t *) jack_port_get_buffer (output_port, nframes);
	jack_midi_event_t in_event;
	jack_nframes_t event_index = 0;
	jack_nframes_t event_count = jack_midi_get_event_count(port_buf);
	jack_nframes_t event_sample = 0;
	unsigned char note = 0;		/* note value from the MIDI data */
	char pttchanged = 0;		/* Set if PTT state is changed */
#if 0
	if(event_count) {
		printf(" midisine: have %d events\n", event_count);
		for(i=0; i<event_count; i++) {
			jack_midi_event_get(&in_event, port_buf, i);
			printf("  event %d time is %d. command is 0x%x channel 0x%x pitch 0x%x velocity 0x%x\n",
				i, in_event.time, *(in_event.buffer)&0xf0, *(in_event.buffer)&0xf,
				*(in_event.buffer+1), *(in_event.buffer+2));
		}
	}
#endif
	if (event_index < event_count) {
		jack_midi_event_get(&in_event, port_buf, event_index);
		event_sample += in_event.time;
	} else {
		event_sample = nframes+1;
	}
	jack_midi_event_get(&in_event, port_buf, 0);
	for(i=0; i<nframes; i++) {
		if((in_event.time == i) && (event_index < event_count)) {
			if( ((*(in_event.buffer) & 0xf0)) == 0x90 ) {
				/* note on */
				note = *(in_event.buffer + 1);
				if (note == cwpitch) {
					keyed_tone_on(&tone);
					pttstate |= PTT_KEY;
					ptton |= PTT_KEY;
					pttchanged = 1;
				} else if (note == pttpitch) {
					keyed_tone_off(&tone);
					pttstate |= PTT_PTT;
					ptton |= PTT_PTT;
					pttchanged = 1;
				} else
					keyed_tone_off(&tone);
			} else if( ((*(in_event.buffer)) & 0xf0) == 0x80 ) {
				/* note off */
				note = *(in_event.buffer + 1);
				keyed_tone_off(&tone);
				if (note == cwpitch) {
					pttstate &= ~(PTT_KEY);
					pttchanged = 1;
				} else if (note == pttpitch) {
					pttstate &= ~(PTT_PTT);
					pttchanged = 1;
				}
			}
			event_index++;
			if(event_index < event_count) {
				jack_midi_event_get(&in_event, port_buf, event_index);
				event_sample += in_event.time;
			} else {
				event_sample = nframes+1;
			}
		}
		out[i] = keyed_tone_process(&tone);
	}
	if (pttchanged) {
		sem_post(&ptt_run);
	}
	return 0;      
}

int srate(jack_nframes_t nframes, void *arg)
{
#ifdef DEBUG
	printf("the sample rate is now %" PRIu32 "/sec\n", nframes);
#endif
	keyed_tone_update(&tone, tone_opts.gain, tone_opts.freq, tone_opts.rise, 
			  tone_opts.fall, WINDOW_BLACKMAN_HARRIS, tone_opts.srate = nframes);
	return 0;
}

void jack_shutdown(void *arg)
{
	/* stop background thread */
	exit(1);
}


int main(int argc, char **argv)
{
	char	*clientname = "midicw";
	int	opt;

	jack_client_t *client;
	int	i;
	struct sigaction siga;

	while ((opt = getopt(argc, argv, "d:f:hn:r:t:e:g:")) != -1) {
		switch (opt) {
		case 'd':
			pttdelay = atoi(optarg);
			break;

		case 'f':
			tone_opts.freq = atoi(optarg);
			break;

		case 'h':
			printf("options: [ -f frequency ] [ -n jack client name ]\n");
			exit(0);

		case 'n':
			clientname = strdup(optarg);
			break;

		case 't':
			if (!strcmp(optarg, "usbsoftrock")) {
				pttrecipient = PTT_SOFTROCK;
			} else if (!strcmp(optarg, "sdr-shell")) {
				pttrecipient = PTT_SHELL;
			} else {
				fprintf(stderr, "Unknown PTT device: '%s'\n", optarg);
			}
			break;

		case 'r':
			/* use syntax: host:port */
			remoteport = atoi(optarg);
			break;
		case 'e':/* envelope in milliseconds */
			tone_opts.rise = tone_opts.fall = atoi(optarg);
			break;
		case 'g':/* gain in dB */
			tone_opts.gain = atoi(optarg);
			break;
		case '?':
			printf("unknown option '%c'\n", optopt);
			exit(1);
		}
	}

	/* signal handler for graceful shutdown & exit */
	siga.sa_handler = (void*)sig_handler;
	sigemptyset(&siga.sa_mask);
	siga.sa_flags = 0;
	sigaction(SIGINT, &siga, NULL);
	sigaction(SIGTERM, &siga, NULL);
	sigaction(SIGHUP, &siga, NULL);

	/* Initialize semaphore for communicating with PTT thread */
	sem_init(&ptt_run, 0, 0);

	/* Connect to the JACK daemon */
	if ((client = jack_client_open (clientname, JackNullOption, NULL)) == 0) {
		fprintf(stderr, "jack server not running?\n");
		return 1;
	}
	
	tone_opts.srate = jack_get_sample_rate (client);
	keyed_tone_init(&tone, tone_opts.gain, tone_opts.freq, tone_opts.rise, 
			tone_opts.fall, WINDOW_BLACKMAN_HARRIS, tone_opts.srate);

	/* Find the note that is equal to or greater than the requested frequency */
	if (tone_opts.freq) {
		float f;
		f = (float)tone_opts.freq / tone_opts.srate;
		for(i=0;i < 128; i++) {
			if (note_frqs[i] >= f) {
				cwnote = i;
				break;
			}
		}
#ifdef DEBUG
		printf("ufreq: %d %f => bucket %d %f\n", ufreq, f, cwnote, note_frqs[cwnote]);
#endif
	}

	jack_set_process_callback (client, process, 0);

	jack_set_sample_rate_callback (client, srate, 0);

	jack_on_shutdown (client, jack_shutdown, 0);

	input_port = jack_port_register (client, "midi_in", JACK_DEFAULT_MIDI_TYPE, JackPortIsInput, 0);
	output_port = jack_port_register (client, "audio_out", JACK_DEFAULT_AUDIO_TYPE, JackPortIsOutput, 0);

	if (jack_activate (client)) {
		fprintf(stderr, "cannot activate client");
		return 1;
	}

	/* Start background thread to communicate PTT state with usbsoftrock or sdr-shell */
	if (pttrecipient) {
		pthread_create(&ptt_pthread, 0, (void *)ptt_thread, 0);
	}

	/* run until interrupted */
	while(running) {
		sleep(1);
	}

	if (pttrecipient) {
		pthread_join(ptt_pthread, 0);
	}

	jack_client_close(client);
	exit (0);
}
