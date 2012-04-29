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

package provide sdrctl::control-band 1.0.0

package require snit
package require sdrctl::types
package require sdrutil::band-data

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
    option -label -configuremethod Opt-handler
    option -low -configuremethod Opt-handler
    option -high -configuremethod Opt-handler
    option -mode -default CWU -type sdrctl::mode -configuremethod Opt-handler
    option -filter-width -configuremethod Opt-handler
    option -freq -configuremethod Opt-handler

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

