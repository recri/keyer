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

package provide sdrdsp::comp-keyer 1.0.0

package require sdrctl::control
package require sdrdsp::dsp-alternates

package require sdrtcl::keyer-ascii
package require sdrtcl::keyer-debounce
package require sdrtcl::keyer-detime
package require sdrtcl::keyer-detone
package require sdrtcl::keyer-iambic-dttsp
package require sdrtcl::keyer-iambic-ad5dz
package require sdrtcl::keyer-iambic-nd7pa
package require sdrtcl::keyer-ptt
package require sdrtcl::keyer-ptt-mute
package require sdrtcl::keyer-tone

namespace eval sdrdsp {}

proc sdrdsp::comp-keyer-ascii {name args} {
    return [sdrctl::control $name -type jack -suffix ascii -factory sdrtcl::keyer-ascii -enable no {*}$args]
}
proc sdrdsp::comp-keyer-debounce {name args} {
    return [sdrctl::control $name -type jack -suffix debounce -factory sdrtcl::keyer-debounce -enable no {*}$args]
}
proc sdrdsp::comp-keyer-detime {name args} {
    return [sdrctl::control $name -type jack -suffix detime -factory sdrtcl::keyer-detime -enable no {*}$args]
}
proc sdrdsp::comp-keyer-detone {name args} {
    return [sdrctl::control $name -type jack -suffix detone -factory sdrtcl::keyer-detone -enable no {*}$args]
}
proc sdrdsp::comp-keyer-iambic-dttsp {name args} {
    return [sdrctl::control $name -type jack -suffix dttsp -factory sdrtcl::keyer-iambic-dttsp -enable no {*}$args]
}
proc sdrdsp::comp-keyer-iambic-ad5dz {name args} {
    return [sdrctl::control $name -type jack -suffix ad5dz -factory sdrtcl::keyer-iambic-ad5dz -enable no {*}$args]
}
proc sdrdsp::comp-keyer-iambic-nd7pa {name args} {
    return [sdrctl::control $name -type jack -suffix nd7pa -factory sdrtcl::keyer-iambic-nd7pa -enable no {*}$args]
}
proc sdrdsp::comp-keyer-ptt {name args} {
    return [sdrctl::control $name -type jack -suffix ptt -factory sdrtcl::keyer-ptt -enable no {*}$args]
}
proc sdrdsp::comp-keyer-ptt-mute {name args} {
    return [sdrctl::control $name -type jack -suffix ptt-mute -factory sdrtcl::keyer-ptt-mute -enable no {*}$args]
}
proc sdrdsp::comp-keyer-tone {name args} {
    return [sdrctl::control $name -type jack -suffix tone -factory sdrtcl::keyer-tone -enable no {*}$args]
}
proc sdrdsp::comp-keyer-iambic {name args} {
    set alts {sdrdsp::comp-keyer-iambic-ad5dz sdrdsp::comp-keyer-iambic-dttsp sdrdsp::comp-keyer-iambic-nd7pa}
    set fopt [list -alternates $alts -map {ad5dz dttsp nd7pa} -signal ctl-keyer-iambic:-iambic -ports {alt_midi_in alt_midi_out}]
    return [sdrctl::control $name -type dsp -suffix iambic -factory sdrdsp::dsp-alternates -factory-options $fopt {*}$args]
}
