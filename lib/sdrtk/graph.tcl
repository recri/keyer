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

package provide sdrtk::graph 1.0.0

package require Tk
package require snit
package require sdrtk::tick-labels

#
# a graph plotting widget and friends
#

snit::widgetadaptor sdrtk::graph {
    component ticklabels

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
	lassign $bbox1 x10 y10 x11 y11
	lassign $bbox2 x20 y20 x21 y21
	set nbbox [list [min $x10 $x20] [min $y10 $y20] [max $x11 $x21] [max $y11 $y21]]
	#puts "bbox-union $bbox1 $bbox2 -> $nbbox"
	return $nbbox
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
    
    # graph frame in window as fraction
    option -frame -default {0.1 0.1 0.1 0.1} -configuremethod Configure

    # inset of graph inside frame as fraction
    option -inset -default {0.1 0.1 0.1 0.1} -configuremethod Configure

    # redraw rate limit
    option -redraw-rate -default 8

    # mode of combining lines
    option -mode -default stack -type {snit::enum -values {stack overlay}}

    # invert the y axis sense
    option -invert -default 1 -type snit::boolean

    # default foreground color
    option -foreground -default black -configuremethod Configure

    # send everything else to the canvas
    delegate option * to hull
    delegate method * to hull
    
    variable data {}

    constructor {args} {
	installhull using canvas
	install ticklabels using sdrtk::tick-labels %AUTO%
	bind $win <Configure> [mymethod window-configure]
	set data [dict create bbox [bbox-empty] inset {} frame {} title {} redraw-time [clock milliseconds]]
	$self configure {*}$args
	$self recompute frame
	$self recompute inset
	# puts "constructor frame [$self frame], inset [$self inset]"
	$hull create rectangle [$self frame] -tag frame -outline $options(-foreground)
    }
	
    # return one of the objects we're managing
    method lines {} { return [lsort [dict keys [dict get $data line]]] }
    method bbox {} { return [dict get $data bbox] }
    method inset {} { return [dict get $data inset] }
    method frame {} { return [dict get $data frame] }
    method window {} { return [list 0 0 [winfo width $win] [winfo height $win]] }
    method stack {i n} {
	lassign [$self window] wx0 wy0 wx1 wy1
	set dy [expr {($wy1-$wy0)/$n}]
	return [list $wx0 [expr {$wy0+$i*$dy}] $wx1 [expr {$wy0+$i*$dy+$dy}]]
    }

    # return if a named object exists
    method {exists line} {name} { return [dict exists $data line $name] }
    method {exists bbox} {name} { return [dict exists $data bbox $name] }
    #method {exists inset} {name} { return [dict exists $data inset $name] }
    #method {exists frame} {name} { return [dict exists $data frame $name] }

    # return parts of a named line
    method {line points} {name} { return [dict get $data line $name points] }
    method {line bbox} {name} { return [dict get $data line $name bbox] }
    method {line index} {name} { return [dict get $data line $name index] }

    # the window size has changed, recompute and redraw as necessary
    method window-configure {} {
	$self recompute frame
	$self recompute inset
	after idle [mymethod redraw]
    }

    # convert an option for an inset proportion into a list of four insets
    # ordered {north east south west}
    # {in} -> {in in in in}
    # {in-n in-e} -> {in-n in-e in-n in-e}
    # {in-n in-e in-s} -> {in-n in-e in-s in-e}
    method fourvals {val} {
	switch [llength $val] {
	    1 { return [list $val $val $val $val] }
	    2 { return [list {*}$val {*}$val] }
	    3 { return [list {*}$val [lindex $val 1]] }
	    4 { return $val }
	    default { error "value should have 1 to 4 elements: \"$val\"" }
	}
    }

    # configure the frame inset inside the window
    method {Configure -frame} {val} {
	set options(-frame) [$self Fourvals $val]
	$self recompute frame
	$self recompute inset
    }
    
    method {recompute frame} {} { dict set data frame [bbox-inset [$self window] $options(-frame)] }

    # configure the graph area inset inside the frame
    method {Configure -inset} {val} {
	set options(-inset) [$self Fourvals $val]
	$self recompute frame
	$self recompute inset
    }
    
    # configure the foreground color
    method {Configure -foreground} {val} {
	set options(-foreground) $val
	$hull itemconfigure frame -outline $options(-foreground)
	$hull itemconfigure x-tick -fill $options(-foreground)
	$hull itemconfigure y-tick -fill $options(-foreground)
	$hull itemconfigure plotted -fill $options(-foreground)
    }

    method {recompute inset} {} { dict set data inset [bbox-inset [$self frame] $options(-inset)] }

    # redraw and rescale the plot
    method redraw {} {
	# don't redraw an empty graph
	if {[bbox-is-empty [$self bbox]]} {
	    $self ticks-delete
	    return
	}

	# don't redraw more than options(-redraw-rate) times per second
	set t [clock milliseconds]
	if {$t - [dict get $data redraw-time] < 1000/$options(-redraw-rate)} return
	dict set data redraw-time $t
	
	# puts "going to redraw [$self bbox]"

	# redraw the lines in their native coordinates
	foreach name [$self lines] {
	    if {[llength [$self line points $name]] >= 4} {
		$self line redraw $name
		# puts "line $name [llength [$self line points $name]] points, [$self line bbox $name]"
	    }
	}
	$self itemconfigure plotted -fill $options(-foreground)

	# redraw the frame
	# $hull coords frame [$self frame]
	# puts "$self frame [$self frame]"
	
	switch $options(-mode) {
	    overlay {
		# find the extent of the points drawn
		lassign [$self bbox] x0 y0 x1 y1
		# puts "\$self bbox [$self bbox] (extent of points plotted raw coordinates) x0 y0 x1 y1"
		# puts "\$hull bbox plotted [$hull bbox plotted]  (after raw redraw)"

		# find the box they go into
		lassign [$self window] wx0 wy0 wx1 wy1
		# puts "$self inset [$self inset] (extent of window to be plotted into) wx0 wy0 wx1 wy1"

		# compute and apply the transform
		lassign [list [expr {-$x0+$wx0}] [expr {-$y0+$wy0}]] xo yo
		# puts "xo yo $xo $yo"
		$hull move plotted $xo $yo
		# puts "\$hull bbox plotted [$hull bbox plotted] (after move)"
		lassign [list  [expr {double($wx1-$wx0)/($x1-$x0)}] [expr {double($wy1-$wy0)/($y1-$y0)}]] xs ys
		if {$xs == 0 || $ys == 0} {
		    puts "bbox [$self bbox]"
		    puts "xs = $xs, wwd = [expr {double($wx1-$wx0)}], pwd = [expr {($x1-$x0)}]"
		    puts "ys = $ys, wht = [expr {double($wy1-$wy0)}], pht = [expr {($y1-$y0)}]"
		} else {
		    # puts "xs ys $xs $ys"
		    $hull scale plotted $wx0 $wy0 $xs $ys
		    # puts "\$hull bbox plotted [$hull bbox plotted] (after scale)"
		}

		# draw and label the tick marks 
		$self ticks x [$self ticks-place $x0 $wx0 $x1 $wx1]
		$self ticks y [$self ticks-place $y0 $wy0 $y1 $wy1]
	    }
	    stack {
		set lines [$self lines]
		set nlines [llength $lines]
		set iline 0
		# puts "stack llength {$lines} is $nlines"
		
		# find the extent of the points drawn, use the overall extent
		lassign [$self bbox] x0 y0 x1 y1
		# puts "\$self bbox [$self bbox] (extent of points plotted raw coordinates) x0 y0 x1 y1"
		# puts "\$hull bbox plotted [$hull bbox plotted]  (after raw redraw)"
		
		# find the box they go into
		lassign [$self window] wx0 wy0 wx1 wy1
		# puts [$self frame]

		foreach line $lines {
		    # puts "stack $line position $iline of $nlines"
		    # inset by 0.1 at top and bottom
		    lassign [bbox-inset [$self stack $iline $nlines] {0 0.1 0 0.1}] wx0 wy0 wx1 wy1
		    incr iline
		    # puts "$self inset [$self inset] (extent of window to be plotted into) wx0 wy0i wx1 wy1i"

		    # compute and apply the transform
		    set xo [expr {-$x0+$wx0}]
		    set yo [expr {-$y0+$wy0}]
		    # puts "xo yo $xo $yo"
		    $hull move line-$line $xo $yo
		    # puts "\$hull bbox plotted [$hull bbox plotted] (after move)"
		    lassign [list  [expr {double($wx1-$wx0)/($x1-$x0)}] [expr {double($wy1-$wy0)/($y1-$y0)}]] xs ys
		    if {$xs == 0 || $ys == 0} {
			puts "bbox [$self bbox]"
			puts "xs = $xs, wwd = [expr {double($wx1-$wx0)}], pwd = [expr {($x1-$x0)}]"
			puts "ys = $ys, wht = [expr {double($wy1-$wy0)}], pht = [expr {($y1-$y0)}]"
		    } else {
			# puts "xs ys $xs $ys"
			$hull scale line-$line $wx0 $wy0 $xs $ys
			# puts "\$hull bbox plotted [$hull bbox plotted] (after scale)"
		    }
		    
		    if {$options(-invert)} {
			lassign [$self line bbox $line] x0 y0 x1 y1
			set ym [expr {($y0+$y1)/2}]
			#$hull scale line-$line 0 $ym 1 -1
		    }
		    # draw and label the tick marks 
		    #$self ticks x [$self ticks-place $x0 $wx0 $x1 $wx1]
		    #$self ticks y [$self ticks-place $y0 $wy0 $y1 $wy1]
		}
	    }
	    default { error "uncaught graph mode $options(-mode)" }
	}
    }

    # decide tick placement for value v0 to value v1
    # located at window wv0 to window wv1
    # return a list of value-string window-coordinate tick-size triples
    method ticks-place {v0 wv0 v1 wv1} {
	# puts "ticks-place $v0 .. $v1 inside $wv0 .. $wv1"
	set marks {}
	if {[catch {
	    set n [expr {max(3,int(abs($wv0-$wv1)/30))}]
	    foreach mark [$ticklabels extended $v0 $v1 $n] {
		set c [expr {($mark-$v0)/($v1-$v0)*($wv1-$wv0)+$wv0}]
		lappend marks [format %.1f $mark] $c 3
	    }
	} error]} {
	    set marks {}
	}
	return $marks
    }
    method ticks-delete {} { $hull delete x-tick; $hull delete y-tick }
    method ticks {coord places} {
	$hull delete $coord-tick
	set index 0
	foreach {v w dw} $places {
	    switch $coord {
		x {
		    set y [bbox-s [$self frame]]
		    $hull create line $w $y $w [expr {$y+$dw}] -tags $coord-tick -fill $options(-foreground)
		    if {($index & 1) == 0} {
			$hull create text $w [expr {$y+$dw}] -text $v -anchor n -tags $coord-tick -fill $options(-foreground)
		    }
		    incr index
		}
		y {
		    set x [bbox-w [$self frame]]
		    $hull create line $x $w [expr {$x-$dw}] $w -tags $coord-tick -fill $options(-foreground)
		    $hull create text [expr {$x-$dw}] $w -text $v -anchor e -tags $coord-tick -fill $options(-foreground)
		}
	    }
	}
    }

    # augment the plotted bounding box by a point
    method {bbox-add-point} {args} { dict set data bbox [bbox-add-point [$self bbox] {*}$args] }

    # delete everything
    method {delete all} {} {
	dict set data line [dict create]
	dict set data bbox [bbox-empty]
	$hull delete plotted
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
	# puts "lines [dict keys [dict get $data line]]"
    }

    # add a point(s) to a line
    method {line add point} {name args} {
	$self bbox-add-point {*}$args
	dict set data line $name points [concat [$self line points $name] $args]
	dict set data line $name bbox [bbox-add-point [$self line bbox $name] {*}$args]
	after idle [mymethod redraw]
    }

    # redraw the coordinates of a line
    method {line redraw} {name} {
	if {[llength [$self line points $name]] > 4} {
	    $hull coords [$self line index $name] [$self line points $name]
	}
    }
}
