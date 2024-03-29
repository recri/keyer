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
package provide sdrtk::cwack 1.0.0

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

namespace eval ::sdrtk {} 
namespace eval ::cwack {}

# some statistical helpers
namespace eval ::tcl::mathfunc {

    # standardized normal mu=0 sigma=1 at z
    proc snormal {z} { expr {exp(0.5*pow($z,2))/2.50662827463} }

    # normal with specfied mu and sigma at x
    proc normal {x mu sigma} { expr {snormal((double($x)-$mu)/$sigma)} }

    # From https://en.wikipedia.org/wiki/Error_function
    # Abramowitz and Stegun approximation to the error function
    # erf(x) = 1-1/(1 + a1*x + a2*x^2 + a3*x^3 + a4*x^4)^4, x>=0
    # (maximum error: 5×10−4)
    # where a1 = 0.278393, a2 = 0.230389, a3 = 0.000972, a4 = 0.078108

    # error function
    proc erf {x} {
        expr {$x < 0 ? -erf(-$x) :
              1.0-1.0/pow(1+0.278393*$x+0.230389*pow($x,2)+0.000972*pow($x,3)+0.078108*pow($x,4), 4)}
    }

    # standardized normal cumulative distribution function: mu = 0 and sigma = 1
    proc sncdf {z} { expr {(1.0-erf($z/sqrt(2)))/2} }

    # normal cumulative distribution function with specified mu and sigma
    proc ncdf {x mu sigma} { expr {sncdf((double($x)-$mu)/$sigma)} }
}

#
# * compute running mean and var from https://www.johndcook.com/blog/standard_deviation
# *
# * Initialize M1 = x1 and S1 = 0.
# *
# * For subsequent x‘s, use the recurrence formulas
# * 
# * Mk = Mk-1+ (xk – Mk-1)/k
# * Sk = Sk-1 + (xk – Mk-1)*(xk – Mk).
# *
# * For 2 ≤ k ≤ n, the kth estimate of the variance is s2 = Sk/(k – 1).
#
snit::type rsummary {
    variable sum
    constructor {args} {
        $self clear
        $self accumulate {*}$args
    }
    method clear {} { set sum [dict create mk 0 sk 0 k 0] }
    method accumulate {args} {
        dict with sum {
            foreach xk $args {
                if {$k == 0} {
                    set k 1
                    set mk $xk
                    set sk 0
                } else {
                    incr k
                    set mj $mk
                    set sj $sk
                    set mk [expr {double($mj)+($xk-$mj)/double($k)}]
                    set sk [expr {double($sj)+double($xk-$mj)*($xk-$mk)}]
                }
            }
        }
    }
    method mean {} { dict get $sum mk }
    method var {} { dict with sum { return [expr {$k >= 2 ? $sk/($k-1) : 0}] } }
    method sd {} { expr {sqrt([$self var])} }
    method n {} { dict get $sum k }
}

## cwack::progressbar labelled progress bar
## tk type, but grid into a larger array at -row -column
## show time remaining or percent correct as progress bars
snit::type cwack::progressbar {
    component title
    component value
    component progress
    
    option -window
    option -var
    option -row
    option -column
    option -variable

    option -title -default {}
    option -foreground -default blue
    option -background -default red
    
    constructor {args} {
	$self configurelist $args

	set win $options(-window)
	set var $options(-var)
	set row $options(-row)
	set column $options(-column)

        install title using ttk::label $win.title$var -text $options(-title)
        install value using ttk::label $win.value$var -textvar $options(-variable)
        install progress using ttk::progressbar $win.progress$var -mode determinate -variable $options(-variable)
        grid $win.title$var -column [expr {$column+0}] -row $row -sticky e
        grid $win.value$var -column [expr {$column+1}] -row $row -ipadx 10
        grid $win.progress$var -column [expr {$column+2}] -row $row -sticky ew -columnspan 3
    }
}

## cwack::lscale labeled scale
## tk type, but grid into a larger array at -row -column
## to constrain column widths together
snit::type cwack::lscale {

    component label
    component value
    component scale

    option -window
    option -var
    option -row
    option -column
    option -text
    option -variable
    option -format
    option -from
    option -to
    option -command

    proc constrain {var fmt val} { set $var [format $fmt $val] }

    constructor {args} {
	$self configurelist $args

	set win $options(-window)
	set var $options(-var)
	set row $options(-row)
	set column $options(-column)

	install label using ttk::label $win.label$var -text $options(-text)
	install value using ttk::label $win.value$var -textvar $options(-variable)
	install scale using ttk::scale $win.scale$var -orient horizontal \
	    -variable $options(-variable) -from $options(-from) -to $options(-to) \
	    -command [mymethod update]

	grid $win.label$var -row $row -column [expr {$column+0}] -sticky e
	grid $win.value$var -row $row -column [expr {$column+1}] -ipadx 10
	grid $win.scale$var -row $row -column [expr {$column+2}] -sticky ew -columnspan 3
    }
    method update {val} {
	set options(-variable) [format $options(-format) $val]
	if {$options(-command) ne {}} { {*}$options(-command) $options(-variable) }
    }
}

package require sdrtk::radiomenubutton

snit::type cwack::lradiomenubutton {
    component label
    component radiomenubutton

    option -window
    option -var
    option -row
    option -column

    delegate option -text to label
    delegate option -values to radiomenubutton
    delegate option -labels to radiomenubutton
    delegate option -defaultvalue to radiomenubutton
    delegate option -command to radiomenubutton
    delegate option -variable to radiomenubutton

    constructor {args} {
	set win [set options(-window) [from args -window]]
	set var [set options(-var) [from args -var]]
	install label using ttk::label $win.lbl$var
	install radiomenubutton using sdrtk::radiomenubutton $win.rbm$var
	$self configurelist $args
	grid $win.lbl$var -row $options(-row) -column [expr {$options(-column)+0}]
	grid $win.rbm$var -row $options(-row) -column [expr {$options(-column)+1}]
    }
}

snit::widget sdrtk::cwack {
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
    option -dict -default builtin;  # decoding dictionary
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
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
    option -session-values -default {0.25 30}
    
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
    option -on-error {Repeat}
    option -on-error-label {Action on error}
    option -on-error-values {Repeat Continue}
    
    # iambic keyer to use (the -values are a cheat, I know the answer)
    option -keyer vk6ph
    option -keyer-label {Keyer}
    option -keyer-tooltip {Implementation of iambic keyer}
    option -keyer-values {ad5dz dttsp k1el nd7pa vk6ph}
    
    # difficulty of challenges, average length in dit clocks
    option -difficulty 1
    option -difficulty-label {Difficulty}
    option -difficulty-tooltip {Average length of challenges in dit clocks}
    option -difficulty-values {1 31}
    
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
	config-options {-wpm -difficulty -spread -wordish -session -tone -challenge-tone -mode -swap -keyer -gain -dah-offset}
	summary {} 
	dits {}
	sample {}
	timepct 0
	hitpct 0
    }
    
    constructor {args} {
	$self configurelist $args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind all <KeyPress> [mymethod keypress %A]
	bind $win <Destroy> [list destroy .]
	# five tabs in a notebook
	pack [ttk::notebook $win.echo] -fill both -expand true
	$win.echo add [$self play-tab $win.play] -text Cwack
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
	    # trimmed response
	    set data(trimmed-response) [regsub -all { } $data(response) {}]
	    set data(n-t-r) [string length $data(trimmed-response)]
	    set data(response-space) [expr {$data(n-t-r) > 0 && [regexp {^.* $}  $data(response)]}]
	    # switch on state
	    # puts "$data(state)"
	    switch $data(state) {
		start {
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
		    array set data [list challenge {} trimmed-challenge {} response {} trimmed-response {} state challenge ]
		    set data(pre-challenge) [$self sample-draw]
		    set data(n-p-c) [string length $data(pre-challenge)]
		    set data(challenge-dits) [morse-word-length [$options(-dict)] $data(pre-challenge)]
		    set data(challenge-dit-ms) [morse-dit-ms $options(-wpm)]
		    set data(response-dit-ms) [morse-dit-ms $options(-wpm)]
		    set data(challenge-response-ms) [expr {$data(challenge-dits)*($data(challenge-dit-ms)+$data(response-dit-ms))}]
		}
		wait-before-reissue-challenge {
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
			$options(-chk) puts [morse-escape-prosign [string toupper $data(pre-challenge)]]
			# puts "challenge {$data(pre-challenge)}"
		    }
		}
		wait-challenge-echo {
		    # $self status-line "Waiting for challenge to echo ..."
		    # if {[string match <*> $data(pre-challenge)]} { puts "$data(pre-challenge) received $data(challenge) $data(trimmed-challenge)" }
		    if {$data(n-p-c) > $data(n-t-c)} {
			# waiting for more input
			break
		    }
		    if {[string first $data(pre-challenge) $data(trimmed-challenge)] >= 0} {
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
		    # $self status-line "Waiting for response ... {$data(trimmed-challenge)} {$data(trimmed-response)}"
		    set data(response-time) [format %.0f [expr {[clock millis]-$data(time-challenge)}]]
		    if {$data(response-space)} {
			if {[string equal $data(trimmed-challenge) $data(trimmed-response)]} {
			    $self status "\n" normal $data(trimmed-challenge) right
			    $self score-challenge; # hits
			    $self score-current
			    array set data [list time-wait [clock millis] state wait-before-new-challenge]
			    break
			}
			if {$data(n-t-r) > 0 && [string first $data(trimmed-response) $data(trimmed-challenge)] < 0} {
			    $self status "\n" normal "$data(trimmed-challenge)" wrong
			    $self score-challenge; # misses
			    $self score-current
			    if {$options(-on-error) eq {Repeat}} {
				array set data [list time-wait [clock millis] state wait-before-reissue-challenge]
			    } else {
				array set data [list time-wait [clock millis] state wait-before-new-challenge]
			    }
			    break
			}
		    }
		    if {[clock millis] > $data(time-of-echo)+$data(time-to-echo)} {
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
		}
		default { error "uncaught state $data(state)" }
	    }
	    break
	}
	set data(handler) [after 10 [mymethod timeout]]
    }
    method status {args} {
	$win.play.text insert end {*}$args
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
	lappend data(session-log) $data(pre-challenge) $data(trimmed-response) $data(response-time)
	# puts "score-challenge {$data(pre-challenge)} {$data(trimmed-response)} $data(response-time) ms"
    }
    
    proc sample-choosei {n} { return [expr {int(rand()*$n)}] }
    proc sample-choose {x} { return [lindex $x [sample-choosei [llength $x]]] }
    proc sample-shuffle {x} {
	set y {}
	while {[llength $x]} {
	    lappend y [lindex $x [set i [sample-choosei [llength $x]]]]
	    set x [lreplace $x $i $i]
	}
	return $y
    }
    
    # make a sample with specified -difficulty and -spread
    # for mean mu and standard deviation sigma evaluate the relative weights
    # for bins centered at the positive odd x
    # puts "about to execute proc weights"
    proc sample-make-weights {mu sigma max} {
	# puts "sample-make-weights $mu $sigma $max"
	set sigma [expr {max(0.01,$sigma)}]
	set bins [dict create sum 0]
	for {set n 1} {$n <= $max} {incr n 2} {
	    set wt [expr {int(101*(ncdf($n-1, $mu, $sigma)-ncdf($n+1, $mu, $sigma)))}]
	    dict set bins $n $wt
	    dict incr bins sum $wt
	}
	set bins [dict map {n wt} $bins { if {$wt} { set wt } else continue }]
	# puts "$bins"
	return $bins
    }
    
    proc sample-make-one-sample {bins} {
	set i [expr {int(rand()*[dict get $bins sum])}]
	foreach j [dict keys $bins {[0-9]*}] {
	    set i [expr {$i-[dict get $bins $j]}]
	    if {$i <= 0} { return $j }
	}
	puts "ran off end of sample bins: $bins"
	return [sample-choose [dict keys $bins {[0-9]*}]]
    }
    
    proc sample-make-sample {bins {n 1}} {
	if {$n == 1} {
	    return [sample-make-one-sample $bins]
	}
	set samps {}
	while {[llength $samps] < $n} {
	    lappend samps [sample-make-one-sample $bins]
	}
	return $samps
    }
    
    method sample-make {} {
	if {$data(dits) eq {}} {
	    # make the dits table
	    # characters by dit length
	    # combinations of characters by dit length
	    # tabulated by length of combination
	    set maxn 31
	    set dits [dict create]
	    set dict [$options(-dict)]
	    # generate unigraphs classified by dit length
	    set cset [dict keys $dict]
	    set cdits [dict create]
	    foreach c $cset { dict lappend cdits [morse-word-length $dict $c] $c }
	    dict set dits 1 $cdits
	    # generate digraphs classified by dit length
	    set nset [lsort -integer [dict keys $cdits]]
	    set wdits [dict create]
	    foreach n1 $nset {
		foreach n2 $nset {
		    set n [expr {$n1+3+$n2}]
		    if {$n > $maxn} continue
		    set ns [lsort -integer [list $n1 $n2]]
		    if { ( ! [dict exists $wdits $n] ) || $ns ni [dict get $wdits $n] } {
			dict lappend wdits $n $ns
		    }
		}
	    }
	    dict set dits 2 $wdits
	    # generate n-graphs classified by dit length up to length 5
	    for {set i 3} {$i <= 5} {incr i} {
		set pdits [dict get $dits [expr {$i-1}]]
		set wdits [dict create]
		foreach n2 [lsort -integer [dict keys $pdits]] {
		    foreach n1 $nset {
			set n [expr {$n1+3+$n2}]
			if {$n > $maxn} continue
			foreach w2 [dict get $pdits $n2] {
			    set ns [lsort -integer [concat $n1 $w2]]
			    if { ( ! [dict exists $wdits $n] ) || $ns ni [dict get $wdits $n] } {
				dict lappend wdits $n $ns
			    }
			}
		    }
		}
		dict set dits $i $wdits
	    }
	    # print out the table
	    if {0} {
		foreach n $nset {
		    set vals [dict values [dict map {k v} $dits {llength [dict get $v $n]}]]
		    if {$vals ne {}} { puts "$n -> $vals" }
		    foreach k [dict keys $dits] { 
			set vals [dict get $dits $k $n]
			if {$vals ne {}} { puts "$n $k -> $vals" }
		    }
		}
	    }
	    set data(dits) $dits
	    set data(mdits) [dict create]
	    dict for {n d} $dits {
		dict for {nd v} $d {
		    dict lappend data(mdits) $nd {*}$v
		}
	    }
	}
	set nset [lsort -integer [dict keys [dict get $data(dits) 1]]]
	# puts "character $nset"
	set nset [lsort -integer [dict keys $data(mdits)]]
	# puts "merged $nset"
	set bins [sample-make-weights $options(-difficulty) $options(-spread) [tcl::mathfunc::max {*}$nset]]
	return $bins
    }
    
    method sample-draw {} {
	set length [sample-make-one-sample $data(sample)]
	# puts "sample-draw length $length"
	set draw [sample-choose [dict get $data(mdits) $length]]
	# puts "sample-draw draw {$draw}"
	# the list/item ambiguity bites us when the item is a "
	if {[string length $draw] == 1 || [regexp {^<[^>]+>$} $draw]} {
	    return $draw
	} elseif {[llength $draw] == 1} {
	    puts "sample-draw {$draw} character didn't match patterns"
	    return $draw
	} else {
	    set draw [join [lmap i [sample-shuffle $draw] {sample-choose [dict get $data(dits) 1 $i]}] {}]
	    return $draw
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
    method test1 {} {
	# generate samples for all combinations of difficulty and spread
	set saved [array get options]
	
	set mind [lindex $options(-difficulty-values) 0]
	set maxd [lindex $options(-difficulty-values) 1]
	set mins [lindex $options(-spread-values) 0]
	set maxs [lindex $options(-spread-values) 1]
	set dict [$options(-dict)]
	#set mind 25
	#set maxd 25
	#set mins 0
	#set maxs 0
	puts "test starts mind $mind maxd $maxd mins $mins maxs $maxs"
	set sum [rsummary testsummary]
	for {set options(-difficulty) $mind} {$options(-difficulty) <= $maxd} {incr options(-difficulty)} {
	    for {set options(-spread) $mins} {$options(-spread) <= $maxs} {incr options(-spread)} {
		$sum clear
		set data(sample) [$self sample-make]
		#puts "dits $data(dits)"
		#puts "bins $data(sample)"
		#break
		for {set n 0} {$n < 2000} {incr n} {
		    set draw [$self sample-draw]
		    set dits [morse-word-length $dict $draw]
		    # puts "$options(-difficulty) $options(-spread) {$draw} $dits"
		    $sum accumulate $dits
		}
		puts [format "diff %.1f spread %.1f mean %.1f sd %.1f n %d" $options(-difficulty) $options(-spread) [$sum mean] [$sum sd] [$sum n]]
	    }
	}
	rename $sum {}
	puts "test ends"
	
	array set options $saved
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
