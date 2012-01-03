package provide keyer-control 1.0.0

namespace eval keyer-control {
    # default keyer parameters
    array set data {
	ascii 0
	iambic 1

	keyer-channel 1
	keyer-note 0

	ascii_tone-freq 700
	ascii_tone-gain -30
	ascii_tone-rise 5
	ascii_tone-fall 5

	ascii-wpm 15
	ascii-word 50
	ascii-dah 3
	ascii-ies 1
	ascii-ils 3
	ascii-iws 7

	iambic_tone-freq 750
	iambic_tone-gain -30
	iambic_tone-rise 5
	iambic_tone-fall 5

	iambic-wpm 15
	iambic-word 50
	iambic-dah 3
	iambic-ies 1
	iambic-ils 3
	iambic-iws 7
	iambic-mode A
	iambic-alsp 0
	iambic-awsp 0
	iambic-swap 0

    }
}

