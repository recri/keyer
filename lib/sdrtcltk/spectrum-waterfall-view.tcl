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
package provide sdrtcltk::spectrum-waterfall-view 1.0.0

#
# encapsulated spectrum-waterfall with spectrum-tap
#
package require Tk
package require snit

package require sdrtk::spectrum-waterfall
package require sdrtcl::spectrum-tap

namespace eval ::sdrtcltk {}

snit::widgetadaptor sdrtcltk::spectrum-waterfall-view {
    component tap
    # tap sdrtcl::spectrum-tap
    # -verbose -server -client -size -planbits -direction -polyphase -result
    delegate option -verbose to tap
    delegate option -server to tap
    delegate option -client to tap
    delegate option -size to tap
    delegate option -planbits to tap
    delegate option -direction to tap
    delegate option -polyphase to tap
    delegate option -result to tap

    delegate method is-busy to tap
    delegate method activate to tap
    delegate method deactivate to tap
    delegate method is-active to tap
    delegate method get to tap
    delegate method get-window to tap
    
    # hull sdrtk::spectrum-waterfall
    # -min-f -max-f -center-freq -tuned-freq -sample-rate -min -max -zoom -pan -width -command 
    # -pal -atten -automatic -smooth -multi -filter-low -filter-high -band-low -band-high -orient
    # -height -takefocus -cursor -style -class
    delegate option * to hull
    delegate method * to hull
    
    variable handler {}
    variable code {}
    
    constructor {args} {
	# puts "spectrum-waterfall-view constructor {$args}"
	installhull using sdrtk::spectrum-waterfall
	set client [winfo name [namespace tail $self]]
	set server [from args -server {}]
	set xargs {}
	if {$server ne {}} { lappend xargs -server $server }
	install tap using sdrtcl::spectrum-tap $self.deti -client ${client} {*}$xargs
	$self configurelist $args
    }

    method exposed-options {} {
	return {
	    -verbose -server -client -size -planbits -direction -polyphase -result
	    -min-f -max-f -center-freq -tuned-freq -sample-rate -min -max -zoom -pan -command 
	    -pal -atten -automatic -smooth -multi -filter-low -filter-high -band-low -band-high
	}


    }

    method info-option {opt} {
	if { ! [catch {$tap info option $opt} info]} { return $info }
	if { ! [catch {$hull info option $opt} info]} { return $info }
	switch -- $opt {
	    -min-f { return {} }
	    -max-f { return {} }
	    -center-freq { return {} }
	    -tuned-freq { return {} }
	    -sample-rate { return {} }
	    -min { return {} }
	    -max { return {} }
	    -zoom { return {} }
	    -pan { return {} }
	    -command { return {} }
	    -pal { return {} }
	    -atten { return {} }
	    -automatic { return {} }
	    -smooth { return {} }
	    -multi { return {} }
	    -filter-low { return {} }
	    -filter-high { return {} }
	    -band-low { return {} }
	    -band-high { return {} }
	    default { puts "no info-option for $opt" }
	}
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
