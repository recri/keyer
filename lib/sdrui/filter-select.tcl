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

##
## filter-select - band pass filter chooser
##
package provide sdrui::filter-select 1.0.0

package require Tk
package require snit
package require sdrctl::types

snit::widgetadaptor sdrui::filter-select {

    option -mode -default CWU -type sdrctl::mode -configuremethod opt-handler
    option -width {}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    ##
    ## QtRadio filter settings simplified.
    ## They use 20 source files to define the 3 filter sets listed below.
    ## Only the filter widths are specified.
    ## Filters are symmetric, carrier-width/2 to carrier+width/2,
    ## upper sideband, carrier+150 to carrier+150+width,
    ## or lower sideband, carrier-150-width to carrier-150.
    ## Modes with identical widths are aliased.
    ##
    typevariable aliases [dict create {*}{
	CWU CWU
	CWL CWU
	USB USB
	LSB USB
	DIGL USB
	DIGU USB
	AM AM
	DSB AM
	SAM AM
	FMN AM
    }]
    typevariable filters [dict create {*}{
	CWU-default 400  CWU { 1000   800   750  600  500  400  250  100   50   25}
	USB-default 3300 USB { 5000  4400  3800 3300 2900 2700 2400 2100 1800 1000}
	AM-default  8000  AM {16000 12000 10000 8000 6600 5200 4000 3100 2900 2400}
	
    }]

    constructor {args} {
	installhull using ttk::labelframe -text Filter -labelanchor n
	pack [ttk::menubutton $win.b -textvar [myvar options(-width)] -menu $win.b.m] -fill x -expand true
	menu $win.b.m -tearoff no
	$self configure {*}$args
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-mode -width} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
    }
    
    method {opt-handler -mode} {val} {
	set options(-mode) $val
	if { ! [dict exists $aliases $val]} { error "no filter mode alias for \"$val\"" }
	set x [dict get $aliases $val]
	if { ! [dict exists $filters $x]} { error "no filter set for mode $val, aliased as $x" }
	if { ! [dict exists $filters $x-default]} { error "no filter set default for mode $val, aliased as $x" }
	set data(widths) [dict get $filters $x]
	set options(-width) [dict get $filters $x-default]
	$win.b.m delete 0 end
	foreach width $data(widths) {
	    $win.b.m add radiobutton -label $width -value $width -variable [myvar options(-width)] -command [mymethod set-filter $width]
	}
	$self set-filter $options(-width)
    }

    method set-filter {width} {
	if {$options(-command) ne {}} { {*}$options(-command) report -width $width }
    }
}
