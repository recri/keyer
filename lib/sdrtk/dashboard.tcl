#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
package provide sdrtk::dashboard 1.0.0

#
# display numbers related to hermes lite 2
#
package require Tk
package require snit

namespace eval ::sdrtk {}

snit::widget sdrtk::dashboard {
    option -hl -default {} -configuremethod Config

    variable data -array {
	const {
	    -peer -code-version -board-id -mac-addr -fixed-ip -fixed-mac -n-hw-rx -wb-fmt -build-id -gateware-minor
	}
	volatile {
	    -hw-dash -hw-dot -hw-ptt -overload -recovery -tx-iq-fifo -temperature -fwd-power -rev-power -pa-current
	}
	steady {
	    -bandscope -n-rx -speed
	}
    }
    constructor {args} {
	# puts "hl-dashboard constructor {$args}"
    }

    method exposed-options {} { return {-verbose -server -client -chan -note -freq -bandwidth -on -off -timeout -wpm -dict -font -foreground -background} }

    method info-option {opt} {
    }
    method Config {opt val} { set options($opt) $val }
}
