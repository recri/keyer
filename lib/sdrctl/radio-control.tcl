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
proc sdrctl::radio-control {name args} {
    set control [sdrctl::controller $name {*}$args]
    set root [sdrctl::control ::sdrctlw::ctl -type ctl -prefix {} -suffix ctl -factory sdrctl::control-stub -control $control]
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
	sdrctl::control ::sdrctlw::$suffix -type ctl -suffix $suffix -factory $factory -control $control -factory-options $opts -container $root
    }
    return $control
}

##
## handle mode setting controls
##
snit::type sdrctl::control-mode {
    option -command {}
    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode
    option -opts {-mode}
    option -ports {}
    option -opt-connect-to {}
    option -opt-connect-from {}

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
    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode
    option -turn-resolution -default 1000 -configuremethod Opt-handler
    option -freq -default 7050000 -configuremethod Opt-handler
    option -lo-freq -default 10000 -configuremethod Opt-handler
    option -cw-freq -default 600 -configuremethod Opt-handler
    option -carrier-freq -default 7040000 -configuremethod Opt-handler
    option -hw-freq -default 7039400 -configuremethod Opt-handler
    option -opt-connect-to {}
    option -opt-connect-from {{ctl-rxtx-mode -mode -mode}}

    method compute-carrier {} {
	switch $options(-mode) {
	    CWU { set options(-carrier-freq) [expr {$options(-freq)-$options(-cw-freq)}] }
	    CWL { set options(-carrier-freq) [expr {$options(-freq)+$options(-cw-freq)}] }
	    default { set options(-carrier-freq) [expr {$options(-freq)}] }
	}
	set options(-hw-freq) [expr {$options(-carrier-freq)-$options(-lo-freq)}]
	{*}$options(-command) report -carrier-freq $options(-carrier-freq)
	{*}$options(-command) report -hw-freq $options(-hw-freq)
    }
    method {Opt-handler -mode} {val} {
	set options(-mode) $val
	$self compute-carrier
    }
    method {Opt-handler -freq} {val} {
	set options(-freq) $val
	$self compute-carrier
	{*}$options(-command) report -freq $options(-freq)
    }
    method {Opt-handler -lo-freq} {val} {
	set options(-lo-freq) $val
	$self compute-carrier
	{*}$options(-command) report -lo-freq $options(-lo-freq)
    }
    method {Opt-handler -cw-freq} {val} {
	set options(-cw-freq) $val
	$self compute-carrier
	{*}$options(-command) report -cw-freq $options(-cw-freq)
    }
    method {Opt-handler -carrier-freq} {val} { }
    method {Opt-handler -hw-freq} {val} { }
}

##
## handle mox/vox/ptt controls
##
snit::type sdrctl::control-rxtx {
    option -command {}
    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode
    option -mox -default 0 -configuremethod Opt-handler 

    option -opt-connect-to {}
    option -opt-connect-from {}

    method {Opt-handler -mode} {val} { }
    method {Opt-handler -mox} {val} { }
}

##
## handle band setting controls
##
snit::type sdrctl::control-band {
    # incoming options
    option -band -configuremethod Opt-handler 
    option -channel -configuremethod Opt-handler 
    # outgoing options
    option -label -readonly true
    option -low -readonly true
    option -high -readonly true
    option -mode -default CWU -readonly true -type sdrctl::mode
    option -filter-width -readonly true
    option -freq -readonly true
    # required options
    option -opts -default {-band -channel -label -low -high -mode -filter -freq} -readonly true
    option -ports -default {} -readonly true
    option -command -default {} -readonly true
    option -opt-connect-to { {-mode ctl-rxtx-mode -mode} {-filter-width ctl-rxtx-if-bpf -width} {-freq ctl-rxtx-tuner -freq} }
    option -opt-connect-from {}

    method {Opt-handler -band} {val} {
	set options(-band) $val
	lassign [sdrutil::band-data-band-range-hertz {*}$val] options(-band-low) options(-band-high)
	set freq [expr {($options(-band-low)+$options(-band-high))/2}]
	{*}$options(-command) report -freq $freq
    }
    method {Opt-handler -channel} {val} {
	set options(-channel) $val
	set freq [sdrutil::band-data-channel-freq-hertz {*}$val]
	{*}$options(-command) report -freq $freq
    }
}

##
## handle filter controls
##
snit::type sdrctl::control-filter {
    # incoming opts
    option -mode -default CWU -configuremethod Opt-handler -type sdrctl::mode
    option -width -default 400 -configuremethod Opt-handler
    option -cw-freq -default 600 -configuremethod Opt-handler
    option -length -default 128 -configuremethod Opt-handler
    # outgoing opts
    option -bpf-low -default 400 -readonly true
    option -bpf-high -default 800 -readonly true
    option -bpf-length -default 128 -readonly true
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-mode -width -cw-freq -bpf-low -bpf-high} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {{ctl-rxtx-mode -mode -mode} {ctl-rxtx-tuner -cw-freq -cw-freq}}

    method {Opt-handler -mode} {val} {
	set options(-mode) $val
	{*}$options(-command) report -mode $val
    }
    method {Opt-handler -width} {val} {
	set options(-width) $val
	$self Compute-filter
	{*}$options(-command) report -width $val
    }
    method {Opt-handler -cw-freq} {val} {
	set options(-cw-freq) $val
	$self Compute-filter
	{*}$options(-command) report -cw-freq $val
    }
    method {Opt-handler -length} {val} {
	set options(-length) $val
	{*}$options(-command) report -length $val
	{*}$options(-command) report -bpf-length $val
    }
    method Compute-filter {} {
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
	{*}$options(-command) report -bpf-low $low -bpf-high $high
    }
}

##
## handle gain controls
##
snit::type sdrctl::control-af-gain {
    # incoming opts
    option -gain -default 0 -configuremethod Opt-handler -type sdrctl::gain
    option -mute -default false -configuremethod Opt-handler -type sdrctl::mute
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-gain -mute} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}
    option -command {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle agc controls
##
snit::type sdrctl::control-agc {
    # incoming opts
    option -mode -default med -configuremethod Opt-handler -type sdrctl::agc-mode
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-mode} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle leveler controls
##
snit::type sdrctl::control-leveler {
    # incoming opts
    option -mode -default leveler -configuremethod Opt-handler -type sdrctl::leveler-mode
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-mode} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer sidetone controls
##
snit::type sdrctl::control-keyer-tone {
    # incoming opts
    option -freq -default 600 -configuremethod Opt-handler -type sdrctl::hertz
    option -spot -default 0 -configuremethod Opt-handler -type sdrctl::spot
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-freq -spot} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to { {-freq ctl-rxtx-tuner -cw-freq} }
    option -opt-connect-from { {ctl-rxtx-tuner -cw-freq -freq} }

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer debounce controls
##
snit::type sdrctl::control-keyer-debounce {
    # incoming opts
    option -debounce -default 0 -configuremethod Opt-handler -type sdrctl::debounce
    option -period -default 0.1 -configuremethod Opt-handler -type sdrctl::debounce-period
    option -steps -default 4 -configuremethod Opt-handler -type sdrctl::debounce-steps
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-freq -spot} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle keyer iambic controls
##
snit::type sdrctl::control-keyer-iambic {
    # incoming opts
    option -iambic -default ad5dz -configuremethod Opt-handler -type sdrctl::iambic
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-iambic} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle rf gain controls
##
snit::type sdrctl::control-rf-gain {
    # incoming opts
    option -gain -default 0 -configuremethod Opt-handler -type sdrctl::gain
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-gain} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}
    option -command {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-balance controls
##
snit::type sdrctl::control-iq-balance {
    # incoming opts
    option -sine-phase -default 0 -configuremethod Opt-handler -type sdrctl::sine-phase
    option -linear-gain -default 1.0 -configuremethod Opt-handler -type sdrctl::linear-gain
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-sine-phase -linear-gain} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-correct controls
##
snit::type sdrctl::control-iq-correct {
    # incoming opts
    option -mu -default 0 -configuremethod Opt-handler -type sdrctl::iq-correct
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-mu} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-delay controls
##
snit::type sdrctl::control-iq-delay {
    # incoming opts
    option -delay -default 0 -configuremethod Opt-handler -type sdrctl::iq-delay
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-delay} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle iq-swap controls
##
snit::type sdrctl::control-iq-swap {
    # incoming opts
    option -swap -default 0 -configuremethod Opt-handler -type sdrctl::iq-swap
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-swap} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to {}
    option -opt-connect-from {}

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

##
## handle local oscillator controls
##
snit::type sdrctl::control-if-mix {
    # incoming opts
    option -freq -default 10000 -configuremethod Opt-handler -type sdrctl::hertz
    # required opts
    option -command -default {} -readonly true
    option -opts -default {-freq} -readonly true
    option -ports -default {} -readonly true
    option -opt-connect-to { {-freq ctl-rxtx-tuner -lo-freq} }
    option -opt-connect-from { {ctl-rxtx-tuner -lo-freq -freq} }

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

