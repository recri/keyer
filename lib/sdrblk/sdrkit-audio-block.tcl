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

package provide sdrblk::sdrkit-audio-block 1.0.0

package require snit
package require sdrblk::validate
package require sdrblk::block

#
# a snit type to wrap a single sdrkit audio module
#

::snit::type ::sdrblk::sdrkit-audio-block {

    typevariable verbose -array {connect 0 construct 0 destroy 0 validate 0 configure 0 control 0 controlget 0}

    component block -public block

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix

    option -implemented -readonly yes -default no
    option -suffix -readonly yes

    option -enable -default no -validatemethod Validate -configuremethod Configure

    option -factory -readonly yes
    option -controls -readonly yes

    constructor {args} {
        $self configure {*}$args
	if {$verbose(construct)} { puts "$options(-name) $self constructor $args" }
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	[$self cget -control] add $options(-name) $self
    }

    destructor {
	if {$verbose(destroy)} { puts "$options(-name) $self destructor" }
	catch {[$self cget -control] remove $options(-name)}
        catch {$block destroy}
	catch {rename $options(-name) {}}
    }

    method controls {} { return $options(-controls) }

    method control {opt val} {
	if {$verbose(control)} { puts "$options(-name) $self control $opt $val" }
	$options(-name) configure $opt $val
    }

    method controlget {opt} {
	if {$verbose(controlget)} { puts "$options(-name) $self control $opt $val" }
	return [$options(-name) cget $opt]
    }

    method Validate {opt val} {
	if {$verbose(validate)} { puts "$options(-name) $self Validate $opt $val" }
	switch -- $opt {
	    -enable { ::sdrblk::validate::boolean $opt $val }
	    default { error "unknown validate option \"$opt\"" }
	}
    }

    method Configure {opt val} {
	if {$verbose(configure)} { puts "$options(-name) $self Configure $opt $val" }
	switch -- $opt {
	    -enable {
		if {$val && ! $options($opt)} {
		    puts "enabling $options(-name)"
		    $options(-factory) $options(-name) -server [$self cget -server]
		    $block configure -internal $options(-name)
		    [$self cget -control] enable $options(-name)
		} elseif { ! $val && $options($opt)} {
		    puts "disabling $options(-name)"
		    [$self cget -control] disable $options(-name)
		    $block configure -internal {}
		    rename $options(-name) {}
		}
	    }
	    default { error "unknown configure option \"$opt\"" }
	}
	set options($opt) $val
    }

    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
    
    method Prefix {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget -name]
	}
    }
}
