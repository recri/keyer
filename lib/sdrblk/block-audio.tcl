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

package provide sdrblk::block-audio 1.0.0

package require snit
package require sdrblk::block-graph
package require sdrblk::block-control

#
# a snit type to wrap a single sdrkit audio module
#
::snit::type ::sdrblk::block-audio {

    typevariable verbose -array {connect 0 construct 0 destroy 0 configure 0 control 0 controlget 0 enable 0}

    component graph -public graph
    component control

    delegate method control to control
    delegate method controls to control
    delegate method controlget to control

    option -partof -readonly yes
    option -server -readonly yes
    option -control -readonly yes
    option -prefix -readonly yes
    option -suffix -readonly yes
    option -name -readonly yes

    option -enable -default no -configuremethod Enable

    option -factory -readonly yes
    option -controls -readonly yes

    delegate option -type to graph
    delegate option -inport to graph
    delegate option -outport to graph

    constructor {args} {
        $self configure {*}$args
	if {$verbose(construct)} { puts "$options(-name) $self constructor $args" }
	set options(-prefix) [$options(-partof) cget -name]
	set options(-server) [$options(-partof) cget -server]
	set options(-control) [$options(-partof) cget -control]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	install graph using ::sdrblk::block-graph %AUTO% -partof $self -type internal -internal-inputs {in_i in_q} -internal-outputs {out_i out_q}
	install control using ::sdrblk::block-control %AUTO% -partof $self -name $options(-name) -control $options(-control)
    }

    destructor {
	if {$verbose(destroy)} { puts "$options(-name) $self destructor" }
	catch {$control destroy}
        catch {$graph destroy}
	catch {rename $options(-name) {}}
    }

    method Enable {opt val} {
	if { ! [$options(-partof) cget -enable]} {
	    error "parent of $options(-name) is not enabled"
	}
	if {$val && ! $options($opt)} {
	    if {$verbose(enable)} { puts "enabling $options(-name)" }
	    $options(-factory) ::sdrblk::$options(-name) -server $options(-server)
	    $self graph configure -internal $options(-name)
	} elseif { ! $val && $options($opt)} {
	    if {$verbose(enable)} { puts "disabling $options(-name)" }
	    $self graph configure -internal {}
	    rename ::sdrblk::$options(-name) {}
	}
	set options($opt) $val
    }
}
