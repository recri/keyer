#
# a rotary encoder
# that can be sized, colored, proportioned,
# and spun
#

package provide dial 1.0
package require Tk

namespace eval dial {
    #
    # radius - is the radius of the dialwhich also sets the
    #	width and height of the window containing the dial
    # bg - is the background color of the window containing the dial
    # fill - is the color of the dial
    # outline - is the color of the dial outline
    # width - is the thickness of the dial outline
    # thumb-radius - is the proportion of the dial radius that the thumb
    #	radius occupies
    # thumb-position - is the proportion of the dial radius that the thumb
    #   is centered on
    # thumb-fill - is the color of the thumb
    # thumb-outline - is the color of the thumb outline
    # thumb-activeoutline - is the color of the thumb outline when the
    #	mouse is over the thumb
    # thumb-width - is the thickness of the thumb outline
    # rotation - is the script which gets called with the amount rotated
    #	as a fraction of a complete rotation
    #
    array set config {
	radius 64
	fill \#88e
	outline black
	width 2
	thumb-radius 0.2
	thumb-position 0.75
	thumb-fill \#44e
	thumb-outline white
	thumb-activeoutline \#00f
	thumb-width 2
	rotation dial::ignore
    }
}

proc dial::thumb-press {w x y} {
    upvar #0 $w data
    set data(phi) [expr {atan2($y-$data(p0),$x-$data(p0))}]
}

proc dial::thumb-motion {w x y} {
    upvar #0 $w data
    ## compute new angle
    set phi [expr {atan2($y-$data(p0),$x-$data(p0))}]
    ## change in angle
    set dphi [expr {$phi-$data(phi)}]
    ## get current coordinates
    foreach {x1 y1 x2 y2} [$w coords thumb] break
    set x [expr {($x1+$x2)/2-$data(p0)}]
    set y [expr {($y1+$y2)/2-$data(p0)}]
    ## rotate coordinates
    set sindphi [expr {sin($dphi)}]
    set cosdphi [expr {cos($dphi)}]
    foreach {x y} [list [expr {$x*$cosdphi - $y*$sindphi}] [expr {$y*$cosdphi + $x*$sindphi}]] break
    ## reset coordinates
    $w coords thumb [expr {$x-$data(tr)+$data(p0)}] [expr {$y-$data(tr)+$data(p0)}] [expr {$x+$data(tr)+$data(p0)}] [expr {$y+$data(tr)+$data(p0)}]
    ## remember last phi
    set data(phi) $phi
    set dturn [expr {fmod($dphi,$data(2pi)) / $data(2pi)}]
    if {$dturn > 0.5} {
	set dturn [expr {$dturn-1}]
    } elseif {$dturn < -0.5} {
	set dturn [expr {$dturn+1}]
    }
    eval $data(rotation) $dturn
}

proc dial::dial {w args} {
    upvar #0 $w data
    variable config
    array set data [array get config]
    foreach {name value} $args {
	switch -- $name {
	    -radius { set data(radius) $value }
	    -fill { set data(fill) $value }
	    -outline { set data(outline) $value }
	    -width { set data(width) $value }
	    -thumb-radius { set data(thumb-radius) $value }
	    -thumb-position { set data(thumb-position) $value }
	    -thumb-fill { set data(thumb-fill) $value }
	    -thumb-outline { set data(thumb-outline) $value }
	    -thumb-activeoutline { set data(thumb-activeoutline) $value }
	    -thumb-width { set data(thumb-width) $value }
	    -rotation { set data(rotation) $value }
	    default {
		error "unknown option $name"
	    }
	}
    }
    set data(pi) [expr atan2(0,-1)]
    set data(2pi) [expr {2*$data(pi)}]
    set data(edge) [expr {2*($data(radius)+$data(width))}]
    set data(p0) [expr {$data(edge)/2}]
    set data(tr) [expr {$data(radius)*$data(thumb-radius)}]
    set data(tp) [expr {$data(radius)*$data(thumb-position)}]
    canvas $w -width $data(edge) -height $data(edge)
    set p1 $data(width)
    set p2 [expr {$data(edge)-$data(width)}]
    $w create oval $p1 $p1 $p2 $p2 -tag dial
    $w itemconfig dial -fill $data(fill) -outline $data(outline) -width $data(width) 
    set xc $data(p0)
    set yc [expr {$data(p0)-$data(tp)}]
    set x1 [expr {$xc-$data(tr)}]
    set y1 [expr {$yc-$data(tr)}]
    set x2 [expr {$xc+$data(tr)}]
    set y2 [expr {$yc+$data(tr)}]
    $w create oval $x1 $y1 $x2 $y2 -fill $data(thumb-fill) -outline $data(thumb-outline) -activeoutline $data(thumb-activeoutline) -width $data(thumb-width) -tag thumb
    $w bind thumb <ButtonPress-1> [list dial::thumb-press $w %x %y]
    $w bind thumb <B1-Motion> [list dial::thumb-motion $w %x %y]
    # $w should become the command procedure for this megawidget, maybe later.
    return $w
}    

proc dial {args} {
    return [eval dial::dial $args]
}
