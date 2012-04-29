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

package provide sdrctl::control-filter 1.0.0

package require snit

package require sdrctl::types

##
## handle filter controls
## keep the -low and -high in sync or you'll get complaints
##
snit::type sdrctl::control-filter {
    option -command -default {} -readonly true
    option -opt-connect-from {{ctl-rxtx-mode -mode -mode} {ctl-rxtx-tuner -cw-freq -cw-freq}}
    # incoming opts
    option -mode -default CWU -configuremethod Retune -type sdrctl::mode
    option -width -default 400 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -length -default 128 -configuremethod Opt-handler
    # outgoing opts
    option -low -default 400 -configuremethod Opt-handler2
    option -high -default 800 -configuremethod Opt-handler2

    method {Opt-handler} {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $val
    }
    method {Opt-handler2} {opt val} {
	set options($opt) $val
	{*}$options(-command) report -low $options(-low) -high $options(-high)
    }
    method Retune {opt val} {
	set options($opt) $val
	set c $options(-cw-freq)
	set w $options(-width)
	set h [expr {$options(-width)/2.0}]
	switch $options(-mode) {
	    CWL { set options(-low) [expr {-$c-$h}]; set options(-high) [expr {-$c+$h}] }
	    CWU { set options(-low) [expr {+$c-$h}]; set options(-high) [expr {+$c+$h}] }
	    AM -
	    SAM -
	    DSB -
	    FMN { set options(-low) [expr {-$h}]; set options(-high) [expr {+$h}] }
	    LSB -
	    DIGL { set options(-low) [expr {-150-$w}]; set options(-high) -150 }
	    USB -
	    DIGU { set options(-low) 150; set options(-high) [expr {150+$w}] }
	    default { error "missed mode $options(-mode)" }
	}
	{*}$options(-command) report $opt $val
	$self configure -low $options(-low) -high $options(-high)
    }
}

