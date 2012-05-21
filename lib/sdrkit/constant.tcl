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
# a constant component
#
package provide sdrkit::constant 1.0.0

package require snit
package require sdrtcl::constant

namespace eval sdrkit {}
namespace eval sdrkitx {}

snit::type sdrkit::constant {    
    option -name sdr-constant
    option -type jack
    option -server default
    option -component {}

    option -window none
    option -title Constant
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {}
    option -out-ports {out_i out_q}
    option -in-options {-real -imag}
    option -out-options {}

    option -real -default 0.0 -configuremethod Configure
    option -imag -default 0.0 -configuremethod Configure

    variable data -array {
	format-real {real %.4f}
	format-imag {imag %.4f}
    }

    constructor {args} {
	$self configure {*}$args
    }
    destructor {
	catch {::sdrkitx::$options(-name) deactivate}
	catch {rename ::sdrkitx::$options(-name) {}}
    }
    method build-parts {} {
	sdrtcl::constant ::sdrkitx::$options(-name) -server $options(-server) -real $options(-real) -imag $options(-imag)
    }
    method build-ui {} {
	set w $options(-window)
	if {$w eq {none}} return
	if {$w eq {}} { set pw . } else { set pw $w }
	
	foreach l {real imag} {
	    ttk::label $w.$l-l -textvar [myvar data(label-$l)] -width 10 -anchor e
	    ttk::scale $w.$l-s -from -2 -to 2 -command [mymethod Set -$l] -variable [myvar options(-$l)]
	    $self Set -$l $options(-$l)
	    grid $w.$l-l $w.$l-s -sticky ew
	}

	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }
    method is-needed {} { return 1 }

    method is-active {} { return [::sdrkitx::$options(-name) is-active] }
    method activate {} { ::sdrkitx::$options(-name) activate }
    method deactivate {} { ::sdrkitx::$options(-name) deactivate }

    method OptionConstrain {opt val} { return $val }

    method OptionConfigure {opt val} { set options($opt) $val }
    method ComponentConfigure {opt val} { ::sdrkitx::$options(-name) configure $opt $val }
    method LabelConfigure {opt val} { set data(label$opt) [format $data(format$opt) $val] }
    method ControlConfigure {opt val} { $options(-component) report $opt $val }

    method Configure {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
    }

    method Set {opt val} {
	set val [$self OptionConstrain $opt $val]
	$self OptionConfigure $opt $val
	$self ComponentConfigure $opt $val
	$self LabelConfigure $opt $val
	$self ControlConfigure $opt $val
    }
    method Changed {opt} { $self Set $opt $options($opt) }

}
