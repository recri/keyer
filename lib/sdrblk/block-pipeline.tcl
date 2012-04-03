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

package provide sdrblk::block-pipeline 1.0.0

package require snit

package require sdrblk::block
package require sdrblk::validate

#
# this type implements a simple pipeline of components
# it needs to be given the list of components to implement
# and the suffix for the name construction
#
::snit::type sdrblk::block-pipeline {

    typevariable verbose -array {connect 0 construct 0 destroy 0 validate 0 configure 0 control 0 controlget 0 enable 0}

    component block -public block

    variable pipeline {}

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}
    option -suffix -readonly yes
    option -pipeline -readonly yes

    option -inport -readonly yes
    option -outport -readonly yes

    constructor {args} {
	puts "block-pipeline $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	foreach element $options(-pipeline) {
	    package require $element
	    lappend pipeline [$element %AUTO% -partof $self]
	}
	catch {unset last}
	foreach element $pipeline next [lrange $pipeline 1 end] {
	    if {[info exists last] && $next ne {}} {
		$element block configure -input $last -output $next
	    } elseif {$next ne {}} {
		$element block configure -output $next
	    } else {
		$element block configure -input $last
	    }
	    set last $element
	}
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
	    foreach element $pipeline {
		catch {$element destroy}
	    }
	}
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
