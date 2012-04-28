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

package provide sdrdsp::comp-meter 1.0.0

package require sdrctl::control
package require sdrdsp::dsp-tap

namespace eval sdrdsp {}

proc sdrdsp::comp-meter-pre-conv {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-pre-conv {*}$args]
}
proc sdrdsp::comp-meter-post-filt {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-post-filt {*}$args]
}
proc sdrdsp::comp-meter-post-agc {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-post-agc {*}$args]
}
proc sdrdsp::comp-meter-waveshape {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-waveshape {*}$args]
}
proc sdrdsp::comp-meter-graphic-eq {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-graphic-eq {*}$args]
}
proc sdrdsp::comp-meter-leveler {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-leveler {*}$args]
}
proc sdrdsp::comp-meter-speech-processor {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-speech-processor {*}$args]
}
proc sdrdsp::comp-meter-compand {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-compand {*}$args]
}
proc sdrdsp::comp-meter-power {name args} {
    return [sdrctl::control $name -type dsp -factory sdrdsp::dsp-tap -suffix meter-power {*}$args]
}
