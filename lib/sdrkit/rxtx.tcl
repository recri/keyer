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
# a composite component that builds a transceiver
#
package provide sdrkit::rxtx 1.0.0

package require snit
package require sdrkit::common-component

namespace eval sdrkit {}

snit::type sdrkit::rxtx {
    option -name rxtx
    option -type dsp
    option -server default
    option -component {}

    option -in-ports {}
    option -out-ports {}
    option -options {
	-mox -freq -tune-rate -lo-freq -lo-tune-rate -cw-freq
	-mode -agc-mode -iq-correct -iq-swap -iq-delay
	-rx-rf-gain -rx-af-gain -hw-freq -rx-lo-freq
	-bpf-width -bpf-offset -bpf-low -bpf-high
	-band -channel -band-low -band-high
    }

    # the transmit button
    option -mox -default 0 -configuremethod Configure
    # the tuned frequency displayed, the carrier frequency
    option -freq -default 7050000 -configuremethod Configure
    # the frequency tuning rate 
    option -tune-rate -default 50 -configuremethod Configure
    # the local oscillator offset mixed to/from baseband
    option -lo-freq -default 10000 -configuremethod Configure
    # the receiver local oscillator offset
    option -rx-lo-freq -default -10000 -configuremethod Configure
    # the local oscillator tuning rate 
    option -lo-tune-rate -default 50 -configuremethod Configure
    # the cw tone offset, how far above or below the carrier we tune on receive
    option -cw-freq -default 400 -configuremethod Configure
    # the mode of operation (no mode split)
    option -mode -default CWU -configuremethod Configure
    # the agc mode of operation
    option -agc-mode -default medium -configuremethod Configure
    # the iq needs to be swapped (RX, need TX)
    option -iq-swap -default 0 -configuremethod Configure
    # the iq needs a sample delay (RX)
    option -iq-delay -default 0 -configuremethod Configure
    # the iq correct learning rate
    option -iq-correct -default 0 -configuremethod Configure
    # the band pass filter width
    option -bpf-width -default 200 -configuremethod Configure
    # the band pass filter offset
    option -bpf-offset -default 150 -configuremethod Configure
    # the band pass filter low cutoff
    option -bpf-low -default 200 -configuremethod Configure
    # the band pass filter high cutoff
    option -bpf-high -default 600 -configuremethod Configure
    # the receiver rf gain
    option -rx-rf-gain -default 0 -configuremethod Configure
    # the receiver af gain
    option -rx-af-gain -default 0 -configuremethod Configure
    # the hardware frequency
    option -hw-freq -default [expr {7050000-10000-400}] -configuremethod Configure
    # the band selection
    option -band -default {} -configuremethod Configure
    # the channel selection
    option -channel -default {} -configuremethod Configure
    # the band low frequency
    option -band-low -default {} -configuremethod Configure
    # the band high frequency
    option -band-high -default {} -configuremethod Configure

    option -sub-components {
	band {Band} band-select {}
	ctl {Ctl} rxtx-control {}
	phys {Phys} physical-ports {}
	hw {HW} hardware {}
	rx {RX} rx {}
	tx {TX} tx {}
	key {Key} keyer {}
	spec {Spec} spectrum {}
    }

    option -sub-controls {
	mox radio {-format {MOX} -values {0 1} -labels {Off On}}
	freq scale {-format {Freq %.0f Hz} -from 1000000 -to 30000000}
	lo-freq scale {-format {LO %.0f Hz}  -from -24000 -to 24000}
	cw-freq scale {-format {CW Tone %.0f Hz} -from 100 -to 1000}
	mode radio {-format {Mode} -values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}}
	bpf-width scale {-format {Width %.0f Hz} -from 10 -to 50000}
	bpf-offset scale {-format {Offset %.0f Hz} -from 10 -to 1000}
    }

    option -port-connections {
    }

    #
    # these connections are all reciprocal
    #
    option -opt-connections {

	rxtx	-mode		rxtx-rx-af-demod	-mode
	rxtx	-rx-rf-gain	rxtx-rx-rf-gain		-gain
	rxtx	-iq-swap	rxtx-rx-rf-iq-swap	-swap
	rxtx	-iq-delay	rxtx-rx-rf-iq-delay	-delay
	rxtx	-iq-correct	rxtx-rx-rf-iq-correct	-mu
	rxtx	-rx-lo-freq	rxtx-rx-if-lo-mixer	-freq
	rxtx	-bpf-low	rxtx-rx-if-bpf		-low
	rxtx	-bpf-high	rxtx-rx-if-bpf		-high
	rxtx	-agc-mode	rxtx-rx-af-agc		-mode
	rxtx	-rx-af-gain	rxtx-rx-af-gain		-gain

	rxtx	-mode		rxtx-dial		-mode
	rxtx	-agc-mode	rxtx-dial		-agc-mode
	rxtx	-freq		rxtx-dial		-freq
	rxtx	-tune-rate	rxtx-dial		-tune-rate
	rxtx	-lo-freq	rxtx-dial		-lo-freq
	rxtx	-lo-tune-rate	rxtx-dial		-lo-tune-rate
	rxtx	-cw-freq	rxtx-dial		-cw-freq
	rxtx	-bpf-width	rxtx-dial		-bpf-width
	rxtx	-rx-af-gain	rxtx-dial		-rx-af-gain
	rxtx	-rx-rf-gain	rxtx-dial		-rx-rf-gain

	rxtx	-mode		rxtx-spec		-mode
	rxtx	-freq		rxtx-spec		-freq
	rxtx	-lo-freq	rxtx-spec		-lo-freq
	rxtx	-cw-freq	rxtx-spec		-cw-freq
	rxtx	-bpf-low	rxtx-spec		-bpf-low
	rxtx	-bpf-high	rxtx-spec		-bpf-high
	rxtx	-band-low	rxtx-spec		-band-low
	rxtx	-band-high	rxtx-spec		-band-high

	rxtx	-band		rxtx-band		-band
	rxtx	-channel	rxtx-band		-channel
    }

    option -rx-source {}
    option -rx-sink {}
    option -rx-enable {}
    option -rx-activate {}
    option -tx-source {}
    option -tx-sink {}
    option -keyer-source {}
    option -keyer-sink {}
    option -physical true
    option -hardware {}

    option -parts-enable { spec meter }

    option -initialize {
	-freq
	-tune-rate
	-lo-freq
	-lo-tune-rate
	-cw-freq
	-mode
	-agc-mode
	-iq-swap
	-iq-delay
	-iq-correct
	-bpf-width
	-bpf-offset
	-rx-rf-gain
	-rx-af-gain
    }

    variable data -array {
	parts {}
	active 0
    }

    component common
    delegate method * to common

    constructor {args} {
	$self configure {*}$args
	install common using sdrkit::common-component %AUTO%
    }
    destructor { $options(-component) destroy-sub-parts $data(parts) }
    method sub-component {window name subsub args} {
	lappend data(parts) $name
	$options(-component) sub-component $window $name $subsub {*}$args
    }
    method build-parts {w} { if {$w eq {none}} { $self build $w {} {} {} } }
    method build-ui {w pw minsizes weights} { if {$w ne {none}} { $self build $w $pw $minsizes $weights } }
    method build {w pw minsizes weights} {
	if {$w ne {none}} {
	    $self sub-component $w dial sdrkit::dial
	    $self sub-component $w meter sdrkit::meter
	    package require sdrtk::cnotebook
	    sdrtk::cnotebook $w.note
	}
	if {0} {
	    if {$w eq {none}} {
		$self sub-component none ports sdrkit::physical-ports -physical $options(-physical)
	    } else {
		set name ports
		set title Ports
		$self sub-component [ttk::frame $w.note.$name] $name sdrkit::physical-ports -physical $options(-physical)
		$w.note add $w.note.$name -text $title
	    }
	    $options(-component) part-configure $options(-name)-ports -enable true -activate true
	}
	if {0} {
	    if {$w eq {none}} {
		$self sub-component none hardware sdrkit::hardware -hardware $options(-hardware)
	    } else {
		set name hw
		set title HW
		$self sub-component [ttk::frame $w.note.$name] hardware sdrkit::hardware -hardware $options(-hardware)
		$w.note add $w.note.$name -text $title
	    }
	}
	foreach {name title command args} $options(-sub-components) {
	    switch $name {
		band {}
		ctl {}
		phys { lappend args -physical $options(-physical) }
		hw { lappend args -hardware $options(-hardware) }
		rx { lappend args -rx-source $options(-rx-source) -rx-sink $options(-rx-sink) }
		tx { lappend args -tx-source $options(-tx-source) -tx-sink $options(-tx-sink) }
		key { lappend args -keyer-source $options(-keyer-source) -keyer-sink $options(-keyer-sink) }
		spec {}
		meter {}
		default { error "rxtx::build-ui unknown name \"$name\"" }
	    }
	    if {$w eq {none}} {
		$self sub-component none $name sdrkit::$command {*}$args
	    } else {
		$self sub-component [ttk::frame $w.note.$name] $name sdrkit::$command {*}$args
		$w.note add $w.note.$name -text $title
	    }
	}
	if {$w ne {none}} {
	    grid $w.dial -sticky nsew -row 0
	    grid $w.meter -sticky ew -row 1
	    grid [ttk::frame $w.buttons] -sticky ew -row 2
	    sdrtk::radiomenubutton $w.buttons.mode -values {CWU CWL USB LSB AM SAM FMN DSB DIGU DIGL} \
		-variable [myvar data(mode)] -command [mymethod SetMode] -defaultvalue $options(-mode)
	    sdrtk::radiomenubutton $w.buttons.bpfwidth -values {100 250 500 1000 2500 5000 10000 25000 50000} \
		-variable [myvar data(bpfwidth)] -command [mymethod SetBpfWidth] -defaultvalue $options(-bpf-width)
	    pack $w.buttons.mode $w.buttons.bpfwidth -side left
	    grid $w.note -sticky nsew -row 3
	    grid columnconfigure $pw 0 -minsize [tcl::mathop::+ {*}$minsizes] -weight 1
	}
    }

    method resolve {} {
	# make the ports connect
	foreach {name1 ports1 name2 ports2} $options(-port-connections) {
	    set name1 [string trim "$options(-name)-$name1" -]
	    set name2 [string trim "$options(-name)-$name2" -]
	    foreach p1 [$options(-component) $ports1 $name1] p2 [$options(-component) $ports2 $name2] {
		$options(-component) connect-ports $name1 $p1 $name2 $p2
	    }
	}
	# connect specified controls
	foreach {name1 opt1 name2 opt2} $options(-opt-connections) {
	    $options(-component) connect-options $name1 $opt1 $name2 $opt2
	    $options(-component) connect-options $name2 $opt2 $name1 $opt1
	}
	# find the hardware frequency control
	# activate the hardware
	if {$options(-hardware) ne {}} {
	    foreach pair [$options(-component) opt-filter {rxtx-hw-* *-freq}] {
		$options(-component) opt-connect [list rxtx -hw-freq] $pair
	    }
	    foreach part [$options(-component) part-filter {rxtx-hardware*}] {
		#puts "$part enabled=[$options(-component) part-is-enabled $part] active=[$options(-component) part-is-active $part]"
		if { ! [$options(-component) part-is-active $part]} {
		    $options(-component) part-activate $part
		}
		#puts "$part enabled=[$options(-component) part-is-enabled $part] active=[$options(-component) part-is-active $part]"
	    }
	}
	# loop back remaining controls,
	# other than our own which will infinitely recurse if looped back
	foreach pair [$options(-component) opt-filter {rxtx-* *}] {
	    if {[$options(-component) opt-connections-from $pair] eq {} &&
		[$options(-component) opt-connections-to $pair] eq {}} {
		# a control with no connections gets looped back
		# puts "$options(-component) opt-connect $pair $pair"
		$options(-component) opt-connect $pair $pair
	    }
	}
	if {$options(-rx-enable) ne {} && $options(-rx-enable)} {
	    $options(-component) part-enable $options(-name)-rx
	}
	if {$options(-rx-activate) ne {} && $options(-rx-activate)} {
	    $options(-component) part-activate $options(-name)-rx
	}
	foreach name $options(-parts-enable) {
	    set data($name-enable) 1
	    $self Enable $name
	}
	after 50 [mymethod Initialize]
    }
    method SetMode {val} { $self configure -mode $val }
    method SetBpfWidth {val} { $self configure -bpf-width $val }
    method Initialize {} {
	foreach opt $options(-initialize) {
	    $self Configure $opt $options($opt)
	    $self Set $opt $options($opt)
	}
    }
    method ComponentConfigure {opt val} {
    }

    # we receive change notifications from remote components via Configure
    # we compute the net result and fire the results via Set
    # this is backwards of the way this works for the remote components
    method Configure {opt val} {
	set val [$self Constrain $opt $val]
	set old $options($opt)
	set options($opt) $val
	switch -- $opt {
	    -mode {
		set data(mode) $val
		switch $old {
		    CWU { $self configure -freq [expr {$options(-freq)-$options(-cw-freq)}] }
		    CWL { $self configure -freq [expr {$options(-freq)+$options(-cw-freq)}] }
		}
		switch $val {
		    CWU { $self configure -freq [expr {$options(-freq)+$options(-cw-freq)}] }
		    CWL { $self configure -freq [expr {$options(-freq)-$options(-cw-freq)}] }
		}
		$self MakeFilter
		$self Set $opt $val
	    }
	    -cw-freq {
		switch $options(-mode) {
		    CWU {
			$self configure -freq [expr {$options(-freq)-$old+$val}]
			$self MakeFilter
		    }
		    CWL {
			$self configure -freq [expr {$options(-freq)+$old-$val}]
			$self MakeFilter
		    }
		}
		$self Set $opt $val
	    }
	    -lo-freq {
		# lo-freq is the offset from the hw-freq for the tuned carrier, or offset +/- cw-freq
		$self configure -freq [expr {$options(-freq)+$val-$old}] -rx-lo-freq [expr {-$val}]
		$self Set $opt $val
	    }
	    -freq {
		switch $options(-mode) {
		    CWU { $self configure -hw-freq [expr {$options(-freq)-$options(-lo-freq)-$options(-cw-freq)}] }
		    CWL { $self configure -hw-freq [expr {$options(-freq)-$options(-lo-freq)+$options(-cw-freq)}] }
		    default  { $self configure -hw-freq [expr {$options(-freq)-$options(-lo-freq)}] }
		}
		$self Set -freq $val
	    }
	    -band {
		lassign [sdrutil::band-data-band-range-hertz {*}$val] low high
		$self configure -freq [expr {($low+$high)/2}] -band-low $low -band-high $high
	    }
	    -channel {
		$self configure -freq [sdrutil::band-data-channel-freq-hertz {*}$val]
	    }
	    -bpf-width {
		set data(bpf-width) $val
		$self Set $opt $val
		$self MakeFilter
	    }
	    -bpf-offset {
		$self Set $opt $val
		$self MakeFilter
	    }
	    -agc-mode {
		if {$val eq {off}} {
		    if {[$options(-component) part-is-enabled rxtx-rx-af-agc]} {
			$options(-component) part-disable rxtx-rx-af-agc
		    }
		} else {
		    if { ! [$options(-component) part-is-enabled rxtx-rx-af-agc]} {
			$options(-component) part-enable rxtx-rx-af-agc
		    }
		    $self Set -agc-mode $val
		}
	    }
	    -band-low -
	    -band-high -
	    -rx-lo-freq -
	    -rx-rf-gain -
	    -rx-af-gain -
	    -hw-freq -
	    -tune-rate -
	    -lo-tune-rate -
	    -iq-swap -
	    -iq-delay -
	    -iq-correct -
	    -bpf-low -
	    -bpf-high {
		$self Set $opt $val
	    }
	    default {
		puts "default option handler $opt $val"
		$self Set $opt $val
	    }
	}
    }

    method MakeFilter {} {
	set wid $options(-bpf-width)
	set off $options(-bpf-offset)
	switch $options(-mode) {
	    CWU { $self configure -bpf-low [expr {$options(-cw-freq)-$wid/2}] -bpf-high [expr {$options(-cw-freq)+$wid/2}] }
	    CWL { $self configure -bpf-low [expr {-$options(-cw-freq)-$wid/2}] -bpf-high [expr {-$options(-cw-freq)+$wid/2}] }
	    DIGU - USB { $self configure -bpf-low $off -bpf-high [expr {$off+$wid}] }
	    DIGL - LSB { $self configure -bpf-low [expr {-$off-$wid}] -bpf-high [expr {-$off}] }
	    AM - SAM - DSB - FMN { $self configure -bpf-low [expr {-$wid/2}] -bpf-high [expr {$wid/2}] }
	    default { error "unanticipated mode \"$options(-mode)\" in configure $opt $val" }
	}
    }

    method Set {opt val} { $options(-component) report $opt $val }
    method Enable {name} {
	if {$data($name-enable)} {
	    $options(-component) part-enable $options(-name)-$name
	} else {
	    $options(-component) part-disable $options(-name)-$name
	}
    }
}
