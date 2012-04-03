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

package provide sdrblk::radio-ui 1.0.0

package require snit

::snit::type sdrblk::radio-ui {
    component impl

    option -partof -readonly yes
    option -control -readonly yes -default {} -cgetmethod Cget

    option -type -readonly yes

    delegate method repl to impl

    constructor {args} {
	$self configure {*}$args
	package require sdrblk::radio-ui-$options(-type)
	install impl using sdrblk::radio-ui-$options(-type) %AUTO% -partof $self
    }

    destructor {
	catch {$impl destroy}
    }

    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
}
