# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
# a value readout consisting of a labelled frame,
# a value chosen from {0 1}
# and no unit string
#

package provide sdrtk::readout-bool 1.0

package require Tk
package require snit

snit::widget sdrtk::readout-bool {
    hulltype ttk::labelframe
    component lvalue

    option -value -default 0 -configuremethod Configure
    option -font -default {Helvetica 20} -configuremethod Configure
    option -variable -default {} -configuremethod Configure
    option -info -default {} -configuremethod Configure
    option -command {}
    option -menu-value {}

    delegate option -text to hull

    variable value 0
    variable pointer 0

    constructor {args} {
	install lvalue using ttk::label $win.value -textvar [myvar value] -width 15 -font $options(-font) -anchor e
	grid $win.value
	$self configure {*}$args
	trace add variable [myvar options(-value)] write [mymethod TraceSelfWrite]
	trace add variable [myvar options(-menu-value)] write [mymethod TraceMenuWrite]
    }
    
    # should go from 11 to 1 o'clock and back again
    method adjust {step} {
	set pointer [expr {fmod($pointer+$step*1+2, 2)}]
	$self configure -value [lindex {0 1} [expr {int($pointer)}]]
    }

    method menu-entry {m text} {
	return [list checkbutton -label $text -variable [myvar options(-menu-value)]]
    }
    method button-entry {m text} {
	return [ttk::checkbutton $m -text $text -variable [myvar options(-menu-value)]]
    }

    method Display {} {
	set value $options(-value)
    }

    method Redisplay {opt val} {
	set options($opt) $val
	$self Display
    }

    method {Configure -value} {val} {
	if {$val in {0 1} && $options(-value) ne $val} {
	    set options(-value) $val
 	    #if {$options(-variable) ne {} && [set $options(-variable)] ne $val} {
		set $options(-variable) $val
	    #}
	    if {$options(-menu-value) eq {} || $options(-menu-value) ne $val} {
		set options(-menu-value) $val
	    }
	    if {$options(-command) ne {}} { {*}$options(-command) $val }
	    $self Display
	}
    }

    method {Configure -font} {val} {
	set options(-font) $val
	$lvalue configure -font $val
    }

    method {Configure -variable} {val} {
	if {$options(-variable) ne {}} {
	    trace remove variable $options(-variable) write [mymethod TraceWrite]
	}
	set options(-variable) $val
	if {$options(-variable) ne {}} {
	    trace add variable $options(-variable) write [mymethod TraceWrite]
	    # $self TraceWrite
	}
    }
    method {Configure -info} {val} {
	set options(-info) $val
    }
    method TraceWrite {args} { 
	if {[catch { $self configure -value [set $options(-variable)] } error]} {
	    puts "TraceWrite {$args} caught $error"
	} else {
	    # puts "TraceWrite {$args}"
	}
    }
    method TraceSelfWrite {args} {
	return
	if {[catch { $self configure -value [set $options(-variable)] } error]} {
	    puts "TraceWrite {$args} caught $error"
	} else {
	    puts "TraceWrite {$args}"
	}
    }
    method TraceMenuWrite {args} { 
	if {$options(-menu-value) ne $options(-value)} {
	    if {[catch { $self configure -value $options(-menu-value) }  error]} {
		puts "TraceMenuWrite {$args} caught $error"
	    } else {
		# puts "TraceMenuWrite {$args}"
	    }
	}
    }
}
