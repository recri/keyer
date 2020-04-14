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
package provide sdrtk::cw-encode-input 1.0.0

#
# keyboard input into morse code
#
package require Tk
package require snit

package require sdrtk::cwtext

namespace eval ::sdrtk {}
#
# cwtext window is a live text entry for sending to the ascii-keyer
# cw-text simply supplies bindings for a menu and an abort key
# the escape key binding could move to cwtext itself, or be bound
# onto . so it works where ever you focused input.
#

snit::widgetadaptor sdrtk::cw-encode-input {
    option -ascii -default {};	# sdrtcl::keyer-ascii or equivalent
    option -sentcolor -default grey -configuremethod Configure
    option -unsentcolor -default white -configuremethod Configure
    option -skippedcolor -default darkgrey -configuremethod Configure
    option -background -default black -configuremethod Configure
    option -font -default Courier -configuremethod Configure

    delegate method * to hull
    delegate option * to hull
    
    constructor {args} {
	installhull using sdrtk::cwtext -ascii [mymethod call-ascii] -width 30 -height 15 -exportselection true
	$self configure {*}$args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	bind $win <Escape> [mymethod stop-sending]
    }

    method call-ascii {args} { return [$options(-ascii) {*}$args] }
    method exposed-options {} { return { -sentcolor -unsentcolor -skippedcolor -background -font -ascii } }
    method info-option {opt} {
	if { ! [catch {$ascii info option $opt} info]} { return $info }
	switch -- $opt {
	    -sentcolor { return {set the color of the sent text} }
	    -unsentcolor { return {set the color of the yet to be sent text} }
	    -skippedcolor { return {set the color of the unsent text which will not be sent} }
	    -background { return {set the background color of the text} }
	    -font { return {choose the font of the text} }
	    -ascii { return {character to morse code sender component} }
	    default { puts "cw-encode-input: uncaught info-option $opt" }
	}
    }

    method option-menu {x y} {
	if { ! [winfo exists $win.m] } {
	    menu $win.m -tearoff no
	    $win.m add command -label {Stop sending} -command [mymethod stop-sending]
	    $win.m add command -label {Clear window} -command [mymethod clear]
	    $win.m add separator
	    $win.m add command -label {Send file} -command [mymethod choose file]
	    $win.m add separator
	    $win.m add command -label {Font} -command [mymethod choose font]
	    $win.m add command -label {Background} -command [mymethod choose background]
	    $win.m add command -label {Sent Color} -command [mymethod choose sentcolor]
	    $win.m add command -label {Unsent Color} -command [mymethod choose unsentcolor]
	    $win.m add command -label {Skipped Color} -command [mymethod choose skippedcolor]
	}
	tk_popup $win.m $x $y
    }
}

