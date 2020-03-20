#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
package provide sdrtk::hl-test 1.0.0

#
# hermes lite 2 test widget
# principally to time the round trip of cw
# use ~/keyer/patch/hl-test.patch in qjackctl
# run ~/keyer/bin/keyer key hl hl-test -hl-discover "`~/keyer/bin/hl-discover`"
#
# was: ../bin/keyer key -kyo-gain -6 & x42-scope & ./hl-test.tcl -jack on -mox 1 -low-pwr 1 -lna-db 14
# should fold the parameter values into the widget
#
package require Tk
package require snit

namespace eval ::sdrtk {}
namespace eval ::hlt {}

# a manually refreshed information string
# probably should just refresh on a timer

snit::widget hlt::refresh {
    component lbl
    option -subst -default {}
    option -period -default 2000
    variable string
    constructor {args} {
	$self configure {*}$args
	install lbl as ttk::label $win.lbl -textvariable [myvar string]
	pack $win.lbl -side left -expand true -fill x
	$self refresh
    }
    method refresh {} {
	set string [subst $options(-subst)]
	after $options(-period) [mymethod refresh]
    }
}

snit::widget hlt::slider {
    component lbl
    component spn
    component scl
    option -label -default {}
    option -from -default 0
    option -to -default 100
    option -increment -default 1
    option -integer -default 0
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configure {*}$args
	set value [$self get]
	install lbl using ttk::label $win.lbl -text $options(-label) -width 10
	install spn using spinbox $win.spn -from $options(-from) -to $options(-to) -increment $options(-increment) \
	    -format %3.0f -width 3 \
	    -textvariable [myvar value] -command [mymethod set]
	install scl using ttk::scale $win.scl -from $options(-from) -to $options(-to) -orient horizontal \
	    -variable [myvar value] -command [mymethod set]
	pack $win.lbl -side left -padx 16
	pack $win.spn -side left -padx 16
	pack $win.scl -side left -padx 16
    }
    method get {} { return [hl cget $options(-hl-opt)] }
    method set {{val {}}} {
	if {$options(-integer)} { set value [expr {int($value)}] }
	dial-set -hl$options(-hl-opt) $value
    }
}

snit::widget hlt::choice {
    component lbl
    component spn
    option -label -default {}
    option -values -default {}
    option -width -default 6
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configure {*}$args
	set value [$self get]
	# puts "$self has value $value"
	install lbl using ttk::label $win.l -text $options(-label) -width 10
	install spn using spinbox $win.p -values $options(-values) -width $options(-width) \
	    -textvariable [myvar value] -command [mymethod set]
	$spn set $value
	pack $win.l $win.p -side left -padx 16
    }
    method get {} { return [hl cget $options(-hl-opt)] }
    method set {{val {}}} { dial-set -hl$options(-hl-opt) $value }
}

snit::widget hlt::check {
    component chk
    option -label -default {}
    option -hl-opt -default {}
    variable value
    constructor {args} {
	$self configurelist $args
	install chk using ttk::checkbutton $win.c -text $options(-label) -width 16 -variable [myvar value] -command [mymethod set]
	pack $win.c -side left -padx 16
	set value [$self get]
    }
    method get {} { return [hl cget $options(-hl-opt)] }
    method set {{val {}}} { dial-set -hl$options(-hl-opt) $value }
}

snit::widget sdrtk::hl-test {
    
    method exposed-options {} { return {} }
    
    constructor {args} {
	set row -1

	grid [hlt::refresh $win.id -period 2000 \
		  -subst [join {
		      {peer: [hl cget -peer]}
		      {mac-addr: [hl cget -mac-addr]}
		      {board-id: [hl cget -board-id]}
		      {code-version: [hl cget -code-version]}
		      {serial: [hl cget -serial]}
		  } {, }]] -row [incr row] -column 0 -columnspan 10 -sticky ew
	grid [hlt::refresh $win.stats -period 250 \
		  -subst [join {
		      {rx-calls: [format %9d [hl cget -rx-calls]]}
		      {tx-calls: [format %9d [hl cget -tx-calls]]}
		      {bs-calls: [format %9d [hl cget -bs-calls]]}
		  } {, }]] -row [incr row] -column 0 -columnspan 10 -sticky ew
	grid [hlt::refresh $win.mon -period 100 \
		  -subst [join {
		      {Temp: [format %4.1f [hl cget -temperature]]}
		      {PA I: [format %4.1f [hl cget -pa-current]]}
		      {Fwd P: [format %4.1f [hl cget -fwd-power]]}
		      {Rev P: [format %4.1f [hl cget -rev-power]]}
		      {Power: [format %4.2f [hl cget -power]]}
		      {SWR: [format %s [hl cget -swr]]}
		      {FIFO: [format %4d [hl cget -raw-tx-iq-fifo]]}
		  } {, }]] -row [incr row] -column 0 -columnspan 10 -sticky ew
	
	grid [hlt::slider $win.lna -label {Rx LNA dB} -from -12 -to 48 -increment 1 -integer true -hl-opt -lna-db] -row [incr row] -column 0 -sticky ew
	grid [hlt::slider $win.lev -label {Tx Level} -from 0 -to 255 -increment 1 -integer 1 -hl-opt -level] -row [incr row] -column 0 -sticky ew

	grid [hlt::check $win.mx -label {MOX} -hl-opt -mox] -row [incr row] -column 0 -sticky ew
	grid [hlt::check $win.bs -label {Bandscope} -hl-opt -bandscope] -row [incr row] -column 0 -sticky ew
	grid [hlt::check $win.low -label {Low Power T/R} -hl-opt -low-pwr] -row [incr row] -column 0 -sticky ew
	grid [hlt::check $win.pa -label {PA Enable} -hl-opt -pa] -row [incr row] -column 0 -sticky ew
	grid [hlt::check $win.sy -label {Not SYNC} -hl-opt -not-sync] -row [incr row] -column 0 -sticky ew
	grid [hlt::check $win.du -label {Duplex} -hl-opt -duplex] -row [incr row] -column 0 -sticky ew
	
	grid [hlt::choice $win.sp -label {Speed} -values {48000} -hl-opt -speed] -row [incr row] -column 0 -sticky ew
	grid [hlt::choice $win.nr -label {N Rx} -values {1 2 3 4} -hl-opt -n-rx] -row [incr row] -column 0 -sticky ew

	# -filters -
	# -f-tx -f-rx?
	# -pure-signal
	# -bias-adjust
	# -vna
	# -vna-count
	# -vna-started

	# -hw-key
	# -hw-ptt
	# -overflow
	# -serial
	# -temperature
	# -fwd-power
	# -rev-power
	# -pa-current
	foreach i {0 1 2 3 4 5 6 7 8 9} {
	    grid columnconfigure . $i -weight 1
	}
    }
}
