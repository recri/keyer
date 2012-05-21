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
# a composite component which switches between demodulation implementations
#
package provide sdrkit::demod 1.0.0

package require snit
package require sdrtk::clabelframe
package require sdrtk::radiomenubutton

namespace eval sdrkit {}

snit::type sdrkit::demod {
    option -name demod
    option -type dsp
    option -title {Demod}
    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {-demod}
    option -out-options {-demod}
    option -sub-components {
	am {AM} demod-am
	fm {FM} demod-fm
	sam {SAM} demod-sam
    }
    option -connections {
	{} in-ports am in-ports		am out-ports {} in-ports
	{} in-ports fm in-ports		fm out-ports {} out-ports
	{} in-ports sam in-ports	sam out-ports {} out-ports
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -demod none

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    constructor {args} {
	# puts "$self constructor"
	$self configure {*}$args
    }
    destructor {
	foreach name $data(parts) {
	    $option(-component) name-destroy $options(-name)-$name
	}
    }
    method resolve-parts {} {
	# need to match midi vs audio
	foreach {name1 ports1 name2 ports2} $options(-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
    }
    method build-parts {} {
	if {$options(-window) ne {none}} return
	foreach {name title command} $options(-sub-components) {
	    set data(enable-$name) 0
	    lappend data(parts) $name
	    package require sdrkit::$command
	    ::sdrkit::component ::sdrkitv::$options(-name)-$name \
		-window none \
		-server $options(-server) \
		-name $options(-name)-$name \
		-subsidiary sdrkit::$command \
		-container $options(-component) \
		-control [$options(-component) get-controller]
	}
    }
    method build-ui {} {
	if {$options(-window) eq {none}} return
	set w $options(-window)
	if {$w eq {}} { set pw . } else { set pw $w }
	
	set values {none}
	set labels {none}
	foreach {name title command} $options(-sub-components) {
	    lappend values $name
	    lappend labels $title
	    set data(window-$name) [sdrtk::clabelframe $w.$name -label $title]
	    lappend data(parts) $name
	    set data(enable-$name) 0
	    package require sdrkit::$command
	    frame $w.$name.container
	    ::sdrkit::component ::sdrkitv::$options(-name)-$name \
		-window $w.$name.container \
		-server $options(-server) \
		-name $options(-name)-$name \
		-subsidiary sdrkit::$command \
		-container $options(-component) \
		-control [$options(-component) get-controller] \
		-minsizes $options(-minsizes) \
		-weights $options(-weights)
	    grid $w.$name.container
	    grid columnconfigure $w.$name 0 -weight 1 -minsize [tcl::mathop::+ {*}$options(-minsizes)]
	}
	ttk::label $w.l -text {Demodulation} -anchor e
	sdrtk::radiomenubutton $w.s -variable [myvar options(-demod)] -values $values -labels $labels -command [mymethod Set -demod]
	grid $w.l $w.s
	foreach col {0 1} ms $options(-minsizes) wt $options(-weights) {
	    grid columnconfigure $pw $col -minsize $ms -weight $wt
	}
    }
    method is-active {} { return $data(active) }
    method activate {} {
	set data(active) 1
	foreach part $data(parts) {
	}
    }
    method deactivate {} {
	set data(active) 1
	foreach part $data(parts) {
	}
    }
    method Set {opt name} {
	# find deselected component
	set exname {none}
	foreach part $data(parts) {
	    if {$data(enable-$part)} {
		if {$exname ne {none}} { error "multiple selected keyers $part and $exname" }
		set exname $part
	    }
	}
	# enable selected component if any
	if {$name ne {none}} {
	    set data(enable-$name) 1
	    $options(-component) part-enable $options(-name)-$name
	}
	# disable deselected keyer
	if {$exname ne {none}} {
	    set data(enable-$exname) 0
	    $options(-component) part-disable $options(-name)-$exname
	}
	# deal with ui details
	set w $options(-window)
	# determine if ui details exist
	if {$w ne {none}} {
	    # remove deselected keyer ui
	    if {$exname ne {none}} {
		grid forget $data(window-$exname)
	    }
	    # install selected keyer ui
	    if {$name ne {none}} {
		grid $data(window-$name) -row 1 -column 0 -columnspan 2 -sticky ew
	    }
	}
    }
}

