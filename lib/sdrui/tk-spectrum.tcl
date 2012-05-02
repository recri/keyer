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
    option -max -default 0 -type sdrtype::decibel -configuremethod opt-handler
    option -min -default -160 -type sdrtype::decibel -configuremethod opt-handler
    option -smooth -default true -type sdrtype::smooth -configuremethod opt-handler
    option -multi -default 1 -type sdrtype::multi -configuremethod opt-handler
    option -center -default 0 -type sdrtype::hertz -configuremethod opt-handler
    option -size -default 4096 -type sdrtype::spec-size -configuremethod opt-handler
    option -rate -default 48000 -type sdrtype::sample-rate -configuremethod opt-handler
    option -zoom -default 1 -type sdrtype::zoom -configuremethod opt-handler
    option -pan -default 0 -type sdrtype::pan -configuremethod opt-handler

    variable data -array {
	xscale 1.0
	xoffset 0.5
	multi 0
    }
    
    constructor {args} {
	installhull using canvas
	$self configure {*}$args
	$hull configure -bg black
	bind $hull <Configure> [mymethod rescale %w %h]
    }
    
    method rescale {wd ht} {
    }

    method scale {tag} {
	set yscale [expr {-[winfo height $win]/double($options(-max)-$options(-min))}]
	set yoffset [expr {-$options(-max)*$yscale}]
	set xscale [expr {[winfo width $win]*$data(xscale)}]
	set xoffset [expr {[winfo width $win]*$data(xoffset)}]
	$hull scale $tag 0 0 $xscale $yscale
	$hull move $tag $xoffset $yoffset
	if {0} {
	    puts "scale $tag 0 0 $xscale $yscale"
	    puts "move $tag $xoffset $yoffset"
	    puts "bbox $tag [$hull bbox $tag]"
	}
    }
    
    method update {xy} {
	$hull coords spectrum-$data(multi) $xy
	$hull raise spectrum-$data(multi)
	$self scale spectrum-$data(multi)
	for {set i 0} {$i < $options(-multi)} {incr i} {
	    set j [expr {($data(multi)+$i)%$options(-multi)}]
	    $hull itemconfigure spectrum-$j -fill [lindex $data(multi-hues) $j]
	}
	set data(multi) [expr {($data(multi)-1+$options(-multi))%$options(-multi)}]
    }

    method adjust {} {
	catch {$hull delete grid}
	set dark \#888
	set med \#AAA
	set light \#CCC
	set lo [expr {-double([winfo width $win])/$data(xscale)/2.0}]
	set hi [expr {-$lo}]
	#puts "scale $data(xscale) offset $data(xoffset) width [winfo width $win], $lo .. $hi"
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
	
    method {opt-handler -max} {value} { set options(-max) $value; $self adjust }

    method {opt-handler -min} {value} { set options(-min) $value; $self adjust }

    method {opt-handler -smooth} {value} { set options(-smooth) $value; catch {$hull configure spectrum -smooth $value} }

    proc gray-scale {n} {
	set scale {}
	set intensity 0xFF
	for {set i 0} {$i <= $n} {incr i} {
	    lappend scale [string range [format {\#%02x%02x%02x} $intensity $intensity $intensity] 1 end]
	    incr intensity [expr {-(0xFF/($n+1))}]
	}
	return $scale
    }

    method {opt-handler -multi} {value} {
	set options(-multi) $value
	set data(multi) 0
	set data(multi-hues) [gray-scale $options(-multi)]
	catch {$hull delete spectrum}
	for {set i 0} {$i < $options(-multi)} {incr i} {
	    $hull create line 0 0 0 0 -tags [list spectrum spectrum-$i]
	    
	}
    }
    method {opt-handler -center} {value} { set options(-center) $value; $self adjust }
    method {opt-handler -rate} {value} {
	set options(-rate) $value
	set data(xscale) [expr {1.0/$value}]
	set data(xoffset) [expr {0.5}]
    }
    method {opt-handler -zoom} {value} { set options(-zoom) $value }
    method {opt-handler -pan} {value} { set options(-pan) $value }

}
