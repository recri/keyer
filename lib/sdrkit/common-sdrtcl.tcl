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
# common component services for sdrtcl wrappers
#
package provide sdrkit::common-sdrtcl 1.0.0

package require snit

package require sdrkit::common-component

namespace eval sdrkit {}
namespace eval sdrkitx {}

## install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]

snit::type sdrkit::common-sdrtcl {    
    option -options {}
    option -name {}
    option -parent {}

    variable data -array {
	defcon {}
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor {
	$common destroy
    }

    ## these are services to simplify the parent component
    method is-busy {} { return [::sdrkitx::$options(-name) is-busy] }    
    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }
    method Defcon {args} {
	lappend data(defcon) {*}$args
	if {[llength $data(defcon)] != 0} {
	    if {[$options(-parent) is-busy]} {
		after 10 [mymethod Defcon]
	    } else {
		lassign [list $data(defcon) {}] config data(defcon)
		::sdrkitx::$options(-name) configure {*}$config
	    }
	}
    }
    method Configure {opt val} {
	upvar #0 $options(-options) poptions
	$self Defcon $opt [set poptions($opt) [$options(-parent) Constrain $opt $val]]
    }
    method Set {opt val} {
	upvar #0 $options(-options) poptions
	$poptions(-component) report $opt [$options(-parent) Constrain $opt $val]
    }
}
