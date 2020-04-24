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
# morse code course
#
# an order for introducing letters and words
#
# e t | ee et | i a |
#     | te tt | n m |
# a n i m | ee et ea en ei em | i a u r 
#         | te tt ta tn ti tm |
#         | ae at aa an ai am |
#         | ne nt na nn ni nm |
#         | ie it ia in ii im |
#         | me mt ma mn mi mm |

package provide morse::course 1.0.0

package require morse::abbrev
# morse-qcodes morse-ham-abbrev morse-ham-qcodes morse-ham
package require morse::callsigns
# morse-pileup-callsigns
package require morse::n0hff
# n0hff-letter-orders n0hff-common-words n0hff-words-by-function 
# n0hff-words-sentences n0hff-more-words n0hff-prefixes n0hff-suffixes
# n0hff-phrases n0hff-long
package require morse::voa
# morse-voa-vocabulary

package require morse::morse
package require morse::itu

namespace eval ::morse {}
namespace eval ::morse::course {

    # get a dictionary
    variable dict [morse-itu-dict]

    # get some word lists
    proc toupper {list} { return [lmap {x} $list {string toupper $x}] }
    variable words [toupper [concat [morse-voa-vocabulary] [n0hff-common-words] [n0hff-more-words] [n0hff-prefixes] [n0hff-suffixes]]]
    variable codes [toupper [concat [morse-pileup-callsigns] [dict keys [morse-qcodes]] [morse-ham-abbrev]]]
    variable prosigns [toupper [concat [dict keys $::morse::abbrev::prosigns] [dict keys $::morse::abbrev::milprosigns]]]

    # get letter frequencies
    proc letter-frequencies {words} { 
	set dist [dict create]
	foreach letter [split ABCDEFGHIJKLMNOPQRSTUVWXYZ {}] { dict set dist $letter 0 }
	foreach word $words { 
	    while {[regexp {^([^<]*)<([^>]*)>(.*)$} $word all prefix prosign suffix]} {
		dict incr dist $prosign
		set word "$prefix$suffix"
	    }
	    foreach letter [split $word {}] { dict incr dist $letter }
	}
	return $dist
    }

    variable dist [dict create]
    namespace eval dist {}

    dict set dist words [letter-frequencies $words]
    dict set dist codes [letter-frequencies $codes]
    dict set dist prosigns [letter-frequencies $prosigns]
    
    foreach d {words codes prosigns} { puts "$d: [dict get $dist $d]" }

    # translate text-to-morse with prosign interpolation
    proc text-to-morse {dict text} {
	set text [string toupper $text]
	set morse {}
	while {[regexp {^([^<]*)<([^>]*)>(.*)$} $text all prefix prosign suffix]} {
	    if {$prefix ne {}} {
		append morse [::text-to-morse $dict $prefix]
		append morse { }
	    }
	    foreach letter [split $prosign {}] {
		if { ! [dict exists $dict $letter]} { error "no code for $letter in <$prosign>" }
		append morse [dict get $dict $letter]
	    }
	    set text $suffix
	    if {$text ne {}} { append morse { } }
	}
	append morse [::text-to-morse $dict $text]
	return $morse
    }
	
    foreach word $words { text-to-morse $dict $word }
    foreach word $codes { text-to-morse $dict $word }
    foreach word $prosigns { text-to-morse $dict $word }
    
    # make an inverse dictionary
    set idict [dict create]
    dict for {key val} $dict { 
	if {[dict exists $idict $val]} {
	    error "duplicate {$val} in inverse dictionary"
	}
	dict set idict $val $key
    }

    # add in prosigns that are not already in the morse dictionary
    foreach key [dict keys [dict get $dist prosigns]] {
	if {[string length $key] <= 1} continue
	if {[dict exists $dict $key]} continue
	set code [text-to-morse $dict <$key>]
	if {[dict exists $idict $code]} continue
	dict set dict <$key> $code
	dict set idict $code <$key>
	puts "inserted <$key> as {$code}"
    }

    if {0} {
	# generate the tiers of letters
	# expand by cartesian product, gets too big
	proc expand {dictname idictname letters} {
	    upvar $dictname dict
	    upvar $idictname idict
	    # take the letters, form the cartesian product
	    foreach l1 $letters {
		foreach l2 $letters {
		    set di [regsub -all {[<>]} $l1$l2 {}]
		    lappend digram $di
		    set dc "[dict get $dict $l1][dict get $dict $l2]"
		    lappend dicode $dc
		    if { ! [dict exists $idict $dc]} {
			dict set dict <$di> $dc
			dict set idict $dc <$di>
		    }
		    lappend ditran [dict get $idict $dc]
		}
	    }
	    return [list letters $letters digrams $digram dicodes $dicode ditrans $ditran]
	}
	
	variable levels [dict create]
	set letters {E T}
	dict set levels $letters [expand dict idict $letters]
	dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
	lappend letters {*}[dict get $levels $letters ditrans]
	dict set levels $letters [expand dict idict $letters]
	dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
	lappend letters {*}[dict get $levels $letters ditrans]
	dict set levels $letters [expand dict idict $letters]
	dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    }
    # find the shortest prosign
    proc shortest-prosign {dict dicode} {
	# find the longest alphabetic 
	set maxkey {}
	set maxval {}
	set maxlen 0
	dict for {key val} $dict {
	    if { ! [string is alpha $key]} continue
	    if {[string length $key] != 1} continue
	    if {[string first $val $dicode] == 0} {
		# exact prefix match
		if {[string length $val] > $maxlen} {
		    # longest exact prefix match so far
		    set maxlen [string length $val]
		    set maxkey $key
		    set maxval $val
		}
	    }
	}
	set remnant [regsub "^$maxval" $dicode ""]
	# puts "best prefix for $dicode is $maxkey $maxval"
	if {$remnant eq {}} {
	    return $maxkey
	} else {
	    return $maxkey[shortest-prosign $dict $remnant]
	}
    }
			    
    # generate the tiers of characters
    # cartesian product with {e t} at each step
    proc expand {dictname idictname letters} {
	upvar $dictname dict
	upvar $idictname idict
	# take the letters, form the cartesian product
	foreach l1 {E T}  {
	    foreach l2 $letters {
		set di [regsub -all {[<>]} $l1$l2 {}]
		lappend digram $di
		set dc "[dict get $dict $l1][dict get $dict $l2]"
		lappend dicode $dc
		if { ! [dict exists $idict $dc]} {
		    set ndi [shortest-prosign $dict $dc]
		    puts "shortest prosign for $di is $ndi"
		    dict set dict <$ndi> $dc
		    dict set idict $dc <$ndi>
		}
		lappend ditran [dict get $idict $dc]
	    }
	}
	return [list letters $letters digrams $digram dicodes $dicode ditrans $ditran]
    }
    variable levels [dict create]

    set letters {E T}
    dict set levels $letters [expand dict idict $letters]
    dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    set letters [dict get $levels $letters ditrans]
    dict set levels $letters [expand dict idict $letters]
    dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    set letters [dict get $levels $letters ditrans]
    dict set levels $letters [expand dict idict $letters]
    dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    set letters [dict get $levels $letters ditrans]
    dict set levels $letters [expand dict idict $letters]
    dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    set letters [dict get $levels $letters ditrans]
    dict set levels $letters [expand dict idict $letters]
    dict for {key val} [dict get $levels $letters] { puts "$key: $val" }
    #
    # I want the dictionary to return <xy> prosigns for undefined codes rather than #
    # I think they should use the longest prefix alphabetic at each step, unless they're
    # already assigned.
    #
    dict for {char code} $dict { if {$code ne [text-to-morse $dict $char]} { puts "{$char} {$code} vs {[text-to-morse $dict $char]}" } }
}
