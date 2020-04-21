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

package provide sdrtk::tap-graph 1.0.0

package require Tk
package require snit
package require sdrtk::stripchart

#
# build a graphical widget which displays the keying on a midi channel
# and the response of a Goertzel filter to the keyed tone
#
# a little useless in the end, but it did sort out some issues
#
snit::widgetadaptor sdrtk::tap-graph {
    option -atap1 -default {} -configuremethod Configure
    option -atap2 -default {} -configuremethod Configure
    option -mtap1 -default {} -configuremethod Configure
    option -mtap2 -default {} -configuremethod Configure
    option -meter1 -default {} -configuremethod Configure
    option -meter2 -default {} -configuremethod Configure
    delegate option * to hull
    delegate method * to hull

    variable data -array {
	input {}
	timeout 50
    }
    
    constructor {args} {
	installhull using sdrtk::stripchart -background black -foreground white
	$self configure {*}$args
	set data(handle1) [after $data(timeout) [mymethod poll]]
	bind $win <Destroy> [mymethod destroy-window %W]
	# bind $win <ButtonPress-3> [mymethod option-menu %W %X %Y]
    }
    method destroy-window {w} {
	catch {after cancel $data(handle1)}
	catch {after cancel $data(handle2)}
	destroy .
    }
    method option-menu {w x y} {
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

    method exposed-options {} { return {-atap1 -atap2 -mtap1 -mtap2 -meter1 -meter2} }
    method {info-option -atap1} {} { return {audio tap name} }
    method {info-option -atap2} {} { return {audio tap name} }
    method {info-option -mtap1} {} { return {midi tap name} }
    method {info-option -mtap2} {} { return {midi tap name} }
    method {info-option -meter1} {} { return {meter tap name} }
    method {info-option -meter2} {} { return {meter tap name} }

    method poll {} {
	foreach opt {-atap1 -atap2 -mtap1 -mtap2 -meter1 -meter2} {
	    if {$options($opt) ne {}} { 
		if { ! [catch {$options($opt) get} get]} {
		    lappend data(input) $opt $get
		} else {
		    error "sdrtk::goertzel: $options($opt) get threw $get"
		}
	    }
	}
	if {$data(input) ne {}} { 
	    set data(handle2) [after idle [mymethod process $data(input)]]
	    set data(input) {}
	}
	set data(handle1) [after $data(timeout) [mymethod poll]]
    }

    method process {input} {
	# puts "sdrtk::goertzel process called with [llength $data(input)] items queued"
	foreach {opt get} $input {
	    set tag [list [llength $get] $opt]
	    switch -glob $tag {
		{0 -*} continue
		{* -meter*} {
		}
		{* -atap*} {
		}
		{* -mtap*} {
		    regexp {^-mtap(\d)$} $opt all tap
		    foreach item $get {
			foreach {frame bytes} $item break
			if {[binary scan $bytes ccc cmd note vel] != 3} continue
			if {($cmd&0xff) == 0x80} {
			    # note off synthesized by someone
			    set cmd 0x90
			    set vel 0
			}
			set line l$opt-$note
			#set vel [expr {-$vel}]
			if { ! [$win exists line $line]} {
			    # puts "add line $line"
			    $win add line $line
			    set data(last-$line-vel) 0
			    # $self extend $line 0 0
			    # add the line margin icons
			}
			$self extend $line $frame $data(last-$line-vel) $frame $vel
			set data(last-$line-vel) $vel
			# some NOTE_OFF messages were being slipped in
			# puts [format "$opt %7d %02x %d %d" $frame [expr {$cmd&0xff}] $note $vel]
		    }
		}
		default {
		    puts "sdrtk::tap-graph process switch $tag not caught"
		}
	    }
	}
    }
    
    method extend {line args} {
	$win line add point $line {*}$args
	if {0} {
	    
	    # check
	    set pts [$win line points $line]
	    set xmax [set xmin [lindex $pts 0]]
	    set ymax [set ymin [lindex $pts 1]]
	    foreach {x y} $pts {
		set xmin [tcl::mathfunc::min $xmin $x]
		set xmax [tcl::mathfunc::max $xmax $x]
		set ymin [tcl::mathfunc::min $ymin $y]
		set ymax [tcl::mathfunc::max $ymax $y]
	    }
	    puts "$xmin $ymin $xmax $ymax [$win line bbox $line]"
	}
    }

    method rescale {wd ht} {
    }

    method Configure {opt value} { 
	switch -- $opt {
	    -atap1 -
	    -atap2 -
	    -mtap1 -
	    -mtap2 -
	    -meter1 -
	    -meter2 {
		if {[catch {$value get} get]} {
		    if {$get eq "midi-tap $value is not running"} {
			$value start
			return [$self Configure $opt $value]
		    }
		    error "$value get threw $get"
		}
	    }
	}
	set options($opt) $value
    }
}
