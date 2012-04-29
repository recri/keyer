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

package provide sdrctl::control-mode 1.0.0

package require snit

package require sdrctl::types

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

