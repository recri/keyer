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
package require sdrkit::common-sdrtcl

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
    option -options {-phase -gain}

    option -phase -default 0 -configuremethod Configure
    option -gain -default 0 -configuremethod Configure

    option -sub-controls {
	phase scale {-format {Phase %.1f Deg} -from -90 -to 90}
	gain scale {-format {Gain %.1f dBFS} -from -6 -to 6}
    }

    variable data -array {
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	set data(pi) [tcl::mathfunc::atan2 0 -1]
	install common using sdrkit::common-sdrtcl %AUTO% -name $options(-name) -parent $self -options [myvar options]
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

	foreach {opt type opts} $options(-sub-controls) {
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }
    method is-needed {} { return [expr {$options(-phase) != 0 || $options(-gain) != 0}] }
    method Configure {opt val} {
	set options($opt) [$self Constrain $opt $val]
	switch -- $opt {
	    -gain { $self Defcon -linear-gain [expr {10.0**($options($opt)/20)}] }
	    -phase { $self Defcon -sine-phase [expr {sin(2*$data(pi)*$options($opt)/360.0)}] }
	    default { $self Defcon $opt $options($opt) }
	}
    }
}
