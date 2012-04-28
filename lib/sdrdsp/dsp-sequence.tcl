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

package provide sdrdsp::dsp-sequence 1.0.0

package require snit
package require sdrdsp::dsp-ports

snit::type sdrdsp::dsp-sequence {
    component ports

    option -ports -default {seq_in_i seq_in_q seq_out_i seq_out_q}
    option -opts -default {}
    option -methods -default {}

    option -container -default {} -readonly true
    option -control -default {} -readonly true
    option -require -default {} -readonly true
    option -name -default {} -readonly true
    
    option -sequence -default {} -readonly true

    variable data -array {}

    constructor {args} {
	# puts "dsp-sequence constructor $self {$args}"
	$self configure {*}$args
	set options(-control) [$options(-container) cget -control]
	set options(-name) [$options(-container) cget -name]
	install ports using sdrdsp::dsp-ports %AUTO% -control $options(-control)
    }

    destructor { $self sequence destructor }
    method finish {} { $self sequence constructor }

    method {sequence constructor} {} {
	# build the components of the sequence
	foreach package $options(-require) {
	    package require $package
	}
	foreach element $options(-sequence) {
	    lappend data(sequence) [$element %AUTO% -container $options(-container)]
	}
	# connect the components of the sequence
	foreach element [lrange $data(sequence) 0 end-1] next [lrange $data(sequence) 1 end] {
	    # puts "$ports connect [$ports outputs $element] [$ports inputs $next]"
	    $ports connect [$ports outputs $element] [$ports inputs $next]
	}
	set first [lindex $data(sequence) 0]
	set last [lindex $data(sequence) end]
	$ports connect [$ports inputs $options(-container)] [$ports inputs $first]
	$ports connect [$ports outputs $last] [$ports outputs $options(-container)]
    }
    
    method {sequence destructor} {} {
	catch {$ports destroy}
	catch {
	    foreach element $data(sequence) {
		catch {$element destroy}
	    }
	}
    }

    method deactivate {} {}
    method activate {} {}

}

