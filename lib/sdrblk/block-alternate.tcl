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

package provide sdrblk::block-alternate 1.0.0

package require snit
package require sdrblk::block-core

#
# this type implements alternate components
# it is given an array list of alternate names
# and alternate components
# and the suffix for the name construction
#
snit::type sdrblk::block-alternate {

    typevariable verbose -array {connect 0 construct 0 destroy 0 configure 0 control 0 controlget 0 enable 1}

    component core
    delegate method * to core
    delegate option * to core

    variable alternates {}

    constructor {args} {
	if {$verbose(construct)} { puts "block-alternate $self constructor $args" }
	install core using sdrblk::block-core %AUTO% -type alternate -coreof $self {*}$args

	sdrblk::comp-stub ::sdrblk::[$core cget -name]
	foreach element [$core cget -alternates] {
	    package require $element
	    lappend alternates [$element %AUTO% -partof $self]
	}

	if {[$core cget -outport] ne {}} {
	    $core configure -sink [$self cget -outport]
	}
	if {[$core cget -inport] ne {}} {
	    $core configure -source [$self cget -inport]
	}
    }

    destructor {
	catch {$core destroy}
	catch {
	    foreach element $alternates {
		catch {$element destroy}
	    }
	}
    }

}
