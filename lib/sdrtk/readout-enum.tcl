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
# a value readout consisting of a labelled frame,
# a value chosen from a list,
# and a unit string displayed in an adjacent label
#

package provide sdrtk::readout-enum 1.0

package require Tk
package require snit

snit::widget sdrtk::readout-enum {
    hulltype ttk::labelframe
    component lvalue
    component lunits

    option -value -default 0 -configuremethod Configure
    option -values -default {0 1 2 3} -configuremethod Configure
    option -step -default 0.1
    option -font -default {Helvetica 20} -configuremethod Configure
    option -variable -default {} -configuremethod Configure
    option -info -default {} -configuremethod Configure
    option -units -default {} -configuremethod Configure
    option -command {}
    option -menu-value {}

    delegate option -text to hull

    variable value 0
    variable pointer 0

    constructor {args} {
	install lvalue using ttk::label $win.value -textvar [myvar value] -width 15 -font $options(-font) -anchor e
	install lunits using ttk::label $win.units -textvar [myvar options(-units)] -width 5 -font $options(-font) -anchor w
	grid $win.value $win.units
	$self configure {*}$args
	trace add variable [myvar options(-value)] write [mymethod TraceSelfWrite]
	trace add variable [myvar options(-menu-value)] write [mymethod TraceMenuWrite]
    }
    
    method adjust {step} {
	set n [llength $options(-values)]
	set pointer [expr {fmod($pointer+$step*$options(-step)+$n, $n)}]
	$self configure -value [lindex $options(-values) [expr {int($pointer)}]]
    }

    method menu-entry {m text} {
	if {[llength $options(-values)] == 2 && [lsearch $options(-values) {0}] >= 0  && [lsearch $options(-values) {1}] >= 0} {
	    # simple checkbutton
	    return [list checkbutton -label $text -variable [myvar options(-menu-value)]]
	} else {
	    # cascade to radiobuttons
	    if { ! [winfo exists $m]} {
		menu $m -tearoff no -font {Helvetica 12 bold}
	    } else {
		$m delete 0 end
	    }
	    foreach v $options(-values) {
		$m add radiobutton -label $v -value $v -variable [myvar options(-menu-value)]
	    }
	    return [list cascade -label $text -menu $m]
	}
    }
    method button-entry {m text} {
	if {[llength $options(-values)] == 2 && {0} in $options(-values) && {1} in $options(-values)} {
	    # simple checkbutton
	    return [ttk::checkbutton $m -text $text -variable [myvar options(-menu-value)]]
	} else {
	    # cascade to radiobuttons
	    ttk::menubutton $m -text $text
	    if { ! [winfo exists $m.m]} {
		menu $m.m -tearoff no -font {Helvetica 12 bold}
	    } else {
		$m.m delete 0 end
	    }
	    $m configure -menu $m.m
	    set i 0
	    foreach v $options(-values) {
		$m.m add radiobutton -label $v -value $v -variable [myvar options(-menu-value)] -columnbreak [expr {([incr i]%10)==0}]
	    }
	    return $m
	}
    }

    method Display {} {
	set value $options(-value)
    }

    method Redisplay {opt val} {
	set options($opt) $val
	$self Display
    }

    method {Configure -values} {val} {
	set options(-values) $val
    }

    method {Configure -value} {val} {
	if {$options(-value) ne $val} {
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

    method {Configure -step} {val} {
	set options(-step) $val
	$self configure -value [expr {int($options(-value)/$val)*$val}]
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
    method {Configure -units} {val} {
	set options(-units) $val
    }
    method TraceWrite {args} { 
	return
	if {[catch { $self configure -value [set $options(-variable)] } error]} {
	    puts "TraceWrite {$args} caught $error"
	} else {
	    puts "TraceWrite {$args}"
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
