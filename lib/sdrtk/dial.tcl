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
# started as a complete package, but moving toward a separated input and
# display, with virtual events to signal input changes which the user should
# use to adjust the display.
#
# the display is currently a simple dial with a pointer line, graticule markings
# around the dial, and a button in the center.
#
# the inputs are <<DialCW>>, <<DialCCW>>, <<DialPress>>, and <<DialRelease>>
# virtual events.
#
# the idea is that the dial tunes some parameter in normal mode, the <<DialCW>> and
# <<DialCCW>> events to the parent changing the parameter managed by the parent and
# fed back to the dial to provide feedback.  The dial turn events may be bound to an
# external rotary encoder which is captured via MIDI events or /dev/input events.
#
# pressing the button switches to menu mode in which different pie sectors select
# different parameters, the parameter names are laid out on the dial, turning the
# dial into a parameter's sector highlights the parameter name and displays the
# parameter value.  pressing the button again with a new parameter highlighted
# switches the dial to tuning that parameter.
#
# so there's a plain dial which conveys turn steps to the parent which updates an
# associated display, and there's a menu which conveys hover information to the
# parent which transitorily switches the associated display as the hover changes,
# and a menu select which shifts to the selected display.
#
# so each menu item has a display component associated, like a notebook tab,
# so we could call this a dialbook component, to which we add display components
# with text labels.  But the dialbook select process is more complicated than
# simply popping the selected component into the foreground.
#
package provide sdrtk::dial 1.0

package require Tk
package require snit

snit::widgetadaptor sdrtk::dial {
    # the maximum radius is 1/2 the minimum of width and height
    option -bg {};			# background color of the window containing the dial

    option -radius -default 80 -configuremethod Gconfig;		# radius of the dial in percent of max
    option -fill -default \#888 -configuremethod Gconfig;		# color of the dial
    option -outline -default black -configuremethod Gconfig;		# color of the dial outline
    option -dial-width -default 3 -configuremethod Gconfig;		# thickness of the dial outline

    option -button-radius -default 10 -configuremethod Gconfig;		# radius of the button in percent of max
    option -button-fill -default \#999 -configuremethod Gconfig;	# color of the button

    option -thumb-length -default 75 -configuremethod Gconfig;		# length of thumb in percent of max
    option -thumb-fill -default black -configuremethod Gconfig;		# color of the thumb outline
    option -thumb-width -default 3 -configuremethod Gconfig;		# thickness of the thumb outline

    option -graticule -default 20 -configuremethod Gconfig;		# number of graticule lines to draw
    option -graticule-radius -default 95 -configuremethod Gconfig;	# radius of graticule lines in percent of max
    option -graticule-width -default 3 -configuremethod Gconfig;	# width of graticule lines in pixels
    option -graticule-fill -default black -configuremethod Gconfig;	# color of the graticule lines

    option -self-responder -default false;				# respond to the event our self

    option -cpr -default 1000 -configuremethod Configure;		# counts per revolution

    option -phi -default 0 -configuremethod Pconfig;			# the angle of the thumb, from top dead center increasing clockwise

    option -command {};			# script called to report rotation 
    
    delegate option * to hull
    delegate method * to hull

    variable data -array [list r 0 w 0 h 0 xc 0 yc 0 tl 0 \
			      pi/2 [expr {atan2(1,0)}] 2pi [expr {2*atan2(0,-1)}] ]

    # coordinates, blech, y increases down, x increases to the right
    # so the standard phi 0 is east and increasing clockwise
    # assuming we want phi 0 north and increasing clockwise
    # we should simply subtract pi/2 from phi
    proc xphi {phi} { return [expr {$phi-1.5707963267948966}] }
    proc ixphi {phi} { return [expr {$phi+1.5707963267948966}] }
    constructor {args} {
	# default -width 350 -height 350
	# with  -width 300 -height 300  things are snug
	installhull using canvas -takefocus 1
	set options(-phi) 0
	$self Configure -cpr $options(-cpr)
	$self configure {*}$args
	if {$options(-bg) eq {}} { set options(-bg) [$hull cget -background] }
	$hull configure -background $options(-bg)
	focus $win
	#event add <<DialPress>> <Shift_R>
	#event add <<DialRelease>> <KeyRelease-Shift_R>
	bind $win <Configure> [mymethod Window-configure %w %h]
	# MouseWheel doesn't get generated by X Windows
	bind $win <MouseWheel> [mymethod Mouse-wheel %W %D]
	# These are the events fired by X for MouseWheel
	bind $win <ButtonPress-5> [list event generate %W <<DialCW>>]
	bind $win <ButtonPress-4> [list event generate %W <<DialCCW>>]
	# make the cursor motion keys adjust the dial
	bind $win <Up> [list event generate %W <<DialCW>>]
	bind $win <Down> [list event generate %W <<DialCCW>>]
	bind $win <KP_Add> [list event generate %W <<DialCW>>]
	bind $win <KP_Subtract> [list event generate %W <<DialCCW>>]
	# Grab the powermate rotation events
	# Grab the midikey rotation events
	if {$options(-self-responder)} {
	    bind $win <<DialCW>> [mymethod Turn %W 1]
	    bind $win <<DialCCW>> [mymethod Turn %W -1]
	    bind $win <<DialPress>> [mymethod Button-press %W]
	    bind $win <<DialRelease>> [mymethod Button-release %W]
	}
    }

    method {Configure -cpr} {cpr} {
	set options(-cpr) $cpr
	set data(step0) [xphi 0]
	set data(step) [expr {$data(2pi)/$cpr}]
    }

    method Gconfig {opt val} {
	set options($opt) $val
	$self Graphics-configure
    }

    method Pconfig {opt val} {
	set options($opt) $val
	$self Pointer-configure
    }
    
    method Mouse-wheel {w delta} {
	puts "Mouse-wheel $w $delta"
	if {$delta > 0} {
	    if {$delta >= 120} { set delta [expr {$delta/120}] }
	    while {[incr delta -1] >= 0} { event generate $w <<DialCW>> }
	} elseif {$delta < 0} {
	    if {$delta <= 120} { set delta [expr {$delta/120}] }
	    while {[incr delta +1] <= 0} { event generate $w <<DialCCW>> }
	}
    }

    method Turn {w steps} { $self Rotate $steps }

    method Button-press {w} { puts "Button-press $w" }

    method Button-release {w} { puts "Button-release $w" }

    method Thumb-press {w x y} {
	#puts "Thumb-press $w $x $y"
	set data(phi-press) [ixphi [expr {atan2($y-$data(yc),$x-$data(xc))}]]
	set data(turn-resid) 0
    }

    method Thumb-motion {w x y} {
	#puts "Thumb-motion $w $x $y"
	set phi0 $data(phi-press)
	set data(phi-press) [ixphi [expr {atan2($y-$data(yc),$x-$data(xc))}]]
	set data(turn-resid) [expr {($data(phi-press)-$phi0)/$data(step)+$data(turn-resid)}]
	if {$data(turn-resid) > $options(-cpr)/2} { set data(turn-resid) [expr {$data(turn-resid)-$options(-cpr)}] }
	if {$data(turn-resid) < -$options(-cpr)/2} { set data(turn-resid) [expr {$data(turn-resid)+$options(-cpr)}] }
	while {$data(turn-resid) >= 1} {
	    event generate $w <<DialCW>>
	    set data(turn-resid) [expr {$data(turn-resid)-1}]
	}
	while {$data(turn-resid) <= -1} {
	    event generate $w <<DialCCW>>
	    set data(turn-resid) [expr {$data(turn-resid)+1}]
	}
    }

    method Rotate {steps} {
	#puts "Rotate $steps"
	## rotate thumb
	set dphi [expr {$data(step)*$steps}]
	## get current thumb coordinates
	foreach {x1 y1 x2 y2} [$hull coords thumb] break
	## compute the thumb end point
	set x [expr {$x2-$x1}]
	set y [expr {$y2-$y1}]
	## rotate thumb coordinates
	set sindphi [expr {sin($dphi)}]
	set cosdphi [expr {cos($dphi)}]
	foreach {x y} [list [expr {$x*$cosdphi - $y*$sindphi}] [expr {$y*$cosdphi + $x*$sindphi}]] break
	## set current thumb coordinates
	$hull coords thumb $x1 $y1 [expr {$x1+$x}] [expr {$y1+$y}]
    }
    
    method Position {step} {
	puts "dial: Position $step"
	set options(-phi) [expr {$data(step0)+$data(step)*$step}]
	foreach x {w h r tl xc yc} { set $x $data($x) }
	set thumb [list $xc $yc [expr {$xc+$tl*cos($options(-phi))}] [expr {$yc+$tl*sin($options(-phi))}]]
	$hull coords thumb $thumb
    }
    
    method Window-configure {w h} {
	# take reconfigured window size and recompute everything
	array set data [list w $w h $h r [expr {min($w,$h)/2.0}] yc [expr {$h/2.0}] xc [expr {$w/2.0}]]
	$self Graphics-configure
    }

    method Graphics-configure {} {
	# redraw everything given window coordinates
	set r $data(r)
	set xc $data(xc)
	set yc $data(yc)
	# dial radius
	if {$options(-radius) <= 0} {
	    set dr 0
	    set dial [list $xc $yc $xc $yc]
	} else {
	    set dr [expr {$r*$options(-radius)/100.0}]
	    set dial [list [expr {$xc-$dr}] [expr {$yc-$dr}] [expr {$xc+$dr}] [expr {$yc+$dr}]]
	}
	
	# button radius
	if {$options(-button-radius) <= 0} {
	    set br 0
	    set button [list $xc $yc $xc $yc]
	} else {
	    set br [expr {$r*$options(-button-radius)/100.0}]
	    set button [list [expr {$xc-$br}] [expr {$yc-$br}] [expr {$xc+$br}] [expr {$yc+$br}]]
	}
	    
	# thumb length
	if {$options(-thumb-length) <= 0} {
	    set tl 0
	    set thumb [list $xc $yc $xc $yc]
	} else {
	    set tl [expr {$r*$options(-thumb-length)/100.0}]
	    set phi [xphi $options(-phi)]
	    set thumb [list $xc $yc [expr {$xc+$tl*cos($phi)}] [expr {$yc+$tl*sin($phi)}]]
	}
	set data(tl) $tl

	# graticule radius
	if {$options(-graticule) <= 0} {
	    set graticule [list $xc $yc $xc $yc]
	    set mask [list $xc $yc $xc $yc]
	} else {
	    set gr [expr {$r*$options(-graticule-radius)/100.0}]
	    set graticule {}
	    set p 0
	    set dp [expr {$data(2pi)/$options(-graticule)}]
	    for {set i 0} {$i < $options(-graticule)} {incr i} {
		set phi [xphi $p]
		set x [expr {$xc+$gr*cos($phi)}]
		set y [expr {$yc+$gr*sin($phi)}]
		lappend graticule $xc $yc $x $y
		set p [expr {$p+$dp}]
	    }
	    set ir [expr {($dr+$gr)/2.0}]
	    set mask [list [expr {$xc-$ir}] [expr {$yc-$ir}] [expr {$xc+$ir}] [expr {$yc+$ir}]]
	}
	if {[llength [$hull find withtag thumb]] == 0} {
	    $hull create line $graticule -tag graticule -fill $options(-graticule-fill) -width $options(-graticule-width)
	    $hull create oval $mask -tag mask -fill $options(-bg) -outline {} 
	    # puts "draw dial: $dial"
	    $hull create oval $dial -tag dial -fill $options(-fill) -outline $options(-outline) -width $options(-dial-width) 
	    $hull create oval $button -tag button -fill $options(-button-fill)
	    $hull create line $thumb -tag thumb -fill $options(-thumb-fill) -width $options(-thumb-width) -capstyle round
	    $hull bind dial <ButtonPress-1> [mymethod Thumb-press %W %x %y]
	    $hull bind button <ButtonPress-1> [list event generate %W <<DialPress>>]
	    $hull bind button <ButtonRelease-1> [list event generate %W <<DialRelease>>]
	    $hull bind dial <B1-Motion> [mymethod Thumb-motion %W %x %y]
	} else {
	    $hull coords graticule $graticule
	    # puts "redraw dial: $dial"
	    $hull coords dial $dial
	    $hull coords button $button
	    $hull coords mask $mask
	    $self Pointer-configure
	}
    }
    method Pointer-configure {} {
	if {$data(tl) != 0} {
	    set x $data(xc)
	    set y $data(yc)
	    set t $data(tl)
	    set p [xphi $options(-phi)]
	    $hull coords thumb [list $x $y [expr {$x+$t*cos($p)}] [expr {$y+$t*sin($p)}]]
	}
    }
}    
