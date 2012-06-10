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
# a composite component that implements a receiver
#
package provide sdrkit::tx 1.0.0

package require snit
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::tx {
    option -name tx
    option -type dsp
    option -title {TX}
    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -options {}
    option -sub-components {
	af-gain {AF Gain} gain {}
	-af-real {Real part} real {}
	-af-wave {Wave shape} waveshape {}
	af-mtr1 {Wave shape meter} meter-tap {}
	-af-dcb {DC Block} dc-block {}
	-af-sql {Squelch} squelch {}
	-af-geq {Graphic EQ} graphic-eq {}
	af-mtr2 {Graphic EQ meter} meter-tap {}
	af-lvlr {Leveler} agc {}
	af-mtr3 {Leveler meter} meter-tap {}
	-af-spch {Speech processor} speech-processor {}
	af-mtr4 {Speech processor meter} meter-tap {}
	af-mod {Modulation} mod {}
	if-bpf {Bandpass} filter-overlap-save {}
	-if-comp {Compander} compand {}
	if-mtr5 {Compander meter} meter-tap {}
	if-sp1 {TX Spectrum} spectrum-tap {}
	if-lo {LO Mixer} lo-mixer {}
	rf-iqb {IQ Balance} iq-balance {}
	rf-gain {RF Level} gain {}
	rf-mtr6 {RF Power meter} meter-tap {}
    }
    option -port-connections {
	{} in-ports af-gain in-ports
	af-gain out-ports af-real in-ports
	af-real out-ports af-wave in-ports
	af-wave out-ports af-mtr1 in-ports
	af-mtr1 out-ports af-dcb in-ports
	af-dcb out-ports af-sql in-ports
	af-sql out-ports af-geq in-ports
	af-geq out-ports af-mtr2 in-ports
	af-mtr2 out-ports af-lvlr in-ports
	af-lvlr out-ports af-mtr3 in-ports
	af-mtr3 out-ports af-spch in-ports
	af-spch out-ports af-mtr4 in-ports
	af-mtr4 out-ports af-mod in-ports
	af-mod out-ports if-bpf in-ports
	if-bpf out-ports if-comp in-ports
	if-comp out-ports if-mtr5 in-ports
	if-mtr5 out-ports if-sp1 in-ports
	if-sp1 out-ports if-lo in-ports
	if-lo out-ports rf-iqb in-ports
	rf-iqb out-ports rf-gain in-ports
	rf-gain out-ports rf-mtr6 in-ports
	rf-mtr6 out-ports {} out-ports
    }
    option -opt-connections {
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -tx-source {}
    option -tx-sink {}

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    constructor {args} { $self configure {*}$args }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method build-parts {} { if {$options(-window) eq {none}} { $self build } }
    method build-ui {} { if {$options(-window) ne {none}} { $self build } }
    method build {} {
	set w $options(-window)
	if {$w ne {none}} {
	    if {$w eq {}} { set pw . } else { set pw $w }
	}
	foreach {name title command args} $options(-sub-components) {
	    if {[string match -* $name]} {
		# placeholder component, replace with spectrum tap
		set name [string range $name 1 end]
		set command spectrum-tap
	    }
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		sdrtk::clabelframe $w.$name -label $title
		if {$command ni {meter-tap spectrum-tap}} {
		    # only display real working components
		    grid $w.$name -sticky ew
		}
		set data($name-enable) 0
		ttk::checkbutton $w.$name.enable -text {} -variable [myvar data($name-enable)] -command [mymethod Enable $name]
		ttk::frame $w.$name.container
		$self sub-component $w.$name.container $name sdrkit::$command {*}$args
		grid $w.$name.enable $w.$name.container
		grid columnconfigure $w.$name 1 -weight 1 -minsize [tcl::mathop::+ {*}$options(-minsizes)]
	    }
	}
	if {$w ne {none}} {
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$options(-minsizes)] -weight 1
	}
    }
    proc match-ports {ports1 ports2} {
	switch "$ports1 to $ports2" {
	    {out_i out_q to out_i out_q midi_out} {
		return {{out_i out_q} {out_i out_q}}
	    }
	    {midi_out to out_i out_q midi_out} {
		return {{midi_out} {midi_out}}
	    }
	    default {
		error "need to match $ports1 to $ports2"
	    }
	}
    }
    method resolve {} {
	# need to match midi vs audio
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    set ports1 [$options(-component) $ports1 $name1]
	    set ports2 [$options(-component) $ports2 $name2]
	    if {[llength $ports1] != [llength $ports2]} {
		lassign [match-ports $ports1 $ports2] ports1 ports2
	    }
	    foreach p1 $ports1 p2 $ports2 {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	foreach {name1 opts1 name2 opts2} $options(-opt-connections) {
	}
    }
    method is-active {} { return 1 }
    method activate {} {}
    method deactivate {} {}
    method Enable {name} {
	if {$data($name-enable)} {
	    $options(-component) part-enable $options(-name)-$name
	} else {
	    $options(-component) part-disable $options(-name)-$name
	}
    }
}

