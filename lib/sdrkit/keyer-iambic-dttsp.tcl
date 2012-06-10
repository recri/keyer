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

package provide sdrkit::keyer-iambic-dttsp 1.0.0

package require snit
package require sdrtcl::keyer-iambic-dttsp
package require sdrkit::common-sdrtcl

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-iambic-dttsp {    
    option -name key-iambic-dttsp
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {midi_in}
    option -out-ports {midi_out}
    option -options {-chan -note -wpm -weight -swap -alsp -awsp -mode -mdit -mdah -mide}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -wpm -default 15 -configuremethod Configure
    option -weight -default 50 -configuremethod Configure
    option -swap -default 0 -configuremethod Configure
    option -alsp -default 0 -configuremethod Configure
    option -awsp -default 0 -configuremethod Configure
    option -mode -default A -configuremethod Configure
    option -mdit -default 0 -configuremethod Configure
    option -mdah -default 0 -configuremethod Configure
    option -mide -default 0 -configuremethod Configure

    option -sub-controls {
	chan spinbox {-format {Midi Channel} -from 1 -to 16}
	note spinbox {-format {Midi Note} -from 0 -to 127}
	wpm scale {-format {%.0f dits/word} -from 5 -to 60}
	weight iscale {-format {Weight %d} -from 20 -to 80}
	swap radio {-format {Paddle} -values {0 1} -labels {Unswapped Swapped}}
	alsp radio {-format {Letter} -values {0 1} -labels {{spacing off} {spacing on}}}
	awsp radio {-format {Word} -values {0 1} -labels {{spacing off} {spacing on}}}
	mode radio {-format {Iambic mode} -values {A B}}
	mdit radio {-format {Dit} -values {0 1} -labels {{memory off} {memory on}}}
	mdah radio {-format {Dah} -values {0 1} -labels {{memory off} {memory on}}}
	mide radio {-format {Mid element} -values {0 1} -labels {{memory off} {memory on}}}
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
    method build-parts {} {
	sdrtcl::keyer-iambic-dttsp ::sdrkitx::$options(-name) -server $options(-server) -chan $options(-chan) -note $options(-note) \
	    -wpm $options(-wpm) -weight $options(-weight) \
	    -swap $options(-swap) -alsp $options(-alsp) -awsp $options(-awsp) -mode $options(-mode) \
	    -mdit $options(-mdit) -mdah $options(-mdah) -mide $options(-mide)
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
}
