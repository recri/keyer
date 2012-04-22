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

package provide sdrhw::hw-softrock-dg8saq 1.0.0

package require snit

snit::type sdrhw::hw-softrock-dg8saq {

    option -partof -readonly true
    option -freq -default 7.050 -configuremethod opt-handle
    option -type hw
    option -prefix {}
    option -suffix hw
    option -control {}
    option -enable yes
    option -activate no

    constructor {args} {
	# puts "radio-hw-softrock-dg8saq $self constructor $args"
	array set tmp $args
	set options(-partof) [from args -partof]
	set options(-suffix) [from args -suffix]
	set options(-prefix) [$options(-partof) cget -name]
	set options(-name) [string trim $options(-prefix)-$options(-suffix) -]
	set options(-control) [$options(-partof) cget -control]
	$self configure {*}$args
	$options(-control) add $options(-name) $self
    }

    method controls {} { return {{-freq freq Freq 7050000 7050000 }} }
    method control {args} { $self configure {*}$args }
    method controlget {opt} { return [$self configure $opt] }

    method {opt-handle -freq} {val} {
	# puts "hw-softrock-dg8saq -freq $val"
	set options(-freq) $val
	if {$options(-activate)} { exec usbsoftrock set freq [expr {$val/1e6}] }
    }
}
