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

package provide sdrdsp::dsp-alternates 1.0.0

package require snit
package require sdrdsp::dsp-ports

snit::type sdrdsp::dsp-alternates {
    component ports

    option -ports -default {alt_in_i alt_in_q alt_out_i alt_out_q}
    option -opts -default {-select} -configuremethod Select
    option -methods -default {}

    option -container -default {} -readonly true
    option -control -default {} -readonly true
    option -require -default {} -readonly true
    
    option -name {}
    option -alternates -default {} -readonly true
    option -map -default {} -readonly true
    option -signal -default {}
    option -opt-connect-from -default {} -readonly true
    option -select -default {}

    variable data -array {}

    constructor {args} {
	# puts "dsp-alternates constructor $self {$args}"
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	set options(-name) [$options(-container) cget -name]
	install ports using sdrdsp::dsp-ports %AUTO% -control $options(-control)
    }

    destructor { $self alternates destructor }
    method finish {} { $self alternates constructor }

    method {alternates constructor} {} {
	# build the components of the sequence
	foreach package $options(-require) {
	    package require $package
	}
	foreach element $options(-alternates) {
	    set element [$element %AUTO% -container $options(-container)]
	    lappend data(alternates) $element
	    # connect the components of the sequence
	    $ports connect [$ports inputs $options(-container)] [$ports inputs $element]
	    $ports connect [$ports outputs $element] [$ports outputs $options(-container)]
	}
    }
    
    method {alternates destructor} {} {
	catch {
	    foreach element $data(alternates) {
		catch {$element destroy}
	    }
	}
    }

    method {Select -select} {val} {
    }
    method deactivate {} {}
    method activate {} {}
    
}

