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

package provide sdrblk::radio-hw-softrock-dg8saq 1.0.0

package require snit

::snit::type sdrblk::radio-hw-softrock-dg8saq {
    component impl

    option -partof -readonly yes
    option -control -readonly yes -default {} -cgetmethod Cget
    
    constructor {args} {
	puts "radio-hw-softrock-dg8saq $self constructor $args"
	$self configure {*}$args
	[$self cget -control] add hw $self
    }

    destructor {
	catch {$impl destroy}
    }

    method controls {} {
	return { -freq {frequency to tune in MHz} }
    }

    method control {opt val} {
	exec usbsoftrock set freq $val
    }

    method controlget {opt} {
	return [exec usbsoftrock getfreq | tail -1]
    }

    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
    
}
