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

package provide sdrctl::vfo-control 1.0.0

package require snit

package require sdrtype::types
package require sdrctl::control
package require sdrctl::control-stub

namespace eval sdrctl {}
namespace eval sdrctlw {}

##
## start the vfo control components
##
## this is an experiment in building just part of the radio, it's not very
## satisfactory as I end up building most of the radio.
## the problem is not knowing exactly what's needed
##
## I guess it's not clear exactly who's in charge of deciding what's needed.
##
proc sdrctl::vfo-controller {name args} {
    return [sdrctl::controller $name {*}$args]
}

proc sdrctl::vfo-controls {args} {
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
	rxtx-mode sdrctl::control-mode {}
	rxtx-mox sdrctl::control-rxtx {}
	rxtx-tuner sdrctl::control-tune {}
	rx-af-agc sdrctl::control-agc {}
	rx-af-gain sdrctl::control-af-gain {}
	rx-rf-gain sdrctl::control-rf-gain {}
	rx-rf-iq-correct sdrctl::control-iq-correct {}
	rx-rf-iq-delay sdrctl::control-iq-delay {}
	rx-rf-iq-swap sdrctl::control-iq-swap {}
	rx-if-mix sdrctl::control-if-mix {}
	tx-af-gain sdrctl::control-af-gain {}
	tx-af-leveler sdrctl::control-leveler {}
	tx-if-mix sdrctl::control-if-mix {}
	tx-rf-gain sdrctl::control-rf-gain {}
	tx-rf-iq-balance sdrctl::control-iq-balance {}
	keyer-debounce sdrctl::control-keyer-debounce {}
	keyer-iambic sdrctl::control-keyer-iambic {}
	keyer-tone sdrctl::control-keyer-tone {}
    } {
	package require $factory
	sdrctl::control ::sdrctlw::$suffix -type ctl -suffix $suffix -factory $factory -factory-options $opts -container $root
    }
}
