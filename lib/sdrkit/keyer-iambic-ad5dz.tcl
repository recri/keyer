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

package provide sdrkit::keyer-iambic-ad5dz 1.0.0

package require snit
package require sdrtcl::keyer-iambic-ad5dz
package require sdrtk::radiomenubutton

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-iambic-ad5dz {    
    option -name key-iambic-ad5dz
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {midi_in}
    option -out-ports {midi_out}
    option -in-options {-chan -note -word -wpm -dah -ies -ils -iws -swap -alsp -awsp -mode}
    option -out-options {-chan -note -word -wpm -dah -ies -ils -iws -swap -alsp -awsp -mode}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -word -default 50 -configuremethod Configure
    option -wpm -default 15 -configuremethod Configure
    option -dah -default 3 -configuremethod Configure
    option -ies -default 1 -configuremethod Configure
    option -ils -default 3 -configuremethod Configure
    option -iws -default 7 -configuremethod Configure
    option -swap -default 0 -configuremethod Configure
    option -alsp -default 0 -configuremethod Configure
    option -awsp -default 0 -configuremethod Configure
    option -mode -default A -configuremethod Configure

    option -sub-controls {
	chan spinbox {-format {Midi Channel} -from 1 -to 16}
	note spinbox {-format {Midi Note} -from 0 -to 127}
	wpm scale {-format {%.0f wpm} -from 5 -to 60}
	dah scale {-format {Dah %.2f} -from 2.5 -to 3.5}
	ies scale {-format {Space %.2f} -from 0.75 -to 1.25}
	ils scale {-format {Letter %.2f} -from 2.5 -to 3.5}
	iws scale {-format {Word %.2f} -from 6 -to 8}
	word radio {-format {%d dits/word} -values {50 60} -labels {PARIS CODEX}}
	swap radio {-format {Paddles} -values {0 1} -labels {Unswapped Swapped}}
	alsp radio {-format {Letter space} -values {0 1} -labels {{Auto off} {Auto on}}}
	awsp radio {-format {Word space} -values {0 1} -labels {{Auto off} {Auto on}}}
	mode radio {-format {Iambic mode} -values {A B} -labels {A B}}
    }

    variable data -array {
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }

    method build-parts {} {
	sdrtcl::keyer-iambic-ad5dz ::sdrkitx::$options(-name) -server $options(-server) -chan $options(-chan) -note $options(-note) \
	    -word $options(-word) -wpm $options(-wpm) -dah $options(-dah) -ies $options(-ies) -ils $options(-ils) -iws $options(-iws) \
	    -swap $options(-swap) -alsp $options(-alsp) -awsp $options(-awsp) -mode $options(-mode)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach {opt type opts} $options(-sub-controls) {
	    switch $type {
		spinbox {
		    package require sdrkit::label-spinbox
		    sdrkit::label-spinbox $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		scale {
		    package require sdrkit::label-scale
		    sdrkit::label-scale $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt]
		}
		separator {
		    ttk::separator $w.$opt
		}
		radio {
		    package require sdrkit::label-radio
		    sdrkit::label-radio $w.$opt {*}$opts -variable [myvar options(-$opt)] -command [mymethod Set -$opt] -defaultvalue $options(-$opt)
		}
	    }
	    grid $w.$opt -sticky ew
	}
	grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
    }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} {
	if {$opt eq {-steps}} { return [expr {int(round($val))}] }
	return $val
    }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} { ::sdrkitx::$options(-name) configure $opt $val }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self ControlConfigure $opt $val
    }
}
