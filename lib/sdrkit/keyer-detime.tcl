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

package provide sdrkit::keyer-detime 1.0.0

package require snit
package require sdrtcl::keyer-detime
package require sdrtk::radiomenubutton

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::keyer-detime {    
    option -name key-detime
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {midi_in}
    option -out-ports {}
    option -in-options {-chan -note -word -wpm}
    option -out-options {}

    option -chan -default 1 -configuremethod Configure
    option -note -default 0 -configuremethod Configure
    option -word -default 50 -configuremethod Configure
    option -wpm -default 15 -configuremethod Configure

    variable data -array {
	label-chan {} format-chan {Channel}
	label-note {} format-note {Note}
	label-word {} format-word {%d dits/word}
	label-wpm {} format-wpm {%.1f words/min}
    }
    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::keyer-detime ::sdrkitx::$options(-name) -server $options(-server) -word $options(-word) -wpm $options(-wpm) \
	    -chan $options(-chan) -note $options(-note)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach opt {chan note} title {{Midi Channel} {Midi Note}} min {1 0} max {16 127} {
	    ttk::label $w.l-$opt -text $title -anchor e
	    ttk::spinbox $w.s-$opt -width 3 -from $min -to $max -increment 1 -textvar [myvar options(-$opt)] -command [mymethod Changed -$opt]
	    grid $w.l-$opt $w.s-$opt -sticky ew
	}

	ttk::label $w.word-l -textvar [myvar data(label-word)] -width 10 -anchor e
	sdrtk::radiomenubutton $w.word-s -values {50 60} -labels {PARIS CODEX} -command [mymethod Set -word] -variable [myvar options(-word)]
	$self Set -word $options(-word)
	grid $w.word-l $w.word-s -sticky ew

	ttk::label $w.wpm-l -textvar [myvar data(label-wpm)] -width 10 -anchor e
	ttk::scale $w.wpm-s -from 5 -to 60 -command [mymethod Set -wpm] -variable [myvar options(-wpm)]
	$self Set -wpm $options(-wpm)
	grid $w.wpm-l $w.wpm-s -sticky ew

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} { return $val }
    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} { ::sdrkitx::$options(-name) configure $opt $val }
    method LabelConfigure {opt val} { set data(label$opt) [format $data(format$opt) $val] }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
    }
    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
    }
    method Changed {opt} { $self Set $opt $options($opt) }
}
