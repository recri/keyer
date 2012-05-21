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

package provide sdrkit::keyer-debounce 1.0.0

package require snit
package require sdrtcl::keyer-debounce

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-debounce {    
    option -name key-debounce
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {midi_in}
    option -out-ports {midi_out}
    option -in-options {-chan -note -period -steps}
    option -out-options {}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -period -default 0.2 -configuremethod Configure
    option -steps -default 6 -configuremethod Configure

    variable data -array {
	label-chan {} format-chan {Channel}
	label-note {} format-note {Note}
	label-period {} format-period {Period %.1f ms}
	label-steps {} format-steps {Steps %d}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }

    method build-parts {} {
	sdrtcl::keyer-debounce ::sdrkitx::$options(-name) -server $options(-server) -period $options(-period) -steps $options(-steps) \
	    -chan $options(-chan) -note $options(-note)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach {opt type format min max} {
	    chan spinbox {Midi Channel} 1 16
	    note spinbox {Midi Note} 0 127
	    period scale  {Period %.1f ms} 0.1 10
	    steps scale {Steps %d} 0 32
	} {
	    switch $type {
		spinbox {
		    set data(format-$opt) $format
		    set data(label-$opt) [format $data(format-$opt) $options(-$opt)]
		    ttk::label $w.l-$opt -textvar [myvar data(label-$opt)] -anchor e
		    ttk::spinbox $w.s-$opt -from $min -to $max -increment 1 -textvar [myvar options(-$opt)] -command [mymethod Changed -$opt]
		}
		scale {
		    set data(format-$opt) $format
		    set data(label-$opt) [format $data(format-$opt) $options(-$opt)]
		    ttk::label $w.l-$opt -textvar [myvar data(label-$opt)] -anchor e
		    ttk::scale $w.s-$opt -from $min -to $max -command [mymethod Set -$opt] -variable [myvar options(-$opt)]
		}
		separator {
		    ttk::separator $w.l-$opt
		    ttk::separator $w.s-$opt
		}
	    }
	    grid $w.l-$opt $w.s-$opt -sticky ew
	}
	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} {
	if {$opt eq {-steps}} { return [expr {int(round($val))}] }
	return $val
    }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} { ::sdrkitx::$options(-name) configure $opt $val }
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
