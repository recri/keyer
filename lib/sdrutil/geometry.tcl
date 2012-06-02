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

package provide geometry 1.0

package require math::geometry;	# from tcllib

namespace eval geometry {}

# a point is a pair of coordinates
proc geometry::point {x y} { return [list $x $y] }
# a vector is a pair of coordinates
proc geometry::vector {x y} { return [list $x $y] }
# a line is two distinct points
proc geometry::line {x1 y1 x2 y2} { return [list $x1 $y1 $x2 $y2] }
# a circle is two distinct points, one at the center and one on the circumference 
proc geometry::circle {x1 y1 x2 y2} { return [list $x1 $y1 $x2 $y2] }
# find a line at right angles to a given line, that shares the first point on the line
proc geometry::orthogonal-line {line} {
    # get the line
    lassign $line x1 y1 x2 y2
    # find the direction of the line from p1
    set vx [expr {$x2-$x1}]
    set vy [expr {$y2-$y1}]
    # rotate the direction 90 degrees
    return [line $x1 $y1 [expr {$x1-$vy}] [expr {$y1+$vx}]]
}
# find the intersections of a line and a circle
# http://mathworld.wolfram.com/Circle-LineIntersection.html
proc geometry::intersection-line-circle {line circle} {
    lassign $line x1 y1 x2 y2
    lassign $circle x0 y0 xr yr
    # move center of circle to 0 0
    set x1 [expr {$x1-$x0}]; set y1 [expr {$y1-$y0}]
    set x2 [expr {$x2-$x0}]; set y2 [expr {$y2-$x0}]
    set r [expr {sqrt(pow($xr-$x0,2)+pow($yr-$y0,2))}]
    # calculate line direction vector
    set dx [expr {$x2-$x1}]; set dy [expr {$y2-$y1}]
    # length of line segment
    set dr2 [expr {$dx*$dx+$dy*$dy}]
    set dr [expr {sqrt($dr2)}]
    # determinant
    set D [expr {$x1*$y2-$x2*$y1}]
    # dicriminant
    set delta [expr {$r*$r * $dr*$dr - $D*$D}]
    # decide what we found
    # no intersection
    if {$delta < 0} { return {} }
    set xt1 [expr {$D*$dy/$dr2}]
    set yt1 [expr {-$D*$dx/$dr2}]
    # tangent point
    if {$delta == 0} { return [list [list $xt1 $yt1]] }
    # secant points
    set t2 [expr {sqrt($delta)/$dr2}]
    set xt2 [expr {sgn($dy)*$dx*$t2}]
    set yt2 [expr {abs($dy)*$t2}]
    return [list [list [expr {$xt1+$xt2}] [expr {$yt1+$yt2}]] [list [expr {$xt1-$xt2}] [expr {$yt1-$yt2}]]]
}
# find the intersection of two lines
proc geometry::intersection-line-line {line1 line2} {
    return [::math::geometry::findLineIntersection $line1 $line2]
}
