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

package provide sdrkit::keyer-iambic-nd7pa 1.0.0

package require snit
package require sdrtcl::keyer-iambic-nd7pa
package require sdrtk::radiomenubutton

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-iambic-nd7pa {    
    option -name key-iambic-nd7pa
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {midi_in}
    option -out-ports {midi_out}
    option -in-options {-chan -note -wpm -dah -ies -swap}
    option -out-options {-chan -note -wpm -dah -ies -swap}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -wpm -default 15 -configuremethod Configure
    option -dah -default 3 -configuremethod Configure
    option -ies -default 1 -configuremethod Configure
    option -swap -default 0 -configuremethod Configure

    option -sub-controls {
	chan spinbox {-format {Midi Channel} -from 1 -to 16}
	note spinbox {-format {Midi Note} -from 0 -to 127}
	wpm scale {-format {%.0f wpm} -from 5 -to 60}
	dah scale {-format {Dah %.2f} -from 2.5 -to 3.5}
	ies scale {-format {Space %.2f} -from 0.75 -to 1.25}
	swap radio {-format {Paddles} -values {0 1} -labels {Unswapped Swapped}}
    }
    variable data -array {}

    constructor {args} { $self configure {*}$args }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::keyer-iambic-nd7pa ::sdrkitx::$options(-name) -server $options(-server) -chan $options(-chan) -note $options(-note) \
	    -wpm $options(-wpm) -dah $options(-dah) -ies $options(-ies) \
	    -swap $options(-swap)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach {opt type opts} $options(-sub-controls) {
	    switch $type {
		spinbox {
		    package require sdrkit::label-spinbox
		    sdrkit::label-spinbox $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		scale {
		    package require sdrkit::label-scale
		    sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		separator {
		    ttk::separator $w.$opt
		}
		radio {
		    package require sdrkit::label-radio
		    sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		}
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method is-busy {} { return [::sdrkitx::$options(-name) is-busy] }
    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }
    method OptionConstrain {opt val} { return $val }
    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {
	lappend data(deferred-config) $opt $val
	if { ! [$self is-busy]} {
	    ::sdrkitx::$options(-name) configure {*}$data(deferred-config)
	    set data(deferred-config) {}
	}
    }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }
    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
    }
    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
