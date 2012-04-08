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
#

package provide sdrblk::ui-vfo 1.0

package require Tk
package require snit

package require sdrblk::ui-dial
package require sdrblk::ui-freq-readout
package require sdrblk::ui-band-select
package require sdrblk::spectrum

::snit::widget ::sdrblk::ui-vfo {
    component spectrum
    component readout
    component dial
    component bandbutton
    component bandpopup
    component bandselect

    variable data -array {
	turn-resolutions {10 100 1000 10000 100000}
    }

    option -turn-resolution 1000
    option -freq 7050000
    option -command {}

    method turned {turns} {
	$self set-freq [expr {$options(-freq)+$turns*$options(-turn-resolution)}]
    }

    method set-freq {hertz} {
	$win.readout set-freq $hertz
	set options(-freq) $hertz
    }

    method popup {} {
	set top [winfo toplevel $win]
	set x [winfo rootx $win.bandbutton]
	set y [winfo rooty $win.bandbutton]
	wm transient $win.band-select $top
	wm title     $win.band-select "Band Select"
	wm geometry  $win.band-select +$x+$y
	wm deiconify $win.band-select
	grab $win.band-select
    }
    
    method band-select {which service arg} {
	grab release $win.band-select
	wm withdraw $win.band-select
	switch $which {
	    no-pick {
		# puts "no-pick"
	    }
	    band-pick {
		lassign [$spectrum band-range-hertz $service $arg] low high
		set freq [expr {($low+$high)/2}]
		# puts "band-pick $service $arg $low .. $high"
		$self set-freq $freq
	    }
	    channel-pick {
		set freq [$spectrum channel-freq-hertz $service $arg]
		# puts "channel-pick $service $arg $freq"
		$self set-freq $freq
	    }
	}
    }

    constructor {args} {
	install spectrum using sdrblk::spectrum %AUTO%
	install readout using sdrblk::ui-freq-readout $win.readout
	install dial using sdrblk::ui-dial $win.dial -radius 100 -command [mymethod turned]
	install bandbutton using ttk::button $win.bandbutton -text Band/Channel -command [mymethod popup]
	install bandpopup using toplevel $win.band-select
	install bandselect using ::sdrblk::ui-band-select $win.band-select.bs -range HF -command [mymethod band-select]
	pack $win.readout -side top
	pack $win.dial -side top
	pack $win.bandbutton -side top
	pack $win.band-select.bs
	wm withdraw $win.band-select
	$self set-freq $options(-freq)
    }    
}