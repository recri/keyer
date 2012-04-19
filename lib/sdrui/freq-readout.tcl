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
# a rotary encoder with a frequency readout
#

package provide sdrui::freq-readout 1.0

package require Tk
package require snit

snit::widget sdrui::freq-readout {

    variable data -array {
	display-units {MHz kHz Hz}
	display-unit-old MHz
	display-precisions {X X.XXX X.XXXXXX X.XXXXXXXXX}
    }

    option -font {Helvetica 16}
    option -display-unit MHz
    option -display-precision X.XXXXXX
    option -freq 7050000

    method set-freq {hertz} {
	set options(-freq) $hertz

	set ff [expr {int($hertz)}]
	set fr [format %03d [expr {int(1000*($hertz-$ff))}]]
	set hz [format %03d [expr {$ff%1000}]]
	set ff [expr {$ff/1000}]
	set kh [format %03d [expr {$ff%1000}]]
	set ff [expr {$ff/1000}]
	set mh [format %03d [expr {$ff%1000}]]
	set gh [expr {$ff/1000}]

	switch $options(-display-unit) {
	    GHz { set f "$gh.$mh $kh $hz $fr" }
	    MHz { set f "$gh $mh.$kh $hz $fr" }
	    kHz { set f "$gh $mh $kh.$hz $fr" }
	    Hz  { set f "$gh $mh $kh $hz.$fr" }
	}
	
	switch $options(-display-precision) {
	    X {           regexp {^(.*)\..*$} $f all f }
	    X.XXX {       regexp {^(.*\....).*$} $f all f }
	    X.XXXXXX {    regexp {^(.*\.... ...).*$} $f all f }
	    X.XXXXXXXXX { regexp {^(.*\.... ... ...).*$} $f all f }
	}
	
	regexp {^[0 ]+(.*)$} $f all f
	set data(f) $f
    }

    method unit-changed {opt u} {
	# preserve the least significant digit by changing precision
	# as much as possible
	switch $u/$data(display-unit-old) {
	    Hz/MHz - kHz/GHz {
		switch $options(-display-precision) {
		    X -
		    X.XXX -
		    X.XXXXXX { set options(-display-precision) X }
		    X.XXXXXXXXX { set options(-display-precision) X.XXX }
		}
	    }
	    MHz/GHz - kHz/MHz - Hz/kHz {
		# from MHz to kHz, or kHz to Hz
		switch $options(-display-precision) {
		    X -
		    X.XXX { set options(-display-precision) X }
		    X.XXXXXX { set options(-display-precision) X.XXX }
		    X.XXXXXXXXX { set options(-display-precision) X.XXXXXX }
		}
	    }
	    GHz/GHz - MHz/MHz - kHz/kHz - Hz/Hz {
		# no change
	    }
	    GHz/MHz - MHz/kHz - kHz/Hz {
		# from Hz to kHz, or kHz to MHz
		switch $options(-display-precision) {
		    X { set options(-display-precision) X.XXX }
		    X.XXX { set options(-display-precision) X.XXXXXX }
		    X.XXXXXX -
		    X.XXXXXXXXX { set options(-display-precision) X.XXXXXXXXX }
		}
	    }
	    GHz/kHz - MHz/Hz {
		# from Hz to MHz
		switch $options(-display-precision) {
		    X { set options(-display-precision) X.XXXXXX }
		    X.XXX -
		    X.XXXXXX -
		    X.XXXXXXXXX { set options(-display-precision) X.XXXXXXXXX }
		}
	    }
	}
	set data(display-unit-old) $u
	$self set-freq $options(-freq)
    }    

    method precision-changed {opt p} {
	$self set-freq $options(-freq)
    }

    constructor {args} {
	pack [ttk::label $win.frequency -textvar [myvar data(f)] -font $options(-font)] -side left
	# fix.me - make the font change for ttk::menubutton
	pack [menubutton $win.displayresolution -textvar [myvar options(-display-unit)] -font $options(-font) -menu $win.displayresolution.m] -side left
	menu $win.displayresolution.m -tearoff no
	foreach u $data(display-units) {
	    $win.displayresolution.m add radiobutton -label $u -variable [myvar options(-display-unit)] -value $u -command [mymethod unit-changed -display-unit $u]
	}
	$win.displayresolution.m add separator
	foreach p $data(display-precisions) {
	    $win.displayresolution.m add radiobutton -label $p -variable [myvar options(-display-precision)] -value $p -command [mymethod precision-changed -display-precision $p]
	}
	$self set-freq $options(-freq)
    }
}