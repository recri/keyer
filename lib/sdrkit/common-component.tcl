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

#
# common component interface for all components
#
package provide sdrkit::common-component 1.0.0

package require snit

package require sdrkit::label-label
package require sdrkit::label-spinbox
package require sdrkit::label-scale
package require sdrkit::label-iscale
package require sdrkit::label-radio
package require sdrkit::label-button

namespace eval sdrkit {}
namespace eval sdrkitx {}

##
## the common snit sub-components cover the methods and options
## which individual components don't care about
## or want to share implementations
## this implementation defines the default implementations of everything
## use this by declaring in the body:
##	component common
##	delegate method * to common
## and in constructor
##	install common using sdrkit::common-component %AUTO% -name $options(-name) -parent $self -options [myvar options]
##
## this common implementation requires no options
##

snit::type sdrkit::common-component {    
    option -options {}
    option -name {}
    option -parent {}

    variable data -array {
	activated 0
	enabled 0
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
    }

    ## these are services to simplify the parent component
    method window {w opt wtype opts myvar mycmd mydef} {
	## there are more of these to be added
	switch $wtype {
	    spinbox { sdrkit::label-spinbox $w.$opt {*}$opts -variable $myvar -command $mycmd }
	    scale { sdrkit::label-scale $w.$opt {*}$opts -variable $myvar -command $mycmd }
	    iscale { sdrkit::label-iscale $w.$opt {*}$opts -variable $myvar -command $mycmd }
	    separator { ttk::separator $w.$opt }
	    radio { sdrkit::label-radio $w.$opt {*}$opts -variable $myvar -command $mycmd -defaultvalue $mydef }
	    button { sdrkit::label-button $w.$opt {*}$opts }
	    label { sdrkit::label-label $w.$opt {*}$opts -variable $myvar }
	    default { error "unimplemented control type \"$wtype\"" }
	}
	return $w.$opt
    }

    ## these are over ridden in the parent if the defaults don't do
    # build the parts that exist independent of user interface
    method build-parts {w} {
    }
    # build a user interface
    method build-ui {w pw minsizes weights} {
    }
    # resolve connections
    method resolve {} { }
    # rewrite the connections between ports coming to this component
    method rewrite-connections-to {port candidates} { return $candidates }
    # rewrite the connections between ports coming from this component
    method rewrite-connections-from {port candidates} { return $candidates }
    # identify the input/output port complementary to this output/input port
    method port-complement {port} {
	# may need alt_* defined, too
	switch -exact $port {
	    in_i { return {out_i} }
	    in_q { return {out_q} }
	    out_i { return {in_i} }
	    out_q { return {in_q} }
	    midi_in { return {midi_out} }
	    midi_out { return {midi_in} }
	    default { error "unknown port \"$port\"" }
	}
    }
    # is this component active?
    method is-active {} { return $data(activated) }
    # activate this component
    method activate {} { set data(activated) 1 }
    # deactivate this component
    method deactivate {} { set data(activated) 0 }
    # will this component do something given its parameter values
    method is-needed {} { return 1 }
    # make this option value meet the constraints on its values
    method Constrain {opt val} { return $val }
    # is this component busy getting its act together?
    method is-busy {} { return 0 }    
}
