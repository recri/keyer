#!/usr/bin/tclsh
# -*- mode: Tcl; tab-width: 8; -*-
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

package require Tk
package require snit

package provide sdrtk::cwtext 1.0

namespace eval ::sdrtk {}

#
# a text window for composing and sending cw.
# the text widget contains text marked with
# three tags: 
# sent, skipped, and no tags signifying to be sent; 
# and identified by two marks:
# the usual insert cursor 
# and the transmit cursor, 
# which is always before or equal to
# the insert cursor.
#
# the insert cursor is modified by the user
# adding and editing text at the end of the 
# widget.  Editing is restricted to text after
# the transmit cursor.  everything before
# the transmit cursor is marked as read only,
# it is history and cannot be changed.
#
# (editing bindings are overridden inside the 
# sent and skipped tags.)
#
# the transmit cursor is updated in the back
# ground as text is queued to the keyer for transmission.
# text that has been transmitted is tagged as sent.
#
# an abort stops transmission and jumps the transmit cursor
# to the insert cursor.  The unsent characters jumped over
# are tagged as skipped.
#
# by default, all text is rendered with the font and background
# specified for the widget.  Unsent text is rendered with the
# widget -foreground color, sent text is rendered in grey,
# skipped text is rendered in lightgrey and overstruck.
#

#
# todo:
# [ ] no edit suppression in the past
# [ ] memories
#

snit::widgetadaptor sdrtk::cwtext {

    option -background -default black -configuremethod Configure
    option -sentcolor -default white -configuremethod Configure
    option -skippedcolor -default white -configuremethod Configure
    option -unsentcolor -default lightgrey -configuremethod Configure
    option -font -default TkFixedFont -configuremethod Configure
    option -ascii -default {}

    variable handle {}
    
    # suppress edits in history
    delegate method ins to hull as insert
    delegate method del to hull as delete
    #
    method delete {index args} {
	if {[$self compare transmit <= $index]} {
	    $self del $index {*}$args
	} else {
	    # puts "$self delete $index $args"
	    # $self del $index {*}$args
	}
    }
    method insert {index args} {
	if {[$self compare transmit <= $index]} {
	    $self ins $index {*}$args
	    if {$handle eq {}} { $self timeout }
	} else {
	    # puts "$self insert $index $args"
	    # $self ins {*}$args
	}
    }
    #
    delegate method * to hull
    delegate option * to hull

    constructor {args} {
	installhull using text
	$self configure -background $options(-background) -unsentcolor $options(-unsentcolor) -wrap word {*}$args
	$self tag configure sent -foreground $options(-sentcolor)
	$self tag configure skipped -foreground $options(-skippedcolor) -overstrike true
	#? if {[event info <<TextScroll>>] eq {}} { event add <<TextScroll>> <Prior> <Next> }
	$self mark set transmit 1.0
	$self mark gravity transmit left
	#puts [$self mark names]
    }

    method timeout {} {
	if { [$self compare transmit >= insert] } {
	    set handle {}
	} else {
	    if { ! [{*}$options(-ascii) is-busy] && [{*}$options(-ascii) pending] < 40} {
		{*}$options(-ascii) puts [string toupper [$self nextchar]]
	    }
	    set handle [after 20 [mymethod timeout]]
	}
    }

    method stop-sending {} {
	$self abort
	{*}$options(-ascii) abort
    }

    method {Configure -background} {color} {
	set options(-background) $color
	$hull configure -background $color
    }
    method {Configure -sentcolor} {color} {
	set options(-sentcolor) $color
	$self tag configure sent -foreground $color
    }
    method {Configure -skippedcolor} {color} {
	set options(-skippedcolor) $color
	$self tag configure skipped -foreground $color
    }
    method {Configure -unsentcolor} {color} {
	set options(-unsentcolor) $color
	$hull configure -foreground $color
    }
    method {Configure -font} {font} {
	set options(-font) $font
	$hull configure -font $font
    }
    # get one character at the transmit cursor
    # and move the transmit cursor forward
    # [$self get transmit insert] returns all the characters 
    # between the transmit and insert cursors.
    method nextchar {} {
	set nextchar [$self get transmit insert]
	if {$nextchar ne {}} {
	    set nextchar [string index $nextchar 0]
	    $self mark set transmit {transmit + 1 chars}
	    $self tag add sent {transmit - 1 chars} transmit
	    return $nextchar
	}
	return $nextchar
    }

    # jump the transmit cursor to the insert cursor
    method abort {} {
	set nextchar [$self get transmit insert]
	if {$nextchar ne {}} {
	    $self tag add skipped transmit insert
	    $self mark set transmit insert
	}
    }

    method clear {} {
	$self del 1.0 end
    }

    # generic make a list of options changed from default
    # so their values can be restored
    method save-config {} {
	set save {}
	foreach row [$self configure] {
	    foreach {opt nm cl def val} $row break
	    if {$def ne $val} {
		lappend save $opt $val
	    }
	}
	return $save
    }

    # external functions moved in here for convenience
    # not actually used because Stop sending requires
    # other actions to implement in the sender component
    method options-menu {x y} {
	if {[winfo exists $win.m]} { destroy $win.m }
	menu $win.m -tearoff no
	$win.m add command -label {Stop sending} -command [list $win abort]
	$win.m add command -label {Clear window} -command [list $win clear]
	$win.m add separator
	$win.m add command -label {Send file} -command [list $win choose file]
	$win.m add separator
	$win.m add command -label {Font} -command [list $win choose font]
	$win.m add command -label {Background} -command [list $win choose background]
	$win.m add command -label {Sent Color} -command [list $win choose sentcolor]
	$win.m add command -label {Unsent Color} -command [list $win choose unsentcolor]
	$win.m add command -label {Skipped Color} -command [list $win choose skippedcolor]
	tk_popup $win.m $x $y
    }
    proc read-file {file} {
	set fp [open $file r]
	set data [read $fp]
	close $fp
	return $data
    }
    proc choose-color {w opt title} {
	set val [tk_chooseColor -parent $w -initialcolor [$w cget $opt] -title $title]
	if {$val ne {}} { $w configure $opt $val }
    }
    proc choose-font {w font args} { 
	# puts "choose-font $w $font {$args}"
	$w configure -font $font
    }
    method choose {opt} {
	switch $opt {
	    file {
		# insert file into transmit queue
		set filename [tk_getOpenFile -title {Insert from file}]
		if {$filename ne {}} { $self insert current [read-file $filename] }
	    }
	    font {
		tk::fontchooser configure -parent $win -command [myproc choose-font $win]
		tk::fontchooser show
		# now wait for <<Font...>> events and do what?
	    }
	    background {choose-color $win -background {Pick background color} }
	    sentcolor { choose-color $win -sentcolor {Pick sent color} }
	    skippedcolor { choose-color $win -skippedcolor {Pick skipped color} }
	    unsentcolor { choose-color $win -unsentcolor {Pick unsent color} }
	}
    }
}

if {0 && [string match *cwtext.tcl $argv0]} {
    # testing 1, 2, 3
    lappend auto_path [file join [file dirname [info script]] .. lib]
    
    package require sdrtcl::keyer-iambic-ad5dz
    package require sdrtcl::keyer-ascii
    package require sdrtcl::keyer-tone
    
    sdrtcl::keyer-iambic-ad5dz ad5dz -wpm 25
    sdrtcl::keyer-ascii ascii -wpm 25
    sdrtcl::keyer-tone tone -freq 888
    
    ad5dz activate
    ascii activate
    tone activate
    
    proc get-and-send {w} {
	if {[ascii pending] < 100} {
	    ascii puts [string toupper [$w nextchar]]
	}
	after 100 [list get-and-send $w]
    }
    
    pack [sdrtk::cwtext .text] -side top -fill both -expand true
    bind .text <ButtonPress-3> [list .text options-menu %X %Y]
    bind .text <Escape> [list .text abort]
    after 100 [list get-and-send .text]
}

