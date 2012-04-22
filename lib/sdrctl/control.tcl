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

#
# a radio is built of parts
# there are three different kinds of parts:
#
#  1) parts which do dsp computations, ../sdrblk/block.tcl;
#  2) parts which supply parameter values, ../sdrui/components.tcl;
#  3) parts which convert parameter values into dsp parameter values,
#  implemented here.
#
# all these parts register themselves here as they are created, and
# register their control options.  The controller matches them up 
# and then supplies the glue required to make the few that don't match
# exactly align.
#
package require snit
package require sdrutil::band-data

namespace eval sdrctl {}

snit::type sdrctl::control {
    variable data -array {}

    option -partof -readonly yes

    constructor {args} {
	set data(parts) [dict create]
	set data(vars) [dict create]
	set data(reporting) [dict create]
	$self configure {*}$args
	sdrctl::controller-init $self
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
		dict set data(vars) $name:$opt {}
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
    ## ui and control value reporters
    ##
    method report {name var value} {
	if { ! [dict exists $data(vars) $name:$var]} { error "control report $name $var -- non-existent var" }
	if {[dict exists $data(reporting) $name:$var] && [dict get $data(reporting) $name:$var]} {
	    error "control report $name $var $value -- looping"
	}
	# if { ! [string match *freq $var]} { puts "control report $name $var $value" }
	dict set data(reporting) $name:$var true
	# $self control $name $var $value
	if {[catch {
	    foreach {name2 var2} [dict get $data(vars) $name:$var] {
		# if { ! [string match *freq $var]} { puts "control report forward to $name2 $var2 $value" }
		$self control $name2 $var2 $value
	    }
	} error]} {
	    puts $error
	}
	dict set data(reporting) $name:$var false
    }

    ##
    ## control value delivery
    ##
    method deliver {name var value args} {
	# puts "control deliver $name $var $value $args"
	$self control $name $var $value {*}$args
    }

    ##
    ## value listeners
    ##
    method add-listener {name1 var1 name2 var2} {
	if { ! [dict exists $data(vars) $name1:$var1]} { error "control add-listener source $name1 $var1 -- no $name1:$var1 in data(vars)" }
	if { ! [dict exists $data(vars) $name2:$var2]} { error "control add-listener destination $name2 $var2 -- no $name2:$var2 in data(vars)" }
	# puts "control add-listener $name1 $var1 $name2 $var2"
	dict lappend data(vars) $name1:$var1 $name2 $var2
    }
    
    ##
    ## resolve the 
    ##
    method resolve {} {
	# resolve the controllers
	foreach name [dict keys $data(parts) ctl-*] { [$self part $name] resolve }
	# match up names to establish some transfers
	dict for {name listeners} $data(vars) {
	    set l [llength $listeners]
	    # puts "$name listeners $listeners"
	    foreach k [dict keys $data(vars) *$name] {
		if {$name ne $k} {
		    # puts "$name matches tail of $k"
		    $self add-listener {*}[split $k :] {*}[split $name :]
		}
	    }
	}
    }
}

proc sdrctl::controller-init {control} {
    foreach {name factory opts} {
	ctl sdrctl::stub {}
	ctl-mode sdrctl::mode {}
	ctl-tune sdrctl::tune {}
	ctl-rxtx sdrctl::rxtx {}
	ctl-band sdrctl::band {}
	ctl-filter sdrctl::filter {}
    } {
	sdrctl::controller ::$name -name $name -factory $factory -control $control -options $opts
    }
}

proc sdrctl::filter-controls {omit conf} {
    foreach element $conf {
	if {[lindex $element 0] in $omit} continue
	lappend controls $element
    }
    return $controls
}

snit::type sdrctl::controller {
    option -control {}
    option -name {}
    option -factory {}
    option -options {}
    option -enable yes
    option -activate yes
    option -type ctl

    constructor {args} {
	$self configure {*}$args
	$options(-factory) ::sdrctl::$options(-name) -command [mymethod command] {*}$options(-options)
	$options(-control) add $options(-name) $self
    }

    method {command report} {opt val} { $options(-control) report $options(-name) $opt $val }
    method {command deliver} {target opt val args} { $options(-control) deliver $target $opt $val {*}$args }
    method {command listen-to} {name1 var1 var2} { $options(-control) add-listener $name1 $var1 $options(-name) $var2 }
    method {command add-listener} {var1 name2 var2} { $options(-control) add-listener $options(-name) $var1 $name2 $var2 }
    method resolve {} { ::sdrctl::$options(-name) resolve }
    # these are the methods the radio controller uses
    method controls {} { return [::sdrctl::$options(-name) controls] }
    method control {args} { return [::sdrctl::$options(-name) control {*}$args] }
    method controlget {opt} { return [::sdrctl::$options(-name) controlget $opt] }
}

snit::type sdrctl::stub {
    option -command {}
    method resolve {} {
    }
    method controls {} { return {} }
}

snit::type sdrctl::mode {
    option -command {}
    option -mode -default CWU -configuremethod opt-handler 
    method resolve {} {
	if {$options(-command) ne {}} {
	    {*}$options(-command) listen-to ui-mode -mode -mode
	    {*}$options(-command) add-listener -mode ui-mode -mode
	}
    }
    method {opt-handler -mode} {val} {
	set options(-mode) $val
	# puts "sdrctl::mode -mode $val"
	{*}$options(-command) report -mode $val
    }
    method controls {} { return [sdrctl::filter-controls {-command} [$self configure]] }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { $self cget $opt }
}

snit::type sdrctl::tune {
    option -command {}
    option -mode -default CWU -configuremethod opt-handler 
    option -freq -default 7050000 -configuremethod opt-handler
    option -lo-freq -default 10000 -configuremethod opt-handler
    option -cw-freq -default 600 -configuremethod opt-handler
    option -carrier-freq -default 7040000 -configuremethod opt-handler
    option -hw-freq -default 7039400 -configuremethod opt-handler
    method resolve {} {
	{*}$options(-command) listen-to ctl-mode -mode -mode
	{*}$options(-command) listen-to ui-tuner -freq -freq
	{*}$options(-command) listen-to ui-if-mix -freq -lo-freq
	{*}$options(-command) listen-to ui-keyer-tone -freq -cw-freq
	{*}$options(-command) add-listener -freq ui-tuner -freq
	{*}$options(-command) add-listener -lo-freq ui-if-mix -freq
	{*}$options(-command) add-listener -cw-freq ui-keyer-tone -freq
	{*}$options(-command) add-listener -hw-freq hw -freq
    }
    method compute-carrier {} {
	switch $options(-mode) {
	    CWU { set options(-carrier-freq) [expr {$options(-freq)-$options(-cw-freq)}] }
	    CWL { set options(-carrier-freq) [expr {$options(-freq)+$options(-cw-freq)}] }
	    default { set options(-carrier-freq) [expr {$options(-freq)}] }
	}
	set options(-hw-freq) [expr {$options(-carrier-freq)-$options(-lo-freq)}]
	{*}$options(-command) report -carrier-freq $options(-carrier-freq)
	{*}$options(-command) report -hw-freq $options(-hw-freq)
    }
    method {opt-handler -mode} {val} {
	set options(-mode) $val
	$self compute-carrier
    }
    method {opt-handler -freq} {val} {
	set options(-freq) $val
	$self compute-carrier
	{*}$options(-command) report -freq $options(-freq)
    }
    method {opt-handler -lo-freq} {val} {
	set options(-lo-freq) $val
	$self compute-carrier
	{*}$options(-command) report -lo-freq $options(-lo-freq)
    }
    method {opt-handler -cw-freq} {val} {
	set options(-cw-freq) $val
	$self compute-carrier
	{*}$options(-command) report -cw-freq $options(-cw-freq)
    }
    method {opt-handler -carrier-freq} {val} { }
    method {opt-handler -hw-freq} {val} { }
    method controls {} { return [sdrctl::filter-controls {-command} [$self configure]] }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { $self cget $opt }
}

snit::type sdrctl::rxtx {
    option -command {}
    option -mode -default CWU -configuremethod opt-handler 
    option -mox -default 0 -configuremethod opt-handler 
    method resolve {} {
    }
    method {opt-handler -mode} {val} { }
    method {opt-handler -mox} {val} { }
    method controls {} { return [sdrctl::filter-controls {-command} [$self configure]] }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { $self cget $opt }
}

snit::type sdrctl::band {
    option -command {}
    option -band -configuremethod opt-handler 
    option -channel -configuremethod opt-handler 
    option -band-low -configuremethod opt-handler
    option -band-high -configuremethod opt-handler
    option -band-mode -configuremethod opt-handler
    option -band-filter -configuremethod opt-handler
    option -freq 7050000

    method resolve {} {
	{*}$options(-command) listen-to ui-band-select -band -band
	{*}$options(-command) listen-to ui-band-select -channel -channel
	{*}$options(-command) add-listener -freq ctl-tune -freq
    }
    method {opt-handler -band} {val} {
	set options(-band) $val
	lassign [sdrutil::band-data-band-range-hertz {*}$val] options(-band-low) options(-band-high)
	set freq [expr {($options(-band-low)+$options(-band-high))/2}]
	{*}$options(-command) report -freq $freq
    }
    method {opt-handler -channel} {val} {
	set options(-channel) $val
	set freq [sdrutil::band-data-channel-freq-hertz {*}$val]
	{*}$options(-command) report -freq $freq
    }
    method controls {} { return [sdrctl::filter-controls {-command} [$self configure]] }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { $self cget $opt }
}

snit::type sdrctl::filter {
    option -command {}
    option -mode -default CWU -configuremethod opt-handler
    option -width -default 400 -configuremethod opt-handler
    option -cw-freq -default 600 -configuremethod opt-handler

    method resolve {} {
	{*}$options(-command) listen-to ui-if-bpf -width -width
	{*}$options(-command) listen-to ctl-mode -mode -mode
	{*}$options(-command) listen-to ctl-tune -cw-freq -cw-freq
    }
    method {opt-handler -mode} {val} {
	set options(-mode) $val
    }
    method {opt-handler -width} {val} {
	set options(-width) $val
	$self compute-filter
	{*}$options(-command) report -width $val
    }
    method compute-filter {} {
	set c $options(-cw-freq)
	set w $options(-width)
	set h [expr {$options(-width)/2.0}]
	switch $options(-mode) {
	    CWL { set low [expr {-$c-$h}]; set high [expr {-$c+$h}] }
	    CWU { set low [expr {+$c-$h}]; set high [expr {+$c+$h}] }
	    AM -
	    SAM -
	    DSB -
	    FMN { set low [expr {-$h}]; set high [expr {+$h}] }
	    LSB -
	    DIGL { set low [expr {-150-$w}]; set high -150 }
	    USB -
	    DIGU { set low 150; set high [expr {150+$w}] }
	    default { error "missed mode $options(-mode)" }
	}
	{*}$options(-command) deliver rx-if-bpf -low $low -high $high
    }
    method controls {} { return [sdrctl::filter-controls {-command} [$self configure]] }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { $self cget $opt }
}

