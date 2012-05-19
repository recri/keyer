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

#
# there should one sdrkit::control in an application
# containing one or more sdrkit::component.
# the control allows components to register their presence,
# their dsp sample stream connectivity, and their interest in
# or ability to supply values for options.
#
#
package provide sdrkit::control 1.0.0

package require Tk
package require snit
package require sdrkit::comm

namespace eval sdrkit {}

snit::type sdrkit::control {

    variable d [dict create]

    constructor {args} {
	#$self configure {*}$args
    }
    method get-controller {} { return [sdrkit::comm::wrap $self] }
    method name-exists {name} { return [dict exists $d $name] }
    method name-get-key {name key} { return [dict get $d $name $key] }
    method name-set-key {name key value} { dict set d $name $key $value }
    method name-call {name args} { return [sdrkit::comm::send [$self name-command $name] {*}$args] }
    method name-register {name args} {
	if {[$self name-exists $name]} { error "name \"$name\" exists" }
	dict set d $name [dict create command $args]
    }
    method name-unregister {name} {
	if { ! [$self name-exists $name]} { error "name \"$name\" does not exist" }
	dict unset d $name
    }
    method name-declare-in-ports {name args} { $self name-set-key $name in-ports $args }
    method name-declare-out-ports {name args} { $self name-set-key  $name out-ports $args }
    method name-declare-in-options {name args} { $self name-set-key  $name in-options $args }
    method name-declare-out-options {name args} { $self name-set-key $name out-options $args }
    method name-command {name} { return [$self name-get-key $name command] }
    method name-configure {name args} { return [$self name-call $name configure {*}$args] }
    method name-cget {name opt} { return [$self name-call $name cget $opt] }
    method name-in-ports {name} { return [$self name-get-key $name in-ports] }
    method name-out-ports {name} { return [$self name-get-key $name out-ports] }
    method name-in-options {name} { return [$self name-get-key $name in-options] }
    method name-out-options {name} { return [$self name-get-key $name out-options] }
    method name-connect-ports {name ports name2 ports2} {
	puts "name-connect-ports $name {$ports} $name2 {$ports2}"
    }
    method name-connect-options {name options name2 options2} {
	puts "name-connect-options $name {$options} $name2 {$options2}"
    }
    method name-is-enabled {name} { return [$self name-get-key enable] }
    method name-enable {name val} {
	$self name-set-key $name enable $val
	$self name-call $name enable $val
    }
    method name-is-activated {name} { return [$self name-get-key activate] }
    method name-activate {name} {
	$self name-set-key $name activate $val
	$self name-call $name activate $val
    }
    method name-report {name args} {
	puts "name-report $name $args"
    }
}

