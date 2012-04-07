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

package require sdrblk::block-graph
package require sdrblk::block-control
package require sdrblk::stub

#
# this type implements a simple pipeline of components
# it needs to be given the list of components to implement
# and the suffix for the name construction
#
::snit::type sdrblk::block-pipeline {

    typevariable verbose -array {connect 0 construct 0 destroy 0 validate 0 configure 0 control 0 controlget 0 enable 0}

    component graph -public graph
    component control

    delegate method control to control
    delegate method controls to control
    delegate method controlget to control

    variable pipeline {}

    option -partof -readonly yes
    option -server -readonly yes
    option -control -readonly yes
    option -prefix -readonly yes
    option -suffix -readonly yes
    option -name -readonly yes

    option -pipeline -readonly yes

    option -inport -readonly yes
    option -outport -readonly yes

    option -implemented -readonly yes -default yes

    option -enable -default no -configuremethod Enable

    delegate option -type to graph

    constructor {args} {
	if {$verbose(construct)} { puts "block-pipeline $self constructor $args" }
	$self configure {*}$args
	set options(-prefix) [$options(-partof) cget -name]
	set options(-server) [$options(-partof) cget -server]
	set options(-control) [$options(-partof) cget -control]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	install graph using ::sdrblk::block-graph %AUTO% -partof $self -type pipeline
	install control using ::sdrblk::block-control %AUTO% -partof $self -name $options(-name) -control $options(-control)

	foreach element $options(-pipeline) {
	    package require $element
	    lappend pipeline [$element %AUTO% -partof $self]
	}

	catch {unset last}
	foreach element $pipeline next [lrange $pipeline 1 end] {
	    if {[info exists last] && $next ne {}} {
		$element graph configure -input $last -output $next
	    } elseif {$next ne {}} {
		$element graph configure -output $next
	    } elseif {[info exists last]} {
		$element graph configure -input $last
	    }
	    set last $element
	}

	if {$options(-outport) ne {}} {
	    $self graph configure -sink $options(-outport)
	}
	if {$options(-inport) ne {}} {
	    $self graph configure -source $options(-inport)
	}
	return $self
    }

    destructor {
	catch {$control destroy}
	catch {$graph destroy}
	catch {
	    foreach element $pipeline {
		catch {$element destroy}
	    }
	}
    }

    method Enable {opt val} {
	if { ! $options(-implemented)} {
	    error "$options(-name) cannot be enabled"
	}
	if {$val && ! $options($opt)} {
	    if {$verbose(enable)} { puts "enabling $options(-name)" }
	    sdrblk::stub ::sdrblk::$options(-name)
	} elseif { ! $val && $options($opt)} {
	    if {$verbose(enable)} { puts "disabling $options(-name)" }
	    rename ::sdrblk::$options(-name) {}
	}
	set options($opt) $val
    }

}
