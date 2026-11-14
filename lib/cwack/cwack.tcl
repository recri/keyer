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
package provide cwack::cwack 1.0.0

package require Tk
package require snit

package require morse::morse
package require morse::itu
package require morse::dicts

package require sdrtk::dialbook
package require sdrtk::cw-decode-view

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
# +itu-punctuation, +prosigns (though I think the ITU character set covers the prosigns?) (wrong)
#
# And then we have n-grams and words formed of the characters which we form from a dictionary of
# of english words, a dictionary of callsigns, and a dictionary of abbreviations.
# Even when doing only alphabetics, we need to augment the dictionary of words with the abbreviations
# since they are generally formed of uncommon letter combinations.
#
# Given an order of introduction for the characters, we can introduce ngrams and words once their
# constituent characters have been introduced as singletons.

namespace eval sdrtk {} 
namespace eval cwack {}

package require cwack::mathfunc
package require cwack::progressbar
package require cwack::lscale
package require cwack::lradiobutton

snit::widget cwack::cwack {
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
    option -dec1 -default {};	# challenge decoder
    option -dec2 -default {};	# response decoder
    option -out -default {};	# output mixer
    option -cas -default {}; 	# keyboard keys
    option -dict -default morse-itu-dict;  # decoding dictionary
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
    # new options
    # number of repeats after initial prompt 1..unlimited
    # display prompts
    # display responses
    # prompt resevoir - file name, read in, sort lines by dit-length,
    # externalize built in prompt as file

    # retired option: source of challenge
    option -source -default {itu characters}
    option -source-label {Source}
    
    # retired values: callsigns abbrevs qcodes prefixes suffixes words phrases sentences
    option -source-values -default {{short letters} letters alphanumerics characters {itu characters}}
    
    # retired option: length of challenge in characters
    option -length -default 1
    option -length-label {Length}
    option -length-values {1 2 3 4 5 6 ...}
    
    # length of session in minutes
    option -session -default 1
    option -session-label {Session}
    option -session-tooltip {Session length in minutes}
    option -session-values -default {1 120}
    
    # speed
    option -wpm 30
    option -wpm-label {WPM}
    option -wpm-tooltip {Words per minute}
    option -wpm-values {12.5 15 17.5 20 22.5 25 27.5 30 32.5 35 40 50}
    
    # frequency of response sidetone
    option -tone 600
    option -tone-label {Tone}
    option -tone-tooltip {Tone used for user keyer}
    option -tone-values {400 1000}
    
    # frequency of challenge sidetone
    option -challenge-tone 550
    option -challenge-tone-label {Tone2}
    option -challenge-tone-tooltip {Tone used for cwack keyer}
    option -challenge-tone-values {400 1000}
    
    # retired option: character space padding, farnsworth here
    option -char-space 3
    option -char-space-label {Char Spacing}
    option -char-space-values {3 3.5 4 4.5 5 5.5 6}
    
    # retired option: word space padding
    option -word-space 7
    option -word-space-label {Word Spacing}
    option -word-space-values {7 8 9 10 11 12 13 14}
    
    # mode of response keyer
    option -mode B
    option -mode-label {Mode}
    option -mode-tooltip {Keyer operation mode}
    option -mode-values {A B}
    
    # swap paddles
    option -swap 0
    option -swap-label {Swap}
    option -swap-tooltip {Swap dit and dah paddles}
    option -swap-values {0 1}
    
    # offset of dah tone from dit tone
    option -dah-offset 0.0
    option -dah-offset-label {Offset}
    option -dah-offset-tooltip {Offset of dah tone from base tone.}
    option -dah-offset-values {-50 50}
    
    # output gain
    option -gain 0
    option -gain-label {Volume}
    option -gain-tooltip {Output gain in decibels}
    option -gain-values {-30 -20 -15 -12 -9 -6 -3 0 3 6}
    
    # retired as option, just repeat: repeat or continue on error
    option -on-error {Continue}
    option -on-error-label {Action on error}
    option -on-error-values {Repeat Continue}
    
    # iambic keyer to use (the -values are a cheat, I know the answer)
    option -keyer vk6ph
    option -keyer-label {Keyer}
    option -keyer-tooltip {Implementation of iambic keyer}
    option -keyer-values {ad5dz dttsp k1el nd7pa vk6ph}
    
    # difficulty of challenges, average length in dit clocks
    option -difficulty 0
    option -difficulty-label {Difficulty}
    option -difficulty-tooltip {Percentage of word list skipped over}
    option -difficulty-values {0 100}
    
    # spread of challenges, sd of lengths in dit clocks
    option -spread 0
    option -spread-label {Spread}
    option -spread-tooltip {Standard deviation of challenges in dit clocks}
    option -spread-values {0 10}
    
    # bias toward words over letters
    option -wordish 0.5
    option -wordish-label {Wordish}
    option -wordish-tooltip {Bias towards more words than letters.}
    option -wordish-values {0 1}

    variable data -array {
	handler {}
	pre-challenge {}
	challenge {}
	challenge-trimmed {}
	response {}
	response-trimmed {}
	state {}
	reddish-color "#D81B60"
	bluish-color "#1E88E5"
	black "#111"
	gray "#777"
	config-options {-wpm -difficulty -spread -wordish -session -tone -challenge-tone -mode -swap -keyer -gain -dah-offset}
	summary {} 
	dits {}
	sample {}
	timepct 0
	hitpct 0
	
	words-list-name {overlearn}
	current-words-list {}
	current-words-list-name {}
	prompt-set-size 48
	number-of-repeat-prompts 0
	last-result {}
	elapsed-time 0
	n-correct 0
	n-wrong 0
	n-passed 0
	n-total 0
    }
    # difficulty moved to options(-difficulty)
    constructor {args} {
	$self configurelist $args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind all <KeyPress> [mymethod keypress %A]
	bind $win <Destroy> [list destroy .]
	# five tabs in a notebook
	pack [ttk::notebook $win.echo] -fill both -expand true
	$win.echo add [$self play-tab $win.play] -text Play
	$win.echo add [$self about-tab $win.about] -text About
	$win.echo add [$self sandbox-tab $win.sandbox] -text Sandbox
	$win.echo add [$self option-tab $win.dial] -text Options
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
	    *option {
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
    method initialize-cwack-config {} { 
	if { ! [file exists ~/.config/cwack/config.tcl]} {
	    if { ! [file exists ~/.config/cwack]} {
		if { ! [file exists ~/.config]} {
		    file mkdir ~/.config
		}
		file mkdir ~/.config/cwack
	    }
	    write-data ~/.config/cwack/config.tcl {}
	    write-data ~/.config/cwack/history.tcl {}
	}
    }
    method load-cwack-config {} { array set options [string trim [read-data ~/.config/cwack/config.tcl]] }
    method load-cwack-history {} { set data(history) [read-data ~/.config/cwack/history.tcl] }
    method save-cwack-config {} { write-data ~/.config/cwack/config.tcl [concat {*}[lmap opt $data(config-options) {list $opt $options($opt)}]] }
    method append-cwack-history {session} { 
	append-data ~/.config/cwack/history.tcl "{$session}"
	lappend data(history) $session
    }
    method clear-cwack-config {} { exec cat /dev/null > ~/.config/cwack/cwack.tcl }
    method clear-cwack-history {} { exec cat /dev/null > ~/.config/cwack/history.tcl }
    method setup {} {
	$self initialize-cwack-config
	$self load-cwack-config
	$self load-cwack-history
	$self history-update
	foreach opt $data(config-options) { $self update $opt $options($opt) }
	$win.echo select $win.play
	$win.play.text tag configure wrong -foreground $data(reddish-color)  -justify center
	$win.play.text tag configure right -foreground $data(bluish-color) -justify center
	$win.play.text tag configure pass  -foreground $data(black) -justify center
	$win.play.text tag configure reddish -foreground $data(reddish-color)
	$win.play.text tag configure bluish -foreground $data(bluish-color)
	$win.play.text tag configure black  -foreground $data(black)
	$win.play.text tag configure gray  -foreground $data(gray)
	$options(-chk) configure -dict $options(-dict)
	$options(-kbd) configure -dict $options(-dict)
	$options(-dec1) configure -dict $options(-dict)
	$options(-dec2) configure -dict $options(-dict)
	set data(state) start
	after 1 [mymethod test]
    }
    
    proc morse-escape-prosign {str} {
	set escaped {}
	foreach c [morse-word-split $str] {
	    if {[regexp {^<(.+)>$} $c all meat]} {
		switch [string length $meat] {
		    2 { append escaped \\$meat }
		    3 { append escaped \\\\$meat }
		    default { error "excessively long prosign $c" }
		}
	    } else {
		append escaped $c
	    }
	}
	return $escaped
    }

    #
    # state machine
    method timeout {} {
	while {1} {
	    # check if explicitly paused
	    if { ! $data(play/pause)} {
		$self status-line "Press Play to continue."
		return
	    }
	    # compute time elapsed
	    set data(play-time) [accumulate-playtime {*}$data(session-stamps) play [clock millis]]
	    set data(session-time) [format-time $data(play-time)]
	    set data(timepct)  [expr {min(100,round(100.0*$data(play-time)/($options(-session)*60*1000)))}]
	    # update challenge text
	    append data(challenge) [$options(-dec1) get]
	    # trimmed challenge
	    set data(trimmed-challenge) [string trim $data(challenge)]
	    set data(n-t-c) [string length $data(trimmed-challenge)]
	    # update response text
	    append data(response) [$options(-dec2) get]
	    # trimmed response, collapse multiple spaces to single space
	    set data(trimmed-response) [string trim [regsub -all {  +} $data(response) { }]]
	    set data(n-t-r) [string length $data(trimmed-response)]
	    # this says that the trimmed response has at least one character, and the last character in the untrimmed response is a space
	    set data(response-space) [expr {$data(n-t-r) > 0 && [regexp {^.* $}  $data(response)]}]
	    # track the results as they change
	    set result "{$data(challenge)} {$data(trimmed-challenge)} {$data(response)} {$data(trimmed-response)} {$data(response-space)}"
	    if {$data(last-result) ne $result} {
		set data(last-result) $result
		# if {$result ne {}} { puts $result }
	    }
	    # switch on state
	    # puts "$data(state)"
	    switch $data(state) {
		start {
		    ## initialize data
		    ## get selected word set
		    ## choose initial prompt set
		    ## initialize scores
		    array set data [list \
					session-time 0 \
					session-time-limit [expr {int($options(-session)*60*1000)}] \
					session-stamps [list play [clock millis]] \
					session-log [list start [clock seconds] $options(-session) \
							 wpm $options(-wpm) $options(-wpm) \
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
					n-correct 0 \
					n-wrong 0 \
					n-passed 0 \
					n-total 0
				       ]
		    $self score-current
		    if {$data(sample) eq {}} { error "no sample to play from" }
		}
		wait-before-new-challenge {
		    if {$data(play-time) >= $data(session-time-limit)} {
			lappend data(session-log) end [clock seconds] $data(play-time)
			$self status-line "Session complete, [$self score-session]"
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
		    # draw a new prompt from the prompt set
		    array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} state challenge ]
		    set data(pre-challenge-index) [$self sample-draw-index]
		    set data(pre-challenge-name) [$self sample-name $data(pre-challenge-index)]
		    # number of characters in the prechallenge name
		    set data(n-p-c) [string length $data(pre-challenge-name)]
		    # dit length
		    set data(challenge-dits) [morse-word-length [$options(-dict)] $data(pre-challenge-name)]
		    # ms per dit in challenge wpm
		    set data(challenge-dit-ms) [morse-dit-ms $options(-wpm)]
		    # ms per dit in response wpm
		    set data(response-dit-ms) [morse-dit-ms $options(-wpm)]
		    # ms for response
		    set data(challenge-response-ms) [expr {$data(challenge-dits)*($data(challenge-dit-ms)+$data(response-dit-ms))}]
		    set data(challenge-repeats) -1
		}
		wait-before-reissue-challenge {
		    # or before initial challenge
		    # maybe end of session
		    if {$data(play-time) >= $data(session-time-limit)} {
			lappend data(session-log) end [clock seconds] $data(play-time)
			$self status-line "Session complete, [$self score-session]"
			$self play-button play/pause
			set data(state) start
			continue
		    }
		    # should this timeout be a word space?
		    if {[clock millis]-$data(time-wait) > 250} {
			array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} state challenge ]
		    }
		}
		challenge {
		    array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} ]
		    if {$options(-chk) ne {} && ! [$options(-chk) is-busy]} {
			array set data [list time-challenge [clock millis] state wait-challenge-echo]
			$options(-chk) puts [morse-escape-prosign [string toupper $data(pre-challenge-name)]]
			# puts "challenge {$data(pre-challenge-name)}"
		    }
		}
		wait-challenge-echo {
		    # $self status-line "Waiting for challenge to echo ..."
		    # if {[string match <*> $data(pre-challenge-name)]} { puts "$data(pre-challenge-name) received $data(challenge) $data(trimmed-challenge)" }
		    if {$data(n-p-c) > $data(n-t-c)} {
			# waiting for more input
			break
		    }
		    if {[string first $data(pre-challenge-name) $data(trimmed-challenge)] >= 0} {
			# $self status-line ""
			set t [clock millis]
			array set data [list time-of-echo $t time-to-echo [expr {8*($t-$data(time-challenge))}] state wait-response-echo]
			# puts "time-to-echo $data(time-to-echo)"
			continue
		    } 
		    if {$data(n-t-c) != 0} {
			# $self status-line ""
			# puts "wait-challenge-echo {$data(pre-challenge)} and {$data(challenge)}"
			array set data [list time-wait [clock millis] state wait-before-new-challenge]
			continue
		    }
		    break
		}
		wait-response-echo {
		    # this is using space to terminate the response, which won't work for phrases with spaces.
		    # $self status-line "Waiting for response ... {$data(trimmed-challenge)} {$data(trimmed-response)}"
		    set data(response-time) [format %.0f [expr {[clock millis]-$data(time-challenge)}]]
		    if {$data(response-space)} {
			# this is the clause that recognizes success
			if {[string equal $data(trimmed-challenge) $data(trimmed-response)]} {
			    incr data(n-total)
			    incr data(n-correct)
			    $self status "\n" normal $data(trimmed-challenge) right
			    $self score-challenge; # hits
			    $self score-current
			    array set data [list time-wait [clock millis] state wait-before-new-challenge]
			    $self sample-replace-index $data(pre-challenge-index)
			    break
			}
			# this is the clause that recognizes failure
			if {$data(n-t-r) > 0 && [string first $data(trimmed-response) $data(trimmed-challenge)] < 0} {
			    incr data(n-total)
			    incr data(n-wrong)
			    $self status "\n" normal "$data(trimmed-challenge)" wrong
			    $self score-challenge; # misses
			    $self score-current
			    if {$options(-on-error) eq {Repeat}} {
				# should be a possible limit on number of repeats
				# or maybe unlimited number, but you only replace index 
				# if you get it right on the first try
				array set data [list time-wait [clock millis] state wait-before-reissue-challenge]
			    } else {
				array set data [list time-wait [clock millis] state wait-before-new-challenge]
			    }
			    break
			}
		    }
		    # this is the clase that recognizes failure to respond
		    if {[clock millis] > $data(time-of-echo)+$data(time-to-echo)} {
			incr data(n-total)
			# incr data(n-passed)
			incr data(n-wrong)
			$self score-challenge; # pass
			$self score-current
			$self status "\n" normal "$data(trimmed-challenge)" pass
			if {$options(-on-error) eq {Repeat}} {
			    array set data [list time-wait [clock millis] state wait-before-reissue-challenge]
			} else {
			    array set data [list time-wait [clock millis] state wait-before-new-challenge]
			}
			continue
		    }
		    # and we reach here if we're still waiting
		}
		default { error "uncaught state $data(state)" }
	    }
	    break
	}
	set data(handler) [after 10 [mymethod timeout]]
    }
    # this method displays the results of each challenge as a scrolling list
    # change it to make a line of elapsed time n-correct / n-wrong / n-passed / n-total
    method status {args} {
	set sec [expr {$data(play-time)/1000}]
	set min [expr {$sec/60}]
	set sec [expr {$sec%60}]
	$win.play.text insert end \n normal {*}$args
	$win.play.text insert end "\n\n$min:$sec $data(n-correct) $data(n-wrong) $data(n-total)" pass
	$win.play.text see end
    }
    method status-line {arg} {
	$win.play.status-line configure -text $arg
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
    proc percent {n m} { expr {$m ? int(round(100.0*$n/$m)) : 0} }
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
	set ms [expr {([morse-dit-ms [lindex $wpm 1]]+[morse-dit-ms [lindex $wpm 2]])/2}]
	# this depends on the word end as a ch being spelled END
	if {[lindex $session end-2] eq {end}} {
	    set challenges [lrange $session 9 end-3]
	} else {
	    set challenges [lrange $session 9 end]
	}
	foreach {ch re time} $challenges { 
	    set l [morse-word-length $morse $ch]
	    set time [expr {$time/(2+$l)/$ms}]
	    dict set sum total [incr-summary [dict get $sum total] $ch $time]
	    if {$ch eq $re} {
		dict set sum hit [incr-summary [dict get $sum hit] $ch $time]
	    } elseif {$re eq {}} {
		dict set sum pass [incr-summary [dict get $sum pass] $ch $time]
	    } else {
		# score the correct answer not given as a miss
		dict set sum miss [incr-summary [dict get $sum miss] $ch $time]
		# if an incorrect answer was given, score it as a miss, too
		# should be a prosign and not a #, but details
		#if {$re ne {}} {
		#    dict set sum miss [incr-summary [dict get $sum miss] $re $time]
		#}
	    }
	    # puts $entry
	}
	if {0} {
	    set chars [lsort [chars-summary [dict get $sum total]]]
	    foreach char $chars {
		set hits {}
		set misses {}
		set passes {}
		if {[char-exists-summary [dict get $sum hit] $char]} {
		    set hits [lsort -real -increasing [char-times-summary [dict get $sum hit] $char]]
		}
		if {[char-exists-summary [dict get $sum miss] $char]} {
		    set misses [lmap {x} [char-times-summary [dict get $sum miss] $char] {lindex {-} 0}]
		}
		if {[char-exists-summary [dict get $sum pass] $char]} {
		    set passes [lmap {x} [char-times-summary [dict get $sum pass] $char] {lindex {-} 0}]
		}
	    }
	}
	return $sum
    }
    
    proc init-session-summary {} { dict create total [init-summary total] hit [init-summary hit] miss [init-summary miss] pass [init-summary pass] }
    
    proc history-summary {sessions morse {filter {}}} {
	return {}
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
	$self append-cwack-history $data(session-log)
	$self history-update
	set s [session-summary [init-session-summary] [$options(-dict)] $data(session-log)]
	return "[percent [count-summary [dict get $s hit]] [count-summary [dict get $s total]]]% correct"
    }
    
    method score-current {} {
	set s [session-summary [init-session-summary] [$options(-dict)] $data(session-log)]
	set total [count-summary [dict get $s total]]
	if {$total == 0} {
	    set data(hitpct) 100
	} else {
	    set data(hitpct) [percent [count-summary [dict get $s hit]] $total]
	}
    }
    
    # score the results of a single challenge
    method score-challenge {} {
	lappend data(session-log) $data(pre-challenge-name) $data(trimmed-response) $data(response-time)
	# puts "score-challenge {$data(pre-challenge-name)} {$data(trimmed-response)} $data(response-time) ms"
    }
    
    proc sample-choose-i {n} { return [expr {int(rand()*$n)}] }
    proc sample-choose {x} { return [lindex $x [sample-choose-i [llength $x]]] }
    proc sample-shuffle {x} {
	set y {}
	while {[llength $x]} {
	    lappend y [lindex $x [set i [sample-choose-i [llength $x]]]]
	    set x [lreplace $x $i $i]
	}
	return $y
    }
    
    # sample make called at start
    # should make the overall collection of prompts
    # and the sub-collection which will be the initial working collection of prompts
    # the working collections are all integer indexes into the overall collection
    method sample-make {} {
	if {$data(current-words-list) eq {} || $data(words-list-name) ne $data(current-words-list-name)} {
	    # load the word list
	    package require cwack::words-$data(words-list-name)
	    # set the name of the current word list
	    set data(current-words-list-name) $data(words-list-name)
	    # set the current word list
	    set data(current-words-list) [words-$data(words-list-name)]
	    # start the word list index at the specified difficulty level
	    set data(word-list-index) [expr {int($options(-difficulty) * [llength $data(current-words-list)] / 100)}]
	    # build the current prompt set
	    set data(current-prompt-set) {}
	    for {set i $data(prompt-set-size)} {$i > 0} {incr i -1} {
		# puts "add $data(word-list-index) {[$self sample-name  $data(word-list-index)]} #[llength $data(current-prompt-set)]"
		lappend data(current-prompt-set) $data(word-list-index)
		incr data(word-list-index)
	    }
	}
	return $data(current-prompt-set)
    }
    
    method sample-draw-index {} {
	return [sample-choose $data(current-prompt-set)]
    }
    
    method sample-name {i} {
	return [lindex $data(current-words-list) $i]
    }
    
    method sample-replace-index {i} {
	set j [lsearch -exact $data(current-prompt-set) $i]
	if {$j < 0} {
	    error "sample-replace-index $i there is no such index in prompt set"
	}
	# puts "replace $i {[$self sample-name  $i]} with $data(word-list-index) {[$self sample-name  $data(word-list-index)]} #[llength $data(current-prompt-set)]"
	set data(current-prompt-set) [lreplace $data(current-prompt-set) $j $j $data(word-list-index)]
	incr data(word-list-index)
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
	    session-time-limit 100
	}

	# the frame is gridded ten columns
	pack [ttk::frame $w] -expand true -fill both
	set row -1
	grid [text $w.text -height 4 -width 16 -background lightgrey -font {Courier 40 bold}] -row [incr row] -column 0 -columnspan 10 -sticky ew
	bind $w.text <KeyPress> {}; # this isn't taking effect
	grid [ttk::button $w.play -text Play -command [mymethod play-button play/pause]] -row [incr row] -column 0 -columnspan 10
	grid [ttk::label $w.status-line] -row [incr row] -column 0 -columnspan 10
	grid [ttk::frame $w.hbar0 -height 8 -borderwidth 2 -relief sunken ] -row [incr row] -column 0 -columnspan 10 -sticky ew
	cwack::progressbar %AUTO% -window $w -var timepct -row [incr row] -column 0 -title {Time: } -foreground $data(bluish-color) -background grey -variable [myvar data(timepct)]
	cwack::progressbar %AUTO% -window $w -var hitpct -row $row -column 5 -title {Score: } -foreground $data(bluish-color) -background $data(reddish-color) -variable [myvar data(hitpct)]
	grid [ttk::frame $w.hbar1 -height 8 -borderwidth 2 -relief sunken ] -row [incr row] -column 0 -columnspan 10 -sticky ew
	foreach vars { {difficulty spread} {wpm session}} {
	    incr row
	    set column 0
	    foreach var $vars {
		cwack::lscale %AUTO% -window $w -var $var -row $row -column $column  -variable [myvar options(-$var)] \
		    -text "$options(-$var-label): " \
		    -from [lindex $options(-$var-values) 0] -to [lindex $options(-$var-values) end] -format %.1f \
		    -command [mymethod update -$var]
		incr column 5
	    }
	}
	grid [ttk::frame $w.hbar2 -height 8 -borderwidth 2 -relief sunken ] -row [incr row] -column 0 -columnspan 10 -sticky ew
	foreach vars { {tone challenge-tone} {dah-offset gain} } {
	    incr row
	    set column 0
	    foreach var $vars {
		cwack::lscale %AUTO% -window $w -var $var -row $row -column $column  -variable [myvar options(-$var)] \
		    -text "$options(-$var-label): " \
		    -from [lindex $options(-$var-values) 0] -to [lindex $options(-$var-values) end] -format %.1f \
		    -command [mymethod update -$var]
		incr column 5
	    }
	}
	grid [ttk::frame $w.hbar3 -height 8 -borderwidth 2 -relief sunken ] -row [incr row] -column 0 -columnspan 10 -sticky ew
	foreach c {0 1 2 3 4 5 6 7 8 9} { grid columnconfigure $w $c -weight 1 }
	incr row
	set scolumn 0
	#  odict
	foreach var {keyer swap mode} {
	    cwack::lradiomenubutton %AUTO% -window $w -var $var -row $row -column $scolumn -variable [myvar options(-$var)] \
		-text "$options(-$var-label): " -values $options(-$var-values)
	    incr scolumn 2
	}
	# keyer, swap, mode, favor single letters, favor words, no triple letters, preferred code dict
	return $w
    }
    method play-button {but} {
	# puts "play-button $but"
	switch $but {
	    play/pause {
		set data(play/pause) [expr {1^$data(play/pause)}]
		if {$data(play/pause)} {
		    $win.play.play configure -text Pause
		    lappend data(session-stamps) play [clock millis]
		    $self timeout
		} else {
		    $win.play.play configure -text Play
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
    method play-text {w text score} {
	
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
    # option-tab
    #
    method option-tab {w} {
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
    # about-tab
    #
    method about-tab {w} {
	ttk::frame $w
	pack [text $w.text -width 40 -background lightgrey -wrap word] -fill both -expand true
	$w.text insert end "" bold "Welcome to cwack\n" \
	    normal "cwack is a CW/Morse code trainer for your ear and your fist. " \
	    normal "Click" italic {[Play]} normal " on the " italic "Play" normal "tab and the computer will play morse code for you." \
	    normal "Echo the code back and Echo will collect statistics on your speed and accuracy."
	return $w
    }
    method update {opt val} {
	# puts "update $opt $val"
	set options($opt) $val
	switch -- $opt {
	    -session {}
	    -difficulty {}
	    -spread {}
	    -wordish {}
	    -wpm { 
		::options cset -$options(-chk)-wpm $val
		::options cset -$options(-dti1)-wpm $val
		::options cset -$options(-kbd)-wpm $val 
		::options cset -$options(-key)-wpm $val
		::options cset -$options(-dti2)-wpm $val
	    }
	    -challenge-tone { 
		set cfreq $val
		::options cset -$options(-dto1)-freq $cfreq
		::options cset -$options(-cho)-freq $cfreq
		$self update -dah-offset $options(-dah-offset)
	    }
	    -char-space { ::options cset -$options(-chk)-ils $val }
	    -word-space { ::options cset -$options(-chk)-iws $val }
	    -tone { 
		set rfreq $val
		::options cset -$options(-kbdo)-freq $rfreq
		::options cset -$options(-keyo)-freq $rfreq
		$self update -dah-offset $options(-dah-offset)
	    }
	    -swap -
	    -mode {
		::options cset -$options(-key)$opt $val
	    }
	    -dah-offset {
		set cfreq [expr {$options(-challenge-tone)+$val}]
		::options cset -$options(-chk)-two $cfreq
		::options cset -$options(-cho)-two $cfreq
		set rfreq [expr {$options(-tone)+$val}]
		::options cset -$options(-kbd)-two $rfreq
		::options cset -$options(-key)-two $rfreq
		::options cset -$options(-kbdo)-two $rfreq
		::options cset -$options(-keyo)-two $rfreq
	    }
	    -gain {
		::options cset -$options(-out)-gain $val
	    }
	    -keyer {
		::options cset -$options(-key)$opt $val
	    }
	    default { error "uncaught option update $opt" }
	}
	$self save-cwack-config
    }
    #
    #
    #
    method exposed-options {} { 
	return {
	    -dict -chk -cho -key -keyo -kbd -kbdo -dec1 -dec2 -dto1 -dto2 -dti1 -dti2 -out -cas -length
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
	    default { puts "no info-option for $opt" }
	}
    }
    
    method ConfigText {opt val} { $hull configure $opt $val }
    method {Config -dti2} {val} { set options(-dti2) $val }
    method test {} {
	# $self test1
    }
}

#
# todo 2020-06-07
# [x] implement color blind friendly colors reddish #d81b60, bluish #1e88e5
# [x] accumulate statistics to startup file
# [x] output statistics into stats tab
# [ ] output layered statistics to show progress
# [ ] use statistics to target drills
# todo 2020-09-15
# [x] optional repeat after miss or pass
# [-] only three repeats?
# [x] make pie chart widget
# [x] pie chart timer countdown
# [x] pie chart score display
# [x] make pie charts round
# [x] center pie chart titles and captions
# [x] unify challenge/response wpm
# [x] challenge tone in
# [x] response tone in Hz
# [x] move game status messages to status line
# [x] figure out how to avoid breaking in, ah, let the user finish, wait for space
# [x] make status start with newline rather than end with one?
# [ ] summarize saved statistics
# [-] only score word spaces when the required space has passed, not when you cross the decision boundary.
#       it's already waiting for 6 dits of key up to mark a word space
# [x] fix the iambic keyer selector
# [x] move setup controls to bottom of play-tab
# [x] eliminate setup-tab
# [ ] eliminate dial-tab, make dial controls optional popup window
# [x] how about parameterizing progress by the distribution of dit-lengths?
#       so symbols are drawn from distribution with specified mean and sd
#       the mean centers the symbol length, the sd spreads the symbol length,
#       just give characters and words blindly
# [x] add dah-offset scale
# [x] refactor labeled scales
# [x] break scales into two columns
# [ ] change pies to progress bars
# [ ] add keyer setup control
# [ ] add button to favor single letters over words.
# [ ] add button to favor words over single letters.
# [ ] add button to drop tripled letters.
# [ ] add button to specify the preferred code dictionary for output
#       recommend farsi, hebrew, arabic, or wabun for eliminating visual cues
# [-] add button to drop the non-english characters 
# [-] add button to drop the less used punctuation marks
# [-] accumulate running mean and sd and monte carlo accept/reject candidates
#       according to how they update the running mean and sd.
# [x] sample-make should deal with fractional difficulty and spread
# [ ] starting from nil, discover the student's ability and push the boundaries
# [ ] should just start pushing letter combinations when the letters are known
# [ ] what happens if letter frequency is inversely proportional to dit length?
# [x] rewrite builtin to include <SK> style prosigns rather than exotic single characters
# [x] * is not a widely used abbreviation for <SK>
# [-] * and % would be useful single character abbreviations
# [x] expand allowed dit lengths beyond known single character dit lengths
# [ ] add user button to controls, segregate setups by user, allow multiple users
# [x] some kind of glitch in the timeout loop, pause/play fixes it, 
#	different prosign convention in keyer-ascii puts than in dict.
# [x] is volume broken? dah-offset broken? yes, all option updates were broken
# [ ] simplify code
# [ ] rewrite into julia
#----------------
# [ ] score only the first attempt at any challenge, not the misses on retries, nor the
#	final success on retries.
# [ ] group by number of elements rather than overall timing. 
#	[e,t][i,a,n,m][s,u,r,d,w,k,g,o,ee,et,te,tt]...
# [ ] adjust difficulty on score on last 4 challenges,
#       75% or better increase, 50% hold, less than 50% decrease difficulty
# [ ] lock out key while until challenge is finished
