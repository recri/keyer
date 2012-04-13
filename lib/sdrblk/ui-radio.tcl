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
# a radio control widget
# with frequency readout, tuning dial, 
# and a notebook of other controls
#

package provide sdrblk::ui-radio 1.0

package require Tk
package require snit

package require sdrblk::ui-dial
package require sdrblk::ui-freq-readout
package require sdrblk::ui-band-select
package require sdrblk::ui-band-pass
package require sdrblk::band-data

snit::widget sdrblk::ui-radio {
    component bands
    component readout
    component dial
    component notebook
    component bandselect
    component bandpass

    variable data -array {
	turn-resolutions {10 100 1000 10000 100000}
    }

    option -turn-resolution 1000
    option -freq 7050000
    option -partof {}
    option -control {}
    option -command {}

    method turned {turns} {
	$self set-freq [expr {$options(-freq)+$turns*$options(-turn-resolution)}]
    }

    method set-freq {hertz} {
	$win.readout set-freq $hertz
	set options(-freq) $hertz
	if {$options(-command) ne {}} {
	    eval "$options(-command) $hertz"
	}
    }

    method band-select {which args} {
	switch $which {
	    no-pick {
		# puts "no-pick"
	    }
	    band-pick {
		lassign [$bands band-range-hertz {*}$args] low high
		set freq [expr {($low+$high)/2}]
		# puts "band-pick $service $arg $low .. $high"
		$self set-freq $freq
	    }
	    channel-pick {
		set freq [$bands channel-freq-hertz {*}$args]
		# puts "channel-pick $service $arg $freq"
		$self set-freq $freq
	    }
	}
    }

    constructor {args} {
	install bands using sdrblk::band-data %AUTO%
	install readout using sdrblk::ui-freq-readout $win.readout
	install dial using sdrblk::ui-dial $win.dial -command [mymethod turned]
	install notebook using ttk::notebook $win.notes
	install bandselect using sdrblk::ui-band-select $win.notes.band-select -command [mymethod band-select]
	#install bandpass using sdrblk::ui-band-pass $win.notes.band-pass -name rx-if-...
	pack $win.readout -side top
	pack [ttk::separator $win.sep1 -orient horizontal] -side top -fill x
	pack $win.dial -side top -expand true -fill both
	pack [ttk::separator $win.sep2 -orient horizontal] -side top -fill x
	pack $win.notes -side top -fill both -expand true
	$win.notes add $win.notes.band-select -text Band
	#add $win.band-pass -text Filter
	$self set-freq $options(-freq)
    }    
}