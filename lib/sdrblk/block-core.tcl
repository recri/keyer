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

package provide sdrblk::block-core 1.0.0

package require snit

package require sdrkit::jack

#
# The block represents a node or a subgraph of computational nodes.
# The nodes may be enabled or disabled. Enabled nodes will participate
# in the computation when activated. The enabled nodes may be activated
# or deactivated. Activated nodes are actively processing samples and
# consuming computational cycles.
#
# The graph is constructed with all the potential computational units
# organized into the structure they would form if enabled and activated.
# The graph has subgraphs which can be sequences, alternate branches,
# parallel paths, fan out, fan in, and terminal nodes.
#
# The units required for the desired computation are enabled, and when
# enabled their parameters can be configured as required.
#
# So, the blocks serve these purposes:
# 1 - they organize the structure of the radio or other dsp computation
# 2 - they organize the enablement/disablement of the units
# 3 - they organize the configuration of the units
# 4 - they organize the activation/deactivation of the units
# 5 - they maintain the port connection/disconnection of the units
#
snit::type sdrblk::block-core {
    ##
    ## this type variable, shared among all instances, enables verbose messages
    ##
    typevariable verbose -array {connect 0 construct 0 configure 0 enable 0 destroy 0}

    ##
    ## data that is private to the instance
    ##
    variable data -array {}

    ##
    ## common options and methods
    ##
    # -type defines the type of block
    option -type -readonly yes -type {snit::stringtype -regexp {^(jack|sequence|parallel|split|join|alternate|spectrum|meter|input|output)$}}
    
    # -server specifies the jack server name
    option -server -readonly yes

    # -partof and -coreof define the instance hierarchy
    option -partof -readonly yes
    option -coreof -readonly yes

    # -input, -output, and -super define the graph and subgraph structure
    option -input -default {}
    option -output -default {}
    option -super -default {}
    
    # -inport and -outport define the enabled connections
    option -inport -default {} -configuremethod SetInport
    option -outport -default {} -configuremethod SetOutport

    method SetInport {opt newval} {
	set oldval $options($opt)
	set options($opt) $newval
	# change in inport requires rewiring the internal inport
	# or propagation of the outport
	if {$verbose(connect)} { puts "block-core $self Inport $opt {$newval} #[llength $parts] was {$oldval}" }
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
	if {$verbose(connect)} { puts "block-core $self Outport $opt {$newval} #[llength $parts] was {$oldval}" }
	if {$options(-output) ne {}} {
	    $options(-output) configure -inport $newval
	} elseif {$options(-super) ne {}} {
	    $options(-super) configure -outport $newval
	} else {
	    # terminal -outport
	    if {$oldval ne $newval} {
		$self connect $newval $options(-sink)
		$self disconnect $oldval $options(-sink)
	    }
	}
    }

    # -prefix, -suffix, and -name define the hierarchical naming of components
    option -prefix -readonly yes
    option -suffix -readonly yes
    option -name -readonly yes

    # -enable and -activate? options or methods?
    option -enable -default no -configuremethod Enable
    option -enablemethod -default {} -readonly yes

    method Enable {opt newval} {
	if {$options(-enablemethod) ne {}} {
	    {*}$options(-enablemethod) $opt $newval
	}
	set options($opt) $newval
    }

    # -control is the radio controller
    option -control -readonly yes

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

    ##
    ## these apply to blocks which contain a single jack module
    ## -type jack
    ##
    option -jack-ports {}
    option -internal-inputs -readonly true
    option -internal-outputs -readonly true
    option -internal -default {} -configuremethod SetInternal
    option -factory -readonly yes
    
    method SetInternal {opt newval} {
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	set oldval $options($opt)
	set options($opt) $newval
	# change in internal block structure requires rewiring, either to connect
	# the new internal and propagate the resulting outport, or to disconnect
	# the old internal and propagate the inport to the outport
	if {$verbose(connect)} { puts "block-core $self Internal $opt {$newval} #[llength $parts] was {$oldval}" }
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
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	set inputs {}
	foreach i $options(-internal-inputs) {
	    lappend inputs ${internal}:$i
	}
	return $inputs
    }

    method internal-outputs {internal} {
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	set outputs {}
	foreach i $options(-internal-outputs) {
	    lappend outputs ${internal}:$i
	}
	return $outputs
    }

    method disconnect {ins outs} {
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	if {[llength $ins] == [llength $outs]} {
	    foreach i $ins o $outs {
		sdrkit::jack -server [$self cget -server] disconnect [$self portname $i] [$self portname $o]
	    }
	} else {
	    error "$options(-name) disconnect: {$ins} don't match {$outs}"
	}
    }
    
    method connect {ins outs} {
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	if {[llength $ins] == [llength $outs]} {
	    foreach i $ins o $outs {
		sdrkit::jack -server [$self cget -server] connect [$self portname $i] [$self portname $o]
	    }
	} else {
	    error "$options(-name) connect: {$ins} don't match {$outs}"
	}
    }
    
    method portname {i} {
	if {$options(-type) ne {jack}} { error "$options(-name) is not a jack block" }
	foreach {name value} [sdrkit::jack -server [$self cget -server] list-ports] {
	    if {[string first ${name}: $i] == 0} {
		return $name
	    }
	}
	return $i
    }

    ##
    ## these apply to the rx and tx blocks which connect directly to hardware
    ## -type input|output
    ##
    option -sink -default {} -configuremethod Sink
    option -source -default {} -configuremethod Source

    method Sink {opt newval} {
	if {$options(-type) ne {output}} { error "$options(-name) is not an output block" }
	set oldval $options($opt)
	set options($opt) $newval
	if {$verbose(connect)} { puts "block-core $self Sink $opt {$newval} #[llength $parts] was {$oldval}" }
	$self connect $options(-outport) $newval
	$self disconnect $options(-outport) $oldval
    }

    method Source {opt newval} {
	if {$options(-type) ne {input}} { error "$options(-name) is not an input block" }
	set oldval $options($opt)
	set options($opt) $newval
	if {$verbose(connect)} { puts "block-core $self Source $opt {$newval} #[llength $parts] was {$oldval}" }
	$self configure -inport $newval
    }

    ##
    ## these options and method applies to blocks which switch between alternate graphs
    ## -type alternate
    ##
    option -alternates -readonly yes
    option -alternate -default {} -configuremethod SetAlternate

    variable alternates -array {}

    method SetAlternate {opt newval} {
	if {$options(-type) ne {alternate}} { error "$options(-name) is not an alternate block" }
	if {$verbose(configure)} { puts "block-core $self Configure $opt $val" }
	set oldval $options($opt)
	set options($opt) $newval
	if {$newval ne {}} {
	    $alternates($newval) configure -inport $options(-inport) -outport $options(-outport)
	}
	if {$oldval ne {}} {
	    $alternates($oldval) configure -inport {} -outport {}
	}
    }
    
    method addalternate {name block} {
	if {$options(-type) ne {alternate}} { error "$options(-name) is not an alternate block" }
	set alternates($name) $block
    }

    ##
    ## these manage sequences of parts
    ## -type sequence
    ##
    option -sequence -readonly yes

    variable parts {}

    method addpart {block} {
	# if {$options(-type) ne {sequence}} { error "$options(-name) is not a sequence block" }
	lappend parts $block
	if {[llength $parts] > 1} {
	}
    }

    method parts {} {
	# if {$options(-type) ne {sequence}} { error "$options(-name) is not a sequence block" }
	return $parts
    }
	
    method input-parts {} {
	# if {$options(-type) ne {sequence}} { error "$options(-name) is not a sequence block" }
	set inputparts {}
	foreach part [$self parts] {
	    if {[$part cget -input] eq {}} {
		lappend inputparts $part
	    }
	}
	return $inputparts
    }
    
    method output-parts {} {
	# if {$options(-type) ne {sequence}} { error "$options(-name) is not a sequence block" }
	set outputparts {}
	foreach part [$self parts] {
	    if {[$part cget -output] eq {}} {
		lappend outputparts $part
	    }
	}
	return $outputparts
    }
    
    ##
    ## common code
    ##
    constructor {args} {
	if {$verbose(construct)} { puts "block-core $self constructor $args" }
	$self configure {*}$args
	set options(-server) [$options(-partof) cget -server]
	set options(-prefix) [$options(-partof) cget -name]
	set options(-control) [$options(-partof) cget -control]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	set options(-super) $options(-partof)
	$options(-control) add $options(-name) $self
	if {[catch {
	    $options(-super) addpart $self
	} error erropts]} {
	    if {[string match {unknown subcommand "addpart": must be*} $error]} {
		set options(-super) {}
	    } else {
		return -options $erropts $error
	    }
	}
    }

    destructor {
	catch {$options(-control) remove $options(-name)}
    }


}

