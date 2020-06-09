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

# session summary type, with summary combination arithmetic
snit::type summary {
    option -start {}
    option -end {}
    option -play-time {}
    option -length {}
    variable data
    constructor {args} {
	set data [dict create tag $self count 0 time 0 time2 0 chars {}]
    }
    method incr {char {time {}}} {
	if {$time ne {}} {
	    set n [dict get [dict incr data count] count]
	    set t [dict get [dict set data time [expr {[dict get $data time]+$time}]] time]
	    set t2 [dict get [dict set data time2 [expr {[dict get $data time2]+$time*$time}]] time2]
	    set avg [dict get [dict set data avg [expr {double($t)/$n}]] avg]
	    set var [dict get [dict set data var [expr {double($t2)/$n - $avg*$avg}]] var]
	    set rms [dict get [dict set data rms [expr {sqrt($var)}]] rms]
	    set min [dict get [dict set data min [expr {min($time,[dict get $data min])}]] min]
	    set max [dict get [dict set data max [expr {max($time,[dict get $data max])}]] max]
	}
	if { ! [dict exists $data $char]} {
	    dict lappend data chars $char
	    dict set data $char {}
	}
	dict lappend data $char $time
	# dict set times [lsort [dict get 
    }
    method format {} {
	dict with $data {count tag avg var rms min max} {
	    format "%5s %3d min %3.1f avg %3.1f rms %3.1f max %3.1f" $tag $count $min $avg $rms $max
	}
    }
    method get {item} { dict get $data $item }
    method tag {} { $self get tag }
    method count {} { $self get count }
    method time {sum} { $self get time }
    method time2 {sum} { $self get time2 }
    method avg {sum} { $self get avg }
    method var {sum} { $self get var }
    method chars {sum} { $self get chars }
    method times {sum char} { $self get $char }
    method exists {sum char} { dict exists $data $char }
}

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

set pangrams {
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
    {a wizard’s job is to vex chumps quickly in fog}
    {the lazy major was fixing Cupid’s broken quiver}
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

snit::widget sdrtk::cw-echo {
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
	sample {}
	state {}
	last-status {}
	time-warp 1
	reddish-color "#D81B60"
	bluish-color "#1E88E5"
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
    method setup {} {
	#  -source -length
	foreach opt {-challenge-wpm -challenge-tone -response-wpm -response-tone -response-mode -session -source -char-space -word-space -gain -dah-offset} {
	    $self update $opt $options($opt)
	}
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
					session-log [list [list start [clock seconds] $options(-session) $options(-source) $options(-length)]] \
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
			$self status "Session complete\n"
			lappend data(session-log) [list end [clock seconds] $data(play-time)]
			$self score-session
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
			array set data [list  \
					    challenge {} trimmed-challenge {} response {} trimmed-response {} \
					    state wait-challenge-echo ]
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
    # score the results of a timed session
    # take the session log with the accumulated time and session parameters
    #
    proc init-summary {tag} {
	return [dict create tag $tag count 0 time 0 time2 0 chars {} avg 0 var 0 min 10000 max -10000]
    }
    proc incr-summary {sum char time} {
	set n [dict get $sum count]
	incr n
	dict set sum count $n
	set t [expr {[dict get $sum time]+$time}]
	dict set sum time $t
	set t2 [expr {[dict get $sum time2]+$time*$time}]
	dict set sum time2 $t2
	set avg [expr {double($t)/$n}]
	dict set sum avg $avg
	dict set sum var [expr {double($t2)/$n - $avg*$avg}]
	dict set sum min [expr {min($time,[dict get $sum min])}]
	dict set sum max [expr {max($time,[dict get $sum max])}]
	if {$char ni [dict get $sum chars]} { dict lappend sum chars $char }
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
    proc tag-summary {sum} { dict get $sum tag }
    proc count-summary {sum} { dict get $sum count }
    proc time-summary {sum} { dict get $sum time }
    proc time2-summary {sum} { dict get $sum time2 }
    proc avg-summary {sum} { dict get $sum avg }
    proc var-summary {sum} { dict get $sum var }
    proc chars-summary {sum} { dict get $sum chars }
    proc times-summary {sum char} { dict get $sum $char }
    proc exists-summary {sum char} { dict exists $sum $char }
    method score-session {} {
	# puts "score-session"
	# record start time, end time, elapsed trial time, session length
	set total [init-summary total]
	set hit [init-summary hit]
	set miss [init-summary miss]
	set ms [expr {([morse-dit-ms $options(-challenge-wpm)]+[morse-dit-ms $options(-response-wpm)])/2}]
	set start [lindex $data(session-log) 0]
	set end [lindex $data(session-log) end]
	puts "{[join $data(session-log) \n]}"
	foreach entry [lrange $data(session-log) 1 end-1] { 
	    foreach {ch re time} $entry break
	    set l [morse-word-length [$options(-dict)] $ch]
	    set time [expr {$time/(2+$l)/$ms}]
	    set total [incr-summary $total $ch $time]
	    if {$ch eq $re} {
		set hit [incr-summary $hit $ch $time]
	    } else {
		# score the correct answer not given as a miss
		set miss [incr-summary $miss $ch $time]
		# if an incorrect answer was given, score it as a miss, too
		# should be a prosign and not a #, but details
		if {$re ne {}} {
		    set miss [incr-summary $miss $re $time]
		}
	    }
	    # puts $entry
	}
	foreach char [lsort [chars-summary $total]] {
	    set hits {}
	    set misses {}
	    if {[exists-summary $hit $char]} {
		set hits [lsort -real -increasing [times-summary $hit $char]]
	    }
	    if {[exists-summary $miss $char]} {
		set misses [lmap {x} [times-summary $miss $char] {lindex {-} 0}]
	    }
	    #puts [format "%2d $char $hits $misses" [morse-word-length [$options(-dict)] $char]]
	}
	#puts "total [count-summary $total]"
	#puts "hit   [count-summary $hit]"
	#puts "miss  [count-summary $miss]"
	$self status ""
	set percent [expr {int(round(100.0*[count-summary $hit]/[count-summary $total]))}]
	if {[count-summary $miss] == 0} {
	    $self status "${percent}%" right " correct on [count-summary $total] trials.\n" normal
	} else {
	    $self status "${percent}%" wrong " correct on [count-summary $total] trials.\n" normal
	}
    }
    # score the results of a single challenge
    method score-challenge {} {
	lappend data(session-log) [list $data(pre-challenge) $data(trimmed-response) $data(response-time)]
	# puts "score-challenge {$data(pre-challenge)} {$data(trimmed-response)} $data(response-time) ms"
    }
    proc choose {x} {
	# puts "choose from {$x} [expr {int(rand()*[llength $x])}]"
	return [lindex $x [expr {int(rand()*[llength $x])}]]
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
		# puts "sample-draw -> $draw"
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
	    grid [ttk::label $w.v$var -textvar [myvar data($var)]] -row $row -column 1
	    switch $var {
		session-time { set data($var) 0:00 }
		response-time { set data($var) 0 }
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
		    array set data [list time-pause [clock millis] state pause-before-new-challenge]
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
    #
    # about-tab
    #
    method about-tab {w} {
	ttk::frame $w
	pack [text $w.text -width 40 -background lightgrey] -fill both -expand true
	$w.text insert end "" bold "Welcome to Echo\n" \
	    normal "Echo is a CW/Morse code trainer for your ear and your fist. " \
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
		    {short letters} { set data(sample) [split {adegikmnorstuw} {}] }
		    {long letters} { set data(sample) [split {bcfhjlpqvxyz} {}] }
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
    }
    #
    #
    #
    method exposed-options {} { 
	return {
	    -dict -chk -cho -key -keyo -kbd -kbdo -dec1 -dec2 -dto1 -dto2 -dti1 -dti2 -out -length -calibrate
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
# [ ] output statistics into stats tab
# [ ] accumulate statistics to startup file
# [ ] accumulate layers of statistics
