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

package provide sdrblk::block-control 1.0.0

package require snit

namespace eval ::sdrblk {}

::snit::type ::sdrblk::block-control {

    typevariable verbose -array {construct 0 destroy 0 control 1 controlget 1 controls 1}

    option -partof -readonly yes
    option -control -readonly yes
    option -name -readonly yes

    constructor {args} {
	if {$verbose(construct)} { puts "block-control $self constructor $args" }
        $self configure {*}$args
	$options(-control) add $options(-name) $options(-partof)
    }

    destructor {
	if {$verbose(destroy)} { puts "block-control $self destructor" }
	$options(-control) remove $options(-name)
    }

    method controls {} {
	if {$verbose(controls)} { puts "$options(-name) $self controls" }
	return [::sdrblk::$options(-name) configure]
    }

    method control {args} {
	if {$verbose(control)} { puts "$options(-name) $self control $args" }
	::sdrblk::$options(-name) configure {*}$args
    }

    method controlget {opt} {
	if {$verbose(controlget)} { puts "$options(-name) $self control $opt" }
	return [::sdrblk::$options(-name) cget $opt]
    }

}
