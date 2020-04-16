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

package require sdrtk::lradiomenubutton

namespace eval ::sdrtk {}

snit::widget sdrtk::cw-echo {
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
    option -source-label {Source}
    option -source-values -default {chars callsigns abbrevs words phrases}
    # length of challenge in characters
    option -length -default 1
    option -length-label {Length}
    option -length-values {1 2 3 4 5 6 ...}
    # number of times challenge is offered
    option -attempts -default 3
    option -attempts-label {Attempts}
    option -attempts-values -default {1 2 3 4 5 6 7}
    # milliseconds pause after each offer
    option -pause -default 5000
    option -pause-label Pause
    option -pause-values {500 1000 2000 3000 4000 5000 6000 7000}
    # speed of challenge
    option -challenge-wpm 30
    option -challenge-wpm-label {Challenge WPM}
    option -challenge-wpm-values {15 20 25 30 35 40}
    # character space padding
    option -char-space 3
    option -char-space-label {Char Spacing}
    option -char-space-values {3 3.5 4 4.5 5 5.5 6}
    # word space padding
    option -word-space 7
    option -word-space-label {Word Spacing}
    option -word-space-values {7 8 9 10 11 12 13 14}
    # speed of response
    option -response-wpm 20
    option -response-wpm-label {Response WPM}
    option -response-wpm-values {12 15 20 25 30 35 40}

    method delete {args} { }
    method insert {args} { }
    
    delegate method * to hull
    delegate option * to hull
    
    delegate method ins to hull as insert
    delegate method del to hull as delete
    
    variable data -array {
	handler {}
	challenge {}
	response {}
    }
    
    constructor {args} {
	$self configurelist $args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind all <KeyPress> [mymethod keypress %A]
	bind $win <Destroy> [list destroy .]
	set row 0
	foreach opt {-challenge-wpm -response-wpm -source -length -attempts -pause -char-space -word-space} {
	    ttk::label $win.l$opt -text "$options($opt-label): "
	    sdrtk::radiomenubutton $win.x$opt \
		-defaultvalue $options($opt) \
		-variable [myvar options($opt)] \
		-values $options($opt-values) \
		-command [mymethod update $opt]
	    grid $win.l$opt -row $row -column 0 -sticky ew
	    grid $win.x$opt -row $row -column 1 -sticky ew
	    incr row
	}
	set data(handler) [after 500 [mymethod timeout]]
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
	append data(challenge) [$options(-dec1) get]
	# get new response text
	append data(response) [$options(-dec2) get]
	# score results in background
	if {$data(challenge) ne {} || $data(response) ne {}} { after idle [mymethod score] }
	# loop around
	set data(handler) [after 250 [mymethod timeout]]
    }

    method keypress {a} { $options(-kbd) puts [string toupper $a] }

    method score {} {
	puts "challenge $data(challenge) response $data(response)"
	array set data { challenge {} response {} }
    }

}
