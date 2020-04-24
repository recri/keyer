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
# routines for using morse code dictionaries
#

package provide morse::morse 1.0.0

namespace eval ::morse {}
namespace eval ::morse::morse {}

#
# translate a text into morse
# using a dictionary
# should handle spaces
# should handle <prosigns>
#
proc text-to-morse {dict text} {
    set code {}
    foreach c [split $text {}] {
	lappend code [dict get $dict $c]
    }
    return [join $code { }]
}

#
# get the inversion of a morse dictionary
#
proc morse-inversion {dict} {
    if { ! [info exists ::morse::morse::inversion($dict)]} {
	set inversion [dict create]
	dict for {key value} $dict {
	    if { ! [string match \#*\# $key]} {
		dict lappend inversion $value $key
	    }
	}
	set ::morse::morse::inversion($dict) $inversion
    }
    return $::morse::morse::inversion($dict)
}

#
# translate a morse string
# into text using a dictionary
#
proc morse-to-text {dict morse} {
    set inversion [morse-inversion $dict]
    set morse [string trim $morse]
    set text {}
    foreach c [split $morse  { }] {
	if {[dict exists $inversion $c]} {
	    append text [join [dict get $inversion $c] {|}]
	} else {
	    append text \#
	}
    }
    return $text
}

#
# compute the length in dit clocks
# of the given character in the given dict
#
proc morse-character-length {dict character} {
    return [morse-dit-length [dict get $dict $character]]
}

#
# compute the length in dit clocks
# of the given word in the given dict
#
proc morse-word-length {dict word} {
    set code {}
    foreach character [split $word {}] {
	if {$code ne {}} {
	    append code { }
	}
	append code [dict get $dict $character]
    }
    return [morse-dit-length $code]
}

#
# compute the length in dit clocks
# of a given string of dits and dahs and spaces and newlines
#
proc morse-dit-length {code} {
    set length -1
    foreach e [split [string trim $code] {}] {
	if {$e eq {.}} {
	    incr length 2;	# dit + ies
	} elseif {$e eq {-}} {
	    incr length 4;	# dah + ies
	} elseif {$e eq { }} {
	    incr length 2;	# - ies + ils
	} elseif {$e eq "\n"} {
	    incr length 6;	# - ies + iws
	} else {
	    error "bad code string $code"
	}
    }
    return $length
}
    
#
# compute the dit time for words/minute in milliseconds
#
proc morse-dit-ms {wpm} {
    return [expr {60*1000/($wpm*50.0)}]; # millis per minute / dits per minute
}

#
# generate the length classes of a dictionary
#
proc morse-get-lengths {dict} {
    if { ! [info exists ::morse::morse::lengths($dict)]} {
	set lengths [dict create]
	dict for {key value} $dict {
	    if { ! [string match \#*\# $key]} {
		dict lappend lengths [morse-character-length $dict $key] $key
	    }
	}
	set ::morse::morse::lengths($dict) $lengths
    }
    return $::morse::morse::lengths($dict)
}

##
## form combinations of the integers in elts
## with the sum of elements + 3*(length-1) < len
##
proc ::morse::combinations {elts len} {
    if {$len <= 0} {
	return {}
    }
    set combinations {}
    foreach e $elts {
	if {$e > $len} { continue }
	lappend combinations $e
	foreach c [combinations $elts [expr {$len-$e-3}]] {
	    lappend combinations [concat [list $e] $c]
	}
    }
    return $combinations
}

##
## enumerate the words with the given dit length characters
##
proc ::morse::enumerate {combo lengths} {
    set enum {}
    if {[llength $combo]} {
	set c0 [lindex $combo 0]
	set cn [lrange $combo 1 end]
	if {[llength $cn]} {
	    foreach e [enumerate $cn $lengths] {
		foreach c [dict get $lengths $c0] {
		    lappend enum $c$e
		}
	    }
	} else {
	    foreach c [dict get $lengths $c0] {
		lappend enum $c
	    }
	}
    }
    return $enum
}

##
## enumerate the words of length $dits or less
## from the length sets in lengths
##
proc ::morse::enumerate-items {dits lengths} {
    set sets {}
    foreach i [dict keys $lengths] {
	if {$i <= $dits} {
	    lappend sets $i
	}
    }
    set combos [combinations $sets $dits]
    set list {}
    foreach c $combos {
	lappend list {*}[enumerate $c $lengths]
    }
    return $list
}

#
# generate the list of words which fit into dits
# given the dictionary dict
#
proc morse-words-of-length {dict dits} {
    if { ! [info exists ::morse::morse::generated($dict)]} {
	set ::morse::morse::generated($dict) [dict create]
    }
    if { ! [dict exists $::morse::morse::generated($dict) $dits]} {
	dict set ::morse::morse::generated($dict) $dits [::morse::enumerate-items $dits [morse-get-lengths $dict]]
    }
    return [dict get $::morse::morse::generated($dict) $dits]
}


