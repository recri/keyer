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
#
package provide sdrui::dial 1.0

package require Tk
package require snit

snit::widgetadaptor sdrui::dial {
    # the maximum radius is 1/2 the minimum of width and height
    option -bg {};			# background color of the window containing the dial

    option -radius 90;			# radius of the dial in percent of max
    option -fill \#888;			# color of the dial
    option -outline black;		# color of the dial outline
    option -width 3;			# thickness of the dial outline

    option -thumb-radius 20;		# radius of the thumb in percent of max
    option -thumb-position 65;		# center of thumb in percent of max
    option -thumb-fill \#999;		# color of the thumb
    option -thumb-outline black;	# color of the thumb outline
    option -thumb-width 2;		# thickness of the thumb outline
    option -thumb-activewidth 4;	# thickness of the thumb outline when active

    option -graticule 20;		# number of graticule lines to draw
    option -graticule-radius 95;	# radius of graticule lines in percent of max
    option -graticule-width 3;		# width of graticule lines in pixels
    option -graticule-fill white;	# 

    option -cpr 1000;			# counts per revolution

    option -command {};			# script called to report rotation 
    
    variable data -array {
	turn 0
	last-turn 0
    }

    constructor {args} {
	installhull using canvas -width 250 -height 250
	$self configure {*}$args
	set data(pi) [expr atan2(0,-1)]
	set data(2pi) [expr {2*$data(pi)}]
	set data(phi) [expr {-$data(pi)/2}]
	set data(up-step) [expr {$data(2pi)/$options(-cpr)}]
	set data(down-step) [expr {-$data(2pi)/$options(-cpr)}]
	if {$options(-bg) eq {}} {
	    set options(-bg) [$hull cget -background]
	}
	$hull configure -background $options(-bg)
	bind $win <Configure> [mymethod window-configure %w %h]
	bind $win <ButtonPress-4> [mymethod tune up]
	bind $win <ButtonPress-5> [mymethod tune down]
    }
    
    method {tune} {dir} { $self rotate $data($dir-step) }

    method thumb-press {x y} { set data(phi) [expr {atan2($y-$data(yc),$x-$data(xc))}] }
    method thumb-motion {x y} { $self rotate [expr {atan2($y-$data(yc),$x-$data(xc))-$data(phi)}] }

    method rotate {dphi} {
	## rotate thumb
	$self rotate-thumb $dphi
	## remember last phi
	set data(phi) [expr {$data(phi)+$dphi}]
	## compute turn as fraction of rotation
	set dturn [expr {fmod($dphi,$data(2pi)) / $data(2pi)}]
	if {$dturn > 0.5} {
	    set dturn [expr {$dturn-1}]
	} elseif {$dturn < -0.5} {
	    set dturn [expr {$dturn+1}]
	}
	## compute counts to send to client
	set data(turn) [expr {$data(turn)+$options(-cpr)*$dturn}]
	set d [expr {$data(turn)-$data(last-turn)}]
	if {abs($d) >= 1} {
	    if {$d > 0} {
		set d [expr {int($d)}]
	    } else {
		set d [expr {-int(-$d)}]
	    }
	    set data(turn) [expr {$data(turn)-$d}]
	    set data(last-turn) $data(turn)
	    if {$options(-command) ne {}} {
		{*}$options(-command) $d
	    }
	}
    }

    method rotate-thumb {dphi} {
	## get current thumb coordinates
	foreach {x1 y1 x2 y2} [$hull coords thumb] break
	## compute the thumb center
	set x [expr {($x1+$x2)/2-$data(xc)}]
	set y [expr {($y1+$y2)/2-$data(yc)}]
	## rotate thumb coordinates
	set sindphi [expr {sin($dphi)}]
	set cosdphi [expr {cos($dphi)}]
	foreach {x y} [list [expr {$x*$cosdphi - $y*$sindphi}] [expr {$y*$cosdphi + $x*$sindphi}]] break
	## set current thumb coordinates
	$hull coords thumb [expr {$x-$data(tr)+$data(xc)}] [expr {$y-$data(tr)+$data(yc)}] [expr {$x+$data(tr)+$data(xc)}] [expr {$y+$data(tr)+$data(yc)}]
    }

    method window-configure {w h} {
	#puts "ui-dial window-configure $w $h"
	set r  [expr {min($w,$h)/2.0}]; # radius of space available
	set xc [expr {$w/2.0}];	       # center of space available
	set yc [expr {$h/2.0}];	       # center of space available
	set dr [expr {$options(-radius)*$r/100.0}];			# dial radius
	set tr [expr {$r*$options(-thumb-radius)/100.0}];		# thumb radius
	set tp [expr {$r*$options(-thumb-position)/100.0}];		# thumb position radius
	set gr [expr {$r*$options(-graticule-radius)/100.0}];	# graticule radius
	set dial [list [expr {$xc-$dr}] [expr {$yc-$dr}] [expr {$xc+$dr}] [expr {$yc+$dr}]]
	set xt [expr {$xc+$tp*cos($data(phi))}]
	set yt [expr {$yc+$tp*sin($data(phi))}]
	set thumb [list [expr {$xt-$tr}] [expr {$yt-$tr}] [expr {$xt+$tr}] [expr {$yt+$tr}]]
	set graticule {}
	if {$options(-graticule) <= 0} {
	    lappend graticule $xc $yc $xc $yc
	} else {
	    set p 0
	    set dp [expr {$data(2pi)/$options(-graticule)}]
	    for {set i 0} {$i < $options(-graticule)} {incr i} {
		lappend graticule $xc $yc [expr {$xc+$gr*cos($p)}] [expr {$yc+$gr*sin($p)}]
		set p [expr {$p+$dp}]
	    }
	}
	if {[llength [$hull find withtag thumb]] == 0} {
	    $hull create line $graticule -tag graticule -fill $options(-graticule-fill) -width $options(-graticule-width)
	    $hull create oval $dial -tag dial -fill $options(-fill) -outline $options(-outline) -width $options(-width) 
	    $hull create oval $thumb -tag thumb -fill $options(-thumb-fill) -outline $options(-thumb-outline) -activewidth $options(-thumb-activewidth) -width $options(-thumb-width)
	    $hull bind thumb <ButtonPress-1> [mymethod thumb-press %x %y]
	    $hull bind thumb <B1-Motion> [mymethod thumb-motion %x %y]
	} else {
	    $hull coords graticule $graticule
	    $hull coords dial $dial
	    $hull coords thumb $thumb
	}
	array set data [list yc $yc xc $xc tr $tr]
    }
}    
