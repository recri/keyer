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

package provide sdrdsp::dsp-ports 1.0.0

package require snit

snit::type sdrdsp::dsp-ports {
    typevariable direction -array {
	alt_in_i input alt_out_i output 
	alt_in_q input alt_out_q output 
	alt_midi_in input alt_midi_out output
	in_i input out_i output
	in_q input out_q output
	midi_in input midi_out output
	playback_1 input capture_1 output
	playback_2 input capture_2 output
	seq_in_i input seq_out_i output
	seq_in_q input seq_out_q output
	seq_midi_in input seq_midi_out output
	tap_i either
	tap_q either
	tap_midi either
    }

    option -control -default {} -readonly true
    
    proc filter {element accept} {
	set ports {}
	foreach p [$element cget -ports] {
	    if { ! [info exists direction($p)]} {
		error "port \"$p\" not classified"
	    } elseif {$direction($p) in $accept} {
		lappend ports [$element cget -name] $p
	    }
	}
	return $ports
    }

    method inputs {element} { return [filter $element {input either}] }
    method outputs {element} { return [filter $element {output either}] }
    method connect {inports outports} {
	foreach {ipart iport} $inports {opart oport} $outports {
	    # puts "$options(-control) port-connect [list $ipart $iport] [list $opart $oport]"
	    $options(-control) port-connect [list $ipart $iport] [list $opart $oport]
	}
    }

}

