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
    option -type dsp
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
	
	foreach {opt type format min max} {
	    chan spinbox {Midi Channel} 1 16
	    note spinbox {Midi Note} 0 127
	    wpm scale {%d dits/word} 5 60
	    dah scale {Dah %.2f Dits} 2.5 3.5
	    ies scale {Space %.2f Dits} 0.75 1.25
	    ils scale {Letter %.2f Dits} 2.5 3.5
	    iws scale {Word %.2f Dits} 6 8
	} {
	    switch $type {
		spinbox {
		    set data(format-$opt) $format
		    set data(label-$opt) [format $data(format-$opt) $options(-$opt)]
		    ttk::label $w.l-$opt -textvar [myvar data(label-$opt)] -anchor e
		    ttk::spinbox $w.s-$opt -from $min -to $max -increment 1 -textvar [myvar options(-$opt)] -command [mymethod Changed -$opt]
		}
		scale {
		    set data(format-$opt) $format
		    set data(label-$opt) [format $data(format-$opt) $options(-$opt)]
		    ttk::label $w.l-$opt -textvar [myvar data(label-$opt)] -anchor e
		    ttk::scale $w.s-$opt -from $min -to $max -command [mymethod Set -$opt] -variable [myvar options(-$opt)]
		}
		separator {
		    ttk::separator $w.l-$opt
		    ttk::separator $w.s-$opt
		}
	    }
	    grid $w.l-$opt $w.s-$opt -sticky ew
	}

	foreach {opt vals lbls} {
	    word {50 60} {PARIS CODEX}
	    swap {0 1} {Unswapped Swapped}
	    alsp {0 1} {{Auto letter space off} {Auto letter space on}}
	    awsp {0 1} {{Auto word space off} {Auto word space on}}
	    mode {A B} {{Iambic Mode A} {Iambic Mode B}}} {
	    set data(format-$opt) {}
	    ttk::label $w.l-$opt -textvar [myvar data(label-$opt)] -width 10 -anchor e
	    sdrtk::radiomenubutton $w.s-$opt -values $vals -labels $lbls -command [mymethod Set -$opt] -variable [myvar options(-$opt)]
	    $self Set -$opt $options(-$opt)
	    grid $w.l-$opt $w.s-$opt -sticky ew
	}

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
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
