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

    # mode of combining lines
    option -mode -default stack -type {snit::enum -values {stack overlay}}

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
	set data [dict create bbox [bbox-empty] title {} changes 0]
	$self configure {*}$args
	$self redraw
    }
    # the window size has changed, recompute and redraw as necessary
    method window-configure {} { $self note-changes }
    method window-destroy {} {
	catch {after cancel [dict get data handler]}
    }
    method button-press {w rx ry x y b} {
	puts "button-press w=$w rx=$rx ry=$ry x=$x y=$y b=$b, cx=[$w canvasx $x] cy=[$w canvasy $y]"
    }
    method button-release {w rx ry x y b} {
	puts "button-release $w $rx $ry $x $y $b"
    }
    method note-changes {} { dict incr data changes }
    method poll-changes {} { return [dict get $data changes] }
    method clear-changes {} { dict set data changes 0 }

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

	    set lines [$self lines]
	    set nlines [llength $lines]
	    set iline 0

	    # puts "going to redraw {[$self bbox]} $nlines {$lines}"
	    
	    # find the extent of the points drawn, use the overall extent
	    lassign [$self bbox] x0 y0 x1 y1

	    # redraw the lines in their native coordinates
	    foreach name $lines {
		if {[llength [$self line points $name]] >= 4} {
		    $self line redraw $name
		    $self line configure $name -fill $options(-foreground)
		    # puts "line $name [llength [$self line points $name]] points, [$self line bbox $name]"
		}
	    }
	    
	    # flip the y-axis
	    $self scale all 0 0 1 -1
	    $self move all 0 1
	    
	    # pan the x-axis

	    # zoom the x-axis
	    
	    foreach line $lines {
		# puts "stack $line position $iline of $nlines"
		# inset by 0.1 at top and bottom
		lassign [bbox-inset [$self stack $iline $nlines] {0 0.1 0 0.1}] wx0 wy0 wx1 wy1
		# puts "stack $iline: $wx0 $wy0 $wx1 $wy1"

		# find the extent of the points drawn, use the overall extent
		lassign [$self bbox] x0 y0 x1 y1

		# compute and apply the transform
		set xo [expr {-$x0+$wx0}]
		set yo [expr {-$y0+$wy0}]
		# puts "xo yo $xo $yo"
		$hull move line-$line $xo $yo
		# puts "\$hull bbox line-$line [$hull bbox line-$line] (after move)"
		# incorporating the y-inversion by negating the y scale
		lassign [list  [expr {double($wx1-$wx0)/($x1-$x0)}] [expr {double($wy1-$wy0)/($y1-$y0)}]] xs ys
		
		if {$xs == 0 || $ys == 0} {
		    puts "bbox [$self bbox]"
		    puts "xs = $xs, wwd = [expr {double($wx1-$wx0)}], pwd = [expr {($x1-$x0)}]"
		    puts "ys = $ys, wht = [expr {double($wy1-$wy0)}], pht = [expr {($y1-$y0)}]"
		} else {
		    # make the x scale 1, 2, or 5 * power of ten
		    # puts "xs ys $xs $ys"
		    $hull scale line-$line $wx0 $wy0 [round-scale $xs] $ys
		    # puts "\$hull bbox line-$line [$hull bbox line-$line] (after scale)"
		}
		
		#lassign [$hull bbox line-$line] x0 y0 x1 y1
		#set ym [expr {($y0+$y1)/2}]
		# puts "$iline {[$hull bbox line-$line]} ym = $ym"
		# $hull scale line-$line 0 $ym 1 -1

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

    # redraw the coordinates of a line
    method {line redraw} {name} {
	if {[llength [$self line points $name]] > 4} {
	    $hull coords [$self line index $name] [$self line points $name]
	}
    }

    # configure the options of a line
    method {line configure} {name args} {
	$hull itemconfigure [$self line index $name] {*}$args
    }
    
}
