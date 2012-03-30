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

package provide radio-control 1.0.0

#
# provide the central control that translates ui controls into
# actual radio operations, and updates ui displays accordingly
#
# the basic issues are:
#
# 1) frequency tuning requests can come in many forms which need
# to be integrated together to provide a tuned frequency.
#
# 2) frequency readouts come in many forms, some of which directly
# readout the frequency, others of which need to be adjusted by
# formulae.
#
# 3) there can be secondary frequency readouts, such as notches
# or channel trackers which need to track tuning changes to keep
# themselves centered.
#
# 4) there can be tertiary frequency readouts, such as iq correction
# or the waterfall display which need to know that the tuned frequency
# has changed in order to adjust their operation accordingly.
#
# so, the controller widget needs to integrate and distribute all this
# information accordingly.  and it may have multiple inputs which serve
# the same function, and it may have multiple outputs that serve the
# same functions, too.
#
