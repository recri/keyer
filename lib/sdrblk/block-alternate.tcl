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

package require sdrblk::block
package require sdrblk::validate

#
# this type implements alternate components
# it is given an array list of alternate names
# and alternate components
# and the suffix for the name construction
#
::snit::type sdrblk::block-alternate {

    typevariable verbose -array {connect 0 construct 0 destroy 0 validate 0 configure 0 control 0 controlget 0 enable 0}

    component block -public block

    variable alternate -array {}
    variable selected

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}
    option -suffix -readonly yes

    option -alternates -readonly yes

    option -inport -readonly yes
    option -outport -readonly yes

    constructor {args} {
	puts "block-alternate $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	foreach {name element} $options(-alternates) {
	    package require $element
	    set alternate($name) [$element %AUTO% -partof $self]
	}
	set selected [lindex $options(-alternates) 0]
	[$self cget -control] add $options(-name) $self
	if {$options(-outport) ne {}} {
	    $block configure -sink $options(-outport)
	}
	if {$options(-inport) ne {}} {
	    $block configure -source $options(-inport)
	}
	return $self
    }

    destructor {
	catch {$block destroy}
	catch {
	    foreach name [array names alternate] {
		catch {$alternate($name) destroy}
	    }
	}
    }

    method controls {} { return [list -alternate [lsort [array names alternate]]]  }

    method control {opt val} {
	if {$verbose(control)} { puts "$options(-name) $self control $opt $val" }
	if {$opt ne {-alternate}} { error "\"$opt\" is not a valid option" }
	if { ! [info exists alternate($val)]} { error "\"$val\" is not a valid alternate" }
	set selected $val
	# FIX.ME - now what?
    }

    method controlget {opt} {
	if {$verbose(controlget)} { puts "$options(-name) $self control $opt $val" }
	if {$opt ne {-alternate}} { error "\"$opt\" is not a valid option" }
	return $selected
    }

    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
    
    method Prefix {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget -name]
	}
    }
}
