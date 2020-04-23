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
# what this needs is a locator map in the lower right corner
# which outlines the currently displayed area on a plot of the
# entire session.  The displayed area should not go outside the
# session.
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
    
    proc bbox-width {bbox} { return [expr {[bbox-e $bbox]-[bbox-w $bbox]}] }
    proc bbox-height {bbox} { return [expr {[bbox-s $bbox]-[bbox-n $bbox]}] }

    # return the i'th of n horizontal strips of bbox
    proc stack {bbox i n} {
	lassign $bbox wx0 wy0 wx1 wy1
	set dy [expr {($wy1-$wy0)/$n}]
	return [list $wx0 [expr {$wy0+$i*$dy}] $wx1 [expr {$wy0+$i*$dy+$dy}]]
    }

    # zoom larger, ie fewer frames per screen x
    proc zoom-larger {zoom} {
	switch -glob $zoom {
	    1 -
	    1.0 { return $zoom }
	    1* -
	    2* { return [expr {$zoom/2}] }
	    5* { return [expr {$zoom/2.5}] }
	    default { error "ack, $zoom isn't \[125]*" }
	}
    }
    # zoom smaller, ie more frames per screen x
    proc zoom-smaller {zoom} {
	switch -glob $zoom {
	    1* -
	    5* { return [expr {2*$zoom}] }
	    2* { return [expr {2.5*$zoom}] }
	    default { error "ack, $zoom isn't \[125]*" }
	}
    }

    # redraw rate limit
    option -redraw-rate -default 8

    # default foreground color
    option -foreground -default black -configuremethod Configure

    # send everything else to the canvas
    delegate option * to hull
    delegate method * to hull
    
    variable data [dict create {*}{
	bbox {} title {}
	changes 0 x-pan 0 x-zoom 0 true-x-pan 0 true-x-zoom 0
	main-frame {} locate-frame {}
    }]

    constructor {args} {
	installhull using canvas
	bind $win <Configure> [mymethod window-configure]
	bind $win <Destroy> [mymethod window-destroy]
	bind $win <ButtonPress> [mymethod button-press %W %X %Y %x %y %b]
	bind $win <ButtonRelease> [mymethod button-release %W %X %Y %x %y %b]
	dict set data bbox [bbox-empty]
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
		# pan left/right
		dict update data last-x-drag last-x-drag start-x-drag start-x-drag {
		    set last-x-drag $x
		    set start-x-drag $x
		}
		bind $w <Motion> [mymethod button-drag %W %X %Y %x %y 1]
	    }
	    2 {
	    }
	    3 {
		# option menu
		$self option-menu $w $rx $ry
	    }
	    4 {
		# vertical scroll button down, zoom out
		# must change pan, too, to preserve mouse position
		dict update data x-zoom x-zoom true-x-zoom true-x-zoom {
		    set x-zoom [zoom-smaller ${true-x-zoom}]
		}
		$self note-changes
	    }
	    5 {
		# vertical scroll button up, zoom in
		# must change pan, too, to preserve mouse position
		dict update data x-zoom x-zoom true-x-zoom true-x-zoom {
		    set x-zoom [zoom-larger ${true-x-zoom}]
		}
		$self note-changes
	    }
	    6 {
		# horizontal scroll button, 
	    }
	    7 {
		# horizontal scroll button,
	    }
	    default {
		puts "button-press w=$w rx=$rx ry=$ry x=$x y=$y b=$b, cx=[$w canvasx $x] cy=[$w canvasy $y]"
	    }
	}
    }
    method button-drag {w rx ry x y b} {
	switch $b {
	    1 {
		dict update data last-x-drag last-x-drag {
		    $hull move main [expr {$x-${last-x-drag}}] 0
		    set last-x-drag $x
		}
	    }
	    default {
		puts "button-motion $w $rx $ry $x $y $b"
	    }
	}
    }
    method button-release {w rx ry x y b} {
	switch $b {
	    1 {
		bind $w <Motion> {}
		$self button-drag $w $rx $ry $x $y $b
		dict update data x-pan x-pan true-x-pan true-x-pan true-x-zoom true-x-zoom start-x-drag start-x-drag last-x-drag last-x-drag {
		    set x-pan [expr {${true-x-pan}-(${last-x-drag}-${start-x-drag})*${true-x-zoom}}]
		    #puts "start ${start-x-drag} end ${last-x-drag} true-x-pan ${true-x-pan} true-x-zoom ${true-x-zoom}"
		    #puts "delta x-pan [expr {-(${last-x-drag}-${start-x-drag})*${true-x-zoom}}]"
		}
		$self note-changes
	    }
	    4 {}
	    5 {}
	    6 {}
	    7 {}
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
	dict set data x-zoom 0
	dict set data x-pan 0
	$self note-changes
    }
    method clear-window {} {
	$self delete lines
	$self clear-zoom-pan
	$hull delete main
	$hull delete locate
    }
    # someone noticed some changes
    method note-changes {} { dict incr data changes }
    method poll-changes {} { return [dict get $data changes] }
    method clear-changes {} { dict set data changes 0 }

    # return one of the objects we're managing
    method lines {} { return [lsort [dict keys [dict get $data line]]] }
    method bbox {} { return [dict get $data bbox] }
    method window {} { return [list 0 0 [winfo width $win] [winfo height $win]] }

    # return if a named object exists
    method {exists line} {name} { return [dict exists $data line $name] }
    method {exists bbox} {name} { return [dict exists $data bbox $name] }

    # return parts of a named line
    method {line points} {name} { return [dict get $data line $name points] }
    method {line bbox} {name} { return [dict get $data line $name bbox] }

    # configure the foreground color
    method {Configure -foreground} {val} {
	set options(-foreground) $val
	$self note-changes
    }

    # round a scale factor, frames/pixel, so it is {1,2,5} times a power of ten
    # and one step larger than the initial scale factor 
    proc round-scale {s} {
	set r [expr {pow(10,int(log10($s)))}]
	foreach f {0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 20 50} {
	    if {$f*$r > $s} { 
		return [expr {$f*$r}]
	    }
	}
    }

    # redraw and rescale the plot inside the 
    method redraw {} {
	# don't try to redraw an empty graph
	# don't redraw if no changes to reflect
	if { ! [bbox-is-empty [$self bbox]] && [$self poll-changes] != 0} {
	    if {[catch {
		# clear the change counter
		$self clear-changes
		
		# clear the canvas
		$hull delete all
		
		# count the lines to draw
		set nlines [llength [$self lines]]
		
		# puts "going to redraw {[$self bbox]} $nlines {$lines}"
		# draw the main screen
		set mainframe [bbox-inset [$self window] [list 0 0 0 [expr {1/($nlines+1.0)}]]]
		lassign [$self redraw-strips $mainframe [dict get $data x-pan] [dict get $data x-zoom] main] left zoom
		

		#puts "main drawn in $mainframe with $left $zoom"
		#puts "main covers $left to [expr {$left+[bbox-width $mainframe]*$zoom}]"
		set mainleft $left
		set mainright [expr {$left+[bbox-width $mainframe]*$zoom}]
		
		# save the result pan and zoom
		dict set data true-x-pan $left
		dict set data true-x-zoom $zoom
		
		# draw the locator map
		set locframe [bbox-inset [$self window] [list 0.5 [expr {$nlines/($nlines+1.0)}] 0 0]]
		set locinset [bbox-inset $locframe {0.05 0.1 0.05 0.1}]
		set locdraw [bbox-inset $locinset {0.05 0.1 0.05 0.1}]
		$hull create rect $locframe -outline $options(-foreground) -fill {} -tags locate-frame
		lassign [$self redraw-strips $locdraw 0 0 locate] left zoom
		
		# check that the result pan and zoom make sense
		#puts "locate drawn in $locdraw with $left $zoom"
		#puts "locate covers $left to [expr {$left+[bbox-width $locdraw]*$zoom}]"
		
		# draw the locator rectangle
		set rleft [expr {[bbox-w $locdraw]+($mainleft-$left)/$zoom}]
		set rright [expr {[bbox-w $locdraw]+($mainright-$left)/$zoom}]
		set rect [list $rleft [bbox-n $locinset] $rright [bbox-s $locinset]]
		$hull create rect $rect -outline $options(-foreground) -fill {} -tags locate-main
		
	    } error]} {
		puts "error in redraw logic: $error"
	    }
	}
	dict set data handler [after [expr {int(0.5+1000.0/$options(-redraw-rate))}] [mymethod redraw]]
    }
    
    # draw the strips into a specified frame in the canvas, 
    # applying the specified pan and zoom (which are 0 if unspecified)
    # and returning the result xpan (frame at left edge) and xzoom (frames per screen x).
    method redraw-strips {frame xpan xzoom tag} {
	# find the extent of the points to be drawn, use the overall extent
	# so all strips get the same scaling
	# start from the overall extent and whittle it down
	lassign [$self bbox] x0 y0 x1 y1
	
	# find the extent of the window to draw into
	lassign $frame wx0 wy0 wx1 wy1
	
	# get the lines to be drawn
	
	# find or make up the x-pan coordinate and write it into x0
	if {$xpan == 0} { 
	    # pan to beginning of data set
	    set xpan $x0 
	} else { 
	    set xpan [tcl::mathfunc::max $x0 $xpan]
	    # truncate data set at pan point
	    set x0 $xpan
	    set maxzoom [expr {double($x1-$x0)/($wx1-$wx0)}]
	}
	# remember where it landed
	set leftedge $x0
	
	# find or make up the x-zoom scale factor and use it to find x1
	if {$xzoom == 0} {
	    # compute zoom from points to display
	    set xzoom [round-scale [expr {double($x1-$x0)/($wx1-$wx0)}]]
	} else {
	    # compute points displayed from amount to zoom
	    # puts "both x-pan and x-zoom set, new x1 [expr {$x0+($wx1-$wx0)*$xzoom}] old $x1"
	    set x1 [expr {$x0+($wx1-$wx0)*$xzoom}]
	}
	# remember how it turned out
	set framesper $xzoom
	
	# redraw the lines in their native coordinates, clipped to x0 y0 x1 y1
	# puts "redraw lines clipped at x {$x0 .. $x1}"
	foreach name [$self lines] {
	    if {[llength [$self line points $name]] >= 4} {
		$self line redraw $tag $name $x0 $y0 $x1 $y1
		$self line configure $tag $name -fill $options(-foreground)
		# puts "line $name [llength [$self line points $name]] points, [$self line bbox $name]"
	    }
	}
	
	# flip the y-axis
	$self scale $tag 0 0 1 -1
	$self move $tag 0 1
	
	# pan the x-axis
	$self move $tag [expr {-$x0}] 0
	
	# zoom the x-axis
	$self scale $tag 0 0 [expr {1.0/$xzoom}] 1
	
	# position in window
	$self move $tag $wx0 0
	
	# move the lines to their position in the stack of strip charts
	set nlines [llength [$self lines]]
	set iline 0
	foreach line [$self lines] {
	    # puts "stack $line position $iline of $nlines"
	    # inset by 0.1 at top and bottom
	    lassign [bbox-inset [stack $frame $iline $nlines] {0 0.1 0 0.1}] wx0 wy0 wx1 wy1
	    # puts "stack $iline: $wx0 $wy0 $wx1 $wy1"
	    
	    # compute and apply the transform
	    set yo [expr {-$y0+$wy0}]
	    # puts "yo $yo"
	    $hull move $tag-$line 0 $yo
	    # puts "\$hull bbox line-$line [$hull bbox line-$line] (after move)"
	    # incorporating the y-inversion by negating the y scale
	    set ys [expr {double($wy1-$wy0)/($y1-$y0)}]
	    
	    if {$ys == 0} {
		puts "bbox [$self bbox]"
		puts "ys = $ys, wht = [expr {double($wy1-$wy0)}], pht = [expr {($y1-$y0)}]"
	    } else {
		# puts "ys $ys"
		$hull scale $tag-$line $wx0 $wy0 1 $ys
		# puts "\$hull bbox line-$line [$hull bbox line-$line] (after scale)"
	    }
	    
	    incr iline
	}
	return [list $leftedge $framesper]
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
	}
    }
    # add a new line with points
    method {add line} {name args} {
	#dict lappend data lines $name
	dict set data line $name [dict create \
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
    method {line redraw} {tag name args} {
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
	    $hull create line [concat $x0 $y0 $xy $x1 $y1] -tags [list $tag $tag-$name] -fill $options(-foreground)
	}
    }
    
    # configure the options of a line
    method {line configure} {tag name args} {
	$hull itemconfigure $tag-$name {*}$args
    }
    
}
