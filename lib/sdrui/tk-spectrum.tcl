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
package require sdrtype::types

snit::widgetadaptor sdrui::tk-spectrum {
    option -pal -default 0 -type sdrtype::spec-palette
    option -max -default 0 -type sdrtype::decibel -configuremethod Readjust
    option -min -default -160 -type sdrtype::decibel -configuremethod Readjust

    option -smooth -default true -type sdrtype::smooth -configuremethod Resmooth

    option -multi -default 1 -type sdrtype::multi -configuremethod Remulti

    option -sample-rate -default 48000 -type sdrtype::sample-rate
    option -zoom -default 1 -type sdrtype::zoom
    option -pan -default 0 -type sdrtype::pan

    # from ctl-rxtx-mode
    option -mode -default CWU -type sdrtype::mode -configuremethod Retune

    # from ctl-rxtx-tune
    option -freq -default 7050000 -configuremethod Retune
    option -lo-freq -default 10000 -configuremethod Retune
    option -cw-freq -default 600 -configuremethod Retune
    option -carrier-freq -default 7040000 -configuremethod Retune

    # from ctl-rxtx-if-bpf
    option -low -default 400 -configuremethod Retune
    option -high -default 800 -configuremethod Retune

    delegate option * to hull
    delegate method * to hull

    variable data -array {
	multi 0
	center-freq 0
	filter-low 0
	filter-high 0
	tuned-freq 0
    }
    
    constructor {args} {
	installhull using canvas
	$self configure {*}$args
	$hull configure -bg black
	bind $win <Configure> [mymethod Adjust]
    }
    
    method update {xy} {
	$hull coords spectrum-$data(multi) $xy
	$hull raise spectrum-$data(multi)
	$self Scale spectrum-$data(multi)
	for {set i 0} {$i < $options(-multi)} {incr i} {
	    set j [expr {($data(multi)+$i)%$options(-multi)}]
	    $hull itemconfigure spectrum-$j -fill [lindex $data(multi-hues) $j]
	}
	set data(multi) [expr {($data(multi)-1+$options(-multi))%$options(-multi)}]
    }

    method VerticalScale {tag} {
	set yscale [expr {-[winfo height $win]/double($options(-max)-$options(-min))}]
	set yoffset [expr {-$options(-max)*$yscale}]
	$hull scale $tag 0 0 1 $yscale
	$hull move $tag 0 $yoffset
    }

    method HorizontalScale {tag} {
	set xscale [expr {[winfo width $win]/double($options(-sample-rate))}]
	set xoffset [expr {[winfo width $win]/2.0}]
	$hull scale $tag 0 0 $xscale 1
	$hull move $tag $xoffset 0
    }
    
    method Scale {tag} {
	$self VerticalScale $tag
	$self HorizontalScale $tag
    }

    method Adjust {} {
	catch {$hull delete grid}
	catch {$hull delete label}
	lassign {\#444 \#666 \#888 \#AAA \#CCC \#EEE \#FFF} darkest darker dark med light lighter lightest
	#lassign {\#FFF \#FFF \#FFF \#FFF \#FFF} darkest darker dark med light
	
	# filter rectangle
	$hull create rectangle $data(filter-low) $options(-min) $data(filter-high) $options(-max) -fill $darker -outline $darker -tag grid
	# carrier tuning line
	$hull create line $data(tuned-freq) $options(-min) $data(tuned-freq) $options(-max) -fill red -tag {grid vgrid}
	set lo [expr {-$options(-sample-rate)/2.0}]
	set hi [expr {$options(-sample-rate)/2.0}]
	set xy {}
	for {set l $options(-min)} {$l <= $options(-max)} {incr l 20} {
	    # main db grid
	    lappend xy $lo $l $hi $l $lo $l
	    $hull create text 0 $l -text " $l" -font {Helvetica 8} -anchor nw -fill $light -tags {label vlabel}
	    # sub grid
	    if {0} {
		for {set ll [expr {$l-10}]} {$ll > $l-20} {incr ll -10} {
		    if {$ll >= $options(-min) && $ll <= $options(-max)} {
			$hull create line $lo $ll $hi $ll -fill $med -tags {grid vgrid}
		    }
		}
	    }
	}
	$hull create line $xy -fill $darkest -tags {grid vgrid}
	# offset of tuning from grid
	set frnd [expr {int($data(center-freq)/10000)*10000}]
	set foff [expr {$data(center-freq)-$frnd}]
	set fmax [expr {int($options(-sample-rate)/20000+1)*10000}]
	set fmin [expr {-$fmax}]
	set xy {}
	for {set f $fmin} {$f <= $fmax} {incr f 10000} {
	    set label [format { %.2f} [expr {($f+$frnd)*1e-6}]]
	    set fo [expr {$f-$foff}]
	    lappend xy $fo $options(-min) $fo $options(-max) $fo $options(-min)
	    $hull create text $fo $options(-min) -text $label -font {Helvetica 8} -anchor sw -fill $light -tags {label hlabel}
	}
	$hull create line $xy -fill $darkest -tags {grid hgrid}
	$hull lower grid
	$self Scale grid
	$self VerticalScale vlabel
	$self Scale hlabel
    }	
	
    method Retune {opt val} {
	set options($opt) $val
	# the frequency at the center of the spectrum
	set data(center-freq) [expr {$options(-carrier-freq)-$options(-lo-freq)}]
	# the limits of the band pass filter in the spectrum
	set data(filter-low) [expr {$options(-lo-freq)+$options(-low)}]
	set data(filter-high) [expr {$options(-lo-freq)+$options(-high)}]
	# the frequency tuned in the spectrum
	switch $options(-mode) {
	    CWU {
		set data(tuned-freq) [expr {$options(-lo-freq)+$options(-cw-freq)}]
	    }
	    CWL {
		set data(tuned-freq) [expr {$options(-lo-freq)-$options(-cw-freq)}]
	    }
	    default {
		set data(tuned-freq) $options(-lo-freq)
	    }
	}
	$self Adjust
    }
    
    method Readjust {opt value} {
	set options($opt) $value
	$self Adjust
    }

    method Resmooth {opt value} {
	set options($opt) $value
	catch {$hull itemconfigure spectrum -smooth $value}
    }

    proc gray-scale {n} {
	set scale {}
	set intensity 0xFF
	for {set i 0} {$i <= $n} {incr i} {
	    lappend scale [string range [format {\#%02x%02x%02x} $intensity $intensity $intensity] 1 end]
	    incr intensity [expr {-(0xFF/($n+1))}]
	}
	return $scale
    }

    method Remulti {opt value} {
	set options($opt) $value
	set data(multi) 0
	set data(multi-hues) [gray-scale $options(-multi)]
	catch {$hull delete spectrum}
	for {set i 0} {$i < $options(-multi)} {incr i} {
	    $hull create line 0 0 0 0 -width 0 -tags [list spectrum spectrum-$i]
	}
    }

}
