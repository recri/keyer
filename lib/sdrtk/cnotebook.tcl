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

##
## a collapsible ttk::notebook
## maintain two notebooks with the same tabs, one containing subpanes
## and the other containing empty subpanes.
## add a collapse tab to both notebooks.
## when the collapse tab is selected, switch to the notebook with the
## empty subpanes, which collapses the notebook to its tabs.
## when any other tab is selected, switch to the notebook with the
## real subpanes, which expands the notebook and its tabs.
##
package provide sdrtk::cnotebook 1.0.0

package require snit
package require Tk
package require Ttk

snit::widget sdrtk::cnotebook {
    hulltype ttk::frame
    component full
    component empty
    option -collapse-text -default {Hide} -configuremethod Configure
    variable data -array { counter -1 }
    constructor {args} {
	install full using ttk::notebook $win.full
	install empty using ttk::notebook  $win.empty
	#$self configure {*}$args               
	ttk::frame $win.full.collapse
	ttk::frame $win.empty.collapse
	$self AddCollapse
	bind $win.full <<NotebookTabChanged>> [mymethod TabSelect $win.full]
	bind $win.empty <<NotebookTabChanged>> [mymethod TabSelect $win.empty]
	grid $win.full -row 0 -column 0 -sticky nsew
    }
    method add {window args} {
	$self ForgetCollapse
	$full add $window {*}$args
	$empty add [$self MakeTranslate $window] {*}$args
	$self AddCollapse
    }
    method AddCollapse {} {
	$full add $win.full.collapse -text $options(-collapse-text)
	$empty add $win.empty.collapse -text $options(-collapse-text)
    }
    method ForgetCollapse {} {
	$full forget $win.full.collapse
	$empty forget $win.empty.collapse
    }
    method {Configure -collapse-text} {val} {
	set options(-collapse-text) $val
	$self ForgetCollapse
	$self AddCollapse
    }
    method MakeTranslate {window} {
	set w [ttk::frame $win.empty.x[incr data(counter)]]
	set data(translate-$w) $window
	return $w
    }
    method Translate {window} { return $data(translate-$window) }
    method TabSelect {window} {
	set select [$window select]
	#puts "TabSelect $window -> $select"
	if {$window eq "$win.full"} {
	    if {$select eq "$win.full.collapse"} {
		#puts "collapsing"
		grid remove $win.full
		grid $win.empty -row 0 -column 0 -sticky ew
		$win.empty select $win.empty.collapse
	    }
	} elseif {$window eq "$win.empty"} {
	    if {$select ne "$win.empty.collapse"} {
		#puts "expanding"
		grid remove $win.empty
		grid $win.full -row 0 -column 0 -sticky nsew
		$win.full select [$self Translate $select]
	    }
	} else {
	    error "unknown window \"$window\" in sdrtk::cnotebook::TabSelect"
	}
    }
}
