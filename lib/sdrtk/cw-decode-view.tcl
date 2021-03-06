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
package provide sdrtk::cw-decode-view 1.0.0

#
# read only text widget, receiving decoded morse
#
package require Tk
package require snit

package require morse::morse
package require morse::itu
package require morse::dicts

namespace eval ::sdrtk {}

snit::widgetadaptor sdrtk::cw-decode-view {
    option -detime -default {} -configuremethod Config;	# sdrtcl::keyer-detime or equivalent
    option -dict -default builtin
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
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
	bind $win <Destroy> [mymethod window-destroy]
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	set handler [after 100 [mymethod timeout]]
    }

    method window-destroy {} {
	catch { after cancel $handler }
    }
    
    method exposed-options {} { return {-dict -font -foreground -background -detime} }

    method info-option {opt} {
	switch -- $opt {
	    -background { return {color of window background} }
	    -foreground { return {color for text display} }
	    -font { return {font for text display} }
	    -dict { return {dictionary for decoding morse} }
	    -detime { return {ASK detiming component} }
	    default { puts "no info-option for $opt" }
	}
    }
    method Config {opt val} {
	# puts "cw-decode-view::configure $opt $val"
	set options($opt) $val
    }
    method ConfigText {opt val} {
	$hull configure $opt $val
    }
    method timeout {} {
	# puts "cw-decode-view::timeout $options(-detime)"
	# get new text
	# append to accumulated code
	if {$options(-detime) ne {} &&  ! [$options(-detime) is-busy] } {
	    append code [$options(-detime) get]
	}
	while {[regexp {^([-.]*) (.*)$} $code all symbol code]} {
	    if {$symbol ne {}} {
		# symbol terminated by a space
		# insert translation
		$self ins end "[morse-to-text [$options(-dict)] $symbol]"
	    } else {
		# an extra space indicates a word space
		$self ins end { }
	    }
	    $self see end
	}
	set handler [after 100 [mymethod timeout]]
    }

    method save {} {
	set filename [tk_getSaveFile -title {Log to file}]
	if {$filename ne {}} {
	    write-file $filename [$self get 1.0 end]
	}
    }

    method clear {} {
	$self del 1.0 end
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
