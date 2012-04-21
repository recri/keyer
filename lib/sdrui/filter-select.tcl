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

snit::widgetadaptor sdrui::filter-select {

    option -mode -default CWU -configuremethod set-mode
    option -cw-pitch -default 600 -configuremethod set-cw-pitch
    option -limits {}
    option -command {}
    option -controls {-limits -mode -pitch}

    ##
    ## qtradio filter settings
    ## the CW settings are offsets from the desired cw pitch
    ## the unique filters settings are listed, the rest are aliases or
    ## negations of the aliased set
    ##
    typevariable filters [dict create \
			      LSB -USB \
			      USB [dict create \
				       0 {"5.0k" 150 5150} 1 {"4.4k" 150 4550} 2 {"3.8k" 150 3950} 3 {"3.3k" 150 3450} 4 {"2.9k" 150 3050} \
				       5 {"2.7k" 150 2850} 6 {"2.4k" 150 2550} 7 {"2.1k" 150 2250} 8 {"1.8k" 150 1950} 9 {"1.0k" 150 1150} \
				       default 3] \
			      DSB AM \
			      CWL CWU \
			      CWU [dict create \
				       0 {"1.0k" -500 500} 1 {"800" -400 400} 2 {"750" -375 375} 3 {"600" -300 300} 4 {"500" -250 250} \
				       5 {"400" -200 200} 6 {"250" -125 125} 7 {"100" -50 50} 8 {"50" -25 25} 9 {"25" -13 13} \
				       default 5] \
			      AM [dict create \
				      0 {"16k" -8000 8000} 1 {"12k" -6000 6000} 2 {"10k" -5000 5000} 3 {"8k"  -4000 4000} 4 {"6.6k" -3300 3300} \
				      5 {"5.2k" -2600 2600} 6 {"4.0k" -2000 2000} 7 {"3.1k" -1550 1550} 8 {"2.9k" -1450 1450} 9 {"2.4k" -1200 1200} \
				      default 3] \
			      SAM AM \
			      FMN AM \
			      DIGL -DIGU \
			      DIGU [dict create \
					0 {"5.0k" 150 5150} 1 {"4.4k" 150 4550} 2 {"3.8k" 150 3950} 3 {"3.3k" 150 3450} 4 {"2.9k" 150 3050} \
					5 {"2.7k" 150 2850} 6 {"2.4k" 150 2550} 7 {"2.1k" 150 2250} 8 {"1.8k" 150 1950} 9 {"1.0k" 150 1150} \
					default 3] \
			     ]
    # local data
    variable data -array {
	selected 0
	filters {}
	string "xxxx"
    }

    constructor {args} {
	installhull using ttk::labelframe -text Filter -labelanchor n
	pack [ttk::menubutton $win.b -textvar [myvar data(string)] -menu $win.b.m] -fill x -expand true
	menu $win.b.m -tearoff no
	$self configure {*}$args
    }
    
    method set-cw-pitch {opt val} {
	set options($opt) $val
	if {$options(-mode) in {CWL CWU}} {
	    $self set-filter $data(selected)
	}
    }

    method set-mode {opt val} {
	if { ! [dict exists $filters $val]} {
	    error "unknown mode \"$val\", must be one of [dict keys filters]"
	}
	set options($opt) $val
	set negative 0
	set fdict [dict get $filters $val]
	if {[dict exists $filters $fdict]} {
	    set fdict [dict get $filters $fdict]
	} elseif {[dict exists $filters [string range $fdict 1 end]]} {
	    set negative [string equal [string range $fdict 0 1] {-}]
	    set fdict [dict get $filters [string range $fdict 1 end]]
	}
	set data(filters) $fdict
	$win.b.m delete 0 end
	dict for {key val} $data(filters) {
	    if {$key eq {default}} {
		set data(selected) $val
		$self set-filter $data(selected)
	    } else {
		lassign $val string low high
		if {$negative} { lassign [list [expr {-$high}] [expr {-$low}]] low high }
		$win.b.m add radiobutton -label $string -value $key -variable [myvar data(selected)] -command [mymethod set-filter $key]
	    }
	}
    }

    method set-filter {index} {
	lassign [dict get $data(filters) $index] string low high
	set data(string) $string
	if {$options(-mode) eq {CWU}} {
	    lassign [list [expr {$options(-cw-pitch)+$low}] [expr {$options(-cw-pitch)+$high}]] low high
	} elseif {$options(-mode) eq {CWL}} {
	    lassign [list [expr {-$options(-cw-pitch)+$low}] [expr {-$options(-cw-pitch)+$high}]] low high
	}
	if {$options(-command) ne {}} { {*}$options(-command) report -limits [list $low $high] }
    }
}
