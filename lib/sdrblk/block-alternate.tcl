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

package require sdrblk::block-graph
package require sdrblk::validate

#
# this type implements the controller for the alternate component block
#
::snit::type sdrblk::block-alternate-controller {
    option -alternates -readonly true
    option -alternate
}

#
# this type implements alternate components
# it is given an array list of alternate names
# and alternate components
# and the suffix for the name construction
#
::snit::type sdrblk::block-alternate {

    typevariable verbose -array {connect 0 construct 0 destroy 0 validate 0 configure 0 control 0 controlget 0 enable 1}

    component graph -public graph
    component control

    delegate method control to control
    delegate method controls to control
    delegate method controlget to control

    variable alternates -array {}
    variable selected {}

    option -partof -readonly yes
    option -server -readonly yes
    option -control -readonly yes
    option -prefix -readonly yes
    option -suffix -readonly yes
    option -name -readonly yes

    option -alternates -readonly yes

    option -inport -readonly yes
    option -outport -readonly yes

    option -implemented -readonly yes -default yes

    option -enable -default no -configuremethod Enable

    delegate option -type to graph

    constructor {args} {
	if {$verbose(construct)} { puts "block-alternate $self constructor $args" }
	$self configure {*}$args
	set options(-prefix) [$options(-partof) cget -name]
	set options(-server) [$options(-partof) cget -server]
	set options(-control) [$options(-partof) cget -control]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	install graph using ::sdrblk::block-graph %AUTO% -partof $self -type alternate
	install control using ::sdrblk::block-control %AUTO% -partof $self -name $options(-name) -control $options(-control)

	foreach {name element} $options(-alternates) {
	    package require $element
	    set alternates($name) [$element %AUTO% -partof $self]
	}
	set selected [lindex $options(-alternates) 0]

	foreach {name element} [array get alternates] {
	    $self graph addalternate $name $element
	}
	$self graph configure -alternate $selected

	if {$options(-outport) ne {}} {
	    $graph configure -sink $options(-outport)
	}
	if {$options(-inport) ne {}} {
	    $graph configure -source $options(-inport)
	}
	return $self
    }

    destructor {
	catch {$graph destroy}
	catch {
	    foreach name [array names alternate] {
		catch {$alternates($name) destroy}
	    }
	}
    }

    method Enable {opt val} {
	if { ! $options(-implemented)} {
	    error "$options(-name) cannot be enabled"
	}
	if {$val && ! $options($opt)} {
	    if {$verbose(enable)} { puts "enabling $options(-name)" }
	    ::sdrblk::block-alternate-controller ::sdrblk::$options(-name) -alternates [array names alternates] -alternate $selected
	} elseif { ! $val && $options($opt)} {
	    if {$verbose(enable)} { puts "disabling $options(-name)" }
	    rename ::sdrblk::$options(-name) {}
	}
	set options($opt) $val
    }

}
