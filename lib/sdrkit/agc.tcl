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

package require sdrkit::common-sdrtcl
package require sdrtcl::agc
package require sdrtype::types

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
    option -options {-target -attack -decay -slope -hang -fasthang -max -min -threshold -mode}

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

    option -sub-controls {
	mode radio {-format {AGC mode}}
	target scale {-format {Target %.5f}}
	attack scale {-format {Attack %.1f ms}}
	decay scale {-format {Decay %.1f ms}}
	slope scale {-format {Slope %.2f}}
	hang scale {-format {Hang %.1f ms}}
	fasthang scale {-format {Fasthang %.1f ms}}
	max scale {-format {Max %.0f}}
	min scale {-format {Min %.5f}}
	threshold scale {-format {Threshold %.5f}}
    }

    variable data -array { defcon {} }

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
    method build-parts {} {
	sdrtcl::agc ::sdrkitx::$options(-name) -server $options(-server) -mode $options(-mode)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach {opt type opts} $options(-sub-controls) {
	    switch $opt {
		mode { lappend opts -values [sdrtype::agc-$opt cget -values] }
		default { lappend opts -from [sdrtype::agc-$opt cget -min] -to [sdrtype::agc-$opt cget -max] }
	    }
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    ## these are specific to this component
    method is-needed {} { return [expr {$options(-mode) ne {off}}] }
    method Configure {opt val} {
	if {$opt eq {-mode} && $val ni {off custom}} {
	    # fetch the itemized values that go with a mode setting
	    foreach opt [::sdrkitx::$options(-name) configure] {
		lassign $opt opt name class default val
		if {$opt ne {-mode} && $opt in $options(-options)} {
		    $self Set $opt $val
		}
	    }
	}
	$self Defcon $opt [set options($opt) [$self Constrain $opt $val]]
    }
}
