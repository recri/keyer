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
# a filter component
#
package provide sdrkit::filter-overlap-save 1.0.0

package require snit
package require sdrtcl::filter-overlap-save
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::filter-overlap-save {    
    option -name sdr-ovsv
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -options {-low -high -length}

    option -low -default -400.0 -configuremethod Configure
    option -high -default 400.0 -configuremethod Configure
    option -length -default 128 -configuremethod Configure

    option -sub-controls {
	low scale {-format {Low %.0f Hz} -from -8000 -to 8000}
	high scale {-format {High %.0f Hz} -from -8000 -to 8000}
	length iscale {-format {Length %d samples} -from 8 -to 2048}
    }

    variable data -array { }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {w} {
	sdrtcl::filter-overlap-save ::sdrkitx::$options(-name) -server $options(-server) -low $options(-low) -high $options(-high) -length $options(-length)
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }

    method Constrain {opt val} {
	switch -- $opt {
	    -low { return [expr {min($options(-high)-11,$val)}] }
	    -high { return [expr {max($options(-low)+11,$val)}] }
	}
	return $val
    }
}
