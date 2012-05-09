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

##
## common ui behaviors as type methods
##
package provide sdrui::common 1.0.0

namespace eval ::sdrui {}
namespace eval ::sdrui::common {}

##
## merge default values for configuration options
## if they aren't already specified
## should probably just put them in front
##
proc sdrui::common::merge {opts args} {
    foreach {opt val} $args {
	set i [lsearch -exact $opts $opt]
	if {$i < 0 || ($i&1) != 0} { lappend opts $opt $val }
    }
    return $opts
}

##
## construct a ctl- tag to connect to for this window and option, or
## construct a ctl- tag to connect from for this window and option
##
proc sdrui::common::connect {tofrom w opts} {
    regexp {^.*ui-(.*)$} $w all tail
    set connect {}
    foreach opt $opts {
	if {$tofrom eq {to}} {
	    lappend connect [list $opt ctl-$tail $opt]
	} else {
	    lappend connect [list ctl-$tail $opt $opt]
	}
    }
    return $connect
}


proc sdrui::common::trap {cmd} {
    if {[catch {uplevel $cmd} error]} {
	puts "trap {$cmd} caught:\n$error\n$::errorInfo"
	exit 1
    }
}
