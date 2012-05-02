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

package provide sdrctl::control-meter 1.0.0

package require snit

package require sdrtype::types

##
## handle meter controls, both capture and display
##
## meters share the peculiarities of spectrums, and there's
## 5) the s-meter derives its signal from the agc component via a "get" method.
##

snit::type sdrctl::control-meter {
    option -command -default {} -readonly true
    # meter-tap opts
    option -period -default 50 -type sdrtype::milliseconds -configuremethod Opt-handler
    option -decay -default 0.999 -type sdrtype::decay -configuremethod Opt-handler
    option -reduce -default mag2 -type sdrtype::meter-reduce -configuremethod Opt-handler
    # meter-display opts
    option -style -default s-meter -type sdrtype::meter-style -configuremethod Opt-display
    # control opts
    option -tap -default {}
    option -instance -default 1 -type sdrtype::instance

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

