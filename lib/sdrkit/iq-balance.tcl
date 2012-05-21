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
# an iq-balance component
#

package provide sdrkit::iq-balance 1.0.0

package require snit
package require sdrtcl::iq-balance

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::iq-balance {    
    option -name sdr-iq-balance
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -title {IQ Balance}
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-phase -gain}
    option -out-options {}

    option -phase -default 0 -configuremethod Configure
    option -gain -default 0 -configuremethod Configure

    variable data -array {
	label-gain {} format-gain {%.1f dBFS}
	label-phase {} format-phase {%.1f Deg}
    }

    constructor {args} {
	$self configure {*}$args
	set data(pi) [tcl::mathfunc::atan2 0 -1]
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::iq-balance ::sdrkitx::$options(-name) -server $options(-server)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }

	ttk::label $w.gain-l -textvar [myvar data(label-gain)] -width 10 -anchor e
	ttk::scale $w.gain-s -from -6 -to 6 -command [mymethod Set -gain] -variable [myvar options(-gain)]
	$self Set -gain $options(-gain)
	grid $w.gain-l $w.gain-s -sticky ew

	ttk::label $w.phase-l -textvar [myvar data(label-phase)] -width 10 -anchor e
	ttk::scale $w.phase-s -from -90 -to 90 -command [mymethod Set -phase] -variable [myvar options(-phase)]
	$self Set -phase $options(-phase)
	grid $w.phase-l $w.phase-s -sticky ew

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }
    method is-needed {} { return [expr {$options(-phase) != 0 || $options(-gain) != 0}] }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} { return $val }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {
	switch -- $opt {
	    -gain { ::sdrkitx::$options(-name) configure -linear-gain [expr {10.0**($val/20)}] }
	    -phase { ::sdrkitx::$options(-name) configure -sine-phase [expr {sin(2*$data(pi)*$val/360.0)}] }
	    default { ::sdrkitx::$options(-name) configure $opt $val }
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
