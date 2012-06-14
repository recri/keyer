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
# a meter
#
package provide sdrkit::meter 1.0.0

package require Tk
package require snit
package require sdrkit::common-sdrtcl
package require sdrtcl::meter-tap
package require sdrtk::meter

namespace eval sdrkit {}

snit::type sdrkit::meter {

    option -name meter
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {}
    option -options {
	-tap -mode -period
    }

    option -mode -default S -configuremethod Configure
    option -tap -default af-mt1 -configuremethod Configure
    option -period -default 50 -type sdrtype::milliseconds -configuremethod Opt-handler

    option -sub-controls {}
	
    variable data -array {
	after {}
	tap-deferred-opts {}
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
    }
    destructor {
	catch {after cancel $data(after)}
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method port-complement {port} { return {} }
    method build-parts {w} {}
    method build-ui {w pw minsizes weights} {
	if {$w ne {none}} {
	    set meter $w.meter
	    set data(display) $meter
	    sdrtk::meter $meter
	    grid $meter -row 0 -column 0 -sticky ew
	    grid columnconfigure $pw 0 -weight 1 -minsize [tcl::mathop::+ {*}$minsizes]
	    sdrtcl::meter-tap ::sdrkitx::$options(-name)
	    set data(after) [after $options(-period) [mymethod Update]]
	    # build a popup menu on the meter window: tap menu, mode menu
	}
    }
    method connect-tap {tap} {
	set taps [$options(-component) part-filter *$tap]
	if {[llength $taps] == 1} {
	    set name1 [lindex $taps 0]
	    set name2 $options(-name)
	    foreach p1 [$options(-component) out-ports $name1] p2 [$options(-component) in-ports $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	} else {
	    error "multiple taps match $tap: $taps"
	}
    }
    method disconnect-tap {tap} {
	set taps [$options(-component) part-filter *$tap]
	if {[llength $taps] == 1} {
	    set name1 [lindex $taps 0]
	    set name2 $options(-name)
	    foreach p1 [$options(-component) out-ports $name1] p2 [$options(-component) in-ports $name2] {
		$options(-component) disconnect-ports $name1 $p1 $name2 $p2
	    }
	} else {
	    error "multiple taps match $tap: $taps"
	}
    }
    method resolve {} {
	$self connect-tap $options(-tap)
    }
    method Constrain {opt val} { return $val }
    method Configure {opt val} {
	set old $options($opt)
	set options($opt) [$self Constrain $opt $val]
	switch -- $opt {
	    -tap {
		# reconnect the meter to a different tap point
		if {$old ne $options(-tap)} {
		    $self connect-tap $options(-tap)
		    $self disconnect-tap $old
		}
	    }
	    -mode {
		# mode changes the meter markings
		# mode changes the tap computation
		# mode may switch to agc based meter which doesn't use the tap
		lappend data(tap-deferred-opts) $opt $val
	    }
	    -period {
	    }
	    default { error "unanticipated option \"$opt\"" }
	}
    }
    method Set {opt val} { $options(-component) report $opt [$self Constrain $opt $val] }
    method BlankUpdate {} {
	if { ! [winfo exists $data(display)]} {
	    unset data(after)
	} else {
	    $data(display) update -160
	    # start the next
	    set data(after) [after $options(-period) [mymethod Update]]
	}
    }
    method Update {} {
	if {[$self is-busy]} {
	    # if busy, then supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# handle configuration
	if {$data(tap-deferred-opts) ne {}} {
	    set config $data(tap-deferred-opts)
	    set data(tap-deferred-opts) {}
	    #puts "Update configure $config"
	    ::sdrkitx::$options(-name) configure {*}$config
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if not active
	if { ! [$self is-active]} {
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# capture meter value
	lassign [::sdrkitx::$options(-name) get] frame nframes max level decayed
	# puts "get -> $frame $level [expr {10*log10($level)}]"
	# pass to meter display
	if { ! [winfo exists $data(display)]} {
	    unset data(after)
	} else {
	    $data(display) update [expr {10*log10($level)}]
	    # start the next
	    set data(after) [after $options(-period) [mymethod Update]]
	}
    }
}
