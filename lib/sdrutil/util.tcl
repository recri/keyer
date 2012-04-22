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

package provide sdrutil::util 1.0

namespace eval sdrutil {}

##
## map a function over a list
##
proc sdrutil::map {command items} { set map {}; foreach i $items { lappend map [{*}$command $i] }; return $map }

##
## convert variously formatted frequencies to Hertz
##
proc sdrutil::hertz {string} {
    # match a number followed by an optional frequency unit
    # allow any case spellings of frequency units
    # allow spaces before, after, or between
    if {[regexp -nocase {^\s*(\d+|\d+\.\d+|\.\d+|\d+\.)([eE][-+]\d+)?\s*([kMG]?Hz)?\s*$} $string all number exponent unit]} {
	set f $number$exponent
	switch -nocase $unit {
	    {} - Hz  { return [expr {$f*1.0}] }
	    kHz { return [expr {$f*1000.0}] }
	    MHz { return [expr {$f*1000.0*1000.0}] }
	    GHz { return [expr {$f*1000.0*1000.0*1000.0}] }
	}
    }
    error "badly formatted frequency: $string"
}

