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

package provide sdrblk::block-stub 1.0.0

package require snit
package require sdrblk::block-core

#
# a snit type for spectrum and meter tap points
#
snit::type sdrblk::block-stub {

    typevariable verbose -array {connect 0 construct 0 destroy 0 configure 0 control 0 controlget 0 enable 0}

    component core

    delegate method * to core
    delegate option * to core

    constructor {args} {
	install core using ::sdrblk::block-core %AUTO% -coreof $self -enablemethod [mymethod enable] {*}$args 
    }

    destructor {
	if {$verbose(destroy)} { puts "$self destructor" }
	catch {rename ::sdrblk::[$core cget -name] {}}
	catch {$core destroy}
    }

    method enable {opt val} {
	set name [$core cget -name]
	if { ! [[$core cget -partof] cget -enable]} {
	    error "parent of $name is not enabled"
	}
	if {$val && ! [$core cget $opt]} {
	    if {$verbose(enable)} { puts "enabling $name" }
	    sdrblk::comp-stub ::sdrblk::$name
	} elseif { ! $val && [$core cget $opt]} {
	    if {$verbose(enable)} { puts "disabling $name" }
	    rename ::sdrblk::$name {}
	}
    }
}
