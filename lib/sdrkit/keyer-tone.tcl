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

package provide sdrkit::keyer-tone 1.0.0

package require snit
package require sdrtcl::keyer-tone
package require sdrkit::common-sdrtcl
package require sdrtcl::jack

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-tone {    
    option -name key-tone
    option -type jack
    option -server default
    option -component {}

    option -sample-rate 48000 

    option -in-ports {midi_in}
    option -out-ports {out_i out_q}
    option -options {-chan -note -freq -gain -rise -fall}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -freq -default 600.0 -configuremethod Configure
    option -min-freq -default -23500 -configuremethod Configure
    option -max-freq -default  23500 -configuremethod Configure
    option -gain -default -30.0 -configuremethod Configure
    option -min-gain -default -160.0 -configuremethod Configure
    option -max-gain -default  160.0 -configuremethod Configure
    option -rise -default 5 -configuremethod Configure
    option -fall -default 5 -configuremethod Configure

    option -sub-controls {
	chan spinbox { -format {Midi Channel} -from 1 -to 16}
	note spinbox { -format {Midi Note} -from 0 -to 127}
	gain scale {-format {Gain %.1f dBFS} -from -200 -to 200}
	freq scale {-format {Freq %.1f Hz} -from -12000 -to 12000}
	rise scale {-format {Rise %.1f ms} -from 0.5 -to 50.0}
	fall scale {-format {Fall %.1f ms} -from 0.5 -to 50.0}
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
    method build-parts {w} {
	sdrtcl::keyer-tone ::sdrkitx::$options(-name) -server $options(-server) -freq $options(-freq) -gain $options(-gain) \
	    -chan $options(-chan) -note $options(-note) -rise $options(-rise) -fall $options(-fall)
    }
    method build-ui {w pw minsizes weights} {
	if {$w eq {none}} return
	foreach {opt type opts} $options(-sub-controls) {
	    if {$opt eq {freq}} { lappend opts -from [expr {-$options(-sample-rate)/2.0}] -to [expr {$options(-sample-rate)/2.0}] }
	    $common window $w $opt $type $opts [myvar options(-$opt)] [mymethod Set -$opt] $options(-$opt)
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
    }
}
