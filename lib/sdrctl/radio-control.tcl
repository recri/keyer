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

package require sdrtype::types
package require sdrctl::control

namespace eval sdrctl {}
namespace eval sdrctlw {}

##
## start the radio control components
##
## this is basically the list of all the controls needed for a radio, or at least all the controls
## that I've implemented and/or found necessary to this point.
##
proc sdrctl::radio-controls {args} {
    set root [sdrctl::control ::sdrctlw::ctl -type ctl -prefix {} -suffix ctl -factory sdrctl::control-stub {*}$args]
    foreach {suffix factory opts} {
	notify			sdrctl::control-notify {}
	rxtx			sdrctl::control-stub {}
	rx			sdrctl::control-stub {}
	rx-af			sdrctl::control-stub {}
	rx-rf			sdrctl::control-stub {}
	tx			sdrctl::control-stub {}
	tx-af			sdrctl::control-stub {}
	tx-rf			sdrctl::control-stub {}
	keyer			sdrctl::control-stub {}
	rxtx-band-select	sdrctl::control-band {}
	rxtx-if-bpf		sdrctl::control-filter {}
	rxtx-mode		sdrctl::control-mode {}
	rxtx-mox		sdrctl::control-rxtx {}
	rxtx-tuner		sdrctl::control-tune {}
	rx-af-agc		sdrctl::control-agc {}
	rx-af-gain		sdrctl::control-af-gain {}
	rx-if-mix		sdrctl::control-if-mix {}
	rx-rf-gain		sdrctl::control-rf-gain {}
	rx-rf-iq-correct	sdrctl::control-iq-correct {}
	rx-rf-iq-delay		sdrctl::control-iq-delay {}
	rx-rf-iq-swap		sdrctl::control-iq-swap {}
	tx-af-gain		sdrctl::control-af-gain {}
	tx-af-leveler		sdrctl::control-leveler {}
	tx-if-mix		sdrctl::control-if-mix {}
	tx-rf-gain		sdrctl::control-rf-gain {}
	tx-rf-iq-balance	sdrctl::control-iq-balance {}
	keyer-debounce		sdrctl::control-keyer-debounce {}
	keyer-iambic		sdrctl::control-keyer-iambic {}
	keyer-iambic-wpm	sdrctl::control-keyer-iambic-wpm {}
	keyer-iambic-dah	sdrctl::control-keyer-iambic-dah {}
	keyer-iambic-space	sdrctl::control-keyer-iambic-space {}
	keyer-tone		sdrctl::control-keyer-tone {}
    } {
	package require $factory
	sdrctl::control ::sdrctlw::$suffix -type ctl -suffix $suffix -factory $factory -factory-options $opts -container $root
    }
}

