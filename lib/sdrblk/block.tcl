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

package provide sdrblk::block 1.0.0

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

::snit::type sdrblk::block {

    typevariable verbose -array {connect 0 construct 0 validate 0 configure 0}

    variable parts {}

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget

    option -input -default {}
    option -output -default {}
    option -super -default {}
    option -internal -default {} -validatemethod Validate -configuremethod Configure
    option -inport -default {} -validatemethod Validate -configuremethod Configure
    option -outport -default {} -validatemethod Validate -configuremethod Configure
    option -sink -default {} -validatemethod Validate -configuremethod Configure
    option -source -default {} -validatemethod Validate -configuremethod Configure
    option -internal-inputs -readonly true -default {in_i in_q}
    option -internal-outputs -readonly true -default {out_i out_q}

    constructor {args} {
	if {$verbose(construct)} { puts "block $self constructor $args" }
	$self configure {*}$args
	set options(-super) [$options(-partof) cget -partof]
	if {[catch {
	    $options(-super) block addpart $self
	} error erropts]} {
	    if {[string match {unknown subcommand "block":*} $error]} {
		set options(-super) {}
	    } else {
		return -options $erropts $error
	    }
	}
    }

    destructor { }

    method addpart {block} { lappend parts $block }

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

    method Validate {opt val} {
	if {$verbose(validate)} { puts "block $self Validate $opt $val" }
	switch -- $opt {
	    -internal -
	    -sink -
	    -source -
	    -inport -
	    -outport {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt newval} {
	if {$verbose(configure)} { puts "block $self Configure $opt $val" }
	set oldval $options($opt)
	set options($opt) $newval
	switch -- $opt {
	    -internal {
		# change in internal block structure
		# requires rewiring, either to connect
		# the new internal and propagate the
		# resulting outport, or to disconnect
		# the old internal and propagate the
		# inport to the outport
		if {$verbose(connect)} { puts "block $self Configure $opt {$newval} #[llength $parts] was {$oldval}" }
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
	    -inport {
		# change in inport requires rewiring the internal inport
		# or propagation of the outport
		if {$verbose(connect)} { puts "block $self Configure $opt {$newval} #[llength $parts] was {$oldval}" }
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
	    -outport {
		# change in outport requires propagation of the outport downstream
		if {$verbose(connect)} { puts "block $self Configure $opt {$newval} #[llength $parts] was {$oldval}" }
		if {$options(-output) ne {}} {
		    $options(-output) block configure -inport $newval
		} elseif {$options(-super) ne {}} {
		    $options(-super) block configure -outport $newval
		} else {
		    # terminal -outport
		    if {$oldval ne $newval} {
			$self connect $newval $options(-sink)
			$self disconnect $oldval $options(-sink)
		    }
		}
	    }
	    -source {
		if {$verbose(connect)} { puts "block $self Configure $opt {$newval} #[llength $parts] was {$oldval}" }
		$self configure -inport $newval
	    }
	    -sink {
		if {$verbose(connect)} { puts "block $self Configure $opt {$newval} #[llength $parts] was {$oldval}" }
		$self connect $options(-outport) $newval
		$self disconnect $options(-outport) $oldval
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
    }
    
    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
}

