/* -*- mode: c; tab-width: 8 -*- */

/*
  The alsa rawmidi api is a discovery and buffering layer on top of
  raw midi devices discovered by the hardware.

  We implement the tcl interface as a simple interface to the
  discovery layer, ::alsa::rawmidi list, and a custom channel driver,
  ::alsa::rawmidi open device direction.

  All other operations are deferred to the channel interface.

  The channel operations implemented are kept to the minimum and
  their implementations are (very) minimal adaptations of the file
  channel type.

  This code is a hacked up version of alsa-utils-1.0.23/amidi/amidi.c

 *  amidi.c - read from/write to RawMIDI ports
 *
 *  Copyright (c) Clemens Ladisch <clemens@ladisch.de>
 *
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/poll.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <alsa/asoundlib.h>

#include <tcl.h>

/*
  the channel instance information structure.
*/
typedef struct {
  Tcl_Channel chan;
  int direction, fd;
  snd_rawmidi_t *rawmidi;
} rawmidi_instance_t;

/*
  the channel instance close function
*/
int rawmidi_close(ClientData instanceData, Tcl_Interp *interp) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  Tcl_DeleteFileHandler(rmi->fd);
  snd_rawmidi_close(rmi->rawmidi);
  ckfree((char *)rmi);
  return TCL_OK;
}

/*
  the channel instance read function
*/
int rawmidi_input(ClientData instanceData, char *buf, int bufSize, int *errorCodePtr) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  int err = snd_rawmidi_read(rmi->rawmidi, buf, bufSize);
  if (err < 0) {
    *errorCodePtr = -err;
    return -1;
  } else {
    *errorCodePtr = 0;
    return err;
  }
}

/*
  the channel instance write function
*/
int rawmidi_output(ClientData instanceData, const char *buf, int toWrite, int *errorCodePtr) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  int err = snd_rawmidi_write(rmi->rawmidi, buf, toWrite);
  if (err < 0) {
    *errorCodePtr = -err;
    return -1;
  } else {
    *errorCodePtr = 0;
    return err;
  }
}

/*
  the channel instance watch function
  this one is verbatim from FileWatchProc in tcl8.5.8/unix/tclUnixChan.c
*/
void rawmidi_watch(ClientData instanceData, int mask) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  mask &= rmi->direction;
  if (mask) {
    Tcl_CreateFileHandler(rmi->fd, mask,
			  (Tcl_FileProc *) Tcl_NotifyChannel,
			  (ClientData) rmi->chan);
  } else {
    Tcl_DeleteFileHandler(rmi->fd);
  }
}

/*
  the channel instance get handle function
*/
int rawmidi_get_handle(ClientData instanceData, int direction, ClientData *handlePtr) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  if (direction & rmi->direction) {
    *handlePtr = (ClientData)(long)rmi->fd;
    return TCL_OK;
  }
  return TCL_ERROR;
}

/*
  the channel instance block mode function
*/
int rawmidi_block_mode(ClientData instanceData, int mode) {
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)instanceData;
  return snd_rawmidi_nonblock(rmi->rawmidi, mode == TCL_MODE_NONBLOCKING);
}

static Tcl_ChannelType rawmidi_channel_type = {
  "rawmidi",			/* typename */
  TCL_CHANNEL_VERSION_5,	/* version */
  rawmidi_close,		/* closeProc */
  rawmidi_input,		/* inputProc */
  rawmidi_output,		/* outputProc */
  NULL,				/* seekProc */
  NULL,				/* setOptionProc */
  NULL,				/* getOptionProc */
  rawmidi_watch,		/* watchProc */
  rawmidi_get_handle,		/* getHandleProc */
  NULL,				/* close2Proc */
  rawmidi_block_mode,		/* blockModeProc */
  NULL,				/* flushProc */
  NULL,				/* handlerProc */
  NULL,				/* wideSeekProc */
  NULL,				/* threadActionProc */
  NULL				/* truncateProc */
};

int rawmidi_make_channel(ClientData clientData, Tcl_Interp *interp, snd_rawmidi_t *rawmidi, int direction) {
  if (snd_rawmidi_poll_descriptors_count(rawmidi) != 1) {
    Tcl_AppendResult(interp, "rawmidi device needs more than one file descriptor", NULL);
    snd_rawmidi_close(rawmidi);
    return TCL_ERROR;
  }
  rawmidi_instance_t *rmi = (rawmidi_instance_t *)ckalloc(sizeof(rawmidi_instance_t));
  char channel_name[256];
  snprintf(channel_name, sizeof(channel_name), "rawmidi@%s", snd_rawmidi_name(rawmidi));
  rmi->direction = direction;
  rmi->rawmidi = rawmidi;
  struct pollfd pollfd;
  snd_rawmidi_poll_descriptors(rmi->rawmidi, &pollfd, 1);
  rmi->fd = pollfd.fd;
  rmi->chan = Tcl_CreateChannel(&rawmidi_channel_type, channel_name, rmi, direction);
  if (rmi->chan == NULL) {
    ckfree((char *)rmi);
    snd_rawmidi_close(rawmidi);
    return TCL_ERROR;
  }
  Tcl_RegisterChannel(interp, rmi->chan);
  Tcl_AppendResult(interp, channel_name, NULL);
  return TCL_OK;
}

/*
  discover the rawmidi devices currently available
*/
static int alsa_rawmidi_list_device(ClientData clientData, Tcl_Interp *interp, Tcl_Obj *dict, snd_ctl_t *ctl, int card, int device) {
  snd_rawmidi_info_t *info;
  const char *name;
  const char *sub_name;
  int subs, subs_in, subs_out;
  int sub;
  int err;

  snd_rawmidi_info_alloca(&info);
  snd_rawmidi_info_set_device(info, device);

  snd_rawmidi_info_set_stream(info, SND_RAWMIDI_STREAM_INPUT);
  err = snd_ctl_rawmidi_info(ctl, info);
  if (err >= 0)
    subs_in = snd_rawmidi_info_get_subdevices_count(info);
  else
    subs_in = 0;

  snd_rawmidi_info_set_stream(info, SND_RAWMIDI_STREAM_OUTPUT);
  err = snd_ctl_rawmidi_info(ctl, info);
  if (err >= 0)
    subs_out = snd_rawmidi_info_get_subdevices_count(info);
  else
    subs_out = 0;

  subs = subs_in > subs_out ? subs_in : subs_out;
  if (!subs)
    return TCL_OK;

  Tcl_Obj *direction_key = Tcl_NewStringObj("direction", -1);
  Tcl_Obj *input = Tcl_NewStringObj("input", -1);
  Tcl_Obj *output = Tcl_NewStringObj("output", -1);
  Tcl_Obj *input_output = Tcl_NewStringObj("input/output", -1);
  Tcl_Obj *name_key = Tcl_NewStringObj("name", -1);

  for (sub = 0; sub < subs; ++sub) {
    snd_rawmidi_info_set_stream(info, sub < subs_in ? SND_RAWMIDI_STREAM_INPUT : SND_RAWMIDI_STREAM_OUTPUT);
    snd_rawmidi_info_set_subdevice(info, sub);
    err = snd_ctl_rawmidi_info(ctl, info);
    if (err < 0) {
      Tcl_AppendPrintfToObj(Tcl_GetObjResult(interp), "cannot get rawmidi information %d:%d:%d: %s", card, device, sub, snd_strerror(err));
      return TCL_ERROR;
    }
    name = snd_rawmidi_info_get_name(info);
    sub_name = snd_rawmidi_info_get_subdevice_name(info);
    Tcl_Obj *io =
      sub < subs_in && sub < subs_out ? input_output :
      sub < subs_in ? input :
      sub < subs_out ? output : Tcl_NewStringObj("", -1);
    if (sub == 0 && sub_name[0] == '\0') {
      Tcl_Obj *element = Tcl_NewDictObj();
      Tcl_Obj *dname = Tcl_NewObj();
      Tcl_AppendPrintfToObj(dname, "hw:%d,%d", card, device);
      Tcl_DictObjPut(interp, element, direction_key, io);
      Tcl_DictObjPut(interp, element, name_key, Tcl_NewStringObj(name, -1));
      if (subs > 1) Tcl_DictObjPut(interp, element, Tcl_NewStringObj("subdevices", -1), Tcl_NewIntObj(subs));
      Tcl_DictObjPut(interp, dict, dname, element);
      break;
    } else {
      Tcl_Obj *element = Tcl_NewDictObj();
      Tcl_Obj *dname = Tcl_NewObj();
      Tcl_AppendPrintfToObj(dname, "hw:%d,%d,%d", card, device, sub);
      Tcl_DictObjPut(interp, element, direction_key, io);
      Tcl_DictObjPut(interp, element, name_key, Tcl_NewStringObj(sub_name, -1));
      Tcl_DictObjPut(interp, dict, dname, element);
    }
  }
  return TCL_OK;
}

static int alsa_rawmidi_list_card_devices(ClientData clientData, Tcl_Interp *interp, Tcl_Obj *dict, int card) {
  snd_ctl_t *ctl;
  char name[32];
  int device;
  int err;

  sprintf(name, "hw:%d", card);
  if ((err = snd_ctl_open(&ctl, name, 0)) < 0) {
    Tcl_AppendPrintfToObj(Tcl_GetObjResult(interp), "cannot open control for card %d: %s", card,  snd_strerror(err));
    return TCL_ERROR;
  }
  device = -1;
  for (;;) {
    if ((err = snd_ctl_rawmidi_next_device(ctl, &device)) < 0) {
      Tcl_AppendResult(interp, "cannot determine device number: %s", snd_strerror(err), NULL);
      snd_ctl_close(ctl);
      return TCL_ERROR;
    }
    if (device < 0)
      break;
    if (alsa_rawmidi_list_device(clientData, interp, dict, ctl, card, device) != TCL_OK) {
      snd_ctl_close(ctl);
      return TCL_ERROR;
    }
  }
  snd_ctl_close(ctl);
  return TCL_OK;
}

static int alsa_rawmidi_list(ClientData clientData, Tcl_Interp *interp) {
  Tcl_Obj *dict = Tcl_NewDictObj();
  int card, err;

  card = -1;
  if ((err = snd_card_next(&card)) < 0) {
    Tcl_AppendResult(interp, "cannot determine card number: ", snd_strerror(err), NULL);
    return TCL_ERROR;
  }
  if (card < 0) {
    Tcl_AppendResult(interp, "no sound card found", NULL);
    return TCL_ERROR;
  }
  do {
    if (alsa_rawmidi_list_card_devices(clientData, interp, dict, card) != TCL_OK) {
      return TCL_ERROR;
    }
    if ((err = snd_card_next(&card)) < 0) {
      Tcl_AppendResult(interp, "cannot determine card number: ", snd_strerror(err), NULL);
      return TCL_ERROR;
    }
  } while (card >= 0);
  Tcl_SetObjResult(interp, dict);
  return TCL_OK;
}

/*
  rawmidi device channel create for reading or writing, not both at once.
*/
static int alsa_rawmidi_open(ClientData clientData, Tcl_Interp *interp, Tcl_Obj *port, Tcl_Obj *direction) {
  const char *port_name = Tcl_GetString(port), *direction_name = Tcl_GetString(direction);
  static snd_rawmidi_t *input, **inputp;
  static snd_rawmidi_t *output, **outputp;
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
  if ((err = snd_rawmidi_open(inputp, outputp, port_name, SND_RAWMIDI_NONBLOCK)) < 0) {
    Tcl_AppendPrintfToObj(Tcl_GetObjResult(interp), "cannot open port \"%s\": %s", port_name, snd_strerror(err));
    return TCL_ERROR;
  }
  if (inputp) {
    snd_rawmidi_read(input, NULL, 0); /* trigger reading */
    return rawmidi_make_channel(clientData, interp, input, TCL_READABLE);
  }
  if (outputp) {
    if ((err = snd_rawmidi_nonblock(output, 0)) < 0) {
      Tcl_AppendResult(interp, "cannot set blocking mode: ", snd_strerror(err), NULL);
      snd_rawmidi_close(output);
      return TCL_ERROR;
    }
    return rawmidi_make_channel(clientData, interp, output, TCL_WRITABLE);
  }
}

/*
  the command which enables alsa rawmidi listing and channels
*/
static int alsa_rawmidi(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc > 1) {
    const char *cmd = Tcl_GetString(objv[1]);
    if (argc == 2) {
      if (strcmp(cmd, "list") == 0) {
	return alsa_rawmidi_list(clientData, interp);
      }
    } else if (argc == 4) {
      if (strcmp(cmd, "open") == 0) {
	return alsa_rawmidi_open(clientData, interp, objv[2], objv[3]);
      }
    }
  }
  Tcl_AppendResult(interp, "usage: ", Tcl_GetString(objv[0]), " list | open port direction", NULL);
  return TCL_ERROR;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Alsa_rawmidi_Init(Tcl_Interp *interp) {
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
  Tcl_PkgProvide(interp, "alsa::rawmidi", "0.0.1");
  Tcl_CreateObjCommand(interp, "alsa::rawmidi", alsa_rawmidi, NULL, NULL);
  return TCL_OK;
}

