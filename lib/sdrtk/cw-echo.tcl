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
package provide sdrtk::quack 1.0.0

package require Tk
package require snit

package require morse::morse
package require morse::itu
package require morse::dicts

package require sdrtk::lscale
package require sdrtk::lradiomenubutton
package require sdrtk::dialbook
package require sdrtk::cw-decode-view

package require midi

#
# generate morse code to be echoed back
#
# echo via key or paddle connected as a MIDI device
# or use the keys of the keyboard or mouse buttons
# or just type the answers.
#
# general options for generated code:
#    speed, inter-letter space, inter-word space, ...
#    tone frequency, ramp on/off, length on/off, level, ...
#    inter-dit-dah frequency shift
#
# general options for response:
#    keyed:
#      key speed, spacing, mode, ...
#      tone frequency, ramp on/off, length on/off, level, ...
#    typed:
#
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
# The general principle is that we are working through a deck of flashcards,
# such as the lines of text in a file, or the words in a file.  We grab a
# bunch of cards from the front of the deck and present them.  When the response
# is 90% correct, we add some more cards, when response is 100% correct, we promote
# the card to the next tranche, which gets reviewed at lower frequency
#
# So the "lesson plan" is simply a recipe for constructing a deck of flash cards.
# Obviously, it contains the letters, numbers, and common ham punctuation marks and
# prosigns.
#
# Starting from the original deck, we draw a primary deck and begin testing on it.
# As elements in the primary deck are learned, they promote to a secondary deck and
# the primary deck is replenished by new draws from the original deck.  The secondary 
# deck is actually structured according to the time to last challenge and success rate.
#
# So we're keeping statistics on each card in the deck, challenges, misses, time to
# answer, overall, and decaying averages.
#
# The general scheme is that we have a set of characters, alphabetic, +numeric, +ham-punctuation,
# +itu-punctuation, +prosigns (though I think the ITU character set covers the prosigns?)
#
# And then we have n-grams and words formed of the characters which we form from a dictionary of
# of english words, a dictionary of callsigns, and a dictionary of abbreviations.
# Even when doing only alphabetics, we need to augment the dictionary of words with the abbreviations
# since they are generally formed of uncommon letter combinations.
#
# Given an order of introduction for the characters, we can introduce ngrams and words once their
# constituent characters have been introduced as singletons.

namespace eval ::sdrtk {} 

# cwops copyright exercises, probably need to go away
set exercises {
    warmup {
	EEEEE TTTTT IIIII MMMMM SSSSS OOOOO HHHHH 00000 55555
	AAAAA NNNNN UUUUU DDDDD VVVVV BBBBB 44444 66666
	ABCDEF GHIJK LMNOP QRSTU VWXYZ 12345 67890 / , . ? <SK> <AR> <BT>
	THE QUICK BROWN FOX JUMPS OVER THE LAZY DOGS BACK 7 0 3 6 4 5 1 2 8 9
    }
    exercise {
	AAAAA BBBBB CCCCC DDDDD EEEEE FFFFF GGGGG HHHHH IIIII JJJJJ
	KKKKK LLLLL MMMMM NNNNN OOOOO PPPPP QQQQQ RRRRR
	SSSSS TTTTT UUUUU VVVVV WWWWW XXXXX YYYYY ZZZZZ
	11111 22222 33333 44444 55555 66666 77777 88888 99999 00000
    }
    drill {
	THE QUICK BROWN FOX JUMPS OVER THE LAZY DOGS BACK 7 0 3 6 4 5 1 2 8 9
	THE QUICK BROWN FOX JUMPS OVER THE LAZY DOGS BACK 7 0 3 6 4 5 1 2 8 9
	BENS BEST BENT WIRE/5
	, , , , , . . . . .
	BENS BEST BENT WIRE/5
	? ? ? ? ? 
	BENS BEST BENT WIRE/5
	/ / / / / * * * * * + + + + + = = = = =
    }
}

snit::widget sdrtk::quack {
    option -chk -default {};	# challenge keyer
    option -cho -default {};	# challenge keyer oscillator
    option -key -default {};	# response keyer
    option -keyo -default {};	# response keyer oscillator
    option -kbd -default {};	# response keyboard
    option -kbdo -default {};	# response keyboard oscillator
    option -dto1 -default {};	# challenge detone (not used)
    option -dto2 -default {};	# response detone (not used)
    option -dti1 -default {};	# challenge detimer
    option -dti2 -default {};	# response detimer
    option -dec1 -default {};   # challenge decoder
    option -dec2 -default {};	# response decoder
    option -out -default {};	# output mixer
    option -cas -default {}; 	# keyboard keys
    option -dict -default builtin; # decoding dictionary
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    option -calibrate -default 0; # run calibrating challenge response timing
    
    # source of challenge
    option -source -default letters
    option -source-label {Source}
    # retired: callsigns abbrevs qcodes prefixes suffixes words phrases sentences
    option -source-values -default {{short letters} {long letters} letters digits characters}
    # length of challenge in characters
    option -length -default 1
    option -length-label {Length}
    option -length-values {1 2 3 4 5 6 ...}
    # length of session in minutes
    option -session -default 1
    option -session-label {Session Length}
    option -session-values -default {0.5 1 2 5 10 15 20}
    # speed of challenge
    option -challenge-wpm 30
    option -challenge-wpm-label {Challenge WPM}
    option -challenge-wpm-values {15 17.5 20 22.5 25 27.5 30 32.5 35 40 50}
    # frequency of challenge sidetone
    option -challenge-tone E5
    option -challenge-tone-label {Challenge Tone}
    option -challenge-tone-values [lreverse {C4 C4# D4 D4# E4 F4 F4# G4 G4# A5 A5# B5 C5 C5# D5 D5# E5 F5 F5# G5 G5# A6 A6# B6}]
    # character space padding, farnsworth here
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
    option -response-wpm-values {12.5 15 17.5 20 22.5 25 27.5 30 32.5 35 40}
    # frequency of challenge sidetone
    option -response-tone F5
    option -response-tone-label {Response Tone}
    option -response-tone-values [lreverse {C4 C4# D4 D4# E4 F4 F4# G4 G4# A5 A5# B5 C5 C5# D5 D5# E5 F5 F5# G5 G5# A6 A6# B6}]
    # mode of response keyer
    option -response-mode B
    option -response-mode-label {Keyer Mode}
    option -response-mode-values {A B}
    # offset of dah tone from dit tone
    option -dah-offset 0
    option -dah-offset-label {Dah Tone Offset}
    option -dah-offset-values {-0.10 -0.05 -0.02 -0.01 0 0.01 0.02 0.05 0.10}
    # output gain
    option -gain 0
    option -gain-label {Output Gain}
    option -gain-values {-30 -20 -15 -12 -9 -6 -3 0 3 6}
    
    variable data -array {
	handler {}
	pre-challenge {}
	challenge {}
	challenge-trimmed {}
	response {}
	response-trimmed {}
	state {}
	last-status {}
	time-warp 1
	reddish-color "#D81B60"
	bluish-color "#1E88E5"
	config-options {-challenge-wpm -challenge-tone -response-wpm -response-tone -response-mode -session -source -length -char-space -word-space -gain -dah-offset}
	summary {} 
	sample-chars {}
	sample-words {}
	sample {}
	pangrams {
	    {quick zephyrs blow, vexing daft jim}
	    {the five boxing wizards jump quickly}
	    {sphinx of black quartz, judge my vow}
	    {waltz, bad nymph, for quick jigs vex}
	    {the five boxing wizards jump quickly}
	    {five quacking zephyrs jolt my wax bed}
	    {two driven jocks help fax my big quiz}
	    {pack my box with five dozen liquor jugs}
	    {a quick brown fox jumps over the lazy dog}
	    {jinxed wizards pluck ivy from the big quilt}
	    {the quick brown fox jumps over the lazy dog}
	    {amazingly few discotheques provide jukeboxes}
	    {a wizard's job is to vex chumps quickly in fog}
	    {the lazy major was fixing Cupid's broken quiver}
	    {my faxed joke won a pager in the cable TV quiz show}
	    {six boys guzzled cheap raw plum vodka quite joyfully}
	    {my girl wove six dozen plaid jackets before she quit}
	    {crazy Fredrick bought many very exquisite opal jewels}
	    {six big devils from Japan quickly forgot how to waltz}
	    {sixty zippers were quickly picked from the woven jute bag}
	    {few black taxis drive up major roads on quiet hazy nights}
	    {just keep examining every low bid quoted for zinc etchings}
	    {jack quietly moved up front and seized the big ball of wax}
	    {a quick movement of the enemy will jeopardize six gunboats}
	    {we promptly judged antique ivory buckles for the next prize}
	    {whenever the black fox jumped the squirrel gazed suspiciously}
	    {jaded zombies acted quaintly but kept driving their oxen forward}
	    {the job requires extra pluck and zeal from every young wage earner}
	    {a quart jar of oil mixed with zinc oxide makes a very bright paint}
	    {a mad boxer shot a quick, gloved jab to the jaw of his dizzy opponent}
	    {just work for improved basic techniques to maximize your typing skill}
	    {the public was amazed to view the quickness and dexterity of the juggler}
	    {gaze at this sentence for just about sixty seconds and then explain what makes it quite different from the average sentence}
	}
    }
    
    constructor {args} {
	puts "quack::constructor $self ($win) $args"
	$self configurelist $args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind all <KeyPress> [mymethod keypress %A]
	bind $win <Destroy> [list destroy .]
	# five tabs in a notebook
	pack [ttk::notebook $win.echo] -fill both -expand true
	$win.echo add [$self play-tab $win.play] -text Echo
	$win.echo add [$self setup-tab $win.setup] -text Setup
	$win.echo add [$self stats-tab $win.stats] -text Stats
	$win.echo add [$self about-tab $win.about] -text About
	$win.echo add [$self sandbox-tab $win.sandbox] -text Sandbox
	$win.echo add [$self dial-tab $win.dial] -text Dial
	bind $win.echo <<NotebookTabChanged>> [mymethod swaptabs]
	after 500 [mymethod setup]
    }

    method swaptabs {} {
	switch -glob [$win.echo select] {
	    *play {
		# steal back the detimer on keyboard and key
		if {[$options(-dec2) cget -detime] eq {}} {
		    $options(-dec2) configure -detime [$win.sandbox cget -detime]
		    $win.sandbox configure -detime {}
		}
	    }
	    *stats {
		# draw the current statistics
		$self stats-draw $win.stats
	    }
	    *setup {
	    }
	    *sandbox {
		# steal the detimer on keyboard and key
		# $win.play configure -detime {}
		if {[$win.sandbox cget -detime] eq {}} {
		    $win.sandbox configure -detime [$options(-dec2) cget -detime]
		    $options(-dec2) configure -detime {}
		}
	    }
	    *about {
	    }
	    *dial {
	    }
	    default {
		error "uncaught NotebookTabChanged select [$win.echo select]"
	    }
	}
    }
    method keypress {a} { $options(-kbd) puts [string toupper $a] }
    #
    # configuration and history
    #
    proc read-data {file} {
	if {[catch {open $file r} fp]} { return {} }
	if {[catch {read $fp} data]} { close $fp; return {} }
	catch {close $fp}
	return $data
    }
    proc write-data {file data} {
	if {[catch {open $file w} fp]} { return {} }
	if {[catch {puts $fp $data}]} { close $fp; return {} }
	catch {close $fp}
	return $data
    }
    proc append-data {file data} {
	if {[catch {open $file a} fp]} { return {} }
	if {[catch {puts $fp $data}]} { close $fp; return {} }
	catch {close $fp}
	return $data
    }
    method initialize-quack-config {} { 
	if { ! [file exists ~/.config/quack/config.tcl]} {
	    if { ! [file exists ~/.config/quack]} {
		if { ! [file exists ~/.config]} {
		    file mkdir ~/.config
		}
		file mkdir ~/.config/quack
	    }
	    write-data ~/.config/quack/config.tcl {}
	    write-data ~/.config/quack/history.tcl {}
	    write-data ~/.config/quack/pangrams.tcl $data(pangrams)
	}
    }
    method load-quack-config {} { array set options [string trim [read-data ~/.config/quack/config.tcl]] }
    method load-quack-history {} { set data(history) [read-data ~/.config/quack/history.tcl] }
    method save-quack-config {} { write-data ~/.config/quack/config.tcl [concat {*}[lmap opt $data(config-options) {list $opt $options($opt)}]] }
    method append-quack-history {session} { 
	append-data ~/.config/quack/history.tcl "{$session}"
	lappend data(history) $session
    }
    method clear-quack-config {} { exec cat /dev/null > ~/.config/quack/quack.tcl }
    method clear-quack-history {} { exec cat /dev/null > ~/.config/quack/history.tcl }
    method setup {} {
	$self initialize-quack-config
	$self load-quack-config
	$self load-quack-history
	$self history-update
	foreach opt $data(config-options) { $self update $opt $options($opt) }
	$win.echo select $win.play
	$win.play.text tag configure wrong -foreground $data(reddish-color)
	$win.play.text tag configure right -foreground $data(bluish-color)
	set data(state) start
    }

    #
    # state machine
    #
    method timeout {} {
	while {1} {
	    # check if explicitly paused
	    # the status message is repeated, but not shown 
	    # because it matches the previous status message
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
	    set data(n-t-c) [string length $data(trimmed-challenge)]
	    # update response text
	    append data(response) [$options(-dec2) get]
	    # trimmed response
	    set data(trimmed-response) [regsub -all { } $data(response) {}]
	    set data(n-t-r) [string length $data(trimmed-response)]
	    # switch on state
	    # puts "$data(state)"
	    switch $data(state) {
		start {
		    array set data [list \
					session-time 0 \
					session-time-limit [expr {int($options(-session)*60*1000)}] \
					session-stamps [list play [clock millis]] \
					session-log [list start [clock seconds] $options(-session) \
							 wpm $options(-challenge-wpm) $options(-response-wpm) \
							 source $options(-source) $options(-length)] \
					sample [$self sample-make] \
					response-time 0 \
					challenges 0 \
					hits 0 \
					misses 0 \
					passes 0 \
					pre-challenge {} \
					challenge {} \
					trimmed-challenge {} \
					response {} \
					trimmed-response {} \
					time-wait [clock millis] \
					time-challenge 0 \
					time-of-echo 0 \
					time-to-echo 0 \
					state wait-before-new-challenge \
				       ]
		}
		wait-before-new-challenge {
		    if {$data(play-time) >= $data(session-time-limit)} {
			lappend data(session-log) end [clock seconds] $data(play-time)
			$self status "Session complete, [$self score-session]\n"
			$self play-button play/pause
			set data(state) start
			continue
		    }
		    # should this timeout be a word space?
		    if {[clock millis]-$data(time-wait) > 250} {
			set data(state) new-challenge
		    }
		}
		new-challenge {
		    if {$options(-chk) ne {} && ! [$options(-chk) is-busy]} {
			array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} state wait-challenge-echo ]
			set data(pre-challenge) [$self sample-draw]
			set data(n-p-c) [string length $data(pre-challenge)]
			set data(time-challenge) [clock millis]
			set data(challenge-dits) [morse-word-length [$options(-dict)] $data(pre-challenge)]
			set data(challenge-dit-ms) [morse-dit-ms $options(-challenge-wpm)]
			set data(response-dit-ms) [morse-dit-ms $options(-response-wpm)]
			set data(challenge-response-ms) [expr {$data(challenge-dits)*($data(challenge-dit-ms)+$data(response-dit-ms))}]
			$options(-chk) puts [string toupper $data(pre-challenge)]
		    }
		}
		wait-challenge-echo {
		    # $self status "Waiting for challenge to echo ..." normal
		    if {$data(n-p-c) > $data(n-t-c)} {
			# waiting for more input
			break
		    }
		    if {[string first $data(pre-challenge) $data(trimmed-challenge)] >= 0} {
			# $self status "\n" normal
			set t [clock millis]
			array set data [list time-of-echo $t time-to-echo [expr {8*$data(time-warp)*($t-$data(time-challenge))}] state wait-response-echo]
			# puts "time-to-echo $data(time-to-echo)"
			if {$options(-calibrate)} {
			    $options(-kbd) puts $data(trimmed-challenge)
			}
			continue
		    } 
		    if {$data(n-t-c) != 0} {
			# $self status "\n" normal
			# puts "wait-challenge-echo {$data(pre-challenge)} and {$data(challenge)}"
			array set data [list time-wait [clock millis] state wait-before-new-challenge]
			continue
		    }
		    break
		}
		wait-response-echo {
		    # $self status "Waiting for response ... {$data(trimmed-challenge)} {$data(trimmed-response)}" normal
		    set data(response-time) [format %.0f [expr {[clock millis]-$data(time-challenge)}]]
		    if {[string first $data(trimmed-challenge) $data(trimmed-response)] >= 0} {
			$self status {}
			$self status $data(trimmed-challenge) right " is correct!\n" normal
			$self score-challenge; # hits
			array set data [list time-wait [clock millis] state wait-before-new-challenge]
			break
		    }
		    if {$data(n-t-r) > 0 && [string first $data(trimmed-response) $data(trimmed-challenge)] < 0} {
			$self status {}
			$self status "$data(trimmed-response)" wrong " is not $data(trimmed-challenge)!\n" normal
			$self score-challenge; # misses
			array set data [list time-wait [clock millis] state wait-before-new-challenge]
			break
		    }
		    if {[clock millis] > $data(time-of-echo)+$data(time-to-echo)} {
			$self score-challenge; # pass
			$self status {}
			$self status "$data(trimmed-challenge)" right " was the answer.\n"
			array set data [list time-wait [clock millis] state wait-before-new-challenge]
			continue
		    }
		}
		default { error "uncaught state $data(state)" }
	    }
	    break
	}
	set data(handler) [after 10 [mymethod timeout]]
    }
    method status {args} { 
	if {$data(last-status) ne $args} {
	    set data(last-status) $args
	    $win.play.text insert end {*}$args
	    $win.play.text see end
	    # puts -nonewline [join $args { }]
	}
    }
    #
    # maintain the count of play time and pause time for the current session in milliseconds
    # also maintain the start time and end time in seconds from unix epoch
    #
    proc format-time {millis} {
	# return [format {%d:%02d:%03d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}] [expr {$millis%1000}]]
	return [format {%d:%02d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}]]
    }
    proc accumulate-playtime {args} {
	#puts "accumulate-playtime $args"
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
	return $playtime
    }

    #
    # score the results of a timed session over single characters
    # take the session log with the accumulated time and session parameters
    # the 'summary' is a statistical summary of the responses
    #
    proc sum {args} { tcl::mathop::+ {*}$args }
    proc sum2 {args} { tcl::mathop::+ {*}[lmap {x} $args {expr {$x*$x}}] }
    proc avg {args} { expr {double([sum {*}$args])/[llength $args]} }
    proc avg2 {args} { expr {double([sum2 {*}$args])/[llength $args]} }
    proc var {args} { expr {[avg2 {*}$args]-pow([avg {*}$args],2)} }
    proc quartiles {args} {
	# this is only accidentally correct according to any of the tedious
	# definitions given in wikipedia, but it's easy and obvious to write
	set args [lsort -increasing -real $args]
	set n [llength $args]
	set q1 [expr {max(0,min($n-1,int(round($n*0.25))))}]
	set q2 [expr {max(0,min($n-1,int(round($n*0.50))))}]
	set q3 [expr {max(0,min($n-1,int(round($n*0.75))))}]
	list [lindex $args 0] [lindex $args $q1] [lindex $args $q2] [lindex $args $q3] [lindex $args end]
    }
    proc percent {n m} { expr {int(round(100.0*$n/$m))} }
    proc init-summary {tag} { dict create tag $tag times {} chars {} }
    proc tag-summary {sum} { dict get $sum tag }
    proc times-summary {sum} { dict get $sum times }
    proc count-summary {sum} { llength [times-summary $sum] }
    proc time-summary {sum} { sum {*}[times-summary $sum] }
    proc time2-summary {sum} { sum2 {*}[times-summary $sum] }
    proc avg-summary {sum} { avg {*}[times-summary $sum] }
    proc var-summary {sum} { var {*}[times-summary $sum] }
    proc quartiles-summary {sum} { quartiles {*}[times-summary $sum] }
    proc chars-summary {sum} { dict get $sum chars }
    proc char-times-summary {sum char} { if {[dict exists $sum $char]} { dict get $sum $char } else { list } }
    proc char-count-summary {sum char} { llength [char-times-summary $sum $char] }
    proc char-exists-summary {sum char} { dict exists $sum $char }
    proc char-quartiles-summary {sum char} { quartiles {*}[char-times-summary $sum $char] }

    proc incr-summary {sum char time} {
	if {$char ni [dict get $sum chars]} { dict lappend sum chars $char }
	dict lappend sum times $time
	dict lappend sum $char $time
	return $sum
    }

    proc format-summary {sum} {
	set n [dict get $sum count]
	set tag [dict get $sum tag]
	set avg [dict get $sum avg]
	set var [dict get $sum var]
	set rms [expr {sqrt($var)}]
	set min [dict get $sum min]
	set max [dict get $sum max]
	return [format "%5s %3d min %3.1f avg %3.1f rms %3.1f max %3.1f" $tag $n $min $avg $rms $max]
    }
    proc session-summary {sum morse session} {
	set start [lrange $session 0 2]
	set wpm [lrange $session 3 5]
	set source [lrange $session 6 8]
	set end [lrange $session end-2 end]
	set ms [expr {([morse-dit-ms [lindex $wpm 1]]+[morse-dit-ms [lindex $wpm 2]])/2}]
	foreach {ch re time} [lrange $session 9 end-3] { 
	    set l [morse-word-length $morse $ch]
	    set time [expr {$time/(2+$l)/$ms}]
	    dict set sum total [incr-summary [dict get $sum total] $ch $time]
	    if {$ch eq $re} {
		dict set sum hit [incr-summary [dict get $sum hit] $ch $time]
	    } else {
		# score the correct answer not given as a miss
		dict set sum miss [incr-summary [dict get $sum miss] $ch $time]
		# if an incorrect answer was given, score it as a miss, too
		# should be a prosign and not a #, but details
		if {$re ne {}} {
		    dict set sum miss [incr-summary [dict get $sum miss] $re $time]
		}
	    }
	    # puts $entry
	}
	set chars [lsort [chars-summary [dict get $sum total]]]
	foreach char $chars {
	    set hits {}
	    set misses {}
	    if {[char-exists-summary [dict get $sum hit] $char]} {
		set hits [lsort -real -increasing [char-times-summary [dict get $sum hit] $char]]
	    }
	    if {[char-exists-summary [dict get $sum miss] $char]} {
		set misses [lmap {x} [char-times-summary [dict get $sum miss] $char] {lindex {-} 0}]
	    }
	}
	return $sum
    }

    proc init-session-summary {} { dict create total [init-summary total] hit [init-summary hit] miss [init-summary miss] }

    proc history-summary {sessions morse {filter {}}} {
	if {$sessions eq {}} { return {} }
	set summary [init-session-summary]
	foreach session $sessions {
	    if {$filter eq {} || [$filter $session]} {
		set summary [session-summary $summary $morse $session]
	    }
	}
	set total [dict get $summary total]
	set hit [dict get $summary hit]
	set miss [dict get $summary miss]
	set stats {}
	lappend stats [list { } [percent [count-summary $hit] [count-summary $total]] {*}[quartiles-summary $hit]]
	set chars [lsort [chars-summary $total]]
	if {1} {
	    # sort chars by dit length
	    set lengths [lmap c $chars {morse-word-length $morse $c}]
	    # puts $lengths
	    set indices [lsort -indices -increasing -integer $lengths]
	    set chars [lmap i $indices {lindex $chars $i}]
	}
	foreach char $chars {
	    set ntot [char-count-summary $total $char]
	    set nhit [char-count-summary $hit $char]
	    set nmiss [char-count-summary $miss $char]
	    # puts "$char total $ntot hit $nhit miss $nmiss"
	    lappend stats [list $char [percent $nhit [expr {$nmiss+$nhit}]] {*}[char-quartiles-summary $hit $char]]
	}
	return $stats
    }

    method history-update {} {
	set data(summary) [history-summary $data(history) [$options(-dict)]]
    }

    method score-session {} {
	# puts "score-session"
	# record start time, end time, elapsed trial time, session length
	$self append-quack-history $data(session-log)
	$self history-update
	set s [session-summary [init-session-summary] [$options(-dict)] $data(session-log)]
	return "[percent [count-summary [dict get $s hit]] [count-summary [dict get $s total]]]% correct"
    }

    # score the results of a single challenge
    method score-challenge {} {
	lappend data(session-log) $data(pre-challenge) $data(trimmed-response) $data(response-time)
	# puts "score-challenge {$data(pre-challenge)} {$data(trimmed-response)} $data(response-time) ms"
    }
    proc choose {x} {
	# puts "choose from {$x} [expr {int(rand()*[llength $x])}]"
	return [lindex $x [expr {int(rand()*[llength $x])}]]
    }
    method sample-make {} {
	set dist [concat {*}[lmap x [lsort -index 0 [lrange $data(summary) 1 end]] {lrange $x 0 1}]]
	set sample {}
	foreach char $data(sample-chars) {
	    set char [string toupper $char]
	    set n [expr {100-([dict exists $dist $char]?[dict get $dist $char]:0)}]
	    if {$n > 10} {
		lappend sample {*}[lrepeat $n $char]
	    }
	}
	return $sample
    }
    method sample-draw {} {
	switch $options(-source) {
	    {short letters} -
	    {long letters} -
	    letters -
	    digits -
	    characters {
		set draw {}
		for {set i 0} {$i < $options(-length)} {incr i} {
		    append draw [choose $data(sample)]
		}
		set draw [string toupper $draw]
		return $draw
	    }
	    warmup {
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
	}
	pack [ttk::frame $w] -side top -expand true -fill x
	set row 0
	# response-time hits misses passes
	foreach var {session-time challenge-wpm response-wpm} {
	    grid [ttk::label $w.l$var -text "$var: "] -row $row -column 0
	    if {$var in {challenge-wpm response-wpm source}} {
		grid [ttk::label $w.v$var -textvar [myvar options(-$var)]] -row $row -column 1
	    } else {
		grid [ttk::label $w.v$var -textvar [myvar data($var)]] -row $row -column 1
	    }
	    switch $var {
		session-time { set data($var) 0:00 }
		response-time { set data($var) 0 }
		source -
		challenge-wpm -
		response-wpm { }
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
		    array set data [list time-pause [clock millis] state wait-before-new-challenge]
		    set data(handler) [after 10 [mymethod timeout]]
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
	pack [sdrtk::cw-decode-view $w] -fill both -expand true
	return $w
    }
    #
    # dial-tab
    #
    method dial-tab {w} {
	::sdrtk::dialbook $w
	foreach text [lsort [::options get-opts]] {
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
    # stats-tab
    #
    method stats-tab {w} {
	ttk::frame $w
	pack [canvas $w.c -background lightgrey] -fill both -expand true
	return $w
    }
    method stats-draw {w} {
	$w.c delete all
	for {set i 0} {$i < [llength $data(summary)]} {incr i} {
	    $self stats-draw-row $w $i [lindex $data(summary) $i] 
	}
    }
    method stats-draw-row {w i row} {
	# puts "stats-draw-row $w $i $row"
	lassign $row char percent min q1 median q3 max
	# row label
	$w.c create text 0 0 -text [format "$char %3d%%" $percent] -anchor nw -tag [list text$i row$i] -font {Courier 12}
	# percent correct
	if {$percent != 0} { $w.c create rectangle 0 0.1 $percent 0.9 -fill $data(bluish-color) -tag [list rect$i row$i] }
	if {$percent != 100} { $w.c create rectangle $percent 0.1 100 0.9 -fill $data(reddish-color) -tag [list rect$i row$i] }
	if {$min ne {}} {
	    # box and whiskers verticals
	    $w.c create line $min 0.1 $min 0.9 -tag [list box$i row$i]
	    $w.c create line $q1 0.1 $q1 0.9 -tag [list box$i row$i]
	    $w.c create line $median 0.1 $median 0.9 -width 2 -tags [list box$i row$i]
	    $w.c create line $q3 0.1 $q3 0.9 -tag [list box$i row$i]
	    $w.c create line $max 0.1 $max 0.9 -tag [list box$i row$i]
	    # box and whiskers horizontals
	    $w.c create line $min 0.5 $q1 0.5 -tags [list box$i row$i]
	    $w.c create line $q3 0.5 $max 0.5 -tags [list box$i row$i]
	    $w.c create line $q1 0.1 $q3 0.1 -tags [list box$i row$i]
	    $w.c create line $q1 0.9 $q3 0.9 -tags [list box$i row$i]
	}
	# scale
	$w.c scale rect$i 0 0 1 18
	if {$min ne {}} { $w.c scale box$i 0 0 30 18 }
	$w.c move row$i 0 [expr {$i*18}]
	$w.c move text$i 10 0
	$w.c move rect$i 70 0
	if {$min ne {}} { $w.c move box$i 150 0 }
    }
    #
    # about-tab
    #
    method about-tab {w} {
	ttk::frame $w
	pack [text $w.text -width 40 -background lightgrey] -fill both -expand true
	$w.text insert end "" bold "Welcome to Quack\n" \
	    normal "Quack is a CW/Morse code trainer for your ear and your fist. " \
	    normal "Click" italic {[Play]} normal " on the " italic "Play" normal "tab and the computer will play morse code for you." \
	    normal "Echo the code back and Echo will collect statistics on your speed and accuracy."
	return $w
    }
    #
    # setup-tab
    #
    method setup-tab {w} {
	ttk::frame $w
	set row 0
	#  -source -length
	foreach opt {-challenge-wpm -challenge-tone -response-wpm -response-tone -response-mode -source -session -char-space -word-space -gain -dah-offset} {
	    ttk::label $w.l$opt -text "$options($opt-label): "
	    sdrtk::radiomenubutton $w.x$opt \
		-defaultvalue $options($opt) \
		-variable [myvar options($opt)] \
		-values $options($opt-values) \
		-command [mymethod update $opt]
	    if {[info exists options($opt-labels)]} {
		$w.x$opt configure -labels $options($opt-labels)
	    }
	    grid $w.l$opt -row $row -column 0 -sticky ew
	    grid $w.x$opt -row $row -column 1 -sticky ew
	    incr row
	}
	# -gain -dah-offset
	foreach opt {} {
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
		    {short letters} { set data(sample-chars) [split {adegikmnorstuw} {}] }
		    {long letters} { set data(sample-chars) [split {bcfhjlpqvxyz} {}] }
		    letters { set data(sample-chars) [split {abcdefghijklmnopqrstuvwxyz} {}] }
		    digits { set data(sample-chars) [split {0123456789} {}] }
		    punctuation { set data(sample-chars) [split {.,?/-=+*} {}] }
		    characters { set data(sample-chars) [split {abcdefghijklmnopqrstuvwxyz0123456789.,?/-=+*} {}] }
		    callsigns { set data(sample-words) [morse-pileup-callsigns] }
		    abbrevs { set data(sample-words) [morse-ham-abbrev] }
		    qcodes { set data(sample-words) [morse-ham-qcodes] }
		    words { set data(sample-words) [morse-voa-vocabulary] }
		    suffixes { }
		    prefixes { }
		    phrases { }
		    default { error "uncaught -source $val" }
		}
		$self sample-trim
	    }
	    -length { $self sample-trim }
	    -session { }
	    -challenge-wpm { 
		::options cset -$options(-chk)-wpm $val
		::options cset -$options(-dti1)-wpm $val
		set data(time-warp) [expr {$options(-challenge-wpm)/$options(-response-wpm)}]
	    }
	    -challenge-tone { 
		set cfreq [::midi::note-to-hertz [::midi::name-octave-to-note $val]]
		::options cset -$options(-dto1)-freq $cfreq
		::options cset -$options(-cho)-freq $cfreq
		$self update -dah-offset $options(-dah-offset)
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
		$self update -dah-offset $options(-dah-offset)
	    }
	    -response-mode {
		::options cset -$options(-key)-mode $val
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
	$self save-quack-config
    }
    #
    #
    #
    method exposed-options {} { 
	return {
	    -dict -chk -cho -key -keyo -kbd -kbdo -dec1 -dec2 -dto1 -dto2 -dti1 -dti2 -out -cas -length -calibrate
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
	    -cas { return {keyboard keys} }
	    -length { return {length of challenges} }
	    -calibrate { return {calibrate response times} }
	    default { puts "no info-option for $opt" }
	}
    }
    
    method ConfigText {opt val} { $hull configure $opt $val }
    method {Config -dti2} {val} { 
	set options(-dti2) $val
    }
    
}

#
# todo 2020-06-07
# [x] implement color blind friendly colors reddish #d81b60, bluish #1e88e5
# [x] accumulate statistics to startup file
# [ ] output statistics into stats tab
# [ ] output layered statistics to show progress
# [ ] use statistics to target drills
