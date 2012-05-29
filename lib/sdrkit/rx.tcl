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
package provide sdrkit::rx 1.0.0

package require snit
package require sdrtk::clabelframe

namespace eval sdrkit {}

snit::type sdrkit::rx {
    option -name rx
    option -type dsp
    option -title {RX}
    option -in-ports {in_i in_q}
    option -out-ports {out_i out_q}
    option -in-options {
	-mode -rf-gain -iq-swap -iq-delay -iq-correct -lo-freq -agc-mode -af-gain
	-cw-freq -bpf-width -bpf-offset
    }
    option -out-options {
	-mode -rf-gain -iq-swap -iq-delay -iq-correct -lo-freq -agc-mode -af-gain
	-low -high
    }

    option -mode -default CWU -configuremethod Configure
    option -rf-gain -default 0 -configuremethod Configure
    option -iq-swap -default 0 -configuremethod Configure
    option -iq-delay -default 0 -configuremethod Configure
    option -iq-correct -default 0 -configuremethod Configure
    option -lo-freq -default 10000 -configuremethod Configure
    option -cw-freq -default 400 -configuremethod Configure
    option -bpf-width -default 200 -configuremethod Configure
    option -bpf-offset -default 150 -configuremethod Configure
    option -agc-mode -default medium -configuremethod Configure
    option -af-gain -default 0 -configuremethod Configure
    option -low -default -100 -configuremethod Configure
    option -high -default 100 -configuremethod Configure

    option -sub-components {
	spectrum {Spectrum} spectrum {}
	rf-gain {RF Gain} gain {}
	rf-iq-swap {IQ Swap} iq-swap {}
	rf-iq-delay {IQ Delay} iq-delay {}
	rf-sp1 {Spectrum Semi-raw} spectrum-tap {}
	-rf-nb1 {Noiseblanker} noiseblanker {}
	-rf-nb2 {SDRom Noiseblanker} sdrom-noiseblanker {}
	rf-iq-correct {IQ Correct} iq-correct {}
	if-sp2 {Spectrum Pre-filter} spectrum-tap {}
	if-lo-mixer {LO Mixer} lo-mixer {}
	if-bpf {BP Filter} filter-overlap-save {}
	af-mt1 {Meter Post-filter} meter-tap {}
	af-sp3 {Spectrum Post-filter} spectrum-tap {}
	-af-compand {Compander} compand {}
	af-agc {AGC} agc {}
	af-sp4 {Spectrum Post-AGC} spectrum-tap {}
	af-demod {Demodulation} demod {}
	-af-squelch {Squelch} squelch {}
	-af-spot {Spot Tone} spot {}
	-af-graphic-eq {Graphic EQ} graphic-eq {}
	af-gain {AF Gain} gain {}
    }

    option -parts-enable { rf-iq-correct if-lo-mixer if-bpf af-agc spectrum }

    option -port-connections {
	{} in-ports rf-gain in-ports
	rf-gain out-ports rf-iq-swap in-ports
	rf-iq-swap out-ports rf-iq-delay in-ports
	rf-iq-delay out-ports rf-sp1 in-ports
	rf-sp1 out-ports rf-nb1 in-ports
	rf-nb1 out-ports rf-nb2 in-ports
	rf-nb2 out-ports rf-iq-correct in-ports
	rf-iq-correct out-ports if-sp2 in-ports
	if-sp2 out-ports if-lo-mixer in-ports
	if-lo-mixer out-ports if-bpf in-ports
	if-bpf out-ports af-mt1 in-ports
	af-mt1 out-ports af-sp3 in-ports
	af-sp3 out-ports af-compand in-ports
	af-compand out-ports af-agc in-ports
	af-agc out-ports af-sp4 in-ports
	af-sp4 out-ports af-demod in-ports
	af-demod out-ports af-squelch in-ports
	af-squelch out-ports af-spot in-ports
	af-spot out-ports af-graphic-eq in-ports
	af-graphic-eq out-ports af-gain in-ports
	af-gain out-ports {} out-ports
	if-sp2 out-ports spectrum in-ports
    }

    option -opt-connections {
	..	-mode		.		-mode
	..	-rx-rf-gain	.		-rf-gain
	..	-iq-swap	.		-iq-swap
	..	-iq-delay	.		-iq-delay
	..	-iq-correct	.		-iq-correct
	..	-lo-freq	.		-lo-freq
	..	-bpf-width	.		-bpf-width
	..	-bpf-offset	.		-bpf-offset
	..	-agc-mode	.		-agc-mode
	..	-rx-af-gain	.		-af-gain
	.	-rf-gain	.-rf-gain	-gain
	.	-iq-swap	.-rf-iq-swap	-swap
	.	-iq-delay	.-rf-iq-delay	-delay
	.	-iq-correct	.-rf-iq-correct	-mu
	.	-lo-freq	.-if-lo-mixer	-freq
	.	-low		.-if-bpf	-low
	.	-high		.-if-bpf	-high
	.	-agc-mode	.-af-agc	-mode
	.	-af-gain	.-af-gain	-gain
    }

    option -server default
    option -component {}

    option -window {}
    option -minsizes {100 200}
    option -weights {1 3}

    option -rx-source {}
    option -rx-sink {}

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
    method resolve-port-name {pair} {
	return [lindex [$options(-component) port-filter "*$pair"] 0]
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
	if {$options(-rx-source) ne {}} {
	    # puts "rx source $options(-rx-source)"
	    foreach src $options(-rx-source) dst {in_i in_q} {
		lassign [$self resolve-port-name [split $src :]] sname sport
		# puts "rx $options(-component) connect-ports $sname $sport $options(-name) $dst"
		$options(-component) connect-ports $sname $sport $options(-name) $dst		
	    }
	}
	if {$options(-rx-sink) ne {}} {
	    # puts "rx sink $options(-rx-sink)"
	    foreach src {out_i out_q} dst $options(-rx-sink) {
		lassign [$self resolve-port-name [split $dst :]] dname dport
		# puts "rx $options(-component) connect-ports $options(-name) $src $dname $dport"
		$options(-component) connect-ports $options(-name) $src $dname $dport
	    }
	}
	# puts "resolve options(-name) is $options(-name)"
	foreach {name1 opt1 name2 opt2} $options(-opt-connections) {
	    set ename1 [$self Expand-name $name1]
	    set ename2 [$self Expand-name $name2]
	    # puts "$name1 $opt1 $name2 $opt2 -> $options(-component) connect-options $ename1 $opt1 $ename2 $opt2"
	    $options(-component) connect-options $ename1 $opt1 $ename2 $opt2
	}
	foreach name $options(-parts-enable) {
	    set data($name-enable) 1
	    $self Enable $name
	}
    }
    method Expand-name {name} {
	if {$name eq {..}} { return [[$options(-component) get-parent] cget -name] }
	if {$name eq {.}} { return $options(-name) }
	if {[string first . $name] == 0} { return [regsub {^.} $name $options(-name)] }
	return $name
    }
    method FilterConfigure {opt val} {
    }
    method Configure {opt val} {
	set options($opt) $val
	switch -- $opt {
	    -bpf-width -
	    -bpf-offset -
	    -cw-freq -
	    -mode {
		switch $options(-mode) {
		    CWU {
			if {$opt in {-cw-freq -bpf-width -mode}} {
			    $self configure -low [expr {$options(-cw-freq)-$options(-bpf-width)/2}] -high [expr {$options(-cw-freq)+$options(-bpf-width)/2}]
			}
		    }
		    CWL {
			if {$opt in {-cw-freq -bpf-width -mode}} {
			    $self configure -low [expr {-$options(-cw-freq)-$options(-bpf-width)/2}] -high [expr {-$options(-cw-freq)+$options(-bpf-width)/2}]
			}
		    }
		    AM - SAM - FM {
			if {$opt in {-bpf-width -mode}} {
			    $self configure -low [expr {-$options(-bpf-width)/2}] -high [expr {+$options(-bpf-width)/2}]
			}
		    }
		    DIGU - USB {
			if {$opt in {-bpf-offset -bpf-width -mode}} {
			    $self configure [expr {$options(-bpf-offset)}] $low -high [expr {$options(-bpf-offset)+$options(-bpf-width)}]
			}
		    }
		    DIGL - LSB {
			if {$opt in {-bpf-offset -bpf-width -mode}} {
			    $self configure -low [expr {-$options(-bpf-offset)-$options(-bpf-width)}] -high [expr {-$options(-bpf-offset)}]
			}
		    }
		    default { error "unanticipated mode \"$options(-mode)\"" }
		}

	    }
	    -lo-freq {
		$options(-component) report $opt [expr {-$val}]
	    }
	    -rf-gain -
	    -iq-swap -
	    -iq-delay -
	    -agc-mode -
	    -af-gain -
	    -low -
	    -high {
		$options(-component) report $opt $val
	    }
	    default {
		error "unanticipated option \"$opt\""
	    }
	}
    }
    method Enable {name} {
	if {$data($name-enable)} {
	    $options(-component) part-enable $options(-name)-$name
	} else {
	    $options(-component) part-disable $options(-name)-$name
	}
    }
}

