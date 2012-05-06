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

package provide sdrui::ui-vfo 1.0.0

package require Tk
package require snit

package require sdrui::vfo

snit::type sdrui::ui-vfo {

    option -container -readonly yes
    option -control -readonly yes
    option -name {}
    option -root {}
    
    constructor {args} {
	$self configure {*}$args
	pack [ttk::frame .vfo] -fill both -expand true
	set options(-control) [$options(-container) cget -control]
	sdrctl::control ::sdrctlw::ui-rxtx-tuner -suffix ui-rxtx-tuner -factory sdrui::vfo \
	    -type ui -root .vfo -control $options(-control) -container $options(-container)
	pack .vfo.ui-rxtx-tuner -fill both -expand true
    }

    method repl {} { }

}
