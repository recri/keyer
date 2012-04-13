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
## frequency display panel
##

package provide sdrblk::tk-frequency 1.0.0

package require Tk
package require snit

snit::widgetadaptor sdrblk::tk-frequency {
    option -offset -default 0.0 -configuremethod handle-option
    option -scale -default 1.0 -configuremethod handle-option
    option -height 50
    option -lo1-offset 0.0
    option -lo2-offset {}

    variable data -array {}

    method handle-option {option value} {
	array set save [array get options]
	set options($option) $value
	$self adjust save
    }

    method adjust {savename} {
	upvar $savename save
	$hull move all [expr {-$save(-offset)}] 0
	$hull scale all 0 0 [expr {$options(-scale)/$save(-scale)}] 1
	$hull move all $options(-offset) 0
    }
    
    method update {xy} {
	set x0 [lindex $xy 0]
	set xn [lindex $xy end-1]
	if { ! [info exists data(saved-x0)] || $data(saved-x0) != $x0 || $data(saved-xn) != $xn} {
	    set data(saved-x0) $x0
	    set data(saved-xn) $xn
	    catch {$hull delete all}
	    set i0 [expr {5000*int(($x0+$options(-lo1-offset))/5000)}]
	    set in [expr {5000*int(($xn+$options(-lo1-offset))/5000)}]
	    set xy {}
	    for {set i $i0} {$i <= $in} {incr i 1000} {
		if {($i % 10000) == 0} {
		    lassign {10 -10} tp tn
		    if {($i % 20000) == 0} {
			set label "[expr {$i/1000}]kHz"
		    }
		} else {
		    lassign {5 -5} tp tn
		}
		set x [expr {$i-$options(-lo1-offset)}]
		lappend xy $x 0 $x $tn $x $tp $x 0
		if {[info exists label]} {
		    $hull create text $x 12 -text $label -anchor n -tag labels -fill white
		    unset label
		}
	    }
	    #puts "ticks $xy"
	    $hull create line $xy -fill white -tags ticks
	    #puts "bbox raw [$hull bbox all]"
	    $hull scale all 0 0 $options(-scale) 1
	    #puts "bbox scaled [$hull bbox all]"
	    $hull move all $options(-offset) [expr {[winfo height $win]/2.0}]
	    #puts "bbox moved [$hull bbox all]"
	}
    }

    constructor {args} {
	installhull using canvas -height $options(-height) -bg black
	$hull create line 0 0 0 0 -fill white -tag ticks
    }
    
}