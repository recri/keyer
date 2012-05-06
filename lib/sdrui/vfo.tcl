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
	turn-resolutions {1 10 100 1000 10000 100000}
    }

    option -freq -default 7050000 -configuremethod Opt-handler
    option -turn-resolution 100

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Turned {turns} { $self Set-freq [expr {$options(-freq)+$turns*$options(-turn-resolution)}] }

    method {Opt-handler -freq} {hertz} {
	set options(-freq) $hertz
	$win.readout set-freq $hertz
    }

    method Set-freq {hertz} {
	$self Opt-handler -freq $hertz
	{*}$options(-command) report -freq $hertz
    }

    constructor {args} {
	$self configure {*}$args
	pack [sdrui::freq-readout $win.readout] -side top
	pack [ttk::separator $win.sep1 -orient horizontal] -side top -fill x
	pack [sdrui::dial $win.dial -command [mymethod Turned]] -side top -expand true -fill both
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-freq -turn-resolution} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }    
}
