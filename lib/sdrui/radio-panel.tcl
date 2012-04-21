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

package provide sdrui::radio-panel 1.0

package require Tk
package require snit

package require sdrui::components

snit::widget sdrui::radio-panel {

    option -partof {}
    option -control {}

    constructor {args} {
	$self configure {*}$args

	# build the containers
	ttk::separator $win.sep1 -orient horizontal
	ttk::frame $win.set1
	ttk::separator $win.sep2 -orient horizontal
	ttk::notebook $win.notes
	ttk::frame $win.set2
	# build the components
	sdrui::components %AUTO% -root $win -control $options(-control); # beware of name conflicts

	# assemble
	pack $win.ui-tuner -side top -expand true -fill both

	pack $win.sep1 -side top -fill x

	grid $win.ui-rxtx-mode -in $win.set1 -row 0 -column 0 -sticky nsew
	grid $win.ui-rxtx-if-bpf -in $win.set1 -row 0 -column 1 -sticky nsew
	grid $win.ui-rx-af-agc -in $win.set1 -row 0 -column 2 -sticky nsew
	grid $win.ui-rx-af-gain -in $win.set1 -row 0 -column 3 -sticky nsew
	foreach c {0 1 2 3} { grid columnconfigure $win.set1 $c -weight 1 }
	pack $win.set1 -side top -fill x

	pack $win.sep2 -side top -fill x

	pack $win.notes -side top -fill both -expand true
	$win.notes add $win.ui-band-select -text Band
	$win.notes add $win.set2 -text Settings
	grid $win.ui-keyer-pitch -in $win.set2 -row 0 -column 2 -sticky nsew
	#add $win.band-pass -text Filter
    }    
}