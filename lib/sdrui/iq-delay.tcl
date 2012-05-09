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
## iq-swap - I/Q channel delay control
##
package provide sdrui::iq-delay 1.0.0

package require Tk
package require snit

package require sdrtype::types
package require sdrtk::lradiomenubutton
    
snit::widgetadaptor sdrui::iq-delay {

    option -delay -default 0 -type sdrtype::iq-delay -configuremethod Configure

    option -options {-delay}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lradiomenubutton -label {IQ delay} -labelanchor n \
	    -defaultvalue 0 -values [sdrtype::iq-delay cget -values] -labels [sdrtype::iq-delay cget -values] \
	    -variable [myvar options(-delay)]
	$self configure {*}$args
    }
    
    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	switch -exact -- $opt {
	    -delay { $hull set-value $val }
	}
    }

    method Set {opt val} {
	set options($opt) $val
	{*}$options(-command) report $opt $options($val)
    }
}


