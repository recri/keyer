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

#
# a rotary encoder
# that can be sized, colored, proportioned, and spun
#

package provide sdrblk::ui-dial 1.0

package require Tk
package require snit

snit::widgetadaptor ::sdrblk::ui-dial {
    option -radius -default 64;		# radius of the dial in pixels
    option -bg {};			# background color of the window containing the dial
    option -fill \#88e;			# color of the dial
    option -outline black;		# color of the dial outline
    option -width 2;			# thickness of the dial outline
    option -thumb-radius 0.2;		# radius of the thumb in fraction of dial radius
    option -thumb-position 0.75;	# center of thumb in fraction of dial radius
    option -thumb-fill \#44e;		# color of the thumb
    option -thumb-outline white;	# color of the thumb outline
    option -thumb-activeoutline \#00f;	# color of the thumb outline when active
    option -thumb-width 2;		# thickness of the thumb outline
    option -command {};			# script called to report rotation 
    
    variable data -array {}

    constructor {args} {
	installhull using canvas
	$self configure {*}$args
	set data(pi) [expr atan2(0,-1)]
	set data(2pi) [expr {2*$data(pi)}]
	set data(edge) [expr {2*($options(-radius)+$options(-width))}]
	set data(p0) [expr {$data(edge)/2}]
	set data(tr) [expr {$options(-radius)*$options(-thumb-radius)}]
	set data(tp) [expr {$options(-radius)*$options(-thumb-position)}]
	if {$options(-bg) eq {}} {
	    set options(-bg) [$hull cget -background]
	}
	$hull configure -width $data(edge) -height $data(edge) -background $options(-bg)
	set p1 $options(-width)
	set p2 [expr {$data(edge)-$options(-width)}]
	$hull create oval $p1 $p1 $p2 $p2 -tag dial
	$hull itemconfig dial -fill $options(-fill) -outline $options(-outline) -width $options(-width) 
	set xc $data(p0)
	set yc [expr {$data(p0)-$data(tp)}]
	set x1 [expr {$xc-$data(tr)}]
	set y1 [expr {$yc-$data(tr)}]
	set x2 [expr {$xc+$data(tr)}]
	set y2 [expr {$yc+$data(tr)}]
	$hull create oval $x1 $y1 $x2 $y2 -fill $options(-thumb-fill) -outline $options(-thumb-outline) -activeoutline $options(-thumb-activeoutline) -width $options(-thumb-width) -tag thumb
	$hull bind thumb <ButtonPress-1> [mymethod thumb-press %x %y]
	$hull bind thumb <B1-Motion> [mymethod thumb-motion %x %y]
    }
    
    method thumb-press {x y} {
	set data(phi) [expr {atan2($y-$data(p0),$x-$data(p0))}]
    }

    method thumb-motion {x y} {
	## compute new angle
	set phi [expr {atan2($y-$data(p0),$x-$data(p0))}]
	## change in angle
	set dphi [expr {$phi-$data(phi)}]
	## get current coordinates
	foreach {x1 y1 x2 y2} [$hull coords thumb] break
	set x [expr {($x1+$x2)/2-$data(p0)}]
	set y [expr {($y1+$y2)/2-$data(p0)}]
	## rotate coordinates
	set sindphi [expr {sin($dphi)}]
	set cosdphi [expr {cos($dphi)}]
	foreach {x y} [list [expr {$x*$cosdphi - $y*$sindphi}] [expr {$y*$cosdphi + $x*$sindphi}]] break
	## reset coordinates
	$hull coords thumb [expr {$x-$data(tr)+$data(p0)}] [expr {$y-$data(tr)+$data(p0)}] [expr {$x+$data(tr)+$data(p0)}] [expr {$y+$data(tr)+$data(p0)}]
	## remember last phi
	set data(phi) $phi
	set dturn [expr {fmod($dphi,$data(2pi)) / $data(2pi)}]
	if {$dturn > 0.5} {
	    set dturn [expr {$dturn-1}]
	} elseif {$dturn < -0.5} {
	    set dturn [expr {$dturn+1}]
	}
	if {$options(-command) ne {}} {
	    eval "$options(-command) $dturn"
	}
    }
}    
