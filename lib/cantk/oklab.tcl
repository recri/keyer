package provide cantk::oklab 1.0

# struct Lab {float L; float a; float b;};
# struct RGB {float r; float g; float b;};

#
# this package is the result of searching color interpolation
# and recognizing that oklab is the right color space to use.
# this is all explained by https://bottosson.github.io/posts/oklab/
#

# provide a dumb cube root function
proc ::tcl::mathfunc::cbrt {a} { 
    # puts "cubrt($a)"
    set x [expr {pow($a, 1/3.0)}]
    # puts "-> x $x [expr {abs($a-$x*$x*$x)}]"
    if {0} {
	# who'd have thunk it, this blows up
	while {abs($a-$x*$x*$x) > 1e-11} {
	    set x [expr {($a/$x*$x + 2*$x)/3.0}]
	    # puts "-> x $x [expr {abs($a-$x*$x*$x)}]"
	}
    }
    set x
}

# from bottosson's c++
proc linear_srgb_to_oklab {c} {
    
    foreach {c.r c.g c.b} $c break
    
    set l [expr {0.4122214708 * ${c.r} + 0.5363325363 * ${c.g} + 0.0514459929 * ${c.b}}]
    set m [expr {0.2119034982 * ${c.r} + 0.6806995451 * ${c.g} + 0.1073969566 * ${c.b}}]
    set s [expr {0.0883024619 * ${c.r} + 0.2817188376 * ${c.g} + 0.6299787005 * ${c.b}}]
    
    set l_ [expr {cbrt($l)}]
    set m_ [expr {cbrt($m)}]
    set s_ [expr {cbrt($s)}]
    
    return [list \
		[expr {0.2104542553 * $l_ + 0.7936177850 * $m_ - 0.0040720468 * $s_}] \
		[expr {1.9779984951 * $l_ - 2.4285922050 * $m_ + 0.4505937099 * $s_}] \
		[expr {0.0259040371 * $l_ + 0.7827717662 * $m_ - 0.8086757660 * $s_}] \
	       ]
}

# from bottosson's c++
proc oklab_to_linear_srgb {c} {
    
    foreach {c.L c.a c.b} $c break
    
    set l_ [expr {${c.L} + 0.3963377774 * ${c.a} + 0.2158037573 * ${c.b}}]
    set m_ [expr {${c.L} - 0.1055613458 * ${c.a} - 0.0638541728 * ${c.b}}]
    set s_ [expr {${c.L} - 0.0894841775 * ${c.a} - 1.2914855480 * ${c.b}}]
    
    set l  [expr {$l_*$l_*$l_}]
    set m  [expr {$m_*$m_*$m_}]
    set s  [expr {$s_*$s_*$s_}]
    
    return [list \
		[expr {+4.0767416621 * $l - 3.3077115913 * $m + 0.2309699292 * $s}] \
		[expr {-1.2684380046 * $l + 2.6097574011 * $m - 0.3413193965 * $s}] \
		[expr {-0.0041960863 * $l - 0.7034186147 * $m + 1.7076147010 * $s}] \
	       ]
}

# srgb is standard RGB as used everywhere
# linear_srgb is RGB before the gamma correction
# note that 0.0031308 < 1/256.0, so the elbow is
# outside the 8bit rgb gamut
proc linear_srgb_to_srgb {c} { 
    lmap x $c {expr {$x >= 0.0031308 ? (1.055) * pow($x, (1.0/2.4)) - 0.055 : 12.92 * $x}}
}

#
proc srgb_to_linear_srgb {c} { 
    lmap x $c {expr {$x >= 0.04045 ? pow(($x + 0.055)/(1 + 0.055), 2.4) : $x / 12.92}}
}

#
proc srgb_to_oklab {c} { linear_srgb_to_oklab [srgb_to_linear_srgb $c] }

#
proc oklab_to_srgb {c} { linear_srgb_to_srgb [oklab_to_linear_srgb $c] }

# if you're running wish, you can use [winfo rgb . <color>] to map hexrgb and color names
# but they're mapped to 24bit colors and exanded back to 48 by duplication
proc hexrgb_to_srgb {c} { 
    # #rrrrggggbbbb, #rrrgggbbb, #rrggbb, #rgb
    if { ! [regexp {^\#[0-9A-Fa-f]+$} $c]} {
	error "invalid hexrgb format: \"$c\""
    }
    switch [string length $c] {
	13 { set ranges {1 4 5 8 9 12}; set denom 0xffff }
	10 { set ranges {1 3 4 6 7 9}; set denom 0xfff }
	7 { set ranges {1 2 3 4 5 6}; set denom 0xff }
	4 { set ranges {1 1 2 2 3 3}; set denom 0xf }
	default { error "invalid hexrgb resolution: \"$c\"" }
    }
    set irgb [lmap {i1 i2} $ranges {string range $c $i1 $i2}]
    if {$denom == 0xf} { 
	set irgb [lmap x $irgb { string cat $x $x }]
	set denom 0xff
    }
    if {$denom == 0xff} {
	set irgb [lmap x $irgb { string cat $x $x }]
	set denom 0xffff
    }
    if {$denom == 0xfff} {
	set irgb [lmap x $irgb { string cat $x [string index $x 0] }]
	set denom 0xffff
    }
    # not quoting expr to concatenate 0x to digits
    lmap x $irgb {expr double(0x$x)/0xffff} 
}

#
proc srgb_to_hexrgb {c} { string cat "#" [join [lmap x $c {format %04x [expr {round(0xffff*$x)&0xffff}]}] {}] }

#
proc hexrgb_to_oklab {c} { srgb_to_oklab [hexrgb_to_srgb $c] }

#
proc oklab_to_hexrgb {c} { srgb_to_hexrgb [oklab_to_srgb $c] }

# interpolate between two hexrgb colors
# returns a list of hexrgb colors which starts at c1,
# ends at c2, and has nsteps or intermediate colors.
proc hexrgb_interpolate {nsteps c1 c2} {
    set colors {}
    lassign [hexrgb_to_oklab $c1] L1 a1 b1
    lassign [hexrgb_to_oklab $c2] L2 a2 b2
    for {set i 0} {$i <= $nsteps+1} {incr i} {
	set p [expr {double($i)/($nsteps+1)}]
	set L3 [expr {(1-$p) * $L1 + $p * $L2}]
	set a3 [expr {(1-$p) * $a1 + $p * $a2}]
	set b3 [expr {(1-$p) * $b1 + $p * $b2}]
	lappend colors [oklab_to_hexrgb [list $L3 $a3 $b3]]
    }
    set colors
}
