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

package provide sdrkit::oscillator 1.0.0

package require snit
package require sdrtcl::oscillator
package require sdrkit::common-sdrtcl
package require sdrtcl::jack

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::oscillator {    

    option -name sdr-osc
    option -type jack
    option -server default
    option -component {}

    option -sample-rate 48000 

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {out_i out_q}
    option -options {-freq -gain}

    option -freq -default 600.0 -configuremethod Configure
    option -gain -default -30.0 -configuremethod Configure

    option -sub-controls {
	freq scale {-format {Freq %.1f Hz} -from -12000 -to 12000}
	gain scale {-format {Gain %.1f dBFS} -from -200 -to 200}
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	$self configure -sample-rate [sdrtcl::jack -server $options(-server) sample-rate]
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }

    method port-complement {port} { return {} }
    method build-parts {} {
	sdrtcl::oscillator ::sdrkitx::$options(-name) -server $options(-server) -freq $options(-freq) -gain $options(-gain)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach {opt type opts} $options(-sub-controls) {
	    if {$opt eq {freq}} { lappend opts -from [expr {-$options(-sample-rate)/2.0}] -to [expr {$options(-sample-rate)/2.0}] }
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
}
