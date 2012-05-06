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

package provide sdrdsp::comp-demod 1.0.0

package require sdrctl::control
package require sdrdsp::dsp-alternates

namespace eval sdrdsp {}

proc sdrdsp::comp-demod {name args} {
    array set fopt {
	-alternates {sdrdsp::comp-demod-am sdrdsp::comp-demod-sam sdrdsp::comp-demod-fm}
	-require {sdrdsp::comp-demod-am sdrdsp::comp-demod-sam sdrdsp::comp-demod-fm}
	-map {USB -1 LSB -1 DSB -1 CWU -1 CWL -1 AM 0 SAM 1 FMN 2 DIGU -1 DIGL -1}
	-opt-connect-from {{ctl-rxtx-mode -mode -select}}
    }
    return [sdrctl::control $name -type dsp -suffix mode -factory sdrdsp::dsp-alternates -factory-options [array get fopt] {*}$args]
}

