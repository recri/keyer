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

package provide sdrblk::gain 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

package require sdrkit::gain

::snit::type ::sdrblk::gain {
    component block -public block
    component gain

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -name -default ::gain -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -gain -default 0 -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "gain $self constructor $args"
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
    }

    destructor {
        $block destroy
	catch {rename $gain {}}
    }

    method Validate {opt val} {
	#puts "gain $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -gain {
		::sdrblk::validate::decibel $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "gain $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -gain {
		if {$val != 0} {
		    if {$options($opt) != 0} {
			# reconfigure existing gain
			$gain configure -gain $val
		    } else {
			# create a gain module
			install gain using ::sdrkit::gain $options(-name) -server $options(-server) -gain $val
			# connect it
			$block configure -internal $gain
		    }
		} else {
		    if {$options($opt) != 0} {
			# disconnect existing gain
			$block configure -internal {}
			# delete existing gain
			rename $gain {}
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
