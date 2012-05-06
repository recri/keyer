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

package provide sdrctl::control-notify 1.0.0

package require snit

package require sdrtype::types

##
## post activate/deactivate/enable/disable and option changes
##
snit::type sdrctl::control-notify {
    option -command {}

    variable data -array {
	after {}
	period 100
    }

    option -any-activate -default {}
    option -any-deactivate -default {}
    option -any-enable -default {}
    option -any-disable -default {}
    option -any-option -default {}

    constructor {args} {
	$self configure {*}$args
	[{*}$options(-command) cget -control] configure -notifier [mymethod Notify]
	set data(after) [after $data(period) [mymethod Post]]
    }

    destructor {
	catch {after cancel $data(after)}
    }

    method Notify {name args} {
	# puts "control-notify notify $name $args"
	foreach {opt val} $args {
	    switch -- $opt {
		-activate { if {$val} { incr data(-any-activate) } else { incr data(-any-deactivate) } }
		-enable { if {$val} { incr data(-any-enable) } else { incr data(-any-disable) } }
		default { incr data(-any-option) }
	    }
	}
    }

    method Post {} {
	foreach {opt val} [array get data -*] {
	    set data($opt) 0
	    if {$val} {
		if {[catch {
		    {*}$options(-command) report $opt $val
		} error]} {
		    puts "error posting $opt $val: $error"
		}
	    }
	}
	set data(after) [after $data(period) [mymethod Post]]
    }
		
}

