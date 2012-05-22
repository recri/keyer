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
# a agc component
#
package provide sdrkit::agc 1.0.0

package require snit
package require sdrtcl::agc
package require sdrtype::types
package require sdrtk::radiomenubutton

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::agc {    
    option -name sdr-agc
    option -type jack
    option -server default
    option -component {} 

    option -window none
    option -title agc
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-target -attack -decay -slope -hang -fasthang -max -min -threshold -mode}
    option -out-options {-target -attack -decay -slope -hang -fasthang -max -min -threshold -mode}

    option -target -default 1 -type sdrtype::agc-target -configuremethod Configure
    option -attack -default 2 -type sdrtype::agc-attack -configuremethod Configure
    option -decay -default 250 -type sdrtype::agc-decay -configuremethod Configure
    option -slope -default 1 -type sdrtype::agc-slope -configuremethod Configure
    option -hang -default 250  -type sdrtype::agc-hang -configuremethod Configure
    option -fasthang -default 100 -type sdrtype::agc-fasthang -configuremethod Configure
    option -max -default 1e+4 -type sdrtype::agc-max -configuremethod Configure
    option -min -default 1e-4 -type sdrtype::agc-min -configuremethod Configure
    option -threshold -default 1 -type sdrtype::agc-threshold -configuremethod Configure
    option -mode -default medium -type sdrtype::agc-mode -configuremethod Configure

    # provide labels, formats for labels, and mapping to dsp option name
    variable data -array {
	label-target {} format-target {Target %.5f} map-target -target
	label-attack {} format-attack {Attack %.1f ms} map-attack -attack
	label-decay {} format-decay {Decay %.1f ms} map-decay -decay
	label-slope {} format-slope {Slope %.2f} map-slope -slope
	label-hang {} format-hang {Hang %.1f ms} map-hang -hang
	label-fasthang {} format-fasthang {Fasthang %.1f ms} map-fasthang -fasthang
	label-max {} format-max {Max %.0f} map-max -max
	label-min {} format-min {Min %.5f} map-min -min
	label-threshold {} format-threshold {Threshold %.5f} map-threshold -threshold
	label-mode {} format-mode {} map-mode -mode
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::agc ::sdrkitx::$options(-name) -server $options(-server) -mode $options(-mode)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	ttk::label $w.mode-l -text {agc mode}
	sdrtk::radiomenubutton $w.mode-s -defaultvalue $options(-mode) -values [sdrtype::agc-mode cget -values] -variable [myvar options(-mode)] -command [mymethod Set -mode]
	grid $w.mode-l $w.mode-s

	foreach opt {target threshold min max slope attack decay hang fasthang} {
	    ttk::label $w.$opt-l -textvar [myvar data(label-$opt)] -width 10 -anchor e
	    ttk::scale $w.$opt-s -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max] \
		-command [mymethod Set -$opt] -variable [myvar options(-$opt)]
	    $self Set -$opt $options(-$opt)
	    grid $w.$opt-l $w.$opt-s -sticky ew
	}

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }
    method is-needed {} { return [expr {$options(-mode) ne {off}}] }
    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} {
	while {[::sdrkitx::$options(-name) is-busy]} { after 1 }
	::sdrkitx::$options(-name) configure $data(map$opt) $val
    }
    method LabelConfigure {opt val} { set data(label$opt) [format $data(format$opt) $val] }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
    }
    method Set {opt val} {
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
	if {$opt eq {-mode} && $val ni {off custom}} {
	    foreach opt [::sdrkitx::$options(-name) configure] {
		lassign $opt opt name class default val
		if {$opt ne {-mode} && $opt in $options(-in-options)} {
		    $self Update $opt $val
		}
	    }
	}
    }
    method Update {opt val} {
	$self OptionConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
