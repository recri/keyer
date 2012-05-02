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
##
package provide sdrui::meter 1.0.0

package require Tk
package require snit
package require sdrui::tk-meter

snit::widget sdrui::meter {
    component display

    # options controlling this component directly
    option -period -default 100 -type sdrtype::milliseconds -configuremethod Opt-handler

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
	# connections to option controls
	regexp {^.*ui-(.*)$} $win all tail
	foreach opt {-period} {
	    lappend options(-opt-connect-to) [list $opt ctl-$tail $opt]
	    lappend options(-opt-connect-from) [list ctl-$tail $opt $opt]
	}
	lappend options(-method-connect-from) [list ctl-$tail get [mymethod update]]
    }
    
    method update {frame meter} {
	$win.s update [sdrtcl::power-to-dB [expr {1.0-$meter}]]
    }
    
    method Opt-handler {opt val} {
	set options($opt) $val
	$options(-command) report $opt $val
    }
}    
