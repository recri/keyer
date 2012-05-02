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
package provide hotiron 1.0.0

##
## hotiron - compute a pixel for a hue in 0..1 from palette in 0 .. 5
##
## palette 0 simulates the spectrum of blackbody radiation with temperature
## starting from black=cold through red, orange, and yellow to white=hot,
## which is what happens to iron when you heat it, hence the name.
##
## palettes 1 through five simply permute the red, green and blue values to
## give some other cheap pixel level map computations.
##
## originally from Eric Grosse's rainbow.c and hotiron.c available from
## http://www.netlib.org/graphics/, though he gives Cleve Moler credit for
## the hotiron palette.  Thanks, Cleve.
##
proc ::hotiron {hue pal} {
    switch $pal {
	0 { lassign [list [expr {3*($hue+0.03)}] [expr {3*($hue-.333333)}] [expr {3*($hue-.666667)}]] r g b }
	1 { lassign [list [expr {3*($hue+0.03)}] [expr {3*($hue-.666667)}] [expr {3*($hue-.333333)}]] r g b }
	2 { lassign [list [expr {3*($hue-.666667)}] [expr {3*($hue+0.03)}] [expr {3*($hue-.333333)}]] r g b }
	3 { lassign [list [expr {3*($hue-.333333)}] [expr {3*($hue+0.03)}] [expr {3*($hue-.666667)}]] r g b }
	4 { lassign [list [expr {3*($hue-.333333)}] [expr {3*($hue-.666667)}] [expr {3*($hue+0.03)}]] r g b }
	5 { lassign [list [expr {3*($hue-.666667)}] [expr {3*($hue-.333333)}] [expr {3*($hue+0.03)}]] r g b }
    }
    return \#[format {%04x%04x%04x} [expr {int(65535*min(1,max($r,0)))}] [expr {int(65535*min(1,max($g,0)))}] [expr {int(65535*min(1,max($b,0)))}]]
}
