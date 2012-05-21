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
# an iq-delay component
#

package provide sdrkit::iq-delay 1.0.0

package require snit
package require sdrtcl::iq-delay
package require snit

namespace eval sdrkit {}

snit::type sdrkit::iq-delay {    
    option -name sdr-iq-delay
    option -type dsp
    option -server default
    option -component {}

    option -sample-rate -default 0 -readonly true
    option -window none
    option -title {IQ Delay}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-delay}
    option -out-options {}

    option -delay -default 0 -configuremethod Configure

    variable data -array {
	label-delay {} format-delay {}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::iq-delay ::sdrkitx::$options(-name) -server $options(-server)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }

	ttk::frame $w.delay
	ttk::radiobutton $w.delay.minus -text "Delay Q" -value -1 -variable [myvar options(-delay)] -command [mymethod Set -delay -1]
	ttk::radiobutton $w.delay.zero -text "No Delay" -value 0 -variable [myvar options(-delay)] -command [mymethod Set -delay 0]
	ttk::radiobutton $w.delay.plus -text "Delay I" -value 1 -variable [myvar options(-delay)] -command [mymethod Set -delay 1]
	grid $w.delay.minus $w.delay.zero $w.delay.plus -sticky ew
	grid $w.delay -sticky ew 

	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)]
    }
    method is-needed {} { return [expr {$options(-delay) != 0}] }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} { return $val }

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
