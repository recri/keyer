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

package provide sdrdsp::dsp-hw 1.0.0

package require snit

namespace eval sdrdsp {}

snit::type sdrdsp::dsp-hw {
    #puts "dsp-hw $name {$args}"
    option -container {}
    option -control {}
    option -server {}

    variable data [dict create]

    constructor {args} {
	$self configure {*}$args

	if {$options(-container) eq {}} { error "no container to leech off" }
	if {$options(-control) eq {}} { set options(-control) [$options(-container) cget -control] }
	if {$options(-server) eq {}} { set options(-server) [$options(-container) cget -server] }

	foreach {pname pdict} [sdrtcl::jack -server $options(-server) list-ports] {
	    # pdict has type, direction, physical, and connections
	    # dict set data $pname $pdict
	    if { ! [dict get $pdict physical]} {
		# may need more finesse at some point, but for now just the physical ports
		continue
	    }
	    lassign [split $pname :] client port
	    if { ! [dict exists $data $client]} {
		dict set data $client {}
	    }
	    dict set data $client $port $pdict
	}
	dict for {client cdict} $data {
	    set ports [dict keys $cdict]
	    set fopt [list -ports $ports]
	    set part ::sdrctlw::$client
	    sdrctl::control $part -type hw -prefix {} -suffix $client -factory sdrdsp::dsp-hw-port -factory-options $fopt -container $options(-container) -activate yes
	    dict set data $client client:ports $ports
	    dict set data $client client:part $part
	}
    }
    
    method activate {} {}
    method deactivate {} {}

    destructor {
	dict for {client cdict} $data {
	    #puts "cleaning up ports for $client -> [dict get $cdict client:part]"
	    if {[catch {[dict get $cdict client:part] destroy} error]} {
		puts "error cleaning up ports for $client: $error"
	    }
	}
    }
}    

snit::type sdrdsp::dsp-hw-port {
    option -ports {}
    option -opts {}
    option -methods {}
    option -command {}
}

