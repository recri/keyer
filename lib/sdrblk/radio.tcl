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

package provide sdrblk::radio 1.0.0

package require snit

::snit::type sdrblk::radio {
    option -server -default default;		  # jack server identifier

    option -freq -default 7.05;			  # frequency tuned (MHz)

    option -lo2 -default 10000;			  # second local oscillator offset

    option -mode -default cw;			  # demodulation mode
    option -binaural -default true;		  # binaural cw processing

    option -bpf-type -default filter-overlap-save; # bandpass filter implementation
    option -bpf-center -default 800;		  # bandpass filter center (Hz)
    option -bpf-width -default 400;		  # bandpass filter width (Hz)
    option -bpf-length -default 512;		  # bandpass filter length (coefficients)

    option -agc -default true;			  # agc on
    option -af-gain -default 80;		  # dB fixed audio gain

    option -rf-gain -default 0;			  # dB fixed rf gain
    
    option -iq-swap -default false;		  # swap I and Q channels on input
    option -iq-delay -default 0;		  # delay I stream by specified samples
    option -iq-correct -default true;		  # apply iq-correction
    
    constructor {args} {
	$self configure {*}$args
    }
}
