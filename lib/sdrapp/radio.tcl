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

package provide sdrapp::radio 1.0.0

package require snit

package require sdrblk::radio-control
package require sdrblk::block

namespace eval sdrapp {}

snit::type sdrapp::radio {
    component control
    component rx
    component tx
    component keyer
    component hw
    component ui

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -rx -readonly yes -default true
    option -tx -readonly yes -default true
    option -keyer -readonly yes -default true
    option -hw -readonly yes -default true
    option -hw-type -readonly yes -default {softrock-dg8saq}
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {notebook}
    option -rx-source -readonly yes -default {system:capture_1 system:capture_2}
    option -rx-sink -readonly yes -default {system:playback_1 system:playback_2}
    option -tx-source -readonly yes -default {}
    option -tx-sink -readonly yes -default {}
    option -keyer-source -readonly yes -default {}
    option -keyer-sink -readonly yes -default {}

    constructor {args} {
	$self configure {*}$args
	install control using ::sdrblk::radio-control %AUTO% -partof $self
	set options(-control) $control
	if {$options(-rx)} {
	    install rx using ::sdrapp::radio-rx %AUTO% -partof $self -source $options(-rx-source) -sink $options(-rx-sink)
	}
	if {$options(-tx)} {
	    install tx using ::sdrapp::radio-tx %AUTO% -partof $self -source $options(-tx-source) -sink $options(-tx-sink)
	}
	if {$options(-keyer)} {
	    install keyer using sdrapp::keyer %AUTO% -partof $self -source $options(-keyer-source) -sink $options(-keyer-sink)
	}
	if {$options(-hw)} {
	    package require sdrblk::radio-hw-$options(-hw-type)
	    install hw using ::sdrblk::radio-hw-$options(-hw-type) %AUTO% -partof $self
	}
	if {$options(-ui)} {
	    package require sdrui::radio-$options(-ui-type)
	    install ui using ::sdrui::radio-$options(-ui-type) %AUTO% -partof $self
	}
    }

    destructor {
	catch {$ui destroy}
	catch {$hw destroy}
	catch {$tx destroy}
	catch {$rx destroy}
	catch {$control destroy}
    }

    method repl {} {
	if {$ui ne {}} { $ui repl }
    }
}

proc sdrapp::radio-rx {name args} {
    set pipe {sdrapp::radio-rx-rf sdrapp::radio-rx-if sdrapp::radio-rx-af}
    return [sdrblk::block $name -type sequence -suffix rx -sequence $pipe {*}$args]
}

proc sdrapp::radio-rx-rf {name args} {
    set seq {sdrblk::comp-gain sdrblk::comp-iq-swap sdrblk::comp-iq-delay sdrblk::comp-spectrum-semi-raw}
    set req {sdrblk::comp-gain sdrblk::comp-iq-swap sdrblk::comp-iq-delay sdrblk::comp-spectrum}
    # lappend seq sdrblk::comp-noiseblanker sdrblk::comp-sdrom-noiseblanker
    # lappend req sdrblk::comp-noiseblanker
    lappend seq sdrblk::comp-iq-correct
    lappend req sdrblk::comp-iq-correct
    return [sdrblk::block $name -type sequence -suffix rf -sequence $seq -require $req {*}$args]
}

proc sdrapp::radio-rx-if {name args} {
    set seq {sdrblk::comp-spectrum-pre-filt sdrblk::comp-lo-mixer sdrblk::comp-filter-overlap-save sdrblk::comp-meter-post-filt sdrblk::comp-spectrum-post-filt}
    set req {sdrblk::comp-spectrum sdrblk::comp-lo-mixer sdrblk::comp-filter-overlap-save sdrblk::comp-meter}
    return [sdrblk::block $name -type sequence -suffix if -sequence $seq -require $req {*}$args]
}

proc sdrapp::radio-rx-af {name args} {
    set seq {}
    set req {}
    # lappend seq sdrblk::comp-compand
    # lappend req sdrblk::comp-compand
    lappend seq sdrblk::comp-agc sdrblk::comp-meter-post-agc sdrblk::comp-spectrum-post-agc sdrblk::comp-demod
    lappend req sdrblk::comp-agc sdrblk::comp-meter sdrblk::comp-spectrum sdrblk::comp-demod
    # lappend seq sdrblk::comp-rx-squelch sdrblk::comp-spottone sdrblk::comp-graphic-eq
    # lappend req sdrblk::comp-rx-squelch sdrblk::comp-spottone sdrblk::comp-graphic-eq
    lappend seq sdrblk::comp-gain
    lappend req sdrblk::comp-gain
    return [sdrblk::block $name -type sequence -suffix af -sequence $seq -require $req {*}$args]
}

proc sdrapp::radio-tx {name args} {
    set seq {sdrapp::radio-tx-af sdrapp::radio-tx-if sdrapp::radio-tx-rf}
    return [sdrblk::block $name -type sequence -suffix tx -sequence $seq {*}$args]
}

proc sdrapp::radio-tx-af {name args} {
    set seq {sdrblk::comp-gain}
    set req {sdrblk::comp-gain}
    # lappend seq sdrblk::comp-real sdrblk::comp-waveshape
    # lappend req sdrblk::comp-real sdrblk::comp-waveshape
    lappend seq sdrblk::comp-meter-waveshape
    lappend req sdrblk::comp-meter
    # lappend seq sdrblk::comp-dc-block sdrblk::comp-tx-squelch sdrblk::comp-grapic-eq
    # lappend req sdrblk::comp-dc-block sdrblk::comp-tx-squelch sdrblk::comp-grapic-eq
    lappend seq sdrblk::comp-meter-graphic-eq sdrblk::comp-leveler sdrblk::comp-meter-leveler
    lappend req sdrblk::comp-meter sdrblk::comp-leveler
    # lappend seq sdrblk::comp-speech-processor
    # lappend req sdrblk::comp-speech-processor
    lappend seq sdrblk::comp-meter-speech-processor
    lappend req sdrblk::comp-meter
    # lappend seq sdrblk::comp-modulate
    # lappend req sdrblk::comp-modulate

    # a lot of this is voice specific
    # CW only has a keyed oscillator feeding into the LO mixer
    # hw-softrock-dg8saq should have an option to poll keystate and insert as midi
    # hw-softrock-dg8saq should by default convert midi control to dg8saq, both directions
    return [sdrblk::block $name -type sequence -suffix af -sequence $seq -require $req {*}$args]
}

proc sdrapp::radio-tx-if {name args} {
    set seq {sdrblk::comp-filter-overlap-save}
    set req {sdrblk::comp-filter-overlap-save}
    # lappend seq sdrblk::comp-compand
    # lappend req sdrblk::comp-compand
    lappend seq sdrblk::comp-meter-compand sdrblk::comp-spectrum-tx sdrblk::comp-lo-mixer
    lappend req sdrblk::comp-meter sdrblk::comp-spectrum sdrblk::comp-lo-mixer
    return [sdrblk::block $name -type sequence -suffix if -sequence $seq -require $req {*}$args]
}

proc sdrapp::radio-tx-rf {name args} {
    set seq {sdrblk::comp-iq-balance sdrblk::comp-gain sdrblk::comp-meter-power}
    set req {sdrblk::comp-iq-balance sdrblk::comp-gain sdrblk::comp-meter}
    return [sdrblk::block $name -type sequence -suffix rf -sequence $seq -require $req {*}$args]
}

proc sdrapp::keyer {name args} {
    set req {sdrblk::comp-keyer}
    set seq {sdrblk::comp-keyer-debounce sdrblk::comp-keyer-iambic sdrblk::comp-keyer-ptt sdrblk::comp-keyer-tone}
    return [sdrblk::block $name -type sequence -suffix keyer -sequence $seq -require $req {*}$args]
}
