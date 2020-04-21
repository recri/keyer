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

package provide sdrtk::stripchart 1.0.0

package require Tk
package require snit

#
# a stripchart plotting widget and friends
# forked from graph.tcl when it began to lose generic function
#

snit::widgetadaptor sdrtk::stripchart {

    # minimum and maximum of arguments
    proc min {args} { return [tcl::mathfunc::min {*}$args] }
    proc max {args} { return [tcl::mathfunc::max {*}$args] }

    # bounding boxes, abused as rectanges, too.
    # make an empty bbox
    proc bbox-empty {} { return {inf inf -inf -inf} }

    # test for an empty bbox
    proc bbox-is-empty {bbox} { return [string equal -nocase $bbox {inf inf -inf -inf}] }

    # add a point to a bbox
    proc bbox-add-point {bbox args} {
	lassign $bbox x0 y0 x1 y1
	foreach {x y} $args {
	    lappend x0 $x
	    lappend x1 $x
	    lappend y0 $y
	    lappend y1 $y
	}
	return [list [min {*}$x0] [min {*}$y0] [max {*}$x1] [max {*}$y1]]
    }
    
    # form the union of two bboxen
    proc bbox-union {bbox1 bbox2} {
	return [bbox-add-point [bbox-empty] {*}bbox1 {*}bbox2]
    }

    # inset a box by percent of width or height on each edge
    proc bbox-inset {bbox inbox} {
	lassign $bbox x0 y0 x1 y1
	lassign $inbox px0 py0 px1 py1
	set wd [expr {$x1-$x0}]
	set ht [expr {$y1-$y0}]
	return [list [expr {$x0+$px0*$wd}] [expr {$y0+$py0*$ht}] [expr {$x1-$px1*$wd}] [expr {$y1-$py1*$ht}]]
    }
    
    # bbox elements by compass direction
    proc bbox-w {bbox} { return [lindex $bbox 0] }
    proc bbox-n {bbox} { return [lindex $bbox 1] }
    proc bbox-e {bbox} { return [lindex $bbox 2] }
    proc bbox-s {bbox} { return [lindex $bbox 3] }
    
    # redraw rate limit
    option -redraw-rate -default 8

    # default foreground color
    option -foreground -default black -configuremethod Configure

    # send everything else to the canvas
    delegate option * to hull
    delegate method * to hull
    
    variable data

    constructor {args} {
	installhull using canvas
	bind $win <Configure> [mymethod window-configure]
	bind $win <Destroy> [mymethod window-destroy]
	bind $win <ButtonPress> [mymethod button-press %W %X %Y %x %y %b]
	bind $win <ButtonRelease> [mymethod button-release %W %X %Y %x %y %b]
	set data [dict create bbox [bbox-empty] title {} changes 0 x-pan 0 x-zoom 0 frames-per-screen-x 1 frame-at-left-edge 0]
	$self configure {*}$args
	$self redraw
    }

    # the window size has changed, recompute and redraw as necessary
    method window-configure {} { $self note-changes }
    method window-destroy {} { catch {after cancel [dict get data handler]} }

    # a button was pressed or released
    method button-press {w rx ry x y b} {
	switch $b {
	    1 {
		# pan left/right, use scan dragto?
		# translate x into frames
		$self scan mark $x 0
		$self set-start-x-drag $x
		bind $w <Motion> [mymethod button-drag %W %X %Y %x %y 1]
	    }
	    2 {
	    }
	    3 {
		# option menu
		$self option-menu $w $rx $ry
	    }
	    4 {
		# scroll button down, zoom in
		# must change pan, too, to preserve mouse position
		puts "zoom in x-zoom [$self x-zoom] frames-per-screen-x [$self frames-per-screen-x]"
		set zoom [$self frames-per-screen-x]
		switch -glob $zoom {
		    1 - 1.0 { }
		    1* { set zoom [expr {$zoom/2}] }
		    2* { set zoom [expr {$zoom/2}] }
		    5* { set zoom [expr {$zoom/2.5}] }
		}
		$self set-x-zoom $zoom
	    }
	    5 {
		# scroll button, zoom out
		# must change pan, too, to preserve mouse position
		puts "zoom out x-zoom [$self x-zoom] frames-per-screen-x [$self frames-per-screen-x]"
		set zoom [$self frames-per-screen-x]
		switch -glob $zoom {
		    1* { set zoom [expr {2*$zoom}] }
		    2* { set zoom [expr {2.5*$zoom}] }
		    5* { set zoom [expr {2*$zoom}] }
		}
		$self set-x-zoom $zoom
	    }
	    default {
		puts "button-press w=$w rx=$rx ry=$ry x=$x y=$y b=$b, cx=[$w canvasx $x] cy=[$w canvasy $y]"
	    }
	}
    }
    method button-drag {w rx ry x y b} {
	switch $b {
	    1 {
		$self scan dragto $x 0 
		$self set-x-pan [expr {[$self frame-at-left-edge]+($x-[$self start-x-drag])*[$self frames-per-screen-x]}]
	    }
	    default {
		puts "button-motion $w $rx $ry $x $y $b"
	    }
	}
    }
    method button-release {w rx ry x y b} {
	switch $b {
	    1 {
		$self scan dragto $x 0
		$self set-x-pan [expr {($x-[$self start-x-drag])/[$self frames-per-screen-x]}]
		bind $w <Motion> {}
	    }
	    4 {}
	    5 {}
	    default {
		puts "button-release $w $rx $ry $x $y $b"
	    }
	}
    }

    method option-menu {w x y} {
	if {[winfo exists $win.m]} { destroy $win.m }
	menu $win.m -tearoff no
	$win.m add command -label {Start collecting} -command [list $win start-collecting]
	$win.m add command -label {Stop collecting} -command [list $win stop-collecting]
	$win.m add separator
	$win.m add command -label {Clear zoom/pan} -command [list $win clear-zoom-pan]
	$win.m add command -label {Clear window} -command [list $win clear-window]
	tk_popup $win.m $x $y
    }
    method start-collecting {} {
	# foreach tap [$self get-taps] { $tap start }
    }
    method stop-collecting {} {
	# foreach tap [$self get-taps] { $tap stop }
    }
    method clear-zoom-pan {} {
	$self set-x-zoom 0
	$self set-x-pan 0
	$self note-changes
    }
    method clear-window {} {
	$self delete lines
    }
    # someone noticed some changes
    method note-changes {} { dict incr data changes }
    method poll-changes {} { return [dict get $data changes] }
    method clear-changes {} { dict set data changes 0 }

    # the x-pan set by mouse twiddling
    method x-pan {} { return [dict get $data x-pan] }
    method set-x-pan {v} { 
	puts "set-x-pan $v was [$self x-pan]"
	dict set data x-pan $v
	$self note-changes
    }
    # the x-zoom set by mouse twiddling
    method x-zoom {} { return [dict get $data x-zoom] }
    method set-x-zoom {v} { 
	puts "set-x-zoom $v was [$self x-zoom]"
	dict set data x-zoom $v
	$self note-changes }
    # the frames scale factor used to draw the screen
    method frames-per-screen-x {} { return [dict get $data frames-per-screen-x] }
    method set-frames-per-screen-x {v} {
	puts "set-frames-per-screen-x $v was [$self frames-per-screen-x]"
	dict set data frames-per-screen-x $v
    }
    # the frame at the left edge when the screen was drawn
    method frame-at-left-edge {} { return [dict get $data frame-at-left-edge] }
    method set-frame-at-left-edge {v} { return [dict set data frame-at-left-edge $v] }
    # the screen x at the start of the drag
    method start-x-drag {} { return [dict get $data start-x-drag] }
    method set-start-x-drag {v} { dict set data start-x-drag $v }
    
    # return one of the objects we're managing
    method lines {} { return [lsort [dict keys [dict get $data line]]] }
    method bbox {} { return [dict get $data bbox] }
    method window {} { return [list 0 0 [winfo width $win] [winfo height $win]] }
    method stack {i n} {
	lassign [$self window] wx0 wy0 wx1 wy1
	set dy [expr {($wy1-$wy0)/$n}]
	return [list $wx0 [expr {$wy0+$i*$dy}] $wx1 [expr {$wy0+$i*$dy+$dy}]]
    }

    # return if a named object exists
    method {exists line} {name} { return [dict exists $data line $name] }
    method {exists bbox} {name} { return [dict exists $data bbox $name] }

    # return parts of a named line
    method {line points} {name} { return [dict get $data line $name points] }
    method {line bbox} {name} { return [dict get $data line $name bbox] }
    method {line index} {name} { return [dict get $data line $name index] }
    method {line first-x} {name} { return [lindex [$self line bbox $name] 0] }
    method {line last-x} {name} { return [lindex [$self line bbox $name] 2] }
    method {line first-y} {name} { return [lindex [$self line points $name] 1] }
    method {line last-y} {name} { return  [lindex [$self line points $name] end] }

    # configure the foreground color
    method {Configure -foreground} {val} {
	set options(-foreground) $val
	$self note-changes
    }

    # round a scale factor so it is {1,2,5} times a power of ten
    # and smaller than the initial scale factor 
    proc round-scale {s} {
	set r [expr {pow(10,int(log10($s)))}]
	foreach f {0.1 0.2 0.5 1 2 5} {
	    if {$f*$r <= $s} { set result $f }
	}
	return [expr {$result*$r}]
    }

    # redraw and rescale the plot
    method redraw {} {
	# don't redraw an empty graph
	# don't redraw if no changes
	if { ! [bbox-is-empty [$self bbox]] && [$self poll-changes] != 0} {
	
	    # clear the change counter
	    $self clear-changes

	    # count the lines to draw
	    set lines [$self lines]
	    set nlines [llength $lines]
	    set iline 0

	    # puts "going to redraw {[$self bbox]} $nlines {$lines}"
	    
	    # find the extent of the points drawn, use the overall extent
	    lassign [$self bbox] x0 y0 x1 y1

	    # find the extent of the window to draw into
	    lassign [$self window] wx0 wy0 wx1 wy1

	    # find or make up the x-pan coordinate and write it into x0
	    set xpan [$self x-pan]
	    if {$xpan == 0} { 
		# pan to beginning of data set
		set xpan $x0 
	    } else { 
		# truncate data set at pan point
		set x0 $xpan
	    }
	    # remember where it landed
	    $self set-frame-at-left-edge $x0

	    # find or make up the x-zoom scale factor and use it to find x1
	    set xzoom [$self x-zoom]
	    if {$xzoom == 0} {
		# compute zoom from points to display
		set xzoom [round-scale [expr {double($x1-$x0)/($wx1-$wx0)}]]
	    } else {
		# compute points displayed from amount to zoom
		set x1 [expr {$x0+($wx1-$wx0)*$xzoom}]
	    }
	    # remember how it turned out
	    $self set-frames-per-screen-x $xzoom

	    # redraw the lines in their native coordinates, clipped to x0 y0 x1 y1
	    foreach name $lines {
		if {[llength [$self line points $name]] >= 4} {
		    $self line redraw $name $x0 $y0 $x1 $y1
		    $self line configure $name -fill $options(-foreground)
		    # puts "line $name [llength [$self line points $name]] points, [$self line bbox $name]"
		}
	    }
	    
	    # flip the y-axis
	    $self scale all 0 0 1 -1
	    $self move all 0 1
	    
	    # pan the x-axis
	    $self move all [expr {-$x0}] 0

	    # zoom the x-axis
	    $self scale all 0 0 [expr {1.0/$xzoom}] 1

	    # move the lines to their position in the stack of strip charts
	    foreach line $lines {
		# puts "stack $line position $iline of $nlines"
		# inset by 0.1 at top and bottom
		lassign [bbox-inset [$self stack $iline $nlines] {0 0.1 0 0.1}] wx0 wy0 wx1 wy1
		# puts "stack $iline: $wx0 $wy0 $wx1 $wy1"

		# compute and apply the transform
		set yo [expr {-$y0+$wy0}]
		# puts "yo $yo"
		$hull move line-$line 0 $yo
		# puts "\$hull bbox line-$line [$hull bbox line-$line] (after move)"
		# incorporating the y-inversion by negating the y scale
		set ys [expr {double($wy1-$wy0)/($y1-$y0)}]
		
		if {$ys == 0} {
		    puts "bbox [$self bbox]"
		    puts "ys = $ys, wht = [expr {double($wy1-$wy0)}], pht = [expr {($y1-$y0)}]"
		} else {
		    # puts "ys $ys"
		    $hull scale line-$line $wx0 $wy0 1 $ys
		    # puts "\$hull bbox line-$line [$hull bbox line-$line] (after scale)"
		}
		
		incr iline
	    }
	}
	dict set data handler [after [expr {int(0.5+1000.0/$options(-redraw-rate))}] [mymethod redraw]]
    }

    # augment the plotted bounding box by a point
    method {bbox-add-point} {args} { dict set data bbox [bbox-add-point [$self bbox] {*}$args] }

    # delete everything
    method {delete all} {} {
	dict set data line [dict create]
	dict set data bbox [bbox-empty]
	$hull delete all
	$self note-changes
    }
    method {delete lines} {} {
	dict set data bbox [bbox-empty]
	foreach name [$self lines] {
	    dict set data line $name points {}
	    dict set data line $name bbox [bbox-empty]
	    $self coords [$self line index $name] 0 0 0 0
	}
    }
    # add a new line with points
    method {add line} {name args} {
	#dict lappend data lines $name
	dict set data line $name [dict create \
				      index [$hull create line 0 0 0 0 -tags [list plotted line line-$name]] \
				      points {} \
				      bbox [bbox-empty] \
				     ]
	if {$args ne {}} { $self line add point $name $args }
	$self note-changes
    }

    # add a point(s) to a line
    method {line add point} {name args} {
	$self bbox-add-point {*}$args
	dict set data line $name points [concat [$self line points $name] $args]
	dict set data line $name bbox [bbox-add-point [$self line bbox $name] {*}$args]
	$self note-changes
    }

    # redraw the coordinates of a line, args is a bounding box
    method {line redraw} {name args} {
	if {$args eq {}} { set args [$self line bbox $name] }
	lassign $args x0 y0 x1 y1
	if {[llength [$self line points $name]] > 4} {
	    set y0 {}
	    set y1 {}
	    set xy {}
	    foreach {x y} [$self line points $name] {
		if {$x<$x0} {
		    set y0 $y
		} elseif {$x<=$x1} {
		    lappend xy $x $y
		    set y1 $y
		} else {
		    set y1 $y
		    break
		}
	    }
	    if {$y0 eq {}} { set y0 0 }
	    if {$y1 eq {}} { set y1 0 }
	    $hull coords [$self line index $name] [concat $x0 $y0 $xy $x1 $y1]
	}
    }

    # configure the options of a line
    method {line configure} {name args} {
	$hull itemconfigure [$self line index $name] {*}$args
    }
    
}
