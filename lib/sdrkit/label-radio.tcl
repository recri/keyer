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
# a labelled radio button menu control
#
package provide sdrkit::label-radio 1.0.0

package require Tk
package require Ttk
package require snit
package require sdrtk::radiomenubutton

namespace eval sdrkit {}

snit::widget sdrkit::label-radio {
    component label
    component radio
    
    option -variable -default {} -configuremethod Configure
    option -command {}
    option -format {}
    option -minsizes {100 200}
    option -weights {1 3}

    delegate option * to radio
    delegate method * to radio

    variable data -array { label {} value {} }

    constructor {args} {
	install label using ttk::label $win.l -textvar [myvar data(label)] -anchor e
	install radio using sdrtk::radiomenubutton $win.s -variable [myvar data(value)] -command [mymethod Value]
	$self configure {*}$args
	grid $win.l $win.s -sticky ew
	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $win $col -minsize $ms -weight $wt
	}
	set data(label) [format $options(-format) $data(value)]
    }
    destructor {
	catch {trace remove variable $options(-variable) write [mymethod TraceWrite]}
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
    }
    method TraceWrite {args} { set data(value) [set $options(-variable)] }
    method Value {args} {
	set data(label) [format $options(-format) $data(value)]
	if {$options(-variable) ne {}} {
	    set $options(-variable) $data(value)
	}
	if {$options(-command) ne {}} {
	    {*}$options(-command) $data(value)
	}
    }
}
