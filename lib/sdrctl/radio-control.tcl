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

package provide sdrctl::radio-control 1.0.0

package require snit

package require sdrctl::types
package require sdrctl::control
package require sdrctl::control-stub

package require sdrutil::band-data

namespace eval sdrctl {}
namespace eval sdrctlw {}

##
## start the radio control components
##
proc sdrctl::radio-controller {name args} {
    return [sdrctl::controller $name {*}$args]
}

proc sdrctl::radio-controls {args} {
    set root [sdrctl::control ::sdrctlw::ctl -type ctl -prefix {} -suffix ctl -factory sdrctl::control-stub {*}$args]
    foreach {suffix factory opts} {
	rxtx sdrctl::control-stub {}
	rx sdrctl::control-stub {}
	rx-af sdrctl::control-stub {}
	rx-rf sdrctl::control-stub {}
	tx sdrctl::control-stub {}
	tx-af sdrctl::control-stub {}
	tx-rf sdrctl::control-stub {}
	keyer sdrctl::control-stub {}
	rxtx-band-select sdrctl::control-band {}
	rxtx-if-bpf sdrctl::control-filter {}
	rxtx-if-mix sdrctl::control-if-mix {}
	rxtx-mode sdrctl::control-mode {}
	rxtx-mox sdrctl::control-rxtx {}
	rxtx-tuner sdrctl::control-tune {}
	rx-af-agc sdrctl::control-agc {}
	rx-af-gain sdrctl::control-af-gain {}
	rx-rf-gain sdrctl::control-rf-gain {}
	rx-rf-iq-correct sdrctl::control-iq-correct {}
	rx-rf-iq-delay sdrctl::control-iq-delay {}
	rx-rf-iq-swap sdrctl::control-iq-swap {}
	tx-af-gain sdrctl::control-af-gain {}
	tx-af-leveler sdrctl::control-leveler {}
	tx-rf-gain sdrctl::control-rf-gain {}
	tx-rf-iq-balance sdrctl::control-iq-balance {}
	keyer-debounce sdrctl::control-keyer-debounce {}
	keyer-iambic sdrctl::control-keyer-iambic {}
	keyer-tone sdrctl::control-keyer-tone {}
    } {
	sdrctl::control ::sdrctlw::$suffix -type ctl -suffix $suffix -factory $factory -factory-options $opts -container $root
    }
}

##
## handle mode setting controls
##
snit::type sdrctl::control-mode {
    option -command {}

    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode

    method {Opt-handler -mode} {val} {
	set options(-mode) $val
	{*}$options(-command) report -mode $val
    }
}

##
## handle tuning controls
##
snit::type sdrctl::control-tune {
    option -command {}
    option -opt-connect-from {{ctl-rxtx-mode -mode -mode}}

    option -mode -default CWU -configuremethod Retune -type sdrctl::mode
    option -turn-resolution -default 1000 -configuremethod Opt-handler
    option -freq -default 7050000 -configuremethod Retune
    option -lo-freq -default 10000 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -carrier-freq -default 7040000 -configuremethod Opt-handler
    option -hw-freq -default 7039400 -configuremethod Opt-handler

    method Retune {opt val} {
	set options($opt) $val
	switch $options(-mode) {
	    CWU { set options(-carrier-freq) [expr {$options(-freq)-$options(-cw-freq)}] }
	    CWL { set options(-carrier-freq) [expr {$options(-freq)+$options(-cw-freq)}] }
	    default { set options(-carrier-freq) [expr {$options(-freq)}] }
	}
	set options(-hw-freq) [expr {$options(-carrier-freq)-$options(-lo-freq)}]
	{*}$options(-command) report -carrier-freq $options(-carrier-freq)
	{*}$options(-command) report -hw-freq $options(-hw-freq)
	{*}$options(-command) report $opt $val
    }
    method {Opt-handler} {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle mox/vox/ptt controls
##
snit::type sdrctl::control-rxtx {
    option -command {}

    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode
    option -mox -default 0 -configuremethod Opt-handler 

    method {Opt-handler} {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle band setting controls
##
snit::type sdrctl::control-band {
    option -command -default {} -readonly true
    option -opt-connect-to { {-mode ctl-rxtx-mode -mode} {-filter-width ctl-rxtx-if-bpf -width} {-freq ctl-rxtx-tuner -freq} }
    # incoming options
    option -band -configuremethod Band-handler 
    option -channel -configuremethod Channel-handler 
    # outgoing options
    option -label -readonly true -configuremethod Opt-handler
    option -low -readonly true -configuremethod Opt-handler
    option -high -readonly true -configuremethod Opt-handler
    option -mode -default CWU -readonly true -type sdrctl::mode -configuremethod Opt-handler
    option -filter-width -readonly true -configuremethod Opt-handler
    option -freq -readonly true -configuremethod Opt-handler

    method Band-handler {opt val} {
	set options($opt) $val
	# could also extract label, mode, filter width, and channel step
	lassign [sdrutil::band-data-band-range-hertz {*}$val] low high
	$self configure -freq [expr {($options(-band-low)+$options(-band-high))/2}] -low $low -high $high
	{*}$options(-command) report $opt $val
    }
    method Channel-handler {opt val} {
	set options($opt) $val
	$self configure -freq [sdrutil::band-data-channel-freq-hertz {*}$val]
	{*}$options(-command) report $opt $val
    }
    method {Opt-handler} {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle filter controls
##
snit::type sdrctl::control-filter {
    option -command -default {} -readonly true
    option -opt-connect-from {{ctl-rxtx-mode -mode -mode} {ctl-rxtx-tuner -cw-freq -cw-freq}}
    # incoming opts
    option -mode -default CWU -configuremethod Retune -type sdrctl::mode
    option -width -default 400 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -length -default 128 -configuremethod Opt-handler
    # outgoing opts
    option -low -default 400 -configuremethod Opt-handler
    option -high -default 800 -configuremethod Opt-handler

    method {Opt-handler} {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
    method Retune {opt val} {
	set options($opt) $val
	set c $options(-cw-freq)
	set w $options(-width)
	set h [expr {$options(-width)/2.0}]
	switch $options(-mode) {
	    CWL { set low [expr {-$c-$h}]; set high [expr {-$c+$h}] }
	    CWU { set low [expr {+$c-$h}]; set high [expr {+$c+$h}] }
	    AM -
	    SAM -
	    DSB -
	    FMN { set low [expr {-$h}]; set high [expr {+$h}] }
	    LSB -
	    DIGL { set low [expr {-150-$w}]; set high -150 }
	    USB -
	    DIGU { set low 150; set high [expr {150+$w}] }
	    default { error "missed mode $options(-mode)" }
	}
	{*}$options(-command) report $opt $val
	$self configure -low $low -high $high
    }
}

##
## handle gain controls
##
snit::type sdrctl::control-af-gain {
    option -command -default {} -readonly true
    # incoming opts
    option -gain -default 0 -configuremethod Opt-handler -type sdrctl::gain
    option -mute -default false -configuremethod Opt-handler -type sdrctl::mute

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle agc controls
##
snit::type sdrctl::control-agc {
    option -command -default {} -readonly true
    # incoming opts
    option -mode -default med -configuremethod Opt-handler -type sdrctl::agc-mode

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle leveler controls
##
snit::type sdrctl::control-leveler {
    option -command -default {} -readonly true
    # incoming opts
    option -mode -default leveler -configuremethod Opt-handler -type sdrctl::leveler-mode

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer sidetone controls
##
snit::type sdrctl::control-keyer-tone {
    option -command -default {} -readonly true
    option -opt-connect-to { {-freq ctl-rxtx-tuner -cw-freq} }
    option -opt-connect-from { {ctl-rxtx-tuner -cw-freq -freq} }
    # incoming opts
    option -freq -default 600 -configuremethod Opt-handler -type sdrctl::hertz
    option -spot -default 0 -configuremethod Opt-handler -type sdrctl::spot

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer debounce controls
##
snit::type sdrctl::control-keyer-debounce {
    option -command -default {} -readonly true
    # incoming opts
    option -debounce -default 0 -configuremethod Opt-handler -type sdrctl::debounce
    option -period -default 0.1 -configuremethod Opt-handler -type sdrctl::debounce-period
    option -steps -default 4 -configuremethod Opt-handler -type sdrctl::debounce-steps

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer iambic controls
##
snit::type sdrctl::control-keyer-iambic {
    option -command -default {} -readonly true
    # incoming opts
    option -iambic -default ad5dz -configuremethod Opt-handler -type sdrctl::iambic

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle rf gain controls
##
snit::type sdrctl::control-rf-gain {
    option -command -default {} -readonly true
    # incoming opts
    option -gain -default 0 -configuremethod Opt-handler -type sdrctl::gain

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-balance controls
##
snit::type sdrctl::control-iq-balance {
    option -command -default {} -readonly true
    # incoming opts
    option -sine-phase -default 0 -configuremethod Opt-handler -type sdrctl::sine-phase
    option -linear-gain -default 1.0 -configuremethod Opt-handler -type sdrctl::linear-gain

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-correct controls
##
snit::type sdrctl::control-iq-correct {
    option -command -default {} -readonly true
    # incoming opts
    option -mu -default 0 -configuremethod Opt-handler -type sdrctl::iq-correct

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-delay controls
##
snit::type sdrctl::control-iq-delay {
    option -command -default {} -readonly true
    # incoming opts
    option -delay -default 0 -configuremethod Opt-handler -type sdrctl::iq-delay

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-swap controls
##
snit::type sdrctl::control-iq-swap {
    option -command -default {} -readonly true
    # incoming opts
    option -swap -default 0 -configuremethod Opt-handler -type sdrctl::iq-swap

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle local oscillator controls
##
snit::type sdrctl::control-if-mix {
    option -command -default {} -readonly true
    option -opt-connect-to { {-freq ctl-rxtx-tuner -lo-freq} }
    option -opt-connect-from { {ctl-rxtx-tuner -lo-freq -freq} }
    # incoming opts
    option -freq -default 10000 -configuremethod Opt-handler -type sdrctl::hertz

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

