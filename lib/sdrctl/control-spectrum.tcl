# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 

package provide sdrctl::control-spectrum 1.0.0

package require snit

package require sdrtype::types

##
## handle spectrum controls, both capture and display
##
## spectrum displays are special cases in several ways
## 1) they don't always connect in the same place in the dsp chain,
##    they can move between taps
## 2) they are only activated when their source is activated and
##    their display side is visible
## 3) they only deliver results when their "get" method is called
## 4) there can be zero, one, or multiple instances of them.
##

snit::type sdrctl::control-spectrum {
    option -command -default {} -readonly true
    # spectrum-tap opts
    option -size -default 256 -type sdrtype::spec-size
    option -planbits -default 0 -type sdrtype::fftw-planbits
    option -direction -default -1 -type sdrtype::fftw-direction
    option -polyphase -default 1 -type sdrtype::spec-polyphase
    option -result -default dB -type sdrtype::spec-result
    # spectrum-display opts
    option -pal -default 0 -type sdrtype::spec-palette
    option -min -default -150 -type sdrtype::decibel
    option -max -default -0 -type sdrtype::decibel
    option -zoom -default 1 -type sdrtype::zoom
    option -pan -default 0 -type sdrtype::pan
    option -smooth -default false -type sdrtype::smooth
    option -center -default 0 -type sdrtype::hertz
    option -multi -default 1 -type sdrtype::multi
    # spectrum control options
    option -period -default 100 -type sdrtype::milliseconds

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

