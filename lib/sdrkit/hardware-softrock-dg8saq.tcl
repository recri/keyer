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

package provide sdrkit::hardware-softrock-dg8saq 1.0.0

package require snit
package require handle

namespace eval sdrkit {}

snit::type sdrkit::hardware-softrock-dg8saq {
    option -name softrock
    option -type hw
    option -server default
    option -component {}

    option -window none
    option -title Hardware
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {}
    option -options {-freq}

    option -sub-controls {
    }
    option -sub-components {
    }
    option -parts-enable {
    }
    option -port-connections {
    }
    option -opt-connections {
	rxtx -hw-freq . -freq
    }

    option -freq -default 7.050 -configuremethod Handler

    variable data -array {
	parts {}
	deferred-freq {}
	deferred-after {}
    }

    constructor {args} {
	#puts "sdrkit::hardware-softrock-dg8saq constructor $args"
	$self configure {*}$args
    }
    destructor {}
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	}
	foreach {name title command args} $options(-sub-components) {
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		sdrtk::clabelframe $w.$name -label $title
		if {$command ni {meter-tap spectrum-tap}} {
		    # only display real working components
		    grid $w.$name -sticky ew
		}
		set data($name-enable) 0
		ttk::checkbutton $w.$name.enable -text {} -variable [myvar data($name-enable)] -command [mymethod Enable $name]
		ttk::frame $w.$name.container
		$self sub-component $w.$name.container $name sdrkit::$command {*}$args
		grid $w.$name.enable $w.$name.container
		grid columnconfigure $w.$name 1 -weight 1 -minsize [tcl::mathop::+ {*}$options(-minsizes)]
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
	if {[catch {
	    foreach handle [handle::find_handles usb] {
		# puts "softrock::build [handle::serial $handle]"
		if {[string match PE0FKO-* [handle::serial $handle]]} {
		    set data(handle) $handle
		}
	    }
	    } error]} {
	    puts "error handling handles: $error"
	}
    }

    method check-softrock {} {
	# dg8saq::get_multiply_lo - needs band
	foreach command {
	    dg8saq::get_read_version
	    dg8saq::get_frequency_by_value
	    dg8saq::get_registers
	    dg8saq::get_frequency
	    dg8saq::get_read_keys
	    dg8saq::get_ptt
	    dg8saq::get_keys
	    dg8saq::get_startup_freq
	    dg8saq::get_xtal_freq
	    dg8saq::get_si570_address
	    dg8saq::get_smooth_tune_ppm
	    dg8saq::get_bpf_addresses
	    dg8saq::get_lpf_addresses
	    dg8saq::get_bands
	    dg8saq::get_lpfs
	    dg8saq::get_bpf_crossovers
	    dg8saq::get_lpf_crossovers
	} {
	    if {[catch {$command $data(handle)} error]} {
		puts "error on $command: $error"
	    } else {
		puts "$command -> $error"
	    }
	}
    }

    method is-needed {} { return 1 }
    method is-busy {} { return 0 }
    method is-active {} { return $data(active) }
    method activate {} { set data(active) 1 }
    method deactivate {} { set data(active) 0 }
    method resolve {} {
	# puts "hardware-softrock-dg8saq::resolve"
	foreach {name1 opt1 name2 opt2} $options(-opt-connections) {
	    set ename1 [$self Expand-name $name1]
	    set ename2 [$self Expand-name $name2]
	    # puts "$name1 $opt1 $name2 $opt2 -> $options(-component) connect-options $ename1 $opt1 $ename2 $opt2"
	    $options(-component) connect-options $ename1 $opt1 $ename2 $opt2
	}
    }
    method Expand-name {name} {
	if {$name eq {..}} { return [[$options(-component) get-parent] cget -name] }
	if {$name eq {.}} { return $options(-name) }
	if {[string first . $name] == 0} { return [regsub {^.} $name $options(-name)] }
	return $name
    }
    method {Handler -freq} {val} {
	# puts "hardware-softrock-dg8saq configure -freq $val"
	set options(-freq) $val
	set data(deferred-freq) $val
	if {$data(deferred-after) eq {}} {
	    set data(deferred-after) [after 50 [mymethod Deferred-handler]]
	}
    }
    method Deferred-handler {} {
	set data(deferred-after) {}
	if {$data(active)} {
	    dg8saq::put_frequency_by_value $data(handle) [expr {$data(deferred-freq)/1e6}]
	    #exec usbsoftrock set freq [expr {$val/1e6}]
	}
    }
}
