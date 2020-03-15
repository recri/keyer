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

package provide sdrtcltk::midi-tap-view 1.0.0

package require Tk
package require snit
package require sdrtcl::midi-tap

#
# midi tap text widget, receiving midi events for timing check
#
snit::widgetadaptor sdrtcltk::midi-tap-view {
    component tap
    
    #delegate method {activate deactivate is-active get start state stop} to tap
    delegate option -verbose to tap
    delegate option -server to tap
    delegate option -client to tap
    delegate option -chan to tap
    delegate option -note to tap
    delegate method * to hull
    delegate option * to hull
    
    variable tapframe 0
    variable handler {}

    constructor {args} {
	installhull using text
	puts "self $self, namespace tail [namespace tail $self], winfo name [winfo name [namespace tail $self]]"
	install tap using sdrtcl::midi-tap $self.tap -client [winfo name [namespace tail $self]]
	$self configure -width 30 -height 15 {*}$args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	$tap start
	set handler [after 100 [mymethod timeout]]
    }
    
    method activate {} { $tap activate }
    method deactivate {} { $tap deactivate }
    method is-busy {} { return [$tap is-busy] }
    
    method exposed-options {} { return [concat {-font -foreground -background} [$tap info options]] }
    method info-option {opt} {
	if { ! [catch {$tap info option $opt} info]} {
	    return $info
	}
	switch -- $opt {
	    default { puts "no info-option for $opt" }
	}
    }
    # can only turn off this timeout loop when the tap is disabled
    # should figure out how to make the tap stream into a channel
    # that fires a fileevent when readable, then there would be no
    # need for this timeout polling
    
    method timeout {} {
	if {[$tap state]} {
	    foreach event [$tap get] {
		foreach {frame midi} $event break
		binary scan $midi c* bytes
		set out [format {%8lu %8lu} $frame [expr {$frame-$tapframe}]]
		set tapframe $frame
		foreach b $bytes {
		    append out [format { %02x} [expr {$b&0xff}]]
		}
		$self insert end $out\n
	    }	
	}
	set handler [after 100 [mymethod timeout]]
    }

    method save-file {} {
	set filename [tk_getSaveFile -title {Midi log to file}]
	if {$filename ne {}} {
	    write-file $filename [$self get 1.0 end]
	}
    }

    method option-menu {x y} {
	if { ! [winfo exists $win.m] } {
	    menu $win.m -tearoff no
	    $win.m add command -label {Clear} -command [mymethod delete 1.0 end]
	    $win.m add separator
	    $win.m add command -label {Save To File} -command [mymethod save-file]
	    $win.m add separator
	    $win.m add command -label {Start} -command [list $tap start]
	    $win.m add command -label {Stop} -command [list $tap stop]
	}
	tk_popup $win.m $x $y
    }
    
}


