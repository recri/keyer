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
# a synchronous AM demodulation component
#
# this module could provide a get method to get the synchronized frequency offset
# it could also allow the pll parameters to be set
#
package provide sdrkit::demod-sam 1.0.0

package require snit
package require sdrtcl::demod-sam
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::demod-sam {    
    option -name sdr-demod-sam
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -options {}

    option -sub-controls {
	sep separator {}
    }

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
    method build-parts {w} {
	sdrtcl::demod-sam ::sdrkitx::$options(-name) -server $options(-server)
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    if {[info exists options(-$opt]} {
		$common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    } else {
		$common window $w $opt $type $opts {} {} {}
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
}
