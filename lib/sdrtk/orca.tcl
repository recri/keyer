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
package provide sdrtk::orca 1.0.0

#
# orca implementation in a Tk text window
#
package require Tk
package require snit

namespace eval ::sdrtk {}

snit::type sdrtk::orca-op {
}

snit::widgetadaptor sdrtk::orca {
    variable data -array {
    }
    
    option -bpm -default 120 -configuremethod Configure
    option -width -default 40 -configuremethod Configure
    option -height -default 40 -configuremethod Configure

    method {Configure -bpm} {val} {
	set options(-bpm) $val
	set data(timeout) [expr {60000/$options(-bpm)}]
    }
    method {Configure -width} {val} {
	set options(-width) $val
	$hull configure -width $val
    }
    method {Configure -height} {val} {
	set options(-height) $val
	$hull configure -height $val
    }
    
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
	$self configurelist $args
	set handler [after $data(timeout) [mymethod timeout]]
    }

    method window-destroy {} {
	catch { after cancel $handler }
    }
    
    method exposed-options {} { return {-bpm -font -foreground -background} }

    method info-option {opt} {
	switch -- $opt {
	    -bpm { return {beats per minute} }
	    -width { return {width of window} }
	    -height { return {height of window} }
	    -background { return {color of window background} }
	    -foreground { return {color for text display} }
	    -font { return {font for text display} }
	    default { puts "no info-option for $opt" }
	}
    }

    method timeout {} {
	# get new text
	# append to accumulated code
	set handler [after $data(timeout) [mymethod timeout]]
    }

}
