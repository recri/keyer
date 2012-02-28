#
# the si570 is used in many amateur radio products
# this package defines the default parameters and
# the computations required to program the oscillator
#

package provide si570 1.0

namespace eval si570 {
    # the part number on an Si570 specifies the I2C address and the startup frequency
    # these are the ones that usually turn up in amateur radios
    set I2C_ADDR	0x55
    set STARTUP_FREQ	56.32
    # the actual crystal freq is trimmed to make the actual startup frequency correct
    set XTAL_FREQ	114.285
    # within the limits defined by this
    set XTAL_DEVIATION_PPM 2000
    # these are limits used to calculate registers
    set DCO_HIGH	5670.0
    set DCO_LOW		4850.0
    # conversion factor
    set FACTOR 268435456.0
    # divider mapping
    # this is just i+4, except that i == 4 or 6 are unimplemented
    array set HS_DIV_MAP {
	0 4
	1 5
	2 6
	3 7
	4 -1
	5 9
	6 -1
	7 11
    }
}

# the default si570 i2c address
proc si570::default_addr {} { return $si570::I2C_ADDR }
# the default si570 startup frequency
proc si570::default_startup {} { return $si570::STARTUP_FREQ }
# the default si570 crystal frequency
proc si570::default_xtal {} { return $si570::XTAL_FREQ }

## compute the HS_DIV, N1, and RFREQ for the registers
proc si570::registers_to_variables {registers} {
    foreach {b0 b1 b2 b3 b4 b5} $registers break
    set HS_DIV [expr {($b0 & 0xE0) >> 5}]
    set N1 [expr {(($b0 & 0x1f) << 2) | (($b1 & 0xc0 ) >> 6)}]
    set RFREQ_int [expr {(($b1 & 0x3f) << 4) | (($b2 & 0xf0) >> 4)}]
    set RFREQ_frac [expr {(((((($b2 & 0xf) << 8) | $b3) << 8) | $b4) << 8) | $b5}]
    set RFREQ [expr {$RFREQ_int + $RFREQ_frac / $::si570::FACTOR}]
    return [list $HS_DIV $N1 $RFREQ]
}

## compute the registers for the HS_DIV, N1, RFREQ
proc si570::variables_to_registers {HS_DIV N1 RFREQ} {
    # chop these values up into registers
    # |DDDNNNNN|NNIIIIII|IIIIFFFF|FFFFFFFF|FFFFFFFF|FFFFFFFF|
    # D=HS_DIV
    # N=N1
    # I=RFREQ_int
    # F=RFREQ_frac
    set RFREQ_int [expr {int($RFREQ)}]
    set RFREQ_frac [expr {int(($RFREQ-$RFREQ_int)*$::si570::FACTOR)}]
    set b0 [expr {($HS_DIV << 5) | (($N1 >> 2) & 0x1f)}]
    set b1 [expr {(($N1&0x3) << 6) | ($RFREQ_int >> 4)}]
    set b2 [expr {(($RFREQ_int&0xF) << 4) | (($RFREQ_frac >> 24) & 0xF)}]
    set b3 [expr {(($RFREQ_frac >> 16) & 0xFF)}]
    set b4 [expr {(($RFREQ_frac >> 8) & 0xFF)}]
    set b5 [expr {(($RFREQ_frac >> 0) & 0xFF)}]
    return [list $b0 $b1 $b2 $b3 $b4 $b5]
}
    
## compute the crystal frequency multiplier for the set of register values
proc si570::calculate_xtal_multiplier {registers} {
    variable HS_DIV_MAP
    foreach {HS_DIV N1 RFREQ} [registers_to_variables $registers] break
    return [expr {$RFREQ / (($N1 + 1) * $HS_DIV_MAP($HS_DIV))}]
}

## compute the crystal frequency from the registers and the factory startup frequency
proc si570::calculate_xtal {registers startup} {
    return [expr {$startup / [calculate_xtal_multiplier $registers]}]
}

## compute the frequency from the registers and the crystal frequency
proc si570::calculate_frequency {registers xtal} {
    return [expr {$xtal * [calculate_xtal_multiplier $registers]}]
}

## compute the variables for a frequency and the specified crystal frequency
proc si570::calculate_all_variables {frequency {xtal {}}} {
    if {$xtal eq {}} {
	set xtal [si570::default_xtal]
    }
    variable HS_DIV_MAP
    variable DCO_LOW
    variable DCO_HIGH
    set solutions {}
    ## for each of the possible dividers
    ## get the divider index (HS_DIV) and the divider value (HS_DIVIDER)
    foreach HS_DIV [lsort [array names HS_DIV_MAP]] {
	set HS_DIVIDER $HS_DIV_MAP($HS_DIV);
	## the negative divider values don't count
	if {$HS_DIVIDER <= 0} continue
	## calculate N1 at the midrange of the DCO
	set y [expr {($DCO_HIGH+$DCO_LOW) / (2 * $frequency * $HS_DIVIDER)}]
	if {$y < 1.5} {
	    set y 1.0
	} else {
	    set y [expr {2 * round($y / 2.0)}]
	}
	if {$y > 128} {
	    set y 128.0
	}
	set N1 [expr {int(floor($y) - 1)}]
	## set N1 [expr {int(floor(($DCO_HIGH+$DCO_LOW) / (2 * $frequency * $HS_DIVIDER)) - 1)}]
	if {$N1 < 0 || $N1 > 127} continue
	set f0 [expr {$frequency * ($N1+1) * $HS_DIVIDER}]
	if {$DCO_LOW <= $f0 && $f0 <= $DCO_HIGH} {
	    set RFREQ [expr {$f0 / $xtal}]
	    lappend solutions [list $HS_DIV $N1 $RFREQ]
	}
    }
    return $solutions
}

## compute the registers for a frequency and the specified crystal frequency
proc si570::calculate_registers {frequency xtal} {
    variable HS_DIV_MAP
    variable DCO_LOW
    variable DCO_HIGH
    ## start with no solution
    set solution {}
    ## for each of the possible dividers
    ## get the divider index (HS_DIV) and the divider value (HS_DIVIDER)
    foreach {HS_DIV HS_DIVIDER} [array get HS_DIV_MAP] {
	## the negative divider values don't count
	if {$HS_DIVIDER <= 0} continue
	## let y be the midrange of the DCO, divided by (the frequency times the divider)
	set y [expr {($DCO_HIGH+$DCO_LOW) / (2 * $frequency * $HS_DIVIDER)}]
	if {$y < 1.5} {
	    set y 1.0
	} else {
	    set y [expr {2 * round($y / 2.0)}]
	}
	if {$y > 128} {
	    set y 128.0
	}
	set N1 [expr {int(floor($y) - 1)}]
	set f0 [expr {$frequency * $y * $HS_DIVIDER}]
	if {$DCO_LOW <= $f0 && $f0 <= $DCO_HIGH} {
	    set RFREQ [expr {$f0 / $xtal}]
	    if {$solution eq {} || $RFREQ < [lindex $solution 2]} {
		set solution [list $HS_DIV $N1 $RFREQ]
	    }
	}
    }
    if {$solutions eq {}} {
	return {}
    }
    return [variables_to_registers {*}$solution]
}

## check if the computed crystal frequency is within spec
proc si570::validate_xtal {xtal} {
    variable XTAL_FREQ
    variable XTAL_DEVIATION_PPM
    if {(1000000.0 * abs($xtal - $XTAL_FREQ) / $XTAL_FREQ) <= $XTAL_DEVIATION_PPM} {
	return $xtal
    } else {
	# The most likely possibility is that since power on,
	# the Si570 has been shifted from the factory default frequency.
	# Except we reset the Si570 before we did this.
	error "calculated crystal reference is outside of the spec for the Si570 device"
    }
}

    