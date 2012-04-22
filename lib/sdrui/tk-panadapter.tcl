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
## panadapter - combined spectrum, waterfall, and frequency display
##
package provide sdrui::tk-panadapter 1.0.0

package require Tk
package require snit

package require sdrkit::jack
package require sdrui::tk-waterfall
package require sdrui::tk-spectrum
package require sdrui::tk-frequency
package require sdrblk::capture

snit::widgetadaptor sdrui::tk-panadapter {
    option -zoom 1.0
    option -scroll 0.0
    option -update {}
    option -min -configuremethod delegate
    option -max -configuremethod delegate
    option -center -configuremethod delegate
    option -pal -configuremethod delegate
    option -connect -default {} -configuremethod delegate
    option -period -default 50 -configuremethod delegate
    option -size -default 4096 -configuremethod delegate
    option -polyphase -default 0 -configuremethod delegate
    option -server -default default -readonly true

    component spectrum
    component waterfall
    component frequency
    component capture

    method update {xy args} {
	# update spectrum and waterfall
	$spectrum update $xy
	$waterfall update $xy
	$frequency update $xy
	if {$options(-update) ne {}} {
	    {*}$options(-update) $xy {*}$args
	}
    }

    method delegate {option value} {
	switch -- $option {
	    -min -
	    -max {
		set options($option) $value
		if {$spectrum ne {}} { $spectrum configure $option $value }
		if {$waterfall ne {}} { $waterfall configure $option $value }
	    }
	    -pal {
		set options($option) $value
		if {$waterfall ne {}} { $waterfall configure $option $value }
	    }
	    -center {
		set options($option) $value
		if {$frequency ne {}} { $frequency configure -lo1-offset $value }
	    }
	    -size -
	    -period -
	    -polyphase {
		set options($option) $value
		if {$capture ne {}} { $capture configure $option $value }
	    }
	    -connect {
		set options($option) $value
		if {$capture ne {}} { $capture configure $option $value }
	    }
	    default {
		set options($option) $value
	    }
	}
    }
    
    method window-configure {w cw width height} {
	if {$w ne $cw} return
	# puts "panadapter::window-configure $w $cw $width $height"
	# puts "::capture::configure $w -size $width"
	$capture configure -size $width
	set srate [sdrkit::jack sample-rate]
	set scale [expr {$options(-zoom)*double($width)/$srate}]
	set offset [expr {double($width)/2}]
	$waterfall configure -scale $scale -offset $offset
	$spectrum configure -scale $scale -offset $offset
	$frequency configure -scale $scale -offset $offset
    }

    destructor  {
	catch {$capture stop}
	catch {$capture destroy}
    }

    delegate method * to hull
    delegate option * to hull

    constructor {args} {
	installhull using ttk::panedwindow -orient vertical
	$self configure {*}$args
	install spectrum using sdrui::tk-spectrum $win.s
	install frequency using sdrui::tk-frequency $win.f
	install waterfall using sdrui::tk-waterfall $win.w
	install capture using sdrblk::capture %AUTO% -type spectrum -server $options(-server) -period $options(-period) -size $options(-size) -update [mymethod update]
	$hull add $win.s -weight 1
	$hull add $win.f -weight 0
	$hull add $win.w -weight 1
	if {$options(-connect) ne {}} {
	    $capture start
	}
	bind $win <Configure> [mymethod window-configure $win %W %w %h]
    }
}
