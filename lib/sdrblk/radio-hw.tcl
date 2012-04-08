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

package provide sdrblk::radio-hw 1.0.0

package require snit

::snit::type sdrblk::radio-hw {
    typevariable verbose -array {enable 0}

    component control

    delegate method control to control
    delegate method controls to control
    delegate method controlget to control

    option -partof -readonly yes
    option -server -readonly yes
    option -control -readonly yes
    option -suffix -readonly yes -default hw
    option -enable -default no -configuremethod Enable
    option -type -readonly yes
    
    constructor {args} {
	puts "hw $self constructor $args"
	$self configure {*}$args
	set options(-prefix) [$options(-partof) cget -name]
	set options(-server) [$options(-partof) cget -server]
	set options(-control) [$options(-partof) cget -control]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	package require sdrblk::radio-hw-$options(-type)
	install control using ::sdrblk::block-control %AUTO% -partof $self -name $options(-name) -control $options(-control)
    }

    destructor {
	catch {$control destroy}
    }

    method Enable {opt val} {
	if {$val && ! $options($opt)} {
	    if {$verbose(enable)} { puts "enabling $options(-name)" }
	    sdrblk::radio-hw-$options(-type) ::sdrblk::$options(-name)
	} elseif { ! $val && $options($opt)} {
	    if {$verbose(enable)} { puts "disabling $options(-name)" }
	    rename ::sdrblk::$options(-name) {}
	}
	set options($opt) $val
    }

}
