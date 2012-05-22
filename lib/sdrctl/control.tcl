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

package require sdrtcl::jack
package require sdrtype::types

namespace eval sdrctl {}

##
## wrapper for controls defined by sdrctl, sdrui, and sdrdsp components
##
snit::type sdrctl::control {
    typevariable verbose -array {
	construct 0 inherit 0 configure 0 destroy 0 require 0
	enable 0 activate 0 connect 0 disconnect 0 make-connect 0 make-disconnect 0
	resolution 0 no-resolution 0
    }
    typevariable typedata -array {
	exclude-opts {
	    -command -opts -methods -ports -opt-connect-to -opt-connect-from
	    -server -client -verbose
	}
	exclude-methods {}
	exclude-ports {}
    }

    component wrapped

    option -type -default {}  -readonly yes -type sdrtype::type
    option -control -default {} -readonly yes
    option -container -default {} -readonly yes

    option -root -default {} -readonly yes; # used by ui components only

    option -prefix -default {} -readonly yes
    option -suffix -default {} -readonly yes
    option -name -default {} -readonly yes

    option -server -default default -readonly yes

    option -opts -default {} -readonly yes
    option -methods -default {} -readonly yes
    option -ports -default {} -readonly yes

    option -require -default {} -readonly yes
    option -factory -default sdrctl::control-stub -readonly yes
    option -factory-options -default {} -readonly yes
    option -factory-require -default {} -readonly yes

    option -opt-connect-to -default {} -readonly yes -cgetmethod Delegate
    option -opt-connect-from -default {} -readonly yes -cgetmethod Delegate

    option -enable -default yes
    option -activate -default no -configuremethod Handler

    option -low -default {} -configuremethod Handler2
    option -high -default {} -configuremethod Handler2
    
    delegate option * to wrapped
    delegate method * to wrapped

    constructor {args} {
	if {$verbose(construct)} { puts "sdrctl::control $self constructor {$args}" }
	$self configure {*}$args
	foreach {local parent} {-prefix -name -control -control -server -server} {
	    $self Inherit $local $parent
	}
	set options(-name) [string trim "$options(-prefix)-$options(-suffix)" -]
	foreach pkg $options(-require) { package require $pkg }
	foreach pkg $options(-factory-require) { package require $pkg }
	# puts "create $options(-type) component $options(-name)"
	## okay, lots of abstraction here that m
	if {$verbose(construct)} { puts "sdrctl::control $self installing [$self Wrapped name]" }
	install wrapped using $options(-factory) [$self Wrapped name] {*}$options(-factory-options) {*}[$self Wrapped extra-opts]
	if {$verbose(construct)} { puts "sdrctl::control $self $wrapped installed" }
	if {$options(-type) eq {jack}} { $wrapped deactivate }
	if {$verbose(construct)} { puts "sdrctl::control $self $wrapped deactivated" }
	set options(-opts) [$self Wrapped opts]
	if {$verbose(construct)} { puts "sdrctl::control $self $wrapped opts $options(-opts)" }
	set options(-methods) [$self Wrapped methods]
	if {$verbose(construct)} { puts "sdrctl::control $self $wrapped methods $options(-methods)" }
	set options(-ports) [$self Wrapped ports]
	if {$verbose(construct)} { puts "sdrctl::control $self $wrapped ports $options(-ports)" }
	$options(-control) part-add $options(-name) $self
	if {{finish} in [$wrapped info methods]} { $wrapped finish }
    }

    destructor {
	# puts "control destructor called"
	if {[$options(-control) part-exists $options(-name)]} {
	    $options(-control) part-remove $options(-name)
	}
	if {$options(-factory) ne {} && $wrapped ne {}} {
	    rename $wrapped {}
	}
    }

    method {Wrapped name} {} {
	switch $options(-type) {
	    ui { return $options(-root).$options(-name) }
	    default { return ::sdrctlx::$options(-name) }
	}
    }

    method {Wrapped extra-opts} {} {
	switch $options(-type) {
	    ctl - ui - hw { return [list -command [mymethod command]] }
	    jack { return {} }
	    dsp { return [list -container $self] }
	}
    }

    method {Wrapped opts} {} {
	if {{-opts} in [$wrapped info options]} {
	    return [$wrapped cget -opts]
	}
	return [Filter-not-in [$wrapped info options] $typedata(exclude-opts)]
    }

    method {Wrapped methods} {} {
	if {{-methods} in [$wrapped info options]} {
	    return [$wrapped cget -methods]
	}
	return [Filter-not-in [$wrapped info methods] $typedata(exclude-methods)]
    }

    method {Wrapped ports} {} {
	if {{-ports} in [$wrapped info options]} {
	    return [$wrapped cget -ports]
	} elseif {$options(-type) eq {jack}} {
	    return [Filter-not-in [$wrapped info ports] $typedata(exclude-ports)]
	}
	return {}
    }

    # these always come in pairs, and the snit per option processing
    # breaks the band pass filter limits
    # there are many more updates coming, mostly duplicates, so I'm filtering here
    # until I can get them sorted out
    # also dealing with the filter being busy changing
    method {Handler2 -low} {val} {
	if {$options(-type) eq {jack}} {
	    set options(-low) $val
	} else {
	    $wrapped configure -low $val
	}
    }

    method {Handler2 -high} {val} {
	if {$options(-type) eq {jack}} {
	    if {[$wrapped is-busy]} {
		# puts "deferred $wrapped configure -low $options(-low) -high $val"
		after 10 [mymethod Handler2 -high $val]
	    } else {
		set options(-high) $val
		set xlow [$wrapped cget -low]
		set xhigh [$wrapped cget -high]
		if {$xlow != $options(-low) || $xhigh != $options(-high)} {
		    $wrapped configure -low $options(-low) -high $options(-high)
		    # puts "performed $wrapped configure -low $options(-low) -high $options(-high) were $xlow $xhigh"
		} else {
		    # puts "ignored $wrapped configure -low $options(-low) -high $options(-high)"
		}
	    }
	} else {
	    $wrapped configure -high $val
	}
    }

    method resolve {} {
	#puts "$self resolve $options(-type)"
	if {{resolve} in $options(-methods)} { $wrapped resolve }
	switch $options(-type) {
	    ctl - ui - hw - dsp {
		foreach conn [$self cget -opt-connect-to] {
		    if {$verbose(resolution)} { puts "$options(-name) opt-connect-to $conn" }
		    $self opt-connect-to {*}$conn
		}
		foreach conn [$self cget -opt-connect-from] {
		    if {$verbose(resolution)} {  puts "$options(-name) opt-connect-from $conn" }
		    $self opt-connect-from {*}$conn
		}
	    }
	    jack {
		foreach opt $options(-opts) {
		    set candidates [$options(-control) opt-filter [list ctl*$options(-name) $opt]]
		    if {[llength $candidates] > 1} {
			error "multiple resolutions (1st pass) for $options(-name):$opt: $candidates"
		    }
		    if {[llength $candidates] == 1} {
			set candidate [lindex $candidates 0]
			if {$verbose(resolution)} { puts "$options(-name) opt-connect-from $candidate $opt" }
			$self opt-connect-from {*}$candidate $opt
			continue
		    }
		    if { ! [regexp {^[rt]x-(.*)$} $options(-name) all tail]} {
			if {$verbose(no-resolution)} { puts "$options(-name): no resolution (1st pass) for $opt" }
			continue
		    }
		    set candidates [$options(-control) opt-filter [list ctl-rxtx*$tail $opt]]
		    if {[llength $candidates] > 1} { error "multiple resolutions (2nd pass) for $options(-name):$opt: $candidates" }
		    if {[llength $candidates] == 1} {
			set candidate [lindex $candidates 0]
			if {$verbose(resolution)} { puts "$options(-name) opt-connect-from $candidate $opt" }
			$self opt-connect-from {*}$candidate $opt
			continue
		    }
		    if {$verbose(no-resolution)} { puts "$options(-name): no resolution (2nd pass) for $opt" }
		}
	    }
	}
    }
    
    method {command report} {opt val args} { $self report $opt $val {*}$args }
    method {command configure} {args} { return [$self configure {*}$args] }
    method {command cget} {opt} { return [$self cget $opt] }
    method {command get-wrapped-command} {} { return [$self get-wrapped-command] }
    method {command destroy} {} { $self destroy }
    
    method opt-connect-to {opt name2 opt2} { $options(-control) opt-connect [list $options(-name) $opt] [list $name2 $opt2] }
    method opt-connect-from {name2 opt2 opt} { $options(-control) opt-connect [list $name2 $opt2] [list $options(-name) $opt] }
    method port-connect-to {port name2 port2} { $options(-control) port-connect [list $options(-name) $port] [list $name2 $port2] }
    method port-connect-from {name2 opt2 opt} { $options(-control) port-connect [list $name2 $opt2] [list $options(-name) $opt] }
    method get-wrapped-command {} { return $wrapped }
    method report {opt val args} { $options(-control) part-report $options(-name) $opt $val {*}$args }
    
    # these are only used for the dsp alternates
    # or, in general, only if they're present in the wrapped command
    method rewrite-connections-to {port candidates} {
	if {{rewrite-connections-to} in $options(-methods)} {
	    return [$wrapped rewrite-connections-to $port $candidates]
	} else {
	    return $candidates
	}
    }
    method rewrite-connections-from {port candidates} {
	if {{rewrite-connections-from} in $options(-methods)} {
	    return [$wrapped rewrite-connections-from $port $candidates]
	} else {
	    return $candidates
	}
    }
    
    method Inherit {opt from_opt} {
	if {$options($opt) eq {}} {
	    set options($opt) [$options(-container) cget $from_opt]
	}
    }
    
    proc Filter-not-in {list nilist} {
	set new {}
	foreach i $list { if {$i ni $nilist} { lappend new $i } }
	return $new
    }
    
    method {Handler -activate} {val} {
	set options(-activate) $val
	if {$options(-type) eq {jack}} {
	    if {$val} {
		$wrapped activate
	    } else {
		$wrapped deactivate
	    }
	}
    }
    
    method Delegate {opt} {
	if {$opt in [$wrapped info options]} { return [$wrapped cget $opt] }
	return $options($opt)
    }
}

