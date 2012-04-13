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

package provide sdrblk::comp-keyer-ascii 1.0.0
package provide sdrblk::comp-keyer-debounce 1.0.0
package provide sdrblk::comp-keyer-detime 1.0.0
package provide sdrblk::comp-keyer-detone 1.0.0
package provide sdrblk::comp-keyer-dttsp-iambic 1.0.0
package provide sdrblk::comp-keyer-iambic 1.0.0
package provide sdrblk::comp-keyer-ptt 1.0.0
package provide sdrblk::comp-keyer-ptt-mute 1.0.0
package provide sdrblk::comp-keyer-tone 1.0.0

package require sdrblk::block-jack

package require keyer::ascii
package require keyer::debounce
package require keyer::detime
package require keyer::detone
package require keyer::dttsp-iambic
package require keyer::iambic
package require keyer::ptt
package require keyer::ptt-mute
package require keyer::tone

namespace eval sdrblk {}

##
## Each of these started to specify a -jack-io {x y z w} option
## but I can just start the module and list its ports.
## And that works for the existing block-audio modules, too.
## I can create all the referenced modules, collect their ports,
## collect their configuration options, and then deactivate them
## until they're enabled.  I can deactivate and activate whole
## chains of computational units as required.  But they're all
## initialized and configured and ready to go.
## I can collect the entire list of activate/connect or deactivate
## commands for the rx and tx and swap between them on ptt. 
##
proc sdrblk::comp-keyer-ascii {name args} {
    return [sdrblk::block-jack $name -suffix ascii -factory keyer::ascii {*}$args]
}
proc sdrblk::comp-keyer-debounce {name args} {
    return [sdrblk::block-jack $name -suffix debounce -factory keyer::debounce {*}$args]
}
proc sdrblk::comp-keyer-detime {name args} {
    return [sdrblk::block-jack $name -suffix detime -factory keyer::detime {*}$args]
}
proc sdrblk::comp-keyer-detone {name args} {
    return [sdrblk::block-jack $name -suffix detone -factory keyer::detone {*}$args]
}
proc sdrblk::comp-keyer-dttsp-iambic {name args} {
    return [sdrblk::block-jack $name -suffix dttsp-iambic -factory keyer::dttsp-iambic {*}$args]
}
proc sdrblk::comp-keyer-iambic {name args} {
    return [sdrblk::block-jack $name -suffix iambic -factory keyer::iambic {*}$args]
}
proc sdrblk::comp-keyer-ptt {name args} {
    return [sdrblk::block-jack $name -suffix ptt -factory keyer::ptt {*}$args]
}
proc sdrblk::comp-keyer-ptt-mute {name args} {
    return [sdrblk::block-jack $name -suffix ptt-mute -factory keyer::ptt-mute {*}$args]
}
proc sdrblk::comp-keyer-tone {name args} {
    return [sdrblk::block-jack $name -suffix tone -factory keyer::tone {*}$args]
}

