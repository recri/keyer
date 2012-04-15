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

#package provide sdrblk::comp-keyer-ascii 1.0.0
#package provide sdrblk::comp-keyer-debounce 1.0.0
#package provide sdrblk::comp-keyer-detime 1.0.0
#package provide sdrblk::comp-keyer-detone 1.0.0
#package provide sdrblk::comp-keyer-iambic-dttsp 1.0.0
#package provide sdrblk::comp-keyer-iambic-ad5dz 1.0.0
#package provide sdrblk::comp-keyer-ptt 1.0.0
#package provide sdrblk::comp-keyer-ptt-mute 1.0.0
#package provide sdrblk::comp-keyer-tone 1.0.0
#package provide sdrblk::comp-keyer-iambic 1.0.0
package provide sdrblk::comp-keyer 1.0.0

package require sdrblk::block

package require keyer::ascii
package require keyer::debounce
package require keyer::detime
package require keyer::detone
package require keyer::iambic-dttsp
package require keyer::iambic-ad5dz
package require keyer::ptt
package require keyer::ptt-mute
package require keyer::tone

namespace eval sdrblk {}

proc sdrblk::comp-keyer-ascii {name args} {
    return [sdrblk::block $name -type jack -suffix ascii -factory keyer::ascii {*}$args]
}
proc sdrblk::comp-keyer-debounce {name args} {
    return [sdrblk::block $name -type jack -suffix debounce -factory keyer::debounce {*}$args]
}
proc sdrblk::comp-keyer-detime {name args} {
    return [sdrblk::block $name -type jack -suffix detime -factory keyer::detime {*}$args]
}
proc sdrblk::comp-keyer-detone {name args} {
    return [sdrblk::block $name -type jack -suffix detone -factory keyer::detone {*}$args]
}
proc sdrblk::comp-keyer-iambic-dttsp {name args} {
    return [sdrblk::block $name -type jack -suffix dttsp -factory keyer::iambic-dttsp {*}$args]
}
proc sdrblk::comp-keyer-iambic-ad5dz {name args} {
    return [sdrblk::block $name -type jack -suffix ad5dz -factory keyer::iambic-ad5dz {*}$args]
}
proc sdrblk::comp-keyer-ptt {name args} {
    return [sdrblk::block $name -type jack -suffix ptt -factory keyer::ptt {*}$args]
}
proc sdrblk::comp-keyer-ptt-mute {name args} {
    return [sdrblk::block $name -type jack -suffix ptt-mute -factory keyer::ptt-mute {*}$args]
}
proc sdrblk::comp-keyer-tone {name args} {
    return [sdrblk::block $name -type jack -suffix tone -factory keyer::tone {*}$args]
}
proc sdrblk::comp-keyer-iambic {name args} {
    set alts {sdrblk::comp-keyer-iambic-dttsp sdrblk::comp-keyer-iambic-ad5dz}
    return [sdrblk::block $name -type alternate -suffix iambic -alternates $alts -enable yes {*}$args]
}
