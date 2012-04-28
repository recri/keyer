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

package provide sdrui::ui-radio-panel 1.0

package require Tk
package require snit

package require sdrui::components

snit::widget sdrui::ui-radio-panel {

    option -container {}
    option -control {}

    constructor {args} {
	$self configure {*}$args

	# build the containers
	ttk::separator $win.sep1 -orient horizontal
	ttk::frame $win.set1
	ttk::separator $win.sep2 -orient horizontal
	ttk::notebook $win.notes
	ttk::frame $win.set2
	ttk::frame $win.set3
	ttk::frame $win.set4

	# build the components
	sdrui::components %AUTO% -root $win -control $options(-control) -container $options(-container)

	# assemble
	grid $win.ui-rxtx-tuner -row 0 -column 0 -sticky nsew
	grid $win.sep1 -row 1 -column 0 -sticky ew
	grid $win.set1 -row 2 -column 0 -sticky ew
	grid $win.sep2 -row 3 -column 0 -sticky ew
	grid $win.notes -row 4 -column 0 -sticky nsew
	grid rowconfigure $win 0 -weight 1
	grid rowconfigure $win 4 -weight 1
	grid columnconfigure $win 0 -weight 1

	foreach {tail row column} {
	    ui-rxtx-mode 0 0
	    ui-rxtx-if-bpf 0 1
	    ui-rx-af-agc 0 2
	    ui-rx-af-gain 0 3
	} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.set1 -row $row -column $column -sticky nsew
		grid columnconfigure $win $column -weight 1
	    }
	}
	$win.notes add $win.ui-rxtx-band-select -text Band

	$win.notes add $win.set2 -text Keyer
	foreach {row col ht tail} {1 0 2 ui-keyer-debounce 0 0 1 ui-keyer-iambic 0 1 1 ui-keyer-iambic-wpm 0 2 1 ui-keyer-iambic-dah 0 3 1 ui-keyer-iambic-space} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.set2 -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}

	$win.notes add $win.set3 -text RX
	foreach {row col ht tail} {
	    0 0 1 ui-rx-rf-gain 0 1 1 ui-rx-rf-iq-swap 0 2 1 ui-rx-rf-iq-delay 0 3 1 ui-rx-rf-iq-correct
	} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.set3 -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}

	$win.notes add $win.set4 -text TX
	foreach {row col ht tail} {
	    0 0 2 ui-tx-rf-iq-balance
	    2 0 1 ui-tx-af-gain
	} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.set4 -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}
	#add $win.band-pass -text Filter
    }    
}