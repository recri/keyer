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

snit::type sdrctl::control {
    #
    # a radio is built of parts
    # there are three different kinds of parts:
    #  parts which do dsp computations;
    #  parts which supply parameter values
    #  parts which convert parameter values into dsp parameter values
    #
    variable data -array {}

    option -partof -readonly yes

    constructor {args} {
	set data(parts) [dict create]
	set data(vars) [dict create]
	set data(reporting) [dict create]
	$self configure {*}$args
    }

    method add {name block} {
	# puts "installing $name"
	if {[dict exists $data(parts) $name]} { error "control part $name already exists" }
	dict set data(parts) $name $block
	foreach opt [$self controls $name] {
	    set opt [lindex $opt 0]
	    if {[dict exists $data(vars) $name:$opt]} {
		error "duplicate variable $name $opt"
	    } elseif {$opt in {-server -client -verbose}} {
		# ignore
	    } else {
		# puts "installing $name:$opt in vars"
		dict set data(vars) $name:$opt [dict create value {} listeners [list $name:$opt]]
	    }
	}
    }

    method remove {name} {
	if { ! [dict exists $data(parts) $name]} { error "control part $name does not exist" }
	dict unset data(parts) $name
    }

    method part {name} { return [dict get $data(parts) $name] }
    method exists {name} { return [dict exists $data(parts) $name] }
    method list {} { return [dict keys $data(parts)] }
    method show {name} { return [$self part $name] }
    method controls {name} { return [[$self part $name] controls] }
    method control {name args} { [$self part $name] control {*}$args }
    method controlget {name opt} { return [[$self part $name] controlget $opt] }
    method ccget {name opt} { return [[$self part $name] cget $opt] }
    method cconfigure {name args} { return [[$self part $name] configure {*}$args] }
    method enable {name} { [$self part $name] configure -enable yes }
    method disable {name} { [$self part $name] configure -enable no }
    method is-enabled {name} { return [[$self part $name] cget -enable] }
    method activate {name} {
	[$self part $name] configure -activate yes
	[$self part $name] connect
    }
    method deactivate {name} {
	[$self part $name] disconnect
	[$self part $name] configure -activate no
    }
    method is-activated {name} { return [[$self part $name] cget -activate] }
    method filter-parts {pred} { set list {}; foreach name $order { if {[$pred $name]} { lappend list $name } }; return $list }
    method enabled {} { return [filter-parts [mymethod is-enabled]] }
    method activated {} { return [filter-parts [mymethod is-activated]] }

    ##
    ## ui value reporters
    ##
    method report {name var value} {
	if { ! [dict exists $data(vars) $name:$var]} { error "control report $name $var -- non-existent var" }
	if {[dict exists $data(reporting) $name:$var] && [dict get $data(reporting) $name:$var]} {
	    error "control report $name $var $value -- looping"
	}
	puts "control report $name $var $value"
	dict set data(reporting) $name:$var true
	foreach ptr [dict get $data(vars) $name:$var listeners] {
	    lassign [split $ptr :] target opt
	    $self control $target $opt $value
	}
	dict set data(vars) $name:$var value $value
	dict set data(reporting) $name:$var false
    }

    method variable-check {} {
	dict for {name value} $data(vars) {
	    set v [dict get $value value]
	    set by [dict get $value created-by]
	    set nreq [llength [dict get $value requires]]
	    set nsup [llength [dict get $value supplies]]
	    puts "$name value $v, created-by $by, supplies $nsup elements, requires $nreq"
	}
    }
}

if {0} {
    # how to handle band-pick and channel-pick from band-select
    method band-select {which args} {
	switch $which {
	    no-pick {
		# puts "no-pick"
	    }
	    band-pick {
		lassign [$bands band-range-hertz {*}$args] low high
		set freq [expr {($low+$high)/2}]
		# puts "band-pick $service $arg $low .. $high"
		$self set-freq $freq
		$options(-control) report ui-tune band $args
	    }
	    channel-pick {
		set freq [$bands channel-freq-hertz {*}$args]
		# puts "channel-pick $service $arg $freq"
		$self set-freq $freq
	    }
	}
    }
}