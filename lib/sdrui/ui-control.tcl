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

package provide sdrui::ui-control 1.0.0

package require Tk
package require snit
package require tkcon

package require sdrui::tree
package require sdrui::connections

# a notebook of control tree displays

snit::type sdrui::ui-control {

    option -container -readonly yes
    option -control -readonly yes
    option -server -readonly yes
    
    constructor {args} {
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	pack [ttk::notebook .nb] -side top -fill both -expand true
	.nb add [sdrui::connections .nb.ports -container $self -connect ports] -text ports
	.nb add [sdrui::connections .nb.opts -container $self -connect opts] -text opts
	.nb add [sdrui::tree .nb.tree -container $self] -text controls
    }

    method repl {} { }

}
