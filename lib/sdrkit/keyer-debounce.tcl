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

package provide sdrkit::keyer-debounce 1.0.0

package require snit
package require sdrtcl::keyer-debounce
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-debounce {    
    option -name key-debounce
    option -type jack
    option -server default
    option -component {}

    option -in-ports {midi_in}
    option -out-ports {midi_out}
    option -options {-chan -note -period -steps}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -period -default 0.2 -configuremethod Configure
    option -steps -default 6 -configuremethod Configure

    option -sub-controls {
	chan spinbox { -format {Midi Channel} -from 1 -to 16}
	note spinbox { -format {Midi Note} -from 0 -to 127}
	period scale { -format {Period %.1f ms} -from  0.1 -to 10}
	steps iscale  { -format {Steps %d} -from 0 -to 32}
    }
    variable data -array {}

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
	sdrtcl::keyer-debounce ::sdrkitx::$options(-name) -server $options(-server) -period $options(-period) -steps $options(-steps) \
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
