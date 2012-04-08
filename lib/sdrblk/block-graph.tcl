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

package provide sdrblk::block-graph 1.0.0

package require snit

package require sdrkit::jack

#
# A computational block which maintains minimal jack audio connections
# to its peers.
#
# A block has an input peer, an output peer, and a supervisor which handles
# input and output outside the block.  At the moment the input and output are
# singular, but there could be multiple connections.
#
# A block graph with no active components simply propagates input to output.
#
# A block with an active component connects its inport to the upstream outport
# and sends its outport downstream to be the inport of the next active component.
#

# 1) needs to know -server option to use sdrkit::jack correctly
# 2) needs to connect the final block's -outport to the -inport
# 3) needs to retain the iq-swap when automatically rewiring

::snit::type sdrblk::block-graph {

    typevariable verbose -array {connect 0 construct 0 configure 0}

    # these options apply to all varieties
    option -partof -readonly yes
    option -server -readonly yes
    option -type -readonly yes -type {snit::stringtype -regexp {^(internal|pipeline|alternate)$}}

    option -input -default {}
    option -output -default {}
    option -super -default {}
    option -inport -default {} -configuremethod SetInport
    option -outport -default {} -configuremethod SetOutport

    method SetInport {opt newval} {
	set oldval $options($opt)
	set options($opt) $newval
	# change in inport requires rewiring the internal inport
	# or propagation of the outport
	if {$verbose(connect)} { puts "block-graph $self Inport $opt {$newval} #[llength $parts] was {$oldval}" }
	if {[llength $parts] > 0} {
	    foreach part [$self input-parts] {
		$part configure -inport $newval
	    }
	} elseif {$newval eq $oldval} {
	    # no change
	} elseif {$options(-internal) eq {}} {
	    # propagate -inport to -outport
	    $self configure -outport $newval
	} else {
	    # connect -inport to -internal
	    $self connect $newval [$self internal-inputs $options(-internal)]
	    # disconnect old -inport from -internal
	    $self disconnect $oldval [$self internal-inputs $options(-internal)]
	    # configure downstream
	    $self configure -outport [$self internal-outputs $options(-internal)]
	}
    }

    method SetOutport {opt newval} {
	set oldval $options($opt)
	set options($opt) $newval
	# change in outport requires propagation of the outport downstream
	if {$verbose(connect)} { puts "block-graph $self Outport $opt {$newval} #[llength $parts] was {$oldval}" }
	if {$options(-output) ne {}} {
	    $options(-output) graph configure -inport $newval
	} elseif {$options(-super) ne {}} {
	    $options(-super) graph configure -outport $newval
	} else {
	    # terminal -outport
	    if {$oldval ne $newval} {
		$self connect $newval $options(-sink)
		$self disconnect $oldval $options(-sink)
	    }
	}
    }

    # these options apply to blocks which contain a single jack module
    option -internal-inputs -readonly true
    option -internal-outputs -readonly true
    option -internal -default {} -configuremethod SetInternal
    
    method SetInternal {opt newval} {
	if {$options(-type) ne {internal}} {
	    error "option \"$opt\" is only valid in a type \"internal\" block-graph"
	}
	set oldval $options($opt)
	set options($opt) $newval
	# change in internal block structure requires rewiring, either to connect
	# the new internal and propagate the resulting outport, or to disconnect
	# the old internal and propagate the inport to the outport
	if {$verbose(connect)} { puts "block-graph $self Internal $opt {$newval} #[llength $parts] was {$oldval}" }
	if {$newval eq $oldval} {
	    # no change
	} elseif {$newval eq {}} { # && $oldval ne {}
	    # replace -internal with {}
	    $self configure -outport $options(-inport)
	    # disconnect -inport from the old -internal
	    $self disconnect $options(-inport) [$self internal-inputs $oldval]
	} elseif {$oldval eq {}} { # && $newval ne {}
	    # replace {} with -internal
	    $self connect $options(-inport) [$self internal-inputs $newval]
	    $self configure -outport [$self internal-outputs $newval]
	} else {
	    # connect -inport to the new -internal
	    $self connect $options(-inport) [$self internal-inputs $newval]
	    # disconnect -inport from the old -internal
	    $self disconnect $options(-inport) [$self internal-inputs $oldval]
	    # update -outport
	    $self configure -outport [$self internal-outputs $newval]
	}
    }

    method internal-inputs {internal} {
	set inputs {}
	foreach i $options(-internal-inputs) {
	    lappend inputs ${internal}:$i
	}
	return $inputs
    }

    method internal-outputs {internal} {
	set outputs {}
	foreach i $options(-internal-outputs) {
	    lappend outputs ${internal}:$i
	}
	return $outputs
    }

    method disconnect {ins outs} {
	if {[llength $ins] == [llength $outs]} {
	    foreach i $ins o $outs {
		sdrkit::jack -server [$self cget -server] disconnect [$self portname $i] [$self portname $o]
	    }
	}
    }
    
    method connect {ins outs} {
	if {[llength $ins] == [llength $outs]} {
	    foreach i $ins o $outs {
		sdrkit::jack -server [$self cget -server] connect [$self portname $i] [$self portname $o]
	    }
	}
    }
    
    method portname {i} {
	foreach {name value} [sdrkit::jack -server [$self cget -server] list-ports] {
	    if {[string first $name $i] >= 0} {
		return $name
	    }
	}
	return $i
    }

    # these apply to the rx and tx blocks which connect directly to hardware
    option -sink -default {} -configuremethod Sink
    option -source -default {} -configuremethod Source

    method Sink {opt newval} {
	set oldval $options($opt)
	set options($opt) $newval
	if {$verbose(connect)} { puts "block-graph $self Sink $opt {$newval} #[llength $parts] was {$oldval}" }
	$self connect $options(-outport) $newval
	$self disconnect $options(-outport) $oldval
    }

    method Source {opt newval} {
	set oldval $options($opt)
	set options($opt) $newval
	if {$verbose(connect)} { puts "block-graph $self Source $opt {$newval} #[llength $parts] was {$oldval}" }
	$self configure -inport $newval
    }

    # this variable and method applies to blocks which switch between alternate graphs
    option -alternate -default {} -configuremethod SetAlternate

    variable alternates -array {}
    method SetAlternate {opt newval} {
	if {$verbose(configure)} { puts "block-graph $self Configure $opt $val" }
	set oldval $options($opt)
	set options($opt) $newval
	if {$newval ne {}} {
	    $alternates($newval) graph configure -inport $options(-inport) -outport $options(-outport)
	}
	if {$oldval ne {}} {
	    $alternates($oldval) graph configure -inport {} -outport {}
	}
    }
    
    method addalternate {name block} {
	set alternates($name) $block
    }

    # this variable and these methods manage pipelined parts
    variable parts {}

    method addpart {block} {
	lappend parts $block
	if {[llength $parts] > 1} {
	}
    }

    method parts {} { return $parts }
	
    method input-parts {} {
	set inputparts {}
	foreach part [$self parts] {
	    if {[$part cget -input] eq {}} {
		lappend inputparts $part
	    }
	}
	return $inputparts
    }
    
    # common code
    constructor {args} {
	if {$verbose(construct)} { puts "block-graph $self constructor $args" }
	$self configure {*}$args
	set options(-server) [$options(-partof) cget -server]
	set options(-super) [$options(-partof) cget -partof]
	if {[catch {
	    $options(-super) graph addpart $self
	} error erropts]} {
	    if {[string match {unknown subcommand "graph":*} $error]} {
		set options(-super) {}
	    } else {
		return -options $erropts $error
	    }
	}
    }

    destructor { }


}

