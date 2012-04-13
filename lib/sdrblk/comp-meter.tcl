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

package provide sdrblk::comp-meter-pre-conv 1.0.0
package provide sdrblk::comp-meter-post-filt 1.0.0
package provide sdrblk::comp-meter-post-agc 1.0.0

package require sdrblk::block-stub
package require sdrkit::gain

namespace eval sdrblk {}

proc sdrblk::comp-meter-pre-conv {name args} {
    return [sdrblk::block-stub $name -type meter -suffix meter-pre-conv {*}$args]
}
proc sdrblk::comp-meter-post-filt {name args} {
    return [sdrblk::block-stub $name -type meter -suffix meter-post-filt {*}$args]
}
proc sdrblk::comp-meter-post-agc {name args} {
    return [sdrblk::block-stub $name -type meter -suffix meter-post-agc {*}$args]
}
