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

package provide sdrblk::radio 1.0.0

package require snit

package require sdrblk::radio-control
package require sdrblk::block-pipeline

namespace eval sdrblk {}

snit::type sdrblk::radio {
    component control
    component rx
    component tx
    component hw
    component ui

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -rx -readonly yes -default true
    option -tx -readonly yes -default false
    option -hw -readonly yes -default true
    option -hw-type -readonly yes -default {softrock-dg8saq}
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {command-line}
    option -rx-inport -readonly yes -default {system:capture_1 system:capture_2}
    option -rx-outport -readonly yes -default {system:playback_1 system:playback_2}
    option -tx-inport -readonly yes -default {}
    option -tx-outport -readonly yes -default {}

    constructor {args} {
	#puts "radio $self constructor $args"
	$self configure {*}$args
	install control using ::sdrblk::radio-control %AUTO% -partof $self
	set options(-control) $control
	if {$options(-rx)} {
	    install rx using ::sdrblk::radio-rx %AUTO% -partof $self -inport $options(-rx-inport) -outport $options(-rx-outport)
	}
	if {$options(-tx)} {
	    install tx using ::sdrblk::radio-tx %AUTO% -partof $self -inport $options(-tx-inport) -outport $options(-tx-outport)
	}
	if {$options(-hw)} {
	    package require sdrblk::radio-hw-$options(-hw-type)
	    install hw using ::sdrblk::radio-hw-$options(-hw-type) %AUTO% -partof $self
	}
	if {$options(-ui)} {
	    # puts "requiring sdrblk::radio-ui-$options(-ui-type)"
	    package require sdrblk::radio-ui-$options(-ui-type)
	    # puts "installing ui using ::sdrblk::radio-ui-$options(-ui-type) %AUTO% -partof $self"
	    install ui using ::sdrblk::radio-ui-$options(-ui-type) %AUTO% -partof $self
	    # puts "ui is $ui"
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

proc sdrblk::radio-rx {name args} {
    set pipe {sdrblk::radio-rx-rf sdrblk::radio-rx-if sdrblk::radio-rx-af}
    return [sdrblk::block-pipeline $name -suffix rx -pipeline $pipe {*}$args]
}

proc sdrblk::radio-rx-rf {name args} {
    #  gain iq-swap spectrum-semi-raw noiseblanker meter-pre-conv iq-delay iq-correct
    set pipe {sdrblk::comp-gain sdrblk::comp-iq-swap sdrblk::comp-spectrum-semi-raw sdrblk::comp-iq-delay sdrblk::comp-iq-correct}
    return [sdrblk::block-pipeline $name -suffix rf -pipeline $pipe {*}$args]
}

proc sdrblk::radio-rx-if {name args} {
    # -pipeline {spec_pre_filt lo-mixer filter-overlap-save rxmeter_post_filt spec_post_filt}
    set pipe {sdrblk::comp-spectrum-pre-filt sdrblk::comp-lo-mixer sdrblk::comp-filter-overlap-save sdrblk::comp-meter-post-filt sdrblk::comp-spectrum-post-filt}
    return [sdrblk::block-pipeline $name -suffix if -pipeline $pipe {*}$args]
}

proc sdrblk::radio-rx-af {name args} {
    # set {compand agc rxmeter_post_agc spec_post_agc sdrblk::comp-demod rx_squelch spottone graphiceq spec_post_det}
    set pipe {sdrblk::comp-agc sdrblk::comp-meter-post-agc sdrblk::comp-spectrum-post-agc sdrblk::comp-demod sdrblk::comp-gain}
    return [sdrblk::block-pipeline $name -suffix af -pipeline $pipe {*}$args]
}

proc sdrblk::radio-tx {name args} {
    set pipe {sdrblk::radio-tx-af sdrblk::radio-tx-if sdrblk-radio-tx-rf}
    return [sdrblk::block-pipeline $name -suffix tx -pipeline $pipe {*}$args]
}

proc sdrblk::radio-tx-af {name args} {
    # -pipeline {sdrblk::comp-gain sdrblk::comp-real sdrblk::comp-waveshape meter_tx_wavs sdrblk::comp-dc-block tx_squelch grapiceq meter_tx_eqtap
    #		sdrblk::comp-leveler meter_tx_leveler sdrblk::comp-speech_processor meter_tx_comp sdrbk::comp-modulate}
    # a lot of this is voice specific
    # CW only has an oscillator feeding into the LO mixer
    set pipe {sdrblk::comp-gain sdrblk::comp-leveler sdrblk::comp-modulate}
    return [sdrblk::block-pipeline $name -suffix af -pipeline $pipe {*}$args]
}

proc sdrblk::radio-tx-if {name args} {
    # -pipeline {sdrblk::comp-filter-overlap-save sdrblk::comp-compander meter_tx_compander spectrum_tx sdrblk::comp-lo-mixer}
    set pipe {sdrblk::comp-filter-overlap-save sdrblk::comp-lo-mixer}
    return [sdrblk::block-pipeline $name -suffix if -pipeline $pipe {*}$args]
}

proc sdrblk::radio-tx-rf {name args} {
    # -pipeline { sdrblk::comp-iq-balance sdrblk::comp-gain meter_tx_power}
    set pipe {sdrblk::comp-iq-balance sdrblk::comp-gain}
    return [sdrblk::block-pipeline $name -suffix rf -pipeline $pipe {*}$args]
}
