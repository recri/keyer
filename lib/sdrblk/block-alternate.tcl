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

#
# this type implements alternate components
# it is given an array list of alternate names
# and alternate components
# and the suffix for the name construction
#
::snit::type sdrblk::block-alternate {

    typevariable verbose -array {connect 0 construct 0 destroy 0 configure 0 control 0 controlget 0 enable 1}

    component graph -public graph
    component control

    delegate method control to control
    delegate method controls to control
    delegate method controlget to control

    variable alternates {}

    option -partof -readonly yes
    option -server -readonly yes
    option -control -readonly yes
    option -prefix -readonly yes
    option -suffix -readonly yes
    option -name -readonly yes

    option -alternates -readonly yes

    option -inport -readonly yes
    option -outport -readonly yes

    option -enable -readonly yes -default yes

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
	sdrblk::stub ::sdrblk::$options(-name)

	foreach element $options(-alternates) {
	    package require $element
	    lappend alternates [$element %AUTO% -partof $self]
	}

	if {$options(-outport) ne {}} {
	    $graph configure -sink $options(-outport)
	}
	if {$options(-inport) ne {}} {
	    $graph configure -source $options(-inport)
	}
	return $self
    }

    destructor {
	catch {$control destroy}
	catch {$graph destroy}
	catch {
	    foreach element $alternates {
		catch {$element destroy}
	    }
	}
    }

}
