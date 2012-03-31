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

::snit::type sdrblk::block {
    variable parts {}

    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -input -default {} -validatemethod Validate -configuremethod Configure
    option -output -default {}  -validatemethod Validate -configuremethod Configure
    option -super -default {} -validatemethod Validate -configuremethod Configure
    option -internal -default {} -validatemethod Validate -configuremethod Configure
    option -inport -default {} -validatemethod Validate -configuremethod Configure
    option -outport -default {} -validatemethod Validate -configuremethod Configure
    option -internal-input -default {} -validatemethod Validate -configuremethod Configure
    option -internal-output -default {} -validatemethod Validate -configuremethod Configure
    option -self -readonly yes -cgetmethod Cget

    constructor {args} {
	#puts "block $self constructor $args"
	$self configure {*}$args
	set options(-super) [$options(-partof) cget -partof]
	if {[catch {
	    $options(-super) block addpart $self
	} error erropts]} {
	    #puts "error calling $options(-super)\n$error\n$erropts"
	    #catch {$options(-super) block addpart $self} error2 erropts2
	    #puts "error calling $options(-super)\n$error2\n$erropts2"
	    if {$error eq {unknown subcommand "block": must be Configure, Validate, or configure} ||
		$error eq {unknown subcommand "block": namespace ::sdrblk::radio::Snit_inst1 does not export any commands}} {
		set options(-super) {}
	    } else {
		return -options $erropts $error
	    }
	}
    }

    destructor { }

    method addpart {block} { lappend parts $block }

    method Validate {opt val} {
	#puts "block $self Validate $opt $val"
	switch -- $opt {
	    -partof -
	    -input -
	    -output -
	    -super -
	    -internal -
	    -inport -
	    -outport {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "block $self Configure $opt $val"
	switch -- $opt {
	    -partof -
	    -input -
	    -output -
	    -super {}
	    -internal {
		# change in internal block structure
		# requires rewiring, either to connect
		# the new internal and propagate the
		# resulting outport, or to disconnect
		# the old internal and propagate the
		# inport to the outport
		puts "block $self Configure $opt {$val} #[llength $parts]"
		if {$val eq $options($opt)} {
		    # no change
		} elseif {$val eq {}} { # && $options(-internal) ne {}
		    # replace -internal with {}
		    $self configure -outport [$self cget -inport]
		    # disconnect -inport from the old -internal
		    foreach i [$self cget -inport] o {in_i in_q} {
			sdrkit::jack disconnect $i $options(-internal):$o
		    }
		} elseif {$options($opt) eq {}} { # && $val ne {}
		    # replace {} with -internal
		    foreach i [$self cget -inport] o {in_i in_q} {
			sdrkit::jack connect $i ${val}:$o
		    }
		    $self configure -outport [list ${val}:out_i ${val}:out_q]
		} else {
		    # connect -inport to the new -internal
		    foreach i [$self cget -inport] o {in_i in_q} {
			sdrkit::jack connect $i ${val}:$o
		    }
		    # disconnect -inport from the old -internal
		    foreach i [$self cget -inport] o {in_i in_q} {
			sdrkit::jack disconnect $i $options(-internal):$o
		    }
		    # update -outport
		    $self configure -outport [list ${val}:out_i ${val}:out_q]
		}
	    }
	    -inport {
		# change in inport requires rewiring the internal inport
		# or propagation of the outport
		puts "block $self Configure $opt {$val} #[llength $parts]"
		if {[llength $parts] > 0} {
		    foreach part [$self InputParts] {
			$part configure -inport $val
		    }
		} elseif {$val eq $options($opt)} {
		    # no change
		} elseif {$options(-internal) eq {}} {
		    # propagate -inport to -outport
		    $self configure -outport $val
		} else {
		    # connect -inport to -internal
		    foreach i $val o {in_i in_q} {
			sdrkit::jack connect $i $options(-internal):$o
		    }
		    # disconnect old -inport from -internal
		    foreach i [$self cget -inport] o {in_i in_q} {
			sdrkit::jack disconnect $i $options(-internal):$o
		    }
		}
	    }
	    -outport {
		# change in outport requires propagation of the outport downstream
		puts "block $self Configure $opt {$val} #[llength $parts]"
		if {$options(-output) ne {}} {
		    $options(-output) block configure -inport $val
		} elseif {$options(-super) ne {}} {
		    $options(-super) block configure -outport $val
		} else {
		    puts "block $self configure -outport {$val} -- terminated"
		}
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
    
    method Cget {opt} {
	switch -- $opt {
	    -self { return $self }
	    default {
		error "unknown cget option \"$opt\""
	    }
	}
    }

    method InputParts {} {
	set inputparts {}
	foreach part $parts {
	    if {[$part cget -input] eq {}} {
		lappend inputparts $part
	    }
	}
	return $inputparts
    }
    
    method OutputParts {} {
	set outputparts {}
	foreach part $parts {
	    if {[$part cget -output] eq {}} {
		lappend outputparts $part
	    }
	}
	return $outputparts
    }
}

