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

package provide sdrblk::rx 1.0.0

package require snit

package require sdrblk::rx-rf
package require sdrblk::rx-if
package require sdrblk::rx-af

::snit::type sdrblk::rx {
    component block -public block
    component rxrf
    component rxif
    component rxaf

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -inport -readonly yes -validatemethod Validate -configuremethod Configure
    option -outport -readonly yes -validatemethod Validate -configuremethod Configure
    
    constructor {args} {
	puts "rx $self constructor $args"
	$self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
	install rxrf using ::sdrblk::rx-rf %AUTO% -partof $self -server $options(-server)
	install rxif using ::sdrblk::rx-if %AUTO% -partof $self -server $options(-server)
	install rxaf using ::sdrblk::rx-af %AUTO% -partof $self -server $options(-server)
	$rxrf block configure -output $rxif
	$rxif block configure -input $rxrf -output $rxaf
	$rxaf block configure -input $rxaf
	$block configure -inport $options(-inport) -outport $options(-outport)
    }

    destructor {
	catch {$block destroy}
	catch {$rxrf destroy}
	catch {$rxif destroy}
	catch {$rxaf destroy}
    }

    method Validate {opt val} {
	#puts "rx $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -inport -
	    -outport {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "rx $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -inport -
	    -outport {}
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
