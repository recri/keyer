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
# a labelled label control
#
package provide sdrkit::label-label 1.0.0

package require Tk
package require Ttk
package require snit

namespace eval sdrkit {}

snit::widget sdrkit::label-label {
    component label1
    component label2
    
    option -format {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -format -default {} -configuremethod Configure
    option -variable -default {} -configuremethod Configure

    delegate option -label to label1 as -text
    delegate option * to label2
    delegate method * to label2

    variable data -array { value 0 }

    constructor {args} {
	install label1 using ttk::label $win.l -anchor e
	install label2 using ttk::label $win.s -textvar [myvar data(value)]
	$self configure {*}$args
	grid $win.l $win.s -sticky ew
	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $win $col -minsize $ms -weight $wt
	}
    }
    method {Configure -format} {val} {
	set options(-format) $val
	if {$options(-variable) ne {}} {
	    $self set-value [set $options(-variable)]
	}
    }
    method {Configure -variable} {val} {
	if {$options(-variable) ne {}} {
	    trace remove variable $options(-variable) write [mymethod TraceWrite]
	}
	set options(-variable) $val
	if {$options(-variable) ne {}} {
	    trace add variable $options(-variable) write [mymethod TraceWrite]
	    $self TraceWrite
	}
	$self set-value [set $options(-variable)]
    }
    method TraceWrite {args} { catch { $self set-value [set $options(-variable)] } }
    method set-value {val} {
	if {$options(-format) ne {}} {
	    set data(value) [format $options(-format) $val]
	} else {
	    set data(value) $val
	}
    }
}
