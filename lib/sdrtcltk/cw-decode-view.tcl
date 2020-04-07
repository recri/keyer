#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
package provide sdrtcltk::cw-decode-view 1.0.0

#
# read only text widget, receiving decoded morse
#
package require Tk
package require snit

package require sdrtcl::filter-goertzel
package require sdrtcl::keyer-detime

package require morse::morse
package require morse::itu
package require morse::dicts

namespace eval ::sdrtcltk {}

snit::widgetadaptor sdrtcltk::cw-decode-view {
    component detone
    # -verbose -server -client -chan -note -freq -bandwidth -on -off -timeout
    component detime
    # -verbose -server -client -chan -note -wpm

    option -verbose -default 0 -configuremethod ConfigShared
    option -server -default {} -configuremethod ConfigShared
    option -client -default 0 -configuremethod ConfigShared
    option -chan -default 1 -configuremethod ConfigShared
    option -note -default 0 -configuremethod ConfigShared
    delegate option -freq to detone
    delegate option -bandwidth to detone
    delegate option -on to detone
    delegate option -off to detone
    delegate option -wpm to detime
    option -dict -default fldigi
    option -font -default TkDefaultFont
    option -foreground -default black -configuremethod ConfigText
    option -background -default white -configuremethod ConfigText
    
    method delete {args} { }
    method insert {args} { }
    
    delegate method * to hull
    delegate option * to hull
    
    delegate method ins to hull as insert
    delegate method del to hull as delete
    
    variable handler {}
    variable code {}
    
    constructor {args} {
	# puts "cw-decode-view constructor {$args}"
	installhull using text
	set client [winfo name [namespace tail $self]]
	set server [from args -server {}]
	set xargs {}
	if {$server ne {}} { lappend xargs -server $server }
	install detime using sdrtcl::keyer-detime $self.deti -client ${client}i {*}$xargs
	install detone using sdrtcl::filter-goertzel $self.deto -client ${client}o {*}$xargs
	$self configure -width 30 -height 15 -exportselection true {*}$args
	bind $win <ButtonPress-3> [mymethod option-menu %X %Y]
	set handler [after 100 [mymethod timeout]]
    }

    method is-busy {} { return 0 }
    method activate {} { $detime activate; $detone activate }
    method deactivate {} { $detime deactivate; $detone deactivate }
    
    # {-color1 -color2 -background}
 
    method exposed-options {} { return {-verbose -server -client -chan -note -freq -bandwidth -on -off -wpm -dict -font -foreground -background} }

    method info-option {opt} {
	if { ! [catch {$detone info option $opt} info]} { return $info }
	if { ! [catch {$detime info option $opt} info]} { return $info }
	switch -- $opt {
	    -background { return {color of window background} }
	    -foreground { return {color for text display} }
	    -font { return {font for text display} }
	    -dict { return {dictionary for decoding morse} }
	    default { puts "no info-option for $opt" }
	}
    }
    method ConfigShared {opt val} {
	$detone configure $opt $val
	$detime configure $opt $val
    }
    method ConfigText {opt val} {
	$hull configure $opt $val
    }
    method timeout {} {
	# get new text
	set text [$detime get]
	# insert into output display
	$self ins end $text
	$self see end
	# append to accumulated code
	append code $text
	while {[regexp {^([^ ]*) (.*)$} $code all symbol rest]} {
	    if {$symbol ne {}} {
		# each symbol must be terminated by a space
		# replace symbol and space with translation
		$self del end-[string length $code]chars-1chars end
		$self ins end "[morse-to-text [$options(-dict)] $symbol]$rest"
	    } else {
		# an extra space indicates a word space
		# and it's already there
	    }
	    set code $rest
	}
	set handler [after 250 [mymethod timeout]]
    }

    method save {} {
	set filename [tk_getSaveFile -title {Log to file}]
	if {$filename ne {}} {
	    write-file $filename [$self get 1.0 end]
	}
    }

    method clear {} {
	$self del 1.0 end
    }

    method option-menu {x y} {
	if { ! [winfo exists $win.m] } {
	    menu $win.m -tearoff no
	    $win.m add command -label {Clear} -command [mymethod clear]
	    $win.m add separator
	    $win.m add command -label {Save To File} -command [mymethod save]
	}
	tk_popup $win.m $x $y
    }
}
