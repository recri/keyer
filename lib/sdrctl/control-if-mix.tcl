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

package provide sdrctl::control-if-mix 1.0.0

package require snit

package require sdrtype::types

##
## handle local oscillator controls
##
snit::type sdrctl::control-if-mix {
    option -command -default {} -readonly true
    option -opt-connect-to { {-freq ctl-rxtx-tuner -lo-freq} }
    option -opt-connect-from { {ctl-rxtx-tuner -lo-freq -freq} }
    # incoming opts
    option -freq -default 10000 -configuremethod Opt-handler -type sdrtype::hertz

    method Opt-handler {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
}

