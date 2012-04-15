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

#package provide sdrblk::comp-spectrum-semi-raw 1.0.0
#package provide sdrblk::comp-spectrum-pre-filt 1.0.0
#package provide sdrblk::comp-spectrum-post-filt 1.0.0
#package provide sdrblk::comp-spectrum-post-agc 1.0.0
package provide sdrblk::comp-spectrum 1.0.0

package require sdrblk::block

namespace eval sdrblk {}

proc sdrblk::comp-spectrum-semi-raw {name args} {
    return [sdrblk::block $name -type spectrum -suffix spectrum-semi-raw -enable yes {*}$args]
}
proc sdrblk::comp-spectrum-pre-filt {name args} {
    return [sdrblk::block $name -type spectrum -suffix spectrum-pre-filt -enable yes {*}$args]
}
proc sdrblk::comp-spectrum-post-filt {name args} {
    return [sdrblk::block $name -type spectrum -suffix spectrum-post-filt -enable yes {*}$args]
}
proc sdrblk::comp-spectrum-post-agc {name args} {
    return [sdrblk::block $name -type spectrum -suffix spectrum-post-agc -enable yes {*}$args]
}
