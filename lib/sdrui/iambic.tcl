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
## iambic - keyer iambic control
##
package provide sdrui::iambic 1.0.0

package require Tk
package require snit

package require sdrtype::types
package require sdrtk::lradiomenubutton
package require sdrtk::lspinbox
    
snit::widgetadaptor sdrui::iambic {

    option -iambic -default ad5dz -type sdrtype::iambic -configuremethod Configure

    option -options {-iambic}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lradiomenubutton -label {Iambic} -labelanchor n \
	    -defaultvalue ad5dz -command [mymethod Set -iambic] \
	    -values [sdrtype::iambic cget -values]
	$self configure {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} {
	set options($opt) $val
	$hull set-value $val
    }

    method Report {opt val} { {*}$options(-command) report $opt $val }

    method Set {opt val} {
	set options($opt) $val
	$self Report $opt $val
    }
}

snit::widgetadaptor sdrui::iambic-wpm {

    option -wpm -default 15 -configuremethod Configure

    option -options {-wpm}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lspinbox -label WPM -labelanchor n \
	    -from 5 -to 60 -increment 1 -width 4 -textvariable [myvar options(-wpm)] \
	    -command [mymethod Set -wpm]
	$self configure {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} { set options($opt) $val }
    method Report {opt val} { {*}$options(-command) report $opt $val }
    method Set {opt} { $self Report $opt $options($opt) }
}

snit::widgetadaptor sdrui::iambic-dah {

    option -dah -default 3 -configuremethod Configure

    option -options {-dah}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lspinbox -label {Dah} -labelanchor n \
	    -from 2.5 -to 3.5 -increment 0.1 -width 4 \
	    -textvariable [myvar options(-dah)] -command [mymethod Set -dah]
	$self configure {*}$args
    }

    method resolve {} {
	foreach tf {to from} {
	    lappend options(-opt-connect-$tf) {*}[sdrui::common::connect $tf $win $options(-options)]
	}
    }

    method Configure {opt val} { set options($opt) $val }
    method Report {opt val} { {*}$options(-command) report $opt $val }
    method Set {opt} { $self Report $opt $options($opt) }
}

snit::widgetadaptor sdrui::iambic-space {

    option -space -default 1

    option -controls {-space}

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}

    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	installhull using sdrtk::lspinbox -label {Space} -labelanchor n \
	    -from 0.7 -to 1.3 -increment 0.1 -width 4 \
	    -textvariable [myvar options(-space)] -command [mymethod Set -space]
	$self configure {*}$args
    }

    method Configure {opt val} { set options($opt) $val }
    method Report {opt val} { {*}$options(-command) report $opt $val }
    method Set {opt} { $self Report $opt $options($opt) }

}
