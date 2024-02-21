/* -*- mode: c; tab-width: 8 -*- */

/*
 * the alsa pcm api is a discovery interface
 * for finding existing pcm interfaces for capture and playback.
 *
 *  We implement the tcl interface as a simple interface to the
 *  discovery layer,
	::alsa::pcm list

  This code is a hacked up version of alsa-utils-1.0.24.2/aplay/aplay.c

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

static int alsa_pcm_list(ClientData clientData, Tcl_Interp *interp)
{
  void **hints, **n;
  Tcl_Obj *pcm = Tcl_NewListObj(0, NULL);

  if (snd_device_name_hint(-1, "pcm", &hints) >= 0) {
    n = hints;
    while (*n != NULL) {
      char *name, *descr, *io;
      Tcl_Obj *dict = Tcl_NewListObj(0, NULL);
      name = snd_device_name_get_hint(*n, "NAME");
      Tcl_ListObjAppendElement(interp, pcm, Tcl_ObjPrintf("%s", name?name:"(null)"));
      Tcl_ListObjAppendElement(interp, pcm, dict);
      descr = snd_device_name_get_hint(*n, "DESC");
      Tcl_ListObjAppendElement(interp, dict, Tcl_ObjPrintf("desc"));
      Tcl_ListObjAppendElement(interp, dict, Tcl_ObjPrintf(descr?descr:"(null)"));
      io = snd_device_name_get_hint(*n, "IOID");
      Tcl_ListObjAppendElement(interp, dict, Tcl_ObjPrintf("ioid"));
      Tcl_ListObjAppendElement(interp, dict, Tcl_ObjPrintf(io?io:"(null)"));
      if (name != NULL)
	free(name);
      if (descr != NULL)
	free(descr);
      if (io != NULL)
	free(io);
      n++;
    }
    snd_device_name_free_hint(hints);
  }
  Tcl_SetObjResult(interp, pcm);
  return TCL_OK;
}

static int alsa_pcm(ClientData clientData, Tcl_Interp *interp, int argc, Tcl_Obj* const *objv) {
  if (argc > 1) {
    const char *cmd = Tcl_GetString(objv[1]);
    if (argc == 2 && strcmp(cmd, "list") == 0) {
      return alsa_pcm_list(clientData, interp);
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
int DLLEXPORT Alsa_pcm_Init(Tcl_Interp *interp) {
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
  Tcl_PkgProvide(interp, "alsa::pcm", "0.0.1");
  Tcl_CreateObjCommand(interp, "alsa::pcm", alsa_pcm, NULL, NULL);
  return TCL_OK;
}
