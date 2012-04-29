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

package provide sdrctl::control-tune 1.0.0

package require snit

package require sdrctl::types

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

