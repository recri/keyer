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

package provide sdrdsp::dsp-keyer 1.0.0

package require sdrctl::control
package require sdrdsp::dsp-sequence

namespace eval sdrdsp {}

proc sdrdsp::keyer {name args} {
    set req {sdrdsp::comp-keyer}
    # sdrdsp::comp-keyer-ptt between iambic and tone makes a mess of things
    # since it might split the keyer midi signal into multiple streams
    # leaving the sequence from multiple points
    set seq {sdrdsp::comp-keyer-debounce sdrdsp::comp-keyer-iambic sdrdsp::comp-keyer-tone}
    set fopt [list -sequence $seq -require $req -ports {seq_midi_in seq_out_i seq_out_q}]
    return [sdrctl::control $name -type dsp -suffix keyer -factory sdrdsp::dsp-sequence -factory-options $fopt {*}$args]
}
