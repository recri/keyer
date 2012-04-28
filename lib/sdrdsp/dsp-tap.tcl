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

package provide sdrdsp::dsp-tap 1.0.0

package require snit

snit::type sdrdsp::dsp-tap {
    option -ports -default {tap_i tap_q}
    option -opts -default {}
    option -methods -default {}

    option -container -default {} -readonly true
    
    constructor {args} {
	# puts "dsp-tap constructor $self {$args}"
	$self configure {*}$args
    }

    method finish {} {}
    method deactivate {} {}
    method activate {} {}
    
}

