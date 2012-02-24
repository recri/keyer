#
# the si570 is used in many amateur radio products
# this package defines the default parameters and
# the computations required to program the oscillator
#

package provide si570 1.0

namespace eval si570 {
    # the part number on an Si570 specifies the I2C address and the startup 
    set I2C_ADDR	0x55
    set STARTUP_FREQ	56.32
    # the actual crystal freq is trimmed to make the actual startup frequency correct
    set XTAL_FREQ	114.285
    # within the limits defined by this
    set XTAL_DEVIATION_PPM 2000
    # these are limits used to calculate registers
    set DCO_HIGH	5670.0
    set DCO_LOW		4850.0
    # divider mapping
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

## compute the crystal frequency multiplier for the set of register values
proc si570::calculate_xtal_multiplier {registers} {
    variable HS_DIV_MAP
    foreach {b0 b1 b2 b3 b4 b5} $registers break
    set HS_DIV [expr {($b0 & 0xE0) >> 5}]
    set N1 [expr {(($b0 & 0x1f) << 2) | (($b1 & 0xc0 ) >> 6)}]
    set RFREQ_int [expr {(($b1 & 0x3f) << 4) | (($b2 & 0xf0) >> 4)}]
    set RFREQ_frac [expr {(((((($b2 & 0xf) << 8) | $b3) << 8) | $b4) << 8) | $b5}]
    set RFREQ [expr {$RFREQ_int + $RFREQ_frac / 268435456.0}]
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

## compute the registers for a frequency and the specified crystal frequency
proc si570::calculate_registers {frequency xtal} {
    ## start with no solution
    set solution {}
    ## for each of the possible dividers
    ## get the divider index (HS_DIV) and the divider value (HS_DIVIDER)
    foreach {HS_DIV HS_DIVIDER} [array get si570::HS_DIV_MAP] {
	## the negative divider values don't count
	if {$HS_DIVIDER <= 0} continue
	## let y be the midrange of the DCO, divided by (the frequency times the divider)
	set y [expr {($si570::DCO_HIGH+$si570::DCO_LOW) / (2 * $frequency * $HS_DIVIDER)}]
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
	if {$si570::DCO_LOW <= $f0 && $f0 <= $si570::DCO_HIGH} {
	    set RFREQ [expr {$f0 / $xtal}]
	    if {$solution eq {} || $RFREQ < [lindex $solution 0]} {
		set solution [list $RFREQ $HS_DIV $N1]
	    }
	}
    }
    if {$solutions eq {}} {
	return {}
    }
    foreach {RFREQ HS_DIV N1} $solution break
    # chop these values up into registers
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

    