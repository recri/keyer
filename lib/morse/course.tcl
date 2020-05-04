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
# given a character preference string, 
# the characters will be introduced into the course roughly in the order specified.
# new characters are introduced when the existing characters are learned
# when characters have been learned,
# words and fragments using the learned characters will be introduced.
# new words and fragments are introduced when the existing words and fragments
# have been learned.
# longer words and fragments will be introduced when the existing words and fragments
# have been learned.
#
# {0123456789
# these could be handled by addition, subtraction, division, and multiplication (by juxtaposition) tables
# with decimals, which misses ? and whichever of . or , is not the radix point.
# 

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
package require morse::words
# words-words words-freq

package require morse::morse
package require morse::itu
package require snit

snit::type morse::course {
    option -old -default {} -configuremethod Configure
    option -seed -default {314159} -configuremethod Configure
    # the order is the rough order of introduction of the letters
    option -order -default {THEBANDOFIVRYUWSMGCLKPJQXZ} -configuremethod Configure
    # these are orders which have been used in courses, or our own invention
    option -orders -default {
	{50ETARSLUQJHONCVIBYPWKZMDXFG}
	{FGHMJRUBDKNTVYCEILOSAPQXZW}
	{ETAIMNSODRCUKPHGWLQBFYZVXJ}
	{EISHTMOANWGDUVJBRKLFPXZCYQ}
	{FKBQTCZHWXMDYUPAJOERSGNLVI}
	{ETIMSOHAWUJVPCGKQFZRYLBXDN}
	{AEIOUTNRSDLHBCFGJKMPQVWXYZ}
	{THEBANDOFIVRYUWSMGCLKPJQXZ}
    }
    # the numbers 
    option -numbers -default {1234567890}
    # the normally used punctuation in ham communications
    option -punctuation -default {+,-./=?}

    # these could all be typevariables, constant across instances
    typevariable data -array {
	dict {}
	dwor5k {}
	wor5k {}
	words {}
	codes {}
	prosigns {}
    }
    
    # map words to upper case only
    proc toupper {list} { return [lmap {x} $list {string toupper $x}] }

    # filter words to alphabetics only, no hyphens or apostrophes
    proc onlyalpha {list} { return [lmap {x} $list {if {[regexp {^[A-Za-z]+$} $x]} {set x} else continue }] }

    # get letter frequencies
    proc letter-frequencies {words {freqs {}}} { 
	set dist [dict create]
	foreach letter [split ABCDEFGHIJKLMNOPQRSTUVWXYZ {}] { dict set dist $letter 0 }
	foreach word $words freq $freqs { 
	    set word [string toupper $word]
	    if {$freq eq {}} { set freq 1 }
	    while {[regexp {^([^<]*)<([^>]*)>(.*)$} $word all prefix prosign suffix]} {
		dict incr dist $prosign $freq
		incr total $freq
		set word "$prefix$suffix"
	    }
	    foreach letter [split $word {}] { 
		dict incr dist $letter $freq 
		incr total $freq
	    }
	}
	dict for {key val} $dist { dict set dist $key [expr {int(10000*double($val)/$total)}] }
	return $dist
    }

    # get ngram frequencies
    proc ngram-frequencies {words {freqs {}} {n 5}} {
	set dist [dict create]
	set total [dict create]
	foreach word $words freq $freqs {
	    set word [string toupper $word]
	    if {$freq eq {}} { set freq 1 }
	    if {[regexp {<([^>]*)>} $word]} continue; # no prosigns this time
	    set strip [regsub -all {[-'/]} $word {}]
	    if {$word ne $strip} { puts "$word -> $strip"; set word $strip } 
	    while {$word ne {}} {
		for {set i 0} {$i < $n} {incr i} {
		    if {[string length $word] > $i} {
			dict incr dist [string range $word 0 $i] $freq
			dict incr totals $i $freq
		    }
		}
		set word [string range $word 1 end]
	    }
	}
	dict for {key val} $dist { 
	    set tot [dict get $totals [expr {[string length $key]-1}]]
	    set value [expr {int(100000*double($val)/$tot)}]
	    if {$value} { dict set dist $key $value }
	}
	return $dist
    }

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
    typeconstructor {
	set data(dict) [morse-itu-dict]
	set data(dwor5k) [words-dict]
	set data(wor5k) [onlyalpha [toupper [dict keys $data(dwor5k)]]]
	set data(words) [toupper [concat [morse-voa-vocabulary] [n0hff-common-words] [n0hff-more-words] [n0hff-prefixes] [n0hff-suffixes]]]
	set data(codes) [toupper [concat [morse-pileup-callsigns] [dict keys [morse-qcodes]] [morse-ham-abbrev]]]
	set data(prosigns) [toupper [concat [morse-abbrev-prosigns] [morse-abbrev-milprosigns]]]
    }
    constructor {args} {
	$self configurelist $args
    }

    method Configure {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -seed { tcl::mathfunc::srand $val }
	    default { error "uncaught option $opt in Configure" }
	}
    }
    if {0} {
	#variable dist [dict create]
	#dict set dist wor5k [letter-frequencies $wor5k]
	#dict set dist words [letter-frequencies $words]
	#dict set dist codes [letter-frequencies $codes]
	#dict set dist prosigns [letter-frequencies $prosigns]
	#foreach d {wor5k words codes prosigns} { 
	#puts "$d: [dict get $dist $d]"
	#}
	
	variable gram [dict create]
	set ix [lsort -indices -real -decreasing [dict values $dwor5k]]
	set wx [lmap i $ix {lindex [dict keys $dwor5k] $i}]
	set vx [lmap i $ix {lindex [dict values $dwor5k] $i}]
	dict set grams wor5k [ngram-frequencies $wx $vx]
	#dict set grams words [ngram-frequencies $words]
	#dict set grams codes [ngram-frequencies $codes]
	
	# words codes
	foreach d {wor5k} { 
	    for {set g ?} {[string length $g] <= 5} {append g ?} {
		set data [dict filter [dict get $grams $d] key $g]
		set xx [dict create]
		foreach k [lmap i [lsort -indices -decreasing -integer [dict values $data]] {lindex [dict keys $data] $i}] {
		    dict set xx $k [dict get $data $k]
		}
		# puts "$d:[string length $g]: $xx"
	    }
	}
	
	#foreach word $words { text-to-morse $dict $word }
	#foreach word $codes { text-to-morse $dict $word }
	#foreach word $prosigns { text-to-morse $dict $word }
    }
    if {0} {
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
    }
    if {0} {
	# the letter frequencies in the 5000 word corpus
	# ordered by their first appearance in the ranked list of words
	#    THEBANDOFIVRYUWSMGCLKPJQXZ
	# by frequency
	#    ETOANIHRSLDCUMFBYWPGVKXJQZ
	# is this is mucked about by folding multiple references?  No, same.
	#set mores1 {T 1036 H 618 E 1320 B 224 A 819 N 662 D 310 O 839 F 239 I 656 V 122 R 573 Y 219 U 279 W 195 S 452 M 246 G 161 C 292 L 402 K 86 P 193 J 13 Q 8 X 16 Z 4}
	#           {T 1036 H 618 E 1320 B 224 A 819 N 662 D 310 O 839 F 239 I 656 V 122 R 573 Y 219 U 279 W 195 S 452 M 246 G 161 L 402 C 292 K 86 P 193 J 13 Q 8 X 16 Z 4}
	#puts [join [dict keys $mores1] {}]
	#set sorts1 [lmap i [lsort -indices -real -decreasing [dict values $mores1]] {lindex [dict keys $mores1] $i}]
	# puts [join $sorts1 {}]
    }
    
}
