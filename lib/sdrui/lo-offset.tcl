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

##
## lo-offset - local oscillator offset in rx and tx
##
package provide sdrui::lo-offset 1.0.0

package require Tk
package require snit
package require sdrtk::lspinbox

snit::widgetadaptor sdrui::lo-offset {

    option -freq -default 10000

    option -options {-freq}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lspinbox -label {LO freq} -labelanchor n \
	    -from -24000 -to 24000 -increment 1000 \
	    -width 6 -textvar [myvar options(-freq)] \
	    -command [mymethod Set -freq]
	$self configure {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Set {opt} { {*}$options(-command) report $opt $options($opt) }
}


