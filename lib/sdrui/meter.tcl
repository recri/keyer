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
## meter - meter display
## actually, the s-meter
##

package provide sdrui::meter 1.0.0

package require Tk
package require snit
package require sdrui::tk-meter
package require sdrtcl::meter-tap
package require sdrtcl

snit::widget sdrui::meter {
    hulltype tk::frame
    component display
    component capture
    variable data -array {}

    # options controlling this component directly
    option -period -default 50 -type sdrtype::milliseconds -configuremethod Opt-handler

    # options for interfacing to jack, the hierarchy, the controller
    option -server -default default -readonly true
    option -container -readonly yes
    option -control -readonly yes

    option -command {}
    option -opt-connect-to {}
    option -opt-connect-from {}
    option -method-connect-from {}

    constructor {args} {
	# puts "sdrui::meter constructor {$args}"
	set options(-control) [from args -control [::radio cget -control]]
	$self configure {*}$args
	install display using sdrui::tk-meter $win.s
	pack $win.s -side top -fill both -expand true
	pack [ttk::frame $win.m] -side top
	# I guess I need to know if the agc is off
	set capture ::sdrctlx::rx-af-agc
	set data(after) [after $options(-period) [mymethod update]]
    }
    
    destructor {
	catch {after cancel $data(after)}
    }

    method capture-is-active {} { return [$capture is-active] }
    method capture-is-busy {} { return false }
    method capture-exists {} { return [expr {[info command $capture] ne {}}] }

    method update {} {
	if { [$self capture-exists] &&
	     ! [$self capture-is-busy] &&
	     [$self capture-is-active]} {
	    lassign [$capture get] frame level
	    set dB [sdrtcl::linear-to-dB [expr {1.0/($level+1e-16)}]]
	    $win.s update $dB
	    # puts "meter update $frame $level $dB busy=[$self capture-is-busy] active=[$self capture-is-active]"
	}
	set data(after) [after $options(-period) [mymethod update]]
    }
    
    method Opt-handler {opt val} {
	set options($opt) $val
	$options(-command) report $opt $val
    }
}    
