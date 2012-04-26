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

package provide sdrctl::control 1.0.0

package require snit

package require sdrkit::jack
package require sdrctl::types

namespace eval sdrctl {}

#
# this is the control component that wraps every
# user interface, dsp computation, and control transfer
# component.
# the controller is further down below
#
snit::type sdrctl::control {
    typevariable typedata -array {
	exclude-opts {-command -opts -methods -ports -opt-connect-to -opt-connect-from}
    }

    component wrapped

    option -type -default {}  -readonly yes -type sdrctl::ctype
    option -control -default {} -readonly yes
    option -container -default {} -readonly yes

    option -root -default {} -readonly yes
    option -prefix -default {} -readonly yes
    option -suffix -default {} -readonly yes
    option -name -default {} -readonly yes

    option -server -default default -readonly yes
    option -opts -default {} -readonly yes
    option -ports -default {} -readonly yes

    option -require -default {} -readonly yes
    option -factory -default sdrctl::control-stub -readonly yes
    option -factory-options -default {} -readonly yes
    option -factory-require -default {} -readonly yes

    option -opt-connect-to -default {} -readonly yes -cgetmethod Delegate
    option -opt-connect-from -default {} -readonly yes -cgetmethod Delegate

    option -enable -default yes -configuremethod Handler
    option -activate -default yes -configuremethod Handler

    delegate option * to wrapped
    delegate method * to wrapped

    constructor {args} {
	# puts "sdrctl::controllee $self constructor {$args}"
	$self configure {*}$args
	$self Inherit -prefix -name
	$self Inherit -control -control
	set options(-name) [string trim "$options(-prefix)-$options(-suffix)" -]
	foreach pkg $options(-require) { package require $pkg }
	foreach pkg $options(-factory-require) { package require $pkg }
	switch $options(-type) {
	    ctl {
		#puts "create ctl component $options(-name)"
		install wrapped using $options(-factory) ::sdrctlx::$options(-name) {*}$options(-factory-options) -command [mymethod command]
		set options(-opts) [$self Exclude-opts [::sdrctlx::$options(-name) info options]]
		set options(-methods) [::sdrctlx::$options(-name) info methods]
		set options(-ports) {}
	    }
	    ui {
		#puts "create ui component $options(-root).$options(-name)"
		install wrapped using $options(-factory) $options(-root).$options(-name) {*}$options(-factory-options) -command [mymethod command]
		set options(-opts) [$self Exclude-opts [$options(-root).$options(-name) info options]]
		set options(-methods) [$options(-root).$options(-name) info methods]
		set options(-ports) {}
	    }
	    dsp {
		#puts "create dsp component $options(-name)"
		install wrapped using $options(-factory) ::sdrctlx::$options(-name) {*}$options(-factory-options)
		::sdrctlx::$options(-name) deactivate
		set options(-enable) false
		set options(-activate) false
		set options(-opts) [$self Exclude-opts [::sdrctlx::$options(-name) info options]]
		set options(-methods) [::sdrctlx::$options(-name) info methods]
		set options(-ports) [::sdrctlx::$options(-name) info ports]
	    }
	}
	{*}$options(-control) part-add $options(-name) $self
	return $self
    }

    method resolve {} {
	#puts "$self resolve $options(-type)"
	switch $options(-type) {
	    ctl - ui {
		foreach conn [$self cget -opt-connect-to] {
		    # puts "$self opt-connect-to $conn"
		    $self opt-connect-to {*}$conn
		}
		foreach conn [$self cget -opt-connect-from] {
		    # puts "$self opt-connect-from $conn"
		    $self opt-connect-from {*}$conn
		}
	    }
	    dsp {
	    }
	}
    }

    method {command report} {opt val args} { $self report $opt $val {*}$args }
    method opt-connect-to {opt name2 opt2} { $options(-control) opt-connect $options(-name) $opt $name2 $opt2 }
    method opt-connect-from {name2 opt2 opt} { $options(-control) opt-connect $name2 $opt2 $options(-name) $opt }
    method port-connect-to {port name2 port2} { $options(-control) port-connect $options(-name) $port $name2 $port2 }
    method port-connect-from {name2 opt2 opt} { $options(-control) port-connect $name2 $opt2 $options(-name) $opt }
    method report {opt val args} { {*}$options(-control) part-report $options(-name) $opt $val {*}$args }
    
    method Inherit {opt from_opt} {
	if {$options(-container) ne {} && $options($opt) eq {}} {
	    set options($opt) [{*}$options(-container) cget -name]
	}
    }
    
    method Exclude-opts {opts} {
	set new {}
	foreach o $opts { if {$o ni $typedata(exclude-opts)} { lappend new $o } }
	return $new
    }

    method {Handler -enable} {val} {
	set options(-enable) $val
    }

    method {Handler -activate} {val} {
	set options(-activate) $val
	switch $options(-type) {
	    dsp {
		::sdrctlx::$options(-name) activate
	    }
	}
    }

    method Delegate {opt} {
	if {[catch {$wrapped cget $opt} value]} {
	    #puts "$self Delegate $opt returns $options($opt)"
	    return $options($opt)
	} else {
	    #puts "$self Delegate $opt returns $value"
	    return $value
	}
    }
}

#
# Okay, redo the controller so it handles both jack and control connections.
# We do get multiple jack inputs and outputs managed for free.
# We don't yet get the make-before-break insertion/deletion of jack components into/from
# active computation graphs.
# We don't yet get the radiobutton logic for alternates disciplines: at-most-one, zero-or-more,
# exactly-one, one-or-more, etc.
# We don't yet get the tap points in the dsp chain because they need to supply dummy ports.
#

snit::type sdrctl::controller {
    option -partof -readonly yes
    option -server -readonly yes

    variable data -array {}
    
    constructor {args} {
	set data(part) [dict create]
	set data(opt) [dict create]
	set data(invert-opt) [dict create]
	set data(port) [dict create]
	set data(invert-port) [dict create]
	$self configure {*}$args
    }

    ## part methods
    ## parts are components in the computation which supply
    ## opts and ports that can be wired up
    method part-exists {name} { return [$self X-exists part $name] }
    method part-get {name} { return [$self X-get part $name] }
    method part-add {name command} {
	$self X-add part $name
	dict set data(part) $name $command
	foreach opt [$self part-opts $name] { $self opt-add $name $opt }
	foreach port [$self part-ports $name] { $self port-add $name $port }
    }
    method part-remove {name} {
	if { ! [$self exists part $name]} { error "part \"$name\" does not exist" }
	foreach opt [$self opt filter $name *] { $self remove opt $name $opt }
	foreach port [$self port filter $name *] { $self remove port $name $port }
	dict unset data(parts) $name
    }
    method part-list {} { return [$self X-list part] }
    method part-filter {glob} { return [$self X-filter part $glob] }

    method part-configure {name args} { return [{*}[dict get $data(part) $name] configure {*}$args] }
    method part-cget {name opt} { return [{*}[dict get $data(part) $name] cget $opt] }

    method part-container {name} { return [$self part-cget $name -container] }
    method part-opts {name} { return [$self part-cget $name -opts] }
    method part-ports {name} { return [$self part-cget $name -ports] }
    method part-type {name} { return [$self part-cget $name -type] }
    method part-is-enabled {name} { return [$self part-cget $name -enable] }
    method part-is-active {name} { return [$self part-cget $name -activate] }

    ## now the tricky stuff
    ## note that activate and deactivate need to work when starting and stopping whole subtrees
    ## and also when enabling or disabling a single component inside an active subtree
    method part-enable {name} {
	if {[$self part-is-enabled $name]} { error "part \"$name\" is enabled" }
	$self part-configure $name -enable true
	if {[$self part-is-active [$self part-container $name]]} {
	    $self part-activate $name
	}
    }
    method part-disable {name} { $self part-configure $name -enable false }

    method port-active-connections-to {pair} {
	# chase each connections-to chain starting from port until you find an active component
	set active {}
	foreach source [$self port-connections-to $pair] {
	    lassign $source part port
	    if {[$self part-is-active $part]} {
		lappend active $source
	    } else {
		lappend active {*}[$self port-active-connections-to $source]
	    }
	}
	return $active
    }
    method port-active-connections-from {port} {
	# chase each connections-from chain starting from port until you find an active component
	set active {}
	foreach sink [$self port-connections-from $pair] {
	    lassign $sink part port
	    if {[$self part-is-active $part]} {
		lappend active $sink
	    } else {
		lappend active {*}[$self port-active-connections-from $sink]
	    }
	}
	return $active
    }

    method part-activate {name} {
	if {[$self part-is-active $name]} { error "part \"$name\" is active" }
	if {[$self part-is-enabled $name]} {
	    set activated {}
	    $self part-configure $name -activate true
	    lappend activated $name
	    foreach part [$self part-filter $name-*] {
		if {[$self part-is-enabled $part]} {
		    $self part-configure $part -activate true
		    lappend activated $part
		}
	    }
	    # now make the active connections
	    foreach part $activated {
		foreach port [$self part-ports $part] {
		    set pair [list $part $port]
		    set jackport [join $port :]
		    foreach sink [$self port-active-connections-from $pair] {
			sdrkit::jack -server $options(-server) connect $jackport [join $sink :]
		    }
		    foreach source [$self port-active-connections-to $pair] {
			sdrkit::jack -server $options(-server) connect [join $source :] $jackport
		    }
		}
	    }
	}
    }
    method part-deactivate {name} {
	if {[$self part-is-active $name]} {
	    set deactivated {}
	    $self part-configure $name -activate false
	    foreach part [$self part-filter $name-*] {
		if {[$self part-is-active $part]} {
		    $self part-configure $part -activate false
		}
	    }
	}
    }

    method part-report {name opt value args} {
	foreach pair [$self opt-connections-from $name $opt] {
	    $self part-configure {*}$pair $value {*}$args
	}
    }

    method part-resolve {} {
	foreach part [$self part-list] {
	    {*}[$self part-get $part] resolve
	}
    }

    ## opt methods
    ## opts are "configure options" in the tcl/tk sense which the components
    ## expose for connection to opts of other components
    method opt-exists {name opt} { return [$self X-exists opt [list $name $opt]] }
    method opt-connected {name1 opt1 name2 opt2} { return [$self X-connected opt [list $name1 $opt1] [list $name2 $opt2]] }
    method opt-add {name opt} { $self X-add opt [list $name $opt] }
    method opt-remove {name opt} { $self X-remove opt [list $name $opt]} 
    method opt-connect {name1 opt1 name2 opt2} { $self X-connect opt [list $name1 $opt1] [list $name2 $opt2] }
    method opt-disconnect {name1 opt1 name2 opt2} { $self X-disconnect opt [list $name1 $opt1] [list $name2 $opt2] }
    method opt-list {} { return [$self X-list opt] }
    method opt-filter {glob} { return [$self X-filter opt $glob] }
    method opt-connections-to {name opt} { return [$self X-connections-to opt [list $name $opt]] }
    method opt-connections-from {name opt} { return [$self X-connections-from opt [list $name $opt]] }

    ## port methods
    ## ports are jack ports, both audio and midi, which the components
    ## expose for connection to ports of other components
    method port-exists {name port} { return [$self X-exists port [list $name $port]] }
    method port-connected {name1 port1 name2 port2} { return [$self X-connected port [list $name1 $port1] [list $name2 $port2]] }
    method port-add {name port} { $self X-add port [list $name $port] }
    method port-remove {name port} { $self X-remove port [list $name $port] }
    method port-connect {name1 port1 name2 port2} { $self X-connect port [list $name1 $port1] [list $name2 $port2] }
    method port-disconnect {name1 port1 name2 port2} { $self X-disconnect port [list $name1 $port1] [list $name2 $port2] }
    method port-list {} { return [$self X-list port] }
    method port-filter {glob} { return [$self X-filter port $glob] }
    method port-connections-to {name port} { return [$self X-connections-to port [list $name $port]] }
    method port-connections-from {name port} { return [$self X-connections-from port [list $name $port]] }

    ## X methods to handle common patterns
    ## tag may be a simple part name, or a part name opt name pair, or part name port name pair 
    ## pair will always be a part name opt name pair, or part name port name pair 
    ##
    method X-exists {x tag} { return [dict exists $data($x) $tag] }
    method X-get {x tag} { return [dict get $data($x) $tag] }
    method X-add {x tag} {
	if {[dict exists $data($x) $tag]} { error "$x \"$tag\" exists" }
	dict set data($x) $tag {}
	if {$x in {opt port}} { dict set data(invert-$x) $tag {} }
    }
    method X-remove {x tag} {
	if { ! [dict exists $data($x) $tag]} { error "$x \"$tag\" does not exist" }
	if {$x in {opt port}} {
	    # remove the connections
	    foreach tag2 [dict get $data($x) $tag] { $self X-disconnect $x $tag $tag2 }
	}
	# remove the tag
	dict unset data($x) $tag
    }
    method X-list {x} { return [dict keys $data($x)] }
    method X-filter {x glob} { return [dict keys $data($x) $glob] }
    method X-connected {x pair1 pair2} { return [expr {[lsearch -exact [dict get $data($x) $pair1] $pair2] >= 0}] }
    method X-connect {x pair1 pair2} {
	if { ! [dict exists $data($x) $pair1]} { error "$x \"$pair1\" does not exist" }
	if { ! [dict exists $data($x) $pair2]} { error "$x \"$pair2\" does not exist" }
	if {[$self X-connected $x $pair1 $pair2]} { error "${x}s \"$pair1\" \"$pair2\" are connected" }
	dict lappend data($x) $pair1 $pair2
	dict lappend data(invert-$x) $pair2 $pair1
    }
    method X-disconnect {x pair1 pair2} {
	if { ! [dict exists $data($x) $pair1]} { error "$x \"$pair1\" does not exist" }
	if { ! [dict exists $data($x) $pair2]} { error "$x \"$pair2\" does not exist" }
	if { ! [$self X-connected $x $pair1 $pair2]} { error "${x}s \"$pair1\" \"$pair2\" are not connected" }
	set list [dict get $data($x) $pair1]
	set i [lsearch -exact $list $pair2]
	dict set data($x) $pair1 [lreplace $list $i $i]
	set list [dict get $data(invert-$x) $pair2]
	set i [lsearch -exact $list $pair1]
	dict set data(invert-$x) $pair2 [lreplace $list $i $i]
    }
    method X-connections-from {x pair} { return [$self X-get $x $pair] }
    method X-connections-to {x pair} { return [$self X-get invert-$x $pair] }

}


