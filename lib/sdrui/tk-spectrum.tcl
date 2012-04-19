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
## spectrum
##

package provide sdrui::tk-spectrum 1.0.0

package require Tk
package require snit

snit::widgetadaptor sdrui::tk-spectrum {
    option -width 250
    option -height 100
    option -offset -default 0.0 -configuremethod handle-option
    option -scale -default 1.0 -configuremethod handle-option
    option -max -default 0 -configuremethod handle-option
    option -min -default -160 -configuremethod handle-option
    # option -smooth ?
    # option -multi

    constructor {args} {
	installhull using canvas
	$self configure {*}$args
	$hull configure -height $options(-height) -bg black
	$hull create line 0 0 0 0 -fill white -tags spectrum
    }
    
    method scale {tag} {
	set yscale [expr {-[winfo height $win]/double($options(-max)-$options(-min))}]
	$hull scale $tag 0 0 $options(-scale) $yscale
	$hull move $tag $options(-offset) [expr {-$options(-max)*$yscale}]
    }

    method update {xy} {
	$hull coords spectrum $xy
	$self scale spectrum
	# keep older copies fading to black?
    }

    method adjust {} {
	catch {$hull delete grid}
	set dark \#888
	set med \#AAA
	set light \#CCC
	set lo [expr {-double([winfo width $win])/$options(-scale)/2.0}]
	set hi [expr {-$lo}]
	#puts "scale $options(-scale) offset $options(-offset) width [winfo width $win], $lo .. $hi"
	for {set l $options(-min)} {$l <= $options(-max)} {incr l 20} {
	    # main db grid
	    $hull create line $lo $l $hi $l -fill $dark -tags grid
	    $hull create text $lo $l -text "$l dB" -anchor nw -fill $dark -tags grid
	    # sub grid
	    if {0} {
		for {set ll [expr {$l-10}]} {$ll > $l-20} {incr ll -10} {
		    if {$ll >= $options(-min) && $ll <= $options(-max)} {
			$hull create line $lo $ll $hi $ll -fill $med -tags grid
		    }
		}
	    }
	}
	$hull lower grid
	$self scale grid
    }	

    method handle-option {option value} {
	set options($option) $value
	$self adjust
    }
}
