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

package provide sdrkit::keyer-detone 1.0.0

package require snit
package require sdrtcl::keyer-detone
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-detone {    
    option -name key-detone
    option -type jack
    option -server default
    option -component {}

    option -in-ports {in_i}
    option -out-ports {midi_out}
    option -options {-chan -note -freq -bandwidth}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -freq -default 600 -configuremethod Configure
    option -bandwidth -default 50 -configuremethod Configure

    option -sub-controls {
	chan spinbox { -format {Midi Channel} -from 1 -to 16}
	note spinbox { -format {Midi Note} -from 0 -to 127}
	freq scale { -format {Freq %.1f Hz} -from  200 -to 1000}
	bandwidth scale { -format {BW %.1f Hz} -from 5 -to 100}
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
	sdrtcl::keyer-detone ::sdrkitx::$options(-name) -server $options(-server) -freq $options(-freq) -bandwidth $options(-bandwidth) \
	    -chan $options(-chan) -note $options(-note)
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
}
