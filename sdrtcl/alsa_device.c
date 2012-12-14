/* -*- mode: c; tab-width: 8 -*- */

/*
 * the alsa device api is a discovery interface
 * for finding existing hardware for capture and playback.
 *
 *  We implement the tcl interface as a simple interface to the
 *  discovery layer,
	::alsa::device cards
	::alsa::device devices card
	::alsa::device info card | device

  This code is a hacked up version of alsa-utils-1.0.24.2/aplay/aplay.c

  Consult ~/Sources/portaudio/src/hostapi/alsa/pa_linux_alsa.c/GropeDevice()
  to see how to determine number of channels and sample rates.
  Elsewhere for sample formats and sizes.

/*
 *  aplay.c - plays and records
 *
 *      CREATIVE LABS CHANNEL-files
 *      Microsoft WAVE-files
 *      SPARC AUDIO .AU-files
 *      Raw Data
 *
 *  Copyright (c) by Jaroslav Kysela <perex@perex.cz>
 *  Based on vplay program by Michael Beck
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
 *
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <alsa/asoundlib.h>

#include <tcl.h>

static int alsa_info(ClientData clientData, Tcl_Interp *interp, char *token)
{
  snd_ctl_t *handle;
  int card, err, dev, idx;
  snd_ctl_card_info_t *info;
  snd_pcm_info_t *pcminfo;
  snd_ctl_card_info_alloca(&info);
  snd_pcm_info_alloca(&pcminfo);
  Tcl_Obj *devices = Tcl_NewListObj(0, NULL);

  for (card = -1; (err = snd_card_next(&card)) >= 0 && card >= 0; ) {
    // open the card
    char name[32];
    sprintf(name, "hw:%d", card);
    if ((err = snd_ctl_open(&handle, name, 0)) < 0) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_open (%s): %s", name, snd_strerror(err)));
      Tcl_DecrRefCount(devices);
      return TCL_ERROR;
    }
    // get the card's info
    if ((err = snd_ctl_card_info(handle, info)) < 0) {
      snd_ctl_close(handle);
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_card_info (%s): %s", name, snd_strerror(err)));
      Tcl_DecrRefCount(devices);
      return TCL_ERROR;
    }
    // enumerate the devices of the card
    for (dev = -1; (err = snd_ctl_pcm_next_device(handle, &dev)) >= 0 && dev >= 0; ) {
      unsigned int count;
      snd_pcm_stream_t stream;

      stream = SND_PCM_STREAM_PLAYBACK;
      snd_pcm_info_set_device(pcminfo, dev);
      snd_pcm_info_set_subdevice(pcminfo, 0);
      snd_pcm_info_set_stream(pcminfo, stream);
      if ((err = snd_ctl_pcm_info(handle, pcminfo)) < 0) {
	if (err != -ENOENT) {
	  snd_ctl_close(handle);
	  Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_info (%s): %s", name, snd_strerror(err)));
	  Tcl_DecrRefCount(devices);
	  return TCL_ERROR;
	}
	continue;
      }
      if (err < 0) {
	snd_ctl_close(handle);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_next_device (%s): %s", name, snd_strerror(err)));
	Tcl_DecrRefCount(devices);
	return TCL_ERROR;
      }
      Tcl_ListObjAppendElement(interp, devices, Tcl_ObjPrintf("%s,%d: %s [%s]: %s [%s]",
							      name, dev,
							      snd_ctl_card_info_get_id(info), snd_ctl_card_info_get_name(info),
							      dev,
							      snd_pcm_info_get_id(pcminfo),
							      snd_pcm_info_get_name(pcminfo)));
      // enumerate the subdevices of the card
      count = snd_pcm_info_get_subdevices_count(pcminfo);
      for (idx = 0; idx < count; idx++) {
	snd_pcm_info_set_subdevice(pcminfo, idx);
	if ((err = snd_ctl_pcm_info(handle, pcminfo)) < 0) {
	  snd_ctl_close(handle);
	  Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_info (%s,%d): %s", name, idx, snd_strerror(err)));
	  Tcl_DecrRefCount(devices);
	  return TCL_ERROR;
	}
	Tcl_ListObjAppendElement(interp, devices, Tcl_ObjPrintf("%s,%d: %s", name, idx, snd_pcm_info_get_subdevice_name(pcminfo)));
      }
    }
    snd_ctl_close(handle);
  }
  if (err < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_card_next : %s", snd_strerror(err)));
    Tcl_DecrRefCount(devices);
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, devices);
  return TCL_OK;
}

static int alsa_card_list(ClientData clientData, Tcl_Interp *interp)
{
  snd_ctl_t *handle;
  int card, err;
  Tcl_Obj *cards = Tcl_NewListObj(0, NULL);

  for (card = -1; (err = snd_card_next(&card)) >= 0 && card >= 0; ) {
    // open the card
    char name[32], *sname, *lname;
    sprintf(name, "hw:%d", card);
    if ((err = snd_ctl_open(&handle, name, 0)) < 0) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_open (%s): %s", name, snd_strerror(err)));
      Tcl_DecrRefCount(cards);
      return TCL_ERROR;
    }
    Tcl_ListObjAppendElement(interp, cards, Tcl_ObjPrintf("%s", name));
    if (err = snd_card_get_name(card, &sname)) {
      Tcl_ListObjAppendElement(interp, cards, Tcl_ObjPrintf("snd_card_get_name(%s): %s", name, snd_strerror(err)));
    } else {
      Tcl_ListObjAppendElement(interp, cards, Tcl_ObjPrintf("%s", sname));
      free(sname);
    }
    if (err = snd_card_get_longname(card, &lname)) {
      Tcl_ListObjAppendElement(interp, cards, Tcl_ObjPrintf("snd_card_get_longname(%s): %s", name, snd_strerror(err)));
    } else {
      Tcl_ListObjAppendElement(interp, cards, Tcl_ObjPrintf("%s", lname));
      free(lname);
    }
    snd_ctl_close(handle);
  }
  if (err < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_card_next : %s", snd_strerror(err)));
    Tcl_DecrRefCount(cards);
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, cards);
  return TCL_OK;
}

static int alsa_device_list(ClientData clientData, Tcl_Interp *interp, char *card)
{
  snd_ctl_t *handle;
  int err, dev;
  snd_ctl_card_info_t *info;
  snd_pcm_info_t *pcminfo;
  snd_ctl_card_info_alloca(&info);
  snd_pcm_info_alloca(&pcminfo);
  Tcl_Obj *devices = Tcl_NewListObj(0, NULL);

  if ((err = snd_ctl_open(&handle, card, 0)) < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_open (%s): %s", card, snd_strerror(err)));
    Tcl_DecrRefCount(devices);
    return TCL_ERROR;
  }

  // enumerate the devices of the card
  for (dev = -1; (err = snd_ctl_pcm_next_device(handle, &dev)) >= 0 && dev >= 0; ) {
    Tcl_ListObjAppendElement(interp, devices, Tcl_ObjPrintf("%s,%d", card, dev));
  }
  if (err < 0) {
    snd_ctl_close(handle);
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_next_device (%s) : %s", card, snd_strerror(err)));
    Tcl_DecrRefCount(devices);
    return TCL_ERROR;
  }

  snd_ctl_close(handle);
  Tcl_SetObjResult(interp, devices);
  return TCL_OK;
}

static int alsa_subdevice_list(ClientData clientData, Tcl_Interp *interp, char *device)
{
  snd_ctl_t *handle;
  int card, err, dev, idx;
  snd_ctl_card_info_t *info;
  snd_pcm_info_t *pcminfo;
  snd_ctl_card_info_alloca(&info);
  snd_pcm_info_alloca(&pcminfo);
  Tcl_Obj *devices = Tcl_NewListObj(0, NULL);

  
  if ((err = snd_ctl_open(&handle, device, 0)) < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_open (%s): %s", device, snd_strerror(err)));
    Tcl_DecrRefCount(devices);
    return TCL_ERROR;
  }

#if 0
  for (card = -1; (err = snd_card_next(&card)) >= 0 && card >= 0; ) {
    // open the card
    char name[32];
    sprintf(name, "hw:%d", card);
    if ((err = snd_ctl_open(&handle, name, 0)) < 0) {
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_open (%s): %s", name, snd_strerror(err)));
      Tcl_DecrRefCount(devices);
      return TCL_ERROR;
    }
    // get the card's info
    if ((err = snd_ctl_card_info(handle, info)) < 0) {
      snd_ctl_close(handle);
      Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_card_info (%s): %s", name, snd_strerror(err)));
      Tcl_DecrRefCount(devices);
      return TCL_ERROR;
    }
    // enumerate the devices of the card
    for (dev = -1; (err = snd_ctl_pcm_next_device(handle, &dev)) >= 0 && dev >= 0; ) {
      unsigned int count;
      snd_pcm_stream_t stream;

      stream = SND_PCM_STREAM_PLAYBACK;
      snd_pcm_info_set_device(pcminfo, dev);
      snd_pcm_info_set_subdevice(pcminfo, 0);
      snd_pcm_info_set_stream(pcminfo, stream);
      if ((err = snd_ctl_pcm_info(handle, pcminfo)) < 0) {
	if (err != -ENOENT) {
	  snd_ctl_close(handle);
	  Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_info (%s): %s", name, snd_strerror(err)));
	  Tcl_DecrRefCount(devices);
	  return TCL_ERROR;
	}
	continue;
      }
      if (err < 0) {
	snd_ctl_close(handle);
	Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_next_device (%s): %s", name, snd_strerror(err)));
	Tcl_DecrRefCount(devices);
	return TCL_ERROR;
      }
      Tcl_ListObjAppendElement(interp, devices, Tcl_ObjPrintf("%s,%d: %s [%s]: %s [%s]",
							      name, dev,
							      snd_ctl_card_info_get_id(info), snd_ctl_card_info_get_name(info),
							      dev,
							      snd_pcm_info_get_id(pcminfo),
							      snd_pcm_info_get_name(pcminfo)));
      // enumerate the subdevices of the card
      count = snd_pcm_info_get_subdevices_count(pcminfo);
      for (idx = 0; idx < count; idx++) {
	snd_pcm_info_set_subdevice(pcminfo, idx);
	if ((err = snd_ctl_pcm_info(handle, pcminfo)) < 0) {
	  snd_ctl_close(handle);
	  Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_ctl_pcm_info (%s,%d): %s", name, idx, snd_strerror(err)));
	  Tcl_DecrRefCount(devices);
	  return TCL_ERROR;
	}
	Tcl_ListObjAppendElement(interp, devices, Tcl_ObjPrintf("%s,%d: %s", name, idx, snd_pcm_info_get_subdevice_name(pcminfo)));
      }
    }
    snd_ctl_close(handle);
  }
  if (err < 0) {
    Tcl_SetObjResult(interp, Tcl_ObjPrintf("snd_card_next : %s", snd_strerror(err)));
    Tcl_DecrRefCount(devices);
    return TCL_ERROR;
  }
  Tcl_SetObjResult(interp, devices);
#endif
  return TCL_OK;
}

/*
  the command which enables alsa sequencer listing and channels
*/
static int alsa_device(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc > 1) {
    const char *cmd = Tcl_GetString(objv[1]);
    if (argc == 2 && strcmp(cmd, "cards") == 0) {
      return alsa_card_list(clientData, interp);
    } else if (argc == 3 && strcmp(cmd, "devices") == 0) {
      return alsa_device_list(clientData, interp, Tcl_GetString(objv[2]));
    } else if (argc == 3 && strcmp(cmd, "subdevices") == 0) {
      return alsa_subdevice_list(clientData, interp, Tcl_GetString(objv[2]));
#if 0
    } else if (argc == 4 && strcmp(cmd, "open") == 0) {
      return alsa_sequencer_open(clientData, interp, objv[2], objv[3]);
#endif
    }
  }
  Tcl_AppendResult(interp, "usage: ", Tcl_GetString(objv[0]), " list", NULL);
  return TCL_ERROR;
}

// the initialization function which installs the adapter factory
int DLLEXPORT Alsa_device_Init(Tcl_Interp *interp) {
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
  Tcl_PkgProvide(interp, "alsa::device", "0.0.1");
  Tcl_CreateObjCommand(interp, "alsa::device", alsa_device, NULL, NULL);
  return TCL_OK;
}


