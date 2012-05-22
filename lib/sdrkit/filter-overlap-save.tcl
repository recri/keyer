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

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::filter-overlap-save {    
    option -name sdr-ovsv
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -title filter-ovsv
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-low -high -length}
    option -out-options {}

    option -low -default -400.0 -configuremethod Configure
    option -min-low -default -8000 -configuremethod Configure
    option -max-low -default  8000 -configuremethod Configure
    option -high -default 400.0 -configuremethod Configure
    option -min-high -default -8000 -configuremethod Configure
    option -max-high -default  8000 -configuremethod Configure
    option -length -default 128 -configuremethod Configure
    option -min-length -default 8 -configuremethod Configure
    option -max-length -default 2048 -configuremethod Configure

    variable data -array {
	label-low {} format-low {Low %.0f Hz}
	label-high {} format-high {High %.0f Hz}
	label-length {} format-length {Length %d samples}
	deferred-config {}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::filter-overlap-save ::sdrkitx::$options(-name) -server $options(-server) -low $options(-low) -high $options(-high) -length $options(-length)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	ttk::label $w.low-l -textvar [myvar data(label-low)] -width 10 -anchor e
	ttk::scale $w.low-s -from $options(-min-low) -to $options(-max-low) -command [mymethod Set -low] -variable [myvar options(-low)]
	$self Set -low $options(-low)
	grid $w.low-l $w.low-s -sticky ew

	ttk::label $w.high-l -textvar [myvar data(label-high)] -width 10 -anchor e
	ttk::scale $w.high-s -from $options(-min-high) -to $options(-max-high) -command [mymethod Set -high] -variable [myvar options(-high)]
	$self Set -high $options(-high)
	grid $w.high-l $w.high-s -sticky ew

	ttk::label $w.length-l -textvar [myvar data(label-length)] -width 10 -anchor e
	ttk::scale $w.length-s -from $options(-min-length) -to $options(-max-length) -command [mymethod Set -length] -variable [myvar options(-length)]
	$self Set -length $options(-length)
	grid $w.length-l $w.length-s -sticky ew

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }
    method is-needed {} { return 1 }
    method is-busy {} { return [::sdrkitx::$options(-name) is-busy] }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} {
	switch -- $opt {
	    -length { return [expr {int(round($val))}] }
	    -low { return [expr {min($options(-high)-11,$val)}] }
	    -high { return [expr {max($options(-low)+11,$val)}] }
	}
	return $val
    }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {
	lappend data(deferred-config) $opt $val
	if { ! [$self is-busy]} {
	    ::sdrkitx::$options(-name) configure {*}$data(deferred-config)
	    set data(deferred-config) {}
	}
    }
    method LabelConfigure {opt val} { set data(label$opt) [format $data(format$opt) $val] }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
    }
    method Changed {opt} { $self Set $opt $options($opt) }
}
