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

package provide sdrblk::lo-mixer 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

package require sdrkit::lo-mixer 

::snit::type ::sdrblk::lo-mixer {
    component block -public block
    component mixer 

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -name -default ::lo-mixer -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -freq -default 10000 -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "lo-mixer $self constructor $args"
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
	# FIX.ME -- mixer should go away if -freq is 0.0
	install mixer using ::sdrkit::lo-mixer $options(-name) -server $options(-server) -freq $options(-freq)
    }

    destructor {
        $block destroy
	catch {rename $mixer {}}
    }

    method Validate {opt val} {
	#puts "lo-mixer $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -freq {
		::sdrblk::validate::double $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "lo-mixer $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -freq {
		if {$mixer ne {}} {
		    $mixer configure -freq $val
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
