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

package provide sdrblk::detect 1.0.0
package provide sdrblk::detect-cw 1.0.0
package provide sdrblk::detect-ssb 1.0.0
package provide sdrblk::detect-am 1.0.0
package provide sdrblk::detect-sam 1.0.0
package provide sdrblk::detect-fm 1.0.0

package require sdrblk::block-alternate

package require sdrblk::stub
package require sdrkit::demod-am
package require sdrkit::demod-sam
package require sdrkit::demod-fm

namespace eval ::sdrblk {}

proc ::sdrblk::detect-cw {name args} {
    return [::sdrblk::block-pipeline $name -suffix cw -pipeline {} {*}$args]
}
proc ::sdrblk::detect-ssb {name args} {
    return [::sdrblk::block-pipeline $name -suffix ssb -pipeline {} {*}$args]
}
proc ::sdrblk::detect-am {name args} {
    return [::sdrblk::block-pipeline $name -suffix am -pipeline {sdrblk::demod-am} {*}$args]
}
proc ::sdrblk::detect-sam {name args} {
    return [::sdrblk::block-pipeline $name -suffix sam -pipeline {sdrblk::demod-sam} {*}$args]
}
proc ::sdrblk::detect-fm {name args} {
    return [::sdrblk::block-pipeline $name -suffix fm -pipeline {sdrblk::demod-fm} {*}$args]
}
    
proc ::sdrblk::detect {name args} {
    set alts {cw sdrblk::detect-cw ssb sdrblk::detect-ssb am sdrblk::detect-am sam sdrblk::detect-sam fm sdrblk::detect-fm}
    return [::sdrblk::block-alternate $name -suffix mode -alternates $alts {*}$args]
}

