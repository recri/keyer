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

package provide sdrblk::bandpass 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

package require sdrkit::filter-overlap-save

::snit::type ::sdrblk::bandpass {
    component block -public block
    component bandpass 

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -name -default ::bandpass -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -center -default 800 -validatemethod Validate -configuremethod Configure
    option -width -default 200 -validatemethod Validate -configuremethod Configure
    option -length -default 1024 -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "bandpass $self constructor $args"
        $self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
	install bandpass using sdrkit::filter-overlap-save $options(-name) -server $options(-server) \
	    -length $options(-length)
	$self configure -center $options(-center) -width $options(-width)
    }

    destructor {
        $block destroy
	catch {rename $bandpass {}}
    }

    method Validate {opt val} {
	#puts "bandpass $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -center -
	    -width {
		::sdrblk::validate::double $opt $val
	    }
	    -length {
		::sdrblk::validate::integer $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "bandpass $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof -
	    -name {}
	    -center -
	    -width {
		if {$bandpass ne {}} {
		    set options(-low) [expr {$options(-center)-$options(-width)/2.0}]
		    set options(-high) [expr {$options(-center)+$options(-width)/2.0}]
		    $bandpass configure -low $options(-low) -high $options(-high)
		}
	    }
	    -length {
		if {$bandpass ne {}} {
		    $bandpass configure $opt $val
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
