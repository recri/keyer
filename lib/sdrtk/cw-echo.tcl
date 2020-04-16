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
package provide sdrtk::cw-echo 1.0.0

package require Tk
package require snit

#
# generate morse code to be echoed back
#
# general options for generated code:
#    speed, inter-letter space, inter-word space, ...
#    tone frequency, ramp on/off, length on/off, level, ...
#    inter-dit-dah frequency shift
# general options for response:
#    keyed:
#      key speed, spacing, mode, ...
#      tone frequency, ramp on/off, length on/off, level, ...
#    typed:
# general options for generated words:
#    character sets: random words of n letters
#    words and phrases
#    abbreviations
#    callsigns
#
# echo only needs one screen,
# it can capture keyboard input with focus dot
# it can capture keyer input
# it can echo in its own screen space


package require morse::morse
package require morse::itu
package require morse::dicts

namespace eval ::sdrtk {}

snit::widgetadaptor sdrtk::cw-echo {
    option -chk -default {}
    option -cho -default {}
    option -key -default {}
    option -keyo -default {}
    option -kbd -default {}
    option -kbdo -default {}
    option -dto1 -default {}
    option -dto2 -default {}
    option -dti1 -default {}
    option -dti2 -default {}
    option -dec1 -default {}
    option -dec2 -default {}
    option -dict -default fldigi
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
    # source of challenge {random callsign abbrev word qcode file}
    option -source -default random-char
    # length of challenge in characters
    option -length -default 1
    # number of times challenge is offered
    option -attempts -default 3
    # milliseconds pause after each offer
    option -pause -default 5000
    # number of challenges
    method delete {args} { }
    method insert {args} { }
    
    delegate method * to hull
    delegate option * to hull
    
    delegate method ins to hull as insert
    delegate method del to hull as delete
    
    variable handler {}
    variable code {}
    
    constructor {args} {
	# puts "cw-decode-view constructor {$args}"
	installhull using text
	set client [winfo name [namespace tail $self]]
	set server [from args -server {}]
	set xargs {}
	if {$server ne {}} { lappend xargs -server $server }
	$self configure -width 30 -height 15 -exportselection true {*}$args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	set handler [after 100 [mymethod timeout]]
    }

    method exposed-options {} { return {-dict -font -foreground -background -chk -cho -key -keyo -kbd -kbdo -dec1 -dec2} }

    method info-option {opt} {
	switch -- $opt {
	    -background { return {color of window background} }
	    -foreground { return {color for text display} }
	    -font { return {font for text display} }
	    -dict { return {dictionary for decoding morse} }
	    -chk { return {challenge encoder} }
	    -cho { return {challenge oscillator} }
	    -kbd { return {response keyboard} }
	    -kbdo { return {response keyboard oscillator} }
	    -key { return {response keyer} }
	    -keyo { return {response keyer oscillator} }
	    -dec1 { return {challenge cw decoder} }
	    -dec2 { return {response cw decoder} }
	    -dto1 { return {challenge tone decoder} }
	    -dto2 { return {response tone decoder} }
	    -dti1 { return {challenge time decoder} }
	    -dti2 { return {response time decoder} }
	    default { puts "no info-option for $opt" }
	}
    }

    method ConfigText {opt val} {
	$hull configure $opt $val
    }

    method timeout {} {
	# get new challenge text
	set text1 [$options(-dec1) get]
	# get new response text
	set text2 [$options(-dec2) get]
	# insert into output display
	if {$text1 ne {} || $text2 ne {}} {
	    puts "challenge {$text1} response {$text2}"
	}
	set handler [after 250 [mymethod timeout]]
    }

    method option-menu {x y} {
	if { ! [winfo exists $win.m] } {
	    menu $win.m -tearoff no
	    $win.m add command -label {Clear} -command [mymethod clear]
	    $win.m add separator
	    $win.m add command -label {Save To File} -command [mymethod save]
	}
	tk_popup $win.m $x $y
    }
}
