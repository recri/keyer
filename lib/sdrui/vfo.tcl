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

#
# a rotary encoder with a frequency readout
# and a band selector
#

package provide sdrui::vfo 1.0

package require Tk
package require snit

package require sdrui::dial
package require sdrui::freq-readout

snit::widget sdrui::vfo {

    variable data -array {
	turn-resolutions {10 100 1000 10000 100000}
    }

    option -turn-resolution 1000
    option -freq -default 7050000 -configuremethod opt-handler
    option -command {}
    option -controls {-freq}

    method turned {turns} { $self set-freq [expr {$options(-freq)+$turns*$options(-turn-resolution)}] }

    method {opt-handler -freq} {hertz} {
	set options(-freq) $hertz
	$win.readout set-freq $hertz
    }

    method set-freq {hertz} {
	$self opt-handler -freq $hertz
	if {$options(-command) ne {}} { {*}$options(-command) report -freq $hertz }
    }

    constructor {args} {
	$self configure {*}$args
	pack [sdrui::freq-readout $win.readout] -side top
	pack [ttk::separator $win.sep1 -orient horizontal] -side top -fill x
	pack [sdrui::dial $win.dial -command [mymethod turned]] -side top -expand true -fill both
	# $self set-freq $options(-freq)
    }    
}
