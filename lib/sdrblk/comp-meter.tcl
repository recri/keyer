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

package provide sdrblk::comp-meter 1.0.0

package require sdrblk::block

namespace eval sdrblk {}

proc sdrblk::comp-meter-pre-conv {name args} {
    return [sdrblk::block $name -type stub -suffix meter-pre-conv -enable yes {*}$args]
}
proc sdrblk::comp-meter-post-filt {name args} {
    return [sdrblk::block $name -type stub -suffix meter-post-filt -enable yes {*}$args]
}
proc sdrblk::comp-meter-post-agc {name args} {
    return [sdrblk::block $name -type stub -suffix meter-post-agc -enable yes {*}$args]
}
proc sdrblk::comp-meter-waveshape {name args} {
    return [sdrblk::block $name -type stub -suffix meter-waveshape -enable yes {*}$args]
}
proc sdrblk::comp-meter-graphic-eq {name args} {
    return [sdrblk::block $name -type stub -suffix meter-graphic-eq -enable yes {*}$args]
}
proc sdrblk::comp-meter-leveler {name args} {
    return [sdrblk::block $name -type stub -suffix meter-leveler -enable yes {*}$args]
}
proc sdrblk::comp-meter-speech-processor {name args} {
    return [sdrblk::block $name -type stub -suffix meter-speech-processor -enable yes {*}$args]
}
proc sdrblk::comp-meter-compand {name args} {
    return [sdrblk::block $name -type stub -suffix meter-compand -enable yes {*}$args]
}
proc sdrblk::comp-meter-power {name args} {
    return [sdrblk::block $name -type stub -suffix meter-power -enable yes {*}$args]
}
