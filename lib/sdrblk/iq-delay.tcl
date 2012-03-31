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

package provide sdrblk::iq-delay 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

package require sdrkit::iq-delay

::snit::type ::sdrblk::iq-delay {
    component block -public block
    component delay

    option -server -default default -readonly yes
    option -partof -readonly yes
    option -delay -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "iq-delay $self constructor $args"
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
    }

    destructor {
        $block destroy
	catch {rename $delay {}}
    }

    method Validate {opt val} {
	#puts "iq-delay $self Validate $opt $val"
	switch -- $opt {
	    -partof {}
	    -delay {
		::sdrblk::validate::integer $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "iq-delay $self Configure $opt $val"
	switch -- $opt {
	    -partof {}
	    -delay {
		if {$val != 0} {
		    if {$options($opt) != 0} {
			# reconfigure existing iq-delay
			$delay configure -delay $val
		    } else {
			# create an iq-delay
			install delay using ::sdrkit::iq-delay ::iq-delay -delay $val
			# connect it
			$block configure -internal ::iq-delay
		    }
		} else {
		    if {$options($opt) != 0} {
			# disconnect existing iq-delay
			$block configure -internal {}
			# delete existing iq-delay
			rename ::iq-delay {}
		    } else {
			# already have no delay
			# nothing to do
		    }
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
