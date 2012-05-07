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
package require tkcon

package require sdrui::ui-components
package require sdrui::meter
package require sdrui::connections
package require sdrui::tree
package require sdrui::spectrum

snit::widget sdrui::ui-radio-panel {

    option -container {}
    option -control {}

    variable data -array {}

    constructor {args} {
	$self configure {*}$args

	# build the containers
	ttk::separator $win.sep1a -orient horizontal
	#ttk::frame $win.mtr
	ttk::separator $win.sep1b -orient horizontal
	ttk::frame $win.modes
	ttk::separator $win.sep2 -orient horizontal
	ttk::notebook $win.notes1
	ttk::notebook $win.notes2
	ttk::frame $win.band-tab
	#ttk::frame $win.band-frame
	ttk::frame $win.keyer-tab
	ttk::frame $win.keyer-frame
	ttk::frame $win.rx-tab
	ttk::frame $win.rx-frame
	ttk::frame $win.tx-tab
	ttk::frame $win.tx-frame
	ttk::frame $win.spectrum-tab
	ttk::frame $win.spectrum-frame
	ttk::frame $win.view-tab
	ttk::frame $win.view-frame
	ttk::frame $win.collapse-tab
	ttk::frame $win.collapse-frame

	# build the components
	sdrui::meter $win.mtr -control $options(-control) -container $options(-container)
	sdrui::ui-components %AUTO% -root $win -control $options(-control) -container $options(-container)

	# assemble
	set row -1
	grid $win.ui-rxtx-tuner -row [incr row] -column 0 -sticky nsew
	grid $win.sep1a -row [incr row] -column 0 -sticky ew
	grid $win.mtr -row [incr row] -sticky ew
	grid $win.sep1b -row [incr row] -column 0 -sticky ew
	grid $win.modes -row [incr row] -column 0 -sticky ew
	grid $win.sep2 -row [incr row] -column 0 -sticky ew
	grid $win.notes1 -row [incr row] -column 0 -sticky nsew
	set data(notes-row) $row
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
		grid $win.$tail -in $win.modes -row $row -column $column -sticky nsew
		grid columnconfigure $win $column -weight 1
	    }
	}

	$win.notes1 add $win.ui-rxtx-band-select -text Band
	$win.notes2 add $win.band-tab -text Band
	
	$win.notes2 add $win.keyer-frame -text Keyer
	$win.notes2 add $win.keyer-tab -text Keyer
	foreach {row col ht tail} {1 0 2 ui-keyer-debounce 0 0 1 ui-keyer-iambic 0 1 1 ui-keyer-iambic-wpm 0 2 1 ui-keyer-iambic-dah 0 3 1 ui-keyer-iambic-space} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.keyer-frame -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}

	$win.notes1 add $win.rx-frame -text RX
	$win.notes2 add $win.rx-tab -text RX
	foreach {row col ht tail} {
	    0 0 1 ui-rx-rf-gain 0 1 1 ui-rx-rf-iq-swap 0 2 1 ui-rx-rf-iq-delay 0 3 1 ui-rx-rf-iq-correct
	} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.rx-frame -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}

	$win.notes1 add $win.tx-frame -text TX
	$win.notes2 add $win.tx-tab -text TX
	foreach {row col ht tail} {
	    0 0 2 ui-tx-rf-iq-balance
	    2 0 1 ui-tx-af-gain
	} {
	    if {[winfo exists $win.$tail]} {
		grid $win.$tail -in $win.tx-frame -row $row -column $col -rowspan $ht -sticky nsew
	    }
	}

	#add $win.band-pass -text Filter

	$win.notes1 add $win.spectrum-frame -text Spectrum
	$win.notes2 add $win.spectrum-tab -text Spectrum

	$win.notes1 add $win.view-frame -text View
	$win.notes2 add $win.view-tab -text View
	set col 0
	foreach view {spectrum tree connections console} {
	    grid [ttk::button $win.view-frame.$view -text $view -command [mymethod view $view]] -row 0 -column [incr col] -sticky ew
	}

	$win.notes1 add $win.collapse-frame -text Collapse
	$win.notes2 add $win.collapse-tab -text Collapse

	bind $win.notes1 <<NotebookTabChanged>> [mymethod notes1-select]
	bind $win.notes2 <<NotebookTabChanged>> [mymethod notes2-select]
    }

    method notes1-select {} {
	puts "notes1-select [$win.notes1 select]"
	if {[string match *collapse* [$win.notes1 select]]} {
	    # collapse
	    puts "collapsing"
	    grid remove $win.notes1
	    grid $win.notes2 -row $data(notes-row) -column 0 -sticky ew
	} else {
	    # stay expanded
	}
    }

    method notes2-select {} {
	puts "notes2-select [$win.notes2 select]"
	if {[string match *collapse* [$win.notes2 select]]} {
	    # stay collapsed
	} else {
	    # expand
	    puts "expanding"
	    grid remove $win.notes2
	    grid $win.notes1 -row $data(notes-row) -column 0 -sticky nsew
	}
    }

    method {view} {window} {
	switch $window {
	    console {
		tkcon show
		tkcon title sdrkit:console
	    }
	    spectrum {
		if { ! [winfo exists .$window]} {
		    spectrum .spectrum -container $self -control $options(-control)
		} else {
		    wm deiconify .spectrum
		}
	    }
	    default {
		if { ! [winfo exists .$window]} {
		    toplevel .$window
		    pack [$window .$window.t -container $self -control $options(-control)] -fill both -expand true
		    wm title .$window sdrkit:$window
		} else {
		    wm deiconify .$window
		}
	    }
	}
    }
}