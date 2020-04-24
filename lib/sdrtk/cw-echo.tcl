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

package require morse::morse
package require morse::itu
package require morse::dicts
package require morse::abbrev
package require morse::callsigns
package require morse::voa
package require morse::n0hff

package require sdrtk::lscale
package require sdrtk::lradiomenubutton
package require sdrtk::dialbook
package require sdrtk::cw-decode-view

package require midi

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
#
# introduce letters, immediately introduce combinations of letters,
# followed by letters with the same combination of elements without the spaces
# lesson 1: e t ee et | i a |
#               te tt | n m |
# lesson 2: e t a n i m  ee et ea en ei em | i a u r s w | * * u r s w |
#                        te tt ta tn ti tm | n m k g d o | * * k g d o |
#                        ae at aa an ai am | r w . p l j | r w . p l j |
#                        ne nt na nn ni nm | d k x c b y | d k x c b y |
#                        ie it ia in ii im | s u v f h . | s u v f h . |
#                        me mt ma mn mi mm | g o q . z . | g o q . z . |
#
# choose these according to value of [llength [lsearch -glob -inline *$word*]]
# tea ten eta team meat neat teen mean meta net nim nam men mat man mam
# lesson 3: 
# (some digrams do not appear in word lists)
# (some digrams only appear in callsign lists)
#
# tally marks
# 𝍩 U+1D369 COUNTING ROD TENS DIGIT ONE
# 𝍪 U+1D36A COUNTING ROD TENS DIGIT TWO
# 𝍫 U+1D36B COUNTING ROD TENS DIGIT THREE
# 𝍬 U+1D36C COUNTING ROD TENS DIGIT FOUR
# 𝍭 U+1D36D COUNTING ROD TENS DIGIT FIVE
# u1D377 - TALLY MARK ONE - 𝍷
# u1D378 - TALLY MARK FIVE - 𝍸
# ᚎ ogham straif
#

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
    option -dti2 -default {} -configuremethod Config
    option -dec1 -default {}
    option -dec2 -default {}
    option -out -default {}
    option -dict -default fldigi
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
    # source of challenge
    option -source -default letters
    option -source-label {Source}
    option -source-values -default {letters digits characters callsigns abbrevs qcodes prefixes suffixes words phrases sentences}
    # length of challenge in characters
    option -length -default 1
    option -length-label {Length}
    option -length-values {1 2 3 4 5 6 ...}
    # length of session in minutes
    option -session -default 0.5
    option -session-label {Session}
    option -session-values -default {0.5 1 2 5 10 15 20 25 30 45 60}
    # speed of challenge
    option -challenge-wpm 30
    option -challenge-wpm-label {Challenge WPM}
    option -challenge-wpm-values {15 17.5 20 22.5 25 30 35 40 50}
    # frequency of challenge sidetone
    option -challenge-tone E5
    option -challenge-tone-label {Challenge Tone}
    option -challenge-tone-values [lreverse {C4 C4# D4 D4# E4 F4 F4# G4 G4# A5 A5# B5 C5 C5# D5 D5# E5 F5 F5# G5 G5# A6 A6# B6}]
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
    # frequency of challenge sidetone
    option -response-tone F5
    option -response-tone-label {Response Tone}
    option -response-tone-values [lreverse {C4 C4# D4 D4# E4 F4 F4# G4 G4# A5 A5# B5 C5 C5# D5 D5# E5 F5 F5# G5 G5# A6 A6# B6}]
    # offset of dah tone from dit tone
    option -dah-offset 0
    option -dah-offset-label {Dah Tone Offset}
    option -dah-offset-min -5.0
    option -dah-offset-max  5.0
    option -dah-offset-step 0.01
    # output gain
    option -gain 0
    option -gain-label {Output Gain}
    option -gain-min -30
    option -gain-max +30
    
    variable data -array {
	handler {}
	pre-challenge {}
	challenge {}
	challenge-trimmed {}
	response {}
	response-trimmed {}
	sample {}
	state {}
	last-status {}
	time-warp 1
    }
    
    constructor {args} {
	$self configurelist $args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind all <KeyPress> [mymethod keypress %A]
	bind $win <Destroy> [list destroy .]
	# five tabs in a notebook
	pack [ttk::notebook $win.echo] -fill both -expand true
	$win.echo add [$self play-tab $win.play] -text Echo
	$win.echo add [$self setup-tab $win.setup] -text Setup
	$win.echo add [$self about-tab $win.about] -text About
	$win.echo add [$self sandbox-tab $win.sandbox] -text Sandbox
	$win.echo add [$self dial-tab $win.dial] -text Dial
	after 500 [mymethod setup]
    }

    method keypress {a} { $options(-kbd) puts [string toupper $a] }
    method setup {} {
	foreach opt {-challenge-wpm -challenge-tone -response-wpm -response-tone -source -length -session -char-space -word-space -gain -dah-offset} {
	    $self update $opt $options($opt)
	}
	$win.echo select $win.play
	$win.play.text tag configure wrong -foreground red
	$win.play.text tag configure right -foreground green
	set data(state) start
    }

    #
    # state machine
    #
    method timeout {} {
	while {1} {
	    # check if pause
	    if { ! $data(play/pause)} {
		$self status "Press Play to continue\n" normal
		return
	    }
	    # compute time elapsed
	    set data(play-time) [accumulate-playtime {*}$data(session-stamps) play [clock millis]]
	    set data(session-time) [format-time $data(play-time)]
	    # update challenge text
	    append data(challenge) [$options(-dec1) get]
	    # trimmed challenge
	    set data(trimmed-challenge) [string trim $data(challenge)]
	    # update response text
	    append data(response) [$options(-dec2) get]
	    # trimmed response
	    set data(trimmed-response) [regsub -all { } $data(response) {}]
	    # switch on state
	    switch $data(state) {
		start {
		    array set data [list \
					session-time 0 \
					session-log {} \
					response-time 0 \
					session-stamps [list play [clock millis]] \
					challenges 0 \
					hits 0 \
					misses 0 \
					passes 0 \
					session-start [clock seconds] \
					pre-challenge {} \
					challenge {} \
					trimmed-challenge {} \
					response {} \
					trimmed-response {} \
					time-pause [clock millis] \
					time-challenge 0 \
					time-of-echo 0 \
					time-to-echo 0 \
					state pause-before-new-challenge \
				       ]
		}
		pause-before-new-challenge {
		    if {($data(play-time)/1000.0)/60.0 >= $options(-session)} {
			$self status "Session complete\n"
			$self score-session
			$self play-button play/pause
			set data(state) start
			continue
		    }
		    if {[clock millis]-$data(time-pause) > 50} {
			if {[$options(-dti2) pending]} {
			    set data(time-pause) [clock millis]
			} else {
			    set data(state) new-challenge
			}
		    }
		}
		new-challenge {
		    if {$options(-chk) ne {} && ! [$options(-chk) is-busy]} {
			array set data [list  \
					    challenge {} trimmed-challenge {} response {} trimmed-response {} \
					    state wait-challenge-echo ]
			set data(pre-challenge) [$self sample-draw]
			set data(time-challenge) [clock millis]
			set data(challenge-dits) [morse-word-length [$options(-dict)] $data(pre-challenge)]
			set data(challenge-dit-ms) [morse-dit-ms $options(-challenge-wpm)]
			set data(response-dit-ms) [morse-dit-ms $options(-response-wpm)]
			set data(challenge-response-ms) [expr {$data(challenge-dits)*($data(challenge-dit-ms)+$data(response-dit-ms))}]
			$options(-chk) puts [string toupper $data(pre-challenge)]
			incr data(challenges)
		    }
		}
		wait-challenge-echo {
		    # $self status "Waiting for challenge to echo ..." normal
		    if {[string length $data(pre-challenge)] > [string length $data(trimmed-challenge)]} {
			# waiting for more input
			break
		    }
		    if {[string first $data(pre-challenge) $data(trimmed-challenge)] >= 0} {
			# $self status "\n" normal
			set t [clock millis]
			array set data [list time-of-echo $t time-to-echo [expr {8*$data(time-warp)*($t-$data(time-challenge))}] state wait-response-echo]
			# puts "time-to-echo $data(time-to-echo)"
			continue
		    } 
		    if {$data(trimmed-challenge) ne {}} {
			# $self status "\n" normal
			# puts "wait-challenge-echo {$data(pre-challenge)} and {$data(challenge)}"
			set data(state) challenge-again
			continue
		    }
		    break
		}
		wait-response-echo {
		    # $self status "Waiting for response ... {$data(trimmed-challenge)} {$data(trimmed-response)}" normal
		    if {[string length $data(trimmed-challenge)] > [string length $data(trimmed-response)]} {
			break
		    }
		    set data(response-time) [expr {[clock millis]-$data(time-challenge)-$data(challenge-response-ms)}]
		    if {[string first $data(trimmed-challenge) $data(trimmed-response)] >= 0} {
			$self status {}
			$self status $data(trimmed-response) right " is correct!\n" normal
			$self score-challenge hits
			array set data [list time-pause [clock millis] state pause-before-new-challenge]
		    } elseif {$data(trimmed-response) ne {} &&
			      [string first $data(trimmed-response) $data(trimmed-challenge)] != 0} {
			$self status {}
			$self status "$data(response)" wrong " is wrong!\n" normal
			$self score-challenge misses
			array set data [list time-pause [clock millis] state pause-before-challenge-again]
		    } elseif {[clock millis] > $data(time-of-echo)+$data(time-to-echo)} {
			# $self status "too long!" tardy "\n" normal
			$self score-challenge passes
			array set data [list time-pause [clock millis] state pause-before-challenge-again]
		    }
		}
		pause-before-challenge-again {
		    if {[clock millis]-$data(time-pause) > 50} {
			if {[$options(-dti2) pending]} {
			    set data(time-pause) [clock millis]
			    continue
			}
			set data(state) challenge-again
			continue
		    }
		    break
		}
		challenge-again {
		    if {$options(-chk) ne {} && ! [$options(-chk) is-busy]} {
			$options(-chk) puts [string toupper $data(pre-challenge)]
			array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} state wait-challenge-echo]
			continue
		    }
		    break
		}
		default { error "uncaught state $data(state)" }
	    }
	    break
	}
	set data(handler) [after 50 [mymethod timeout]]
    }
    method status {args} { 
	if {$data(last-status) ne $args} {
	    set data(last-status) $args
	    $win.play.text insert end {*}$args
	    $win.play.text see end
	    # puts -nonewline [join $args { }]
	}
    }
    proc format-time {millis} {
	# return [format {%d:%02d:%03d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}] [expr {$millis%1000}]]
	return [format {%d:%02d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}]]
    }
    proc accumulate-time {args} {
	#puts "accumulate-time $args"
	set playtime 0
	set pausetime 0
	foreach {tag millis} $args {
	    if {[info exists lasttag]} {
		switch [list $lasttag $tag] {
		    {play play} -
		    {play pause} { incr playtime [expr {$millis-$lastmillis}] }
		    {pause pause} -
		    {pause play} { incr pausetime [expr {$millis-$lastmillis}] }
		    default { error "uncaught time interval {$lasttag $tag}" }
		}
	    }
	    set lasttag $tag
	    set lastmillis $millis
	}
	#puts "accumulate-time $args -> $playtime $pausetime"
	return [list $playtime $pausetime]
    }
    proc accumulate-playtime {args} { return [lindex [accumulate-time {*}$args] 0] }
    proc accumulate-pausetime {args} { return [lindex [accumulate-time {*}$args] 1] }
    # score the results of a timed session
    method score-session {} {
	puts "score-session"
    }
    # score the results of a single challenge
    method score-challenge {as} {
	incr data($as)
	lappend data(session-log) [list $data(pre-challenge) $data(trimmed-response) $as $data(response-time)]
	# puts "score-challenge {$data(pre-challenge)} {$data(trimmed-response)} $as $data(response-time) ms"
    }
    proc choose {x} {
	# puts "choose from {$x} [expr {int(rand()*[llength $x])}]"
	return [lindex $x [expr {int(rand()*[llength $x])}]]
    }
    method sample-draw {} {
	switch $options(-source) {
	    letters -
	    digits -
	    characters {
		set draw {}
		for {set i 0} {$i < $options(-length)} {incr i} {
		    append draw [choose $data(sample)]
		}
		set draw [string toupper $draw]
		# puts "sample-draw -> $draw"
		return $draw
	    }
	    default { error "uncaught source $options(-source) in sample-draw" }
	}
    }
    #
    # play-tab
    #
    method play-tab {w} {
	array set data {
	    session-stamps {}
	    play/pause 0
	    session-time 0
	    response-time 0
	    challenges 0
	    hits 0
	    misses 0
	    passes 0
	    challenge {}
	    response {}
	}
	pack [ttk::frame $w] -side top -expand true -fill x
	set row 0
	foreach var {session-time response-time challenges hits misses passes challenge-wpm response-wpm} {
	    grid [ttk::label $w.l$var -text "$var: "] -row $row -column 0
	    grid [ttk::label $w.v$var -textvar [myvar data($var)]] -row $row -column 1
	    switch $var {
		session-time { set data($var) 0:00 }
		response-time -
		challenges -
		hits -
		misses -
		passes  { set data($var) 0 }
		challenge-wpm { set data($var) "$options(-challenge-wpm) WPM" }
		response-wpm { set data($var) "$options(-response-wpm) WPM" }
		default { error "uncaught dashboard variable $var" }
	    }
	    incr row
	}
	grid [text $w.text -height 8 -width 40 -background lightgrey] -row $row -column 0 -columnspan 2 -sticky ew
	bind $w.text <KeyPress> {}
	incr row
	foreach but {play/pause} {
	    grid [ttk::button $w.b$but -text Play -command [mymethod play-button $but]] -row $row -column 0 -columnspan 2
	}
	return $w
    }
    method play-button {but} {
	# puts "play-button $but"
	switch $but {
	    play/pause {
		set data(play/pause) [expr {1^$data(play/pause)}]
		if {$data(play/pause)} {
		    $win.play.b$but configure -text Pause
		    lappend data(session-stamps) play [clock millis]
		    $self timeout
		} else {
		    $win.play.b$but configure -text Play
		    lappend data(session-stamps) pause [clock millis]
		    set data(handler) [after 50 [mymethod timeout]]
		}
	    }
	    settings {
		
	    }
	    default { error "uncaught button $but" }
	}
    }
    #
    # sandbox-tab
    #
    method sandbox-tab {w} {
	# $options(-dti2)
	pack [sdrtk::cw-decode-view $w -detime {} ] -fill both -expand true
	return $w
    }
    #
    # dial-tab
    #
    method dial-tab {w} {
	::sdrtk::dialbook $w
	foreach text [::options get-opts] {
	    if {[::options is-hide $text]} continue

	    set type [::options get $text type]
	    set name [::options get $text name]
	    set readout [::options get $text readout]
	
	    set wx $w.x$text
	    package require sdrtk::readout-$type
	    sdrtk::readout-$type $wx -dialbook $w \
		-text $text -info [::options get $text info] {*}$readout \
		-value [::options cget $text] -variable [::options cvar $text] -command [list ::options configure $text]
	    $w add $wx $name $type -text $text
	}

	if {[$w select] eq {}} { $w select 0 }

	return $w
    }
    #
    # about-tab
    #
    method about-tab {w} {
	ttk::frame $w
	pack [text $w.text -width 40 -background lightgrey] -fill both -expand true
	return $w
    }
    #
    # setup-tab
    #
    method setup-tab {w} {
	ttk::frame $w
	set row 0
	foreach opt {-challenge-wpm -challenge-tone -response-wpm -response-tone -source -length -session -char-space -word-space} {
	    ttk::label $w.l$opt -text "$options($opt-label): "
	    sdrtk::radiomenubutton $w.x$opt \
		-defaultvalue $options($opt) \
		-variable [myvar options($opt)] \
		-values $options($opt-values) \
		-command [mymethod update $opt]
	    if {[info exists options($opt-labels)]} {
		$w.x$opt configure -labels $options($opt-labels)
		ttk::frame $w
	    }
	    grid $w.l$opt -row $row -column 0 -sticky ew
	    grid $w.x$opt -row $row -column 1 -sticky ew
	    incr row
	}
	foreach opt {-gain -dah-offset} {
	    sdrtk::lscale $w.x$opt \
		-label "$options($opt-label)" \
		-from $options($opt-min) \
		-to $options($opt-max) \
		-value $options($opt) \
		-variable [myvar options($opt)] \
		-command [mymethod update $opt]
	    grid $w.x$opt -row $row -column 0 -columnspan 2 -sticky ew
	    incr row
	}
	return $w
    }
    method sample-trim {} {
    }
    method update {opt val} {
	# puts "update $opt $val"
	set options($opt) $val
	switch -- $opt {
	    -source {
		switch -- $val {
		    letters { set data(sample) [split {abcdefghijklmnopqrstuvwxyz} {}] }
		    digits { set data(sample) [split {0123456789} {}] }
		    characters { set data(sample) [split {abcdefghijklmnopqrstuvwxyz0123456789.,?/-=+} {}] }
		    callsigns { set data(sample) [morse-pileup-callsigns] }
		    abbrevs { set data(sample) [morse-ham-abbrev] }
		    qcodes { set data(sample) [morse-ham-qcodes] }
		    words { set data(sample) [morse-voa-vocabulary] }
		    suffixes { }
		    prefixes { }
		    phrases { }
		    default { error "uncaught -source $val" }
		}
		$self sample-trim
	    }
	    -length {
		$self sample-trim
	    }
	    -session {
	    }
	    -challenge-wpm { 
		::options cset -$options(-chk)-wpm $val
		::options cset -$options(-dti1)-wpm $val
		set data(time-warp) [expr {$options(-challenge-wpm)/$options(-response-wpm)}]
	    }
	    -challenge-tone { 
		set cfreq [::midi::note-to-hertz [::midi::name-octave-to-note $val]]
		::options cset -$options(-dto1)-freq $cfreq
		::options cset -$options(-cho)-freq $cfreq
	    }
	    -char-space { ::options cset -$options(-chk)-ils $val }
	    -word-space { ::options cset -$options(-chk)-iws $val }
	    -response-wpm { 
		::options cset -$options(-kbd)-wpm $val 
		::options cset -$options(-key)-wpm $val
		::options cset -$options(-dti2)-wpm $val
		set data(time-warp) [expr {$options(-challenge-wpm)/$options(-response-wpm)}]
	    }
	    -response-tone { 
		set rfreq [::midi::note-to-hertz [::midi::name-octave-to-note $val]]
		::options cset -$options(-kbdo)-freq $rfreq
		::options cset -$options(-keyo)-freq $rfreq
	    }
	    -dah-offset {
		set cfreq [::midi::note-to-hertz [expr {[::midi::name-octave-to-note $options(-challenge-tone)]+$val}]]
		::options cset -$options(-chk)-two $cfreq
		::options cset -$options(-cho)-two $cfreq
		set rfreq [::midi::note-to-hertz [expr {[::midi::name-octave-to-note $options(-response-tone)]+$val}]]
		::options cset -$options(-kbd)-two $rfreq
		::options cset -$options(-key)-two $rfreq
		::options cset -$options(-kbdo)-two $rfreq
		::options cset -$options(-keyo)-two $rfreq
	    }
	    -gain {
		::options cset -$options(-out)-gain $val
	    }
	    default { error "uncaught option update $opt" }
	}
    }
    #
    #
    #
    method exposed-options {} { 
	return {
	    -dict -chk -cho -key -keyo -kbd -kbdo -dec1 -dec2 -dto1 -dto2 -dti1 -dti2 -out
	    -length
	}
    }

    method info-option {opt} {
	switch -- $opt {
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
	    -out { return {output gain} }
	    -length { return {length of challenges} }
	    default { puts "no info-option for $opt" }
	}
    }

    method ConfigText {opt val} { $hull configure $opt $val }
    method {Config -dti2} {val} { 
	set options(-dti2) $val
	# $val
	$win.sandbox configure -detime {}
    }

}
