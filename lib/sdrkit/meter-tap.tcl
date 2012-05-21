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

#
# a meter tap component, just a marker in the graph
#
package provide sdrkit::meter-tap 1.0.0

package require snit

namespace eval sdrkit {}

snit::type sdrkit::meter-tap {    
    option -name meter-tap
    option -type dsp
    option -server default
    option -component {}

    option -window none
    option -title Gain
    option -minsizes {100 200}
    option -weights {1 3}

    option -in-ports {i q}
    option -out-ports {i q}
    option -in-options {}
    option -out-options {}

    variable data -array { activate 0 }

    constructor {args} { $self configure {*}$args }
    destructor {}
    method build-parts {} {}
    method build-ui {} {}

    method is-needed {} { return 1 }
    method is-active {} { return $data(activate) }
    method activate {} { set data(activate) 1 }
    method deactivate {} { set data(activate) 0 }
}
