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
# spectrum-waterfall with spectrum-tap
#
package require Tk
package require snit

package require sdrtcl::spectrum-tap
package require sdrtk::spectrum-waterfall

namespace eval ::sdrtcltk {}

snit::widgetadaptor sdrtcltk::spectrum-waterfall-view {
    component tap

    # tap sdrtcl::spectrum-tap
    # -verbose -server -client -size -planbits -direction -polyphase -result
    option -verbose -default 0 -configuremethod TapConfigure
    option -server -default {} -configuremethod TapConfigure
    option -client -default spec -configuremethod TapConfigure
    option -size -default 2048 -configuremethod TapConfigure
    option -planbits -default 0 -configuremethod TapConfigure
    option -direction -default -1 -configuremethod TapConfigure
    option -polyphase -default 1 -configuremethod TapConfigure
    option -result -default dB -configuremethod TapConfigure

    method TapConfigure {opt val} { 
	set options($opt) $val
	lappend data(tap-deferred-opts) $opt $val 
    }
    method is-busy {} { return 0 }

    delegate method activate to tap
    delegate method deactivate to tap
    delegate method is-active to tap
    delegate method get to tap
    delegate method get-window to tap
    
    # hull sdrtk::spectrum-waterfall
    # tk-options {-sample-rate -pal -max -min -smooth -multi -zoom -pan -band-low -band-high}
    # -sample-rate -pal -min -max -smooth -multi -zoom -pan -band-low -band-high
    # -min-f -max-f -center-freq -tuned-freq -width -command 
    # -atten -automatic -filter-low -filter-high -orient
    # -height -takefocus -cursor -style -class
    # -f-rx1 default = 7012352
    option -sample-rate -default 48000 -configuremethod HullConfigure
    option -min-f -default 6988352 -configuremethod HullConfigure
    option -max-f -default 7036352 -configuremethod HullConfigure
    option -min -default -160 -configuremethod HullConfigure
    option -max -default 0 -configuremethod HullConfigure
    method HullConfigure {opt val} { 
	set options($opt) $val
	$hull configure $opt $val
    }

    # tuner sdrtcl::tuner
    # retune-options {}
    # -mode -freq -lo-freq -cw-freq -carrier-freq -bpf-low -bpf-high
    option -period -default 50

    delegate option * to hull
    delegate method * to hull

    variable data -array {
	after {}
	frequencies {}
	tap-deferred-opts {}
    }
    
    constructor {args} {
	# puts "spectrum-waterfall-view constructor {$args}"
	installhull using sdrtk::spectrum-waterfall -multi 1
	set client [winfo name [namespace tail $self]]
	set server [from args -server {}]
	set xargs {}
	if {$server ne {}} { lappend xargs -server $server }
	install tap using sdrtcl::spectrum-tap $self.deti -client ${client} {*}$xargs -size $options(-size) -result $options(-result)
	$self configure {*}$args -size $options(-size)
	set data(after) [after $options(-period) [mymethod Update]]
    }

    method UpdateFrequencies {} {
	#puts "recomputing frequencies for length $n from [llength $data(frequencies)]"
	set data(frequencies) {}
	set maxf [expr {$options(-sample-rate)/2.0}]
	set minf [expr {-$maxf}]
	set df [expr {double($options(-sample-rate))/$options(-size)}]
	for {set i 0} {$i < $options(-size)} {incr i} {
	    lappend data(frequencies) [expr {$minf+$i*$df}]
	}
	#puts "recomputed [llength $data(frequencies)] frequencies"
    }

    method BlankUpdate {{msg {}}} {
	if {[llength $data(frequencies)] != $options(-size)} { $self UpdateFrequencies }
	foreach x $data(frequencies) { lappend xy $x $options(-min) }
	$hull update $xy
	# start the next
	set data(after) [after $options(-period) [mymethod Update]]
	if {$msg ne {}} { puts $msg }
    }
    method Update {} {
	if {[$tap is-busy]} {
	    # if busy, then supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# handle configuration
	if {$data(tap-deferred-opts) ne {}} {
	    set config $data(tap-deferred-opts)
	    set data(tap-deferred-opts) {}
	    #puts "Update configure $config"
	    if {[catch {$tap configure {*}$config} error]} {
		puts "$tap configurelist $config threw $error"
	    }
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if not active
	if { ! [$self is-active]} {
	    # supply a blank
	    $self BlankUpdate
	    # finished
	    return
	}
	# if {[incr data(nspectrum)] == 1} { puts [join [::sdrkitx::$options(-name) configure] \n] }
	# capture spectrum and pass to display
	lassign [$tap get] frame dB
	binary scan $dB f* dB
	#puts "Update capture got $n bins"
	if {[llength $data(frequencies)] != $options(-size)} {
	    $self UpdateFrequencies
	}
	set n [llength $dB]
	if {$n != $options(-size)} {
	    $self BlankUpdate "received $n spectrum values instead of $options(-size)"
	    return
	}
	set dB [concat [lrange $dB [expr {$n/2}] end] [lrange $dB 0 [expr {($n/2)-1}]]]
	foreach x $data(frequencies) y $dB {
	    if {$y < $options(-min) || $y > $options(-max)} {
		$self BlankUpdate "received out of bounds dB value: $y"
		return
	    }
	    lappend xy $x $y
	}
	#puts "$xy"
	$hull update $xy
	# start the next
	set data(after) [after $options(-period) [mymethod Update]]
    }
    
    method exposed-options {} {
	return {
	    -verbose -server -client -size -planbits -direction -polyphase -result
	    -min-f -max-f -center-freq -tuned-freq -sample-rate -min -max -zoom -pan -command 
	    -pal -atten -automatic -smooth -multi -filter-low -filter-high -band-low -band-high
	    -period
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
	    -period { return {} }
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
