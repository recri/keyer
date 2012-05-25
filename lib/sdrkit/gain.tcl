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
# a gain component
#
package provide sdrkit::gain 1.0.0

package require snit
package require sdrtcl::gain

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::gain {    
    option -name sdr-gain
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -title Gain
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-gain}
    option -out-options {-gain}

    option -gain -default 0 -configuremethod Configure

    option -sub-controls {
	gain scale {-format {Gain %.1f dBFS} -from -200 -to 200}
    }
	
    variable data -array {
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::gain ::sdrkitx::$options(-name) -server $options(-server) -gain $options(-gain)
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
		    #lappend opts -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max]
		    sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		separator {
		    ttk::separator $w.$opt
		}
		radio {
		    package require sdrkit::label-radio
		    #lappend opts -defaultvalue $options(-$opt) -values [sdrtype::agc-$opt cget -values]
		    sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		}
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method is-needed {} { return [expr {$options(-gain) != 0}] }
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
