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

package provide sdrblk::iq-correct 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

package require sdrkit::iq-correct

::snit::type ::sdrblk::iq-correct {
    component block -public block
    component correct

    option -server -default default -readonly yes
    option -partof -readonly yes
    option -correct -default 0 -validatemethod Validate -configuremethod Configure
    option -mu -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "iq-correct $self constructor $args"
	set correct {}
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
    }

    destructor {
        $block destroy
	catch {rename $correct {}}
    }

    method Validate {opt val} {
	#puts "iq-correct $self Validate $opt $val"
	switch -- $opt {
	    -partof {}
	    -correct {
		::sdrblk::validate::boolean $opt $val
	    }
	    -mu {
		::sdrblk::validate::double $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "iq-correct $self Configure $opt $val"
	switch -- $opt {
	    -partof {}
	    -correct {
		set val [::sdrblk::validate::get-boolean $val]
		if {$val != 0} {
		    if {$options($opt) == 0} {
			# create an iq-delay
			install correct using ::sdrkit::iq-correct ::iq-correct
			# connect it
			$block configure -internal ::iq-correct
		    }
		} else {
		    if {$options($opt) != 0} {
			# disconnect existing iq-correct
			$block configure -internal {}
			# delete existing iq-correct
			rename ::iq-correct {}
			# remove component??
			unset correct
		    }
		}
	    }
	    -mu {
		if {$options(-correct) != 0} {
		    $correct configure -mu $val
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
