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
# a graphical band/channel select manager
# needs to zoom
# needs detailed band plans to zoom into
# needs to move channel markers off the band rectangles
# needs merge some services into single row
#

package provide sdrblk::ui-band-select 1.0

package require Tk
package require snit

package require sdrblk::band-data

snit::widgetadaptor sdrblk::ui-band-select {

    option -command {};			# script called to report band selection 
    option -height 150;			# height of the band display
    option -width 200;			# width of the band display
    option -hover-time 250;		# milliseconds before popup
    
    component bands

    variable data -array {
	hover-displayed 0
	hover-text {}
    }

    constructor {args} {
	installhull using canvas
	install bands using sdrblk::band-data %AUTO%
	$self configure {*}$args
	$hull configure -width $options(-width) -height $options(-height)
	bind $win <Configure> [mymethod window-configure %w %h]
	$self draw-bands
    }
    
    destructor {
	catch {$bands destroy}
    }

    proc x-for-frequency {f} {
	return [expr {log10($f)-log10(30000)}]
    }

    method draw-bands {} {
	set xmin [x-for-frequency  2500000]
	set xmax [x-for-frequency 25000000]
	set nrows [$bands nrows]
	set dy [expr {$options(-height)/(2+$nrows)}]
	foreach service [$bands services] {
	    set y0 [expr {[$bands row $service]*$dy}]
	    set y1 [expr {$y0+$dy/2}]
	    set y2 [expr {$y1+$dy/8}]
	    set y3 [expr {$y2+$dy/4}]
	    foreach band [$bands bands $service] {
		lassign [$bands band-range-hertz $service $band] bmin bmax
		set i [$hull create rectangle [x-for-frequency $bmin] $y0 [x-for-frequency $bmax] $y1 -fill [$bands color $service] -width 1 -activewidth 2]
		$hull bind $i <Button-1> [mymethod band-pick $service $band]
		$hull bind $i <Enter> [mymethod hover-text "$service $band\n[join [$bands band-range $service $band]]"]
		$hull bind $i <Leave> [mymethod hover-text ""]
	    }
	    foreach channel [$bands channels $service] {
		set freq [$bands channel-freq-hertz $service $channel]
		set x [x-for-frequency $freq]
		set i [$hull create rectangle $x $y2 $x $y3 -fill white -outline black -width 1 -activewidth 2]
		$hull bind $i <Button-1> [mymethod channel-pick $service $channel]
		$hull bind $i <Enter> [mymethod hover-text "$service $channel\n[join [$bands channel-freq $service $channel]]"]
		$hull bind $i <Leave> [mymethod hover-text ""]
	    }
	}
	#catch {unset last}
	set y0 0
	set y1 [expr {2*$dy/3}]
	set y2 [expr {(1+$nrows)*$dy+$dy/3}]
	set y3 [expr {(2+$nrows)*$dy}]
	foreach tick {50kHz 100kHz 250kHz 500kHz 1MHz 2.5MHz 5MHz 10MHz 25MHz 50MHz 100MHz 250MHz 500MHz 1GHz 2.5GHz 5GHz 10GHz 25GHz 50GHz 100GHz 250GHz} {
	    set x [x-for-frequency [$bands hertz $tick]]
	    $hull create line $x $y0 $x $y1
	    $hull create text $x $y0 -text " $tick" -anchor nw
	    $hull create line $x $y2 $x $y3
	    $hull create text $x $y3 -text " $tick" -anchor sw
	}
	$hull move all [expr {-$xmin}] 0
	$hull scale all 0 0 [expr {$options(-width)/double($xmax-$xmin)}] 1
	bind $win <ButtonPress-1> [mymethod no-pick]
	bind $win <ButtonPress-3> [mymethod scan-mark %x]
	bind $win <B3-Motion> [mymethod scan-dragto %x]
	bind $win <Motion> [mymethod motion %x %y]
	bind $win <ButtonPress-4> [mymethod scroll left]
	bind $win <ButtonPress-5> [mymethod scroll right]
	bind $win <Shift-ButtonPress-4> [mymethod zoom in %x]
	bind $win <Shift-ButtonPress-5> [mymethod zoom out %x]
    }

    method {scroll left} {} { $hull scan mark 10 0; $hull scan dragto 9 0 }
    method {scroll right} {} { $hull scan mark 10 0; $hull scan dragto 11 0 }
    method {zoom in} {x} { $hull scale all [$hull canvasx $x] 0 1.0101010101 1 } 
    method {zoom out} {x} { $hull scale all [$hull canvasy $x] 0 0.99 1 }
    method scan-mark {x} { $hull scan mark $x 0 }
    method scan-dragto {x} { $hull scan dragto $x 0 }

    method no-pick {} { if {$data(hover-text) eq {}} { $self callback no-pick } }
    method band-pick {service band} { $self callback band-pick $service $band }
    method channel-pick {service channel} { $self callback channel-pick $service $channel }
    
    method window-configure {w h} {
	if {$h != $options(-height)} {
	    $hull scale all 0 0 1 [expr {double($h)/$options(-height)}]
	    set options(-height) $h
	}
    }

    method callback {args} {
	if {$options(-command) ne {}} { eval "$options(-command) $args" }
    }

    method hover-text {text} {
	set data(hover-text) $text
    }

    method motion {x y} {
	if {$data(hover-displayed)} {
	    $self hover-cancel
	} elseif {$data(hover-text) ne {}} {
	    set data(hover-x) $x
	    set data(hover-y) $y
	    catch {after cancel $data(hover-timer)}
	    set data(hover-timer) [after $options(-hover-time) [mymethod hover-display]]
	}
    }

    method hover-display {} {
	if {$data(hover-text) ne {}} {
	    set xc [expr {$options(-width)/2}]
	    set yc [expr {$options(-height)/2}]
	    if {$data(hover-x)-$xc >= 0} {
		set dx -4
		set a1 e
	    } else {
		set dx 4
		set a1 w
	    }
	    if {$data(hover-y)-$yc <= 0} {
		set dy -4
		set a2 s
	    } else {
		set dy -4
		set a2 s
	    }
	    set x [expr {$dx+[$hull canvasx $data(hover-x)]}]
	    set y [expr {$dy+[$hull canvasy $data(hover-y)]}]
	    set data(hover-displayed) [$hull create text $x $y -text $data(hover-text) -anchor $a2$a1 -justify center]
	    lassign [$hull bbox $data(hover-displayed)] x0 y0 x1 y1
	    set data(hover-display-box) [$hull create rectangle $x0 $y0 $x1 $y1 -outline black -fill {light yellow}]
	    $hull raise $data(hover-displayed)
	}
    }

    method hover-cancel {} {
	if {$data(hover-displayed)} {
	    $hull delete $data(hover-displayed)
	    $hull delete $data(hover-display-box)
	    set data(hover-displayed) 0
	    set data(hover-display-box) 0
	}
    }
}    
