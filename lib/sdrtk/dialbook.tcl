# -*- mode: Tcl; tab-width: 8; -*-
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

#
# a rotary encoder menu multiple display widget
#
# this manages a group of tabs associated with a rotary encoder
# controller.
#
# initially planned to use the rotary encoder to select options to dial
# as well as option value, but never got the finite set select properly
# done so reverted to checkbuttons, radiobuttons, and menubuttons in a
# grid.  Need to go back to the original plan sometime.  Make it work 
# with keyboard focus, Enter to select the menu of options, Up and Down
# to select the option, Enter to pick the option, Up and Down to select
# the option value, possibly with Ctrl Meta Super Shift prefixes to accelerate.

# Left and Right to traverse the tabs

#
package provide sdrtk::dialbook 1.0

package require Tk
package require snit
package require sdrtk::dial

snit::widgetadaptor sdrtk::dialbook-tab {
    # Either normal, disabled or hidden.
    # If disabled, then the tab is not selectable.
    # If hidden, then the tab is not shown.
    option {-state state State} -default normal -type { snit::enum -values {normal disabled hidden} }

    # Specifies how the slave window is positioned within the pane area.
    # Value is a string containing zero or more of the characters n, s, e, or w.
    # Each letter refers to a side (north, south, east, or west) that the slave window
    # will “stick” to, as per the grid geometry manager.
    option {-sticky sticky Sticky} -default {} -type { snit::stringtype -regexp {[nsew]*} }

    # Specifies the amount of extra space to add between the notebook and this pane.
    # Syntax is the same as for the widget -padding option.
    option {-padding padding Padding} -default {} -type { snit::listtype -maxlen 4 -type snit::integer }

    delegate option -text to hull
    delegate option -image to hull
    delegate option -compound to hull
    delegate option -underline to hull

    variable data -array {}
    
    constructor {window args} {
	# the hull is the label displayed for tab selection
	installhull using ttk::label
	set data(window) $window
	$self configurelist $args
	# puts "dialbook create tab window {$window} text {[$self cget -text]} self {$self}"
	# create button here
	# create menu here
    }

    destructor {
    }

    method mapped {} { $data(window) mapped }
    method unmapped {} { $data(window) unmapped }
    method menu-entry {w text} { return [$data(window) menu-entry $w $text] }
    method button-entry {w text} {
	if { ! [winfo exists $w] } { 
	    $data(window) button-entry $w $text 
	} 
	return $w 
    }

    method get-text {} { return [$hull cget -text] }
    method get-window {} { return $data(window) }
    method get-label {} { return $win }
}

snit::widget sdrtk::dialbook {
    component tab
    component dial
    component grid
    component tree
    option -class undefined
    option {-cursor cursor Cursor} {}
    option {-style style Style} {}
    option {-takefocus takeFocus TakeFocus} 1
    # If present and greater than zero, specifies the desired height of the pane area
    # (not including internal padding or the dial).
    # Otherwise, the maximum height of all panes is used.
    option {-height height Height} {}
    # Specifies the amount of extra space to add around the outside of the notebook.
    # The padding is a list of up to four length specifications left top right bottom.
    # If fewer than four elements are specified, bottom defaults to top,
    # right defaults to left, and top defaults to left.
    option {-padding padding Padding} {}
    # If present and greater than zero, specifies the desired width of the pane area
    # (not including internal padding). Otherwise, the maximum width of all panes is used.
    option {-width width Width} {}
    
    option {-grid grid Grid} 0
    option {-tree tree Tree} 0
    
    delegate option * to dial
    delegate method * to dial

    variable data -array {
	tabs {}
	current {}
	displayed {}
	menu false
	counter 0
	button {}
    }

    constructor {args} {
	# puts "sdrtk::dialbook constructor {$args}"
	$self configurelist $args
	install tab using ttk::frame $win.tab
	install dial using sdrtk::dial $win.dial

	bind $dial <<DialCW>> [mymethod Adjust %W 1]
	bind $dial <<DialCCW>> [mymethod Adjust %W -1]
	bind $dial <<DialPress>> [mymethod Press %W]
	bind $dial <Left> [mymethod PreviousTab %W]
	bind $dial <Right> [mymethod NextTab %W]
	#? bind $win <Enter> [list focus $win.dial]
	#bind $dial <FocusIn> [list puts "FocusIn $win.dial"]
	#bind $dial <FocusOut> [list puts "FocusOut $win.dial"]
	#bind $win <FocusIn> [list puts "FocusIn $win"]
	#bind $win <FocusOut> [list puts "FocusOut $win"]
	#bind $win <ButtonPress-1> +[list focus $win.dial]
	bind $dial <ButtonPress-1> +[list focus $win.dial]

	if {$options(-grid)} { install grid using ttk::frame $win.grid }
	if {$options(-tree)} { install tree using ttk::treeview $win.tree -columns {current comp type window} -display {current} }
	$self configure {*}$args
	pack $tab -side top -fill x -expand true
	pack $dial -side top -fill x -expand true
	if {$options(-grid)} {
	    pack $grid -side right -fill both -expand true
	}
	if {$options(-tree)} {
	    bind $tree <<TreeviewSelect>> [mymethod TreeSelect $tree]
	    bind $tree <Return> [mymethod TreeReturn $tree]
	    $tree column current -width 150
	    $tree column #0 -width 150
	    pack $tree -side bottom -fill both -expand true
	    #puts "$win.tree and $tree are the same"
	    #puts "bind $tree <KeyPress-Return> -> [bind $tree <KeyPress-Return>]"
	}
    }

    #
    # The tabid argument to the following commands may take any of the following forms:
    # •  An integer between zero and the number of tabs;
    # •  The name of a slave window;
    # •  A positional specification of the form “@x,y”, which identifies the tab
    # •  The literal string “current”, which identifies the currently-selected tab; or:
    # •  The literal string “end”, which returns the number of tabs (only valid for “pathname index”).
    #

    # Adds a new tab to the dialbook.
    # See TAB OPTIONS for the list of available options.
    # If window is currently managed by the notebook but hidden,
    # it is restored to its previous position.
    method add {window comp xtype args} {
	set tab [$self FindWindow $window]
	if {$tab ne {}} {
	    # remember hidden window
	    $tab configure -state normal {*}$args
	    return
	}
	lappend data(tabs) [$self NewTab $window {*}$args]
	set tab [$self FindWindow $window]
	$self UpdateLists
	if {$options(-grid)} { $self LayoutGrid }
	if {$options(-tree)} {
	    # should be $self LayoutTree, but too much information to transfer
	    set text [$tab cget -text]
	    set value [$window cget -value]
	    set var [$window cget -variable]
	    # inserting components into the tree
	    if {$comp ne {} && $comp ni [$tree children {}]} {
		$tree insert {} end -id $comp -text -$comp
	    }
	    $tree insert $comp end -id $text -text $text -values [list $value $comp $xtype $window]
	    trace add variable $var write [mymethod TreeUpdateCurrent]
	}
    }

    # when an option in the treeview is selected, copy the selection to the dialbook
    method TreeSelect {w} {
	if {[$w focus] eq {}} return
	set window [$tree set [$w focus] window]
	if {$window eq {}} return
	set tab [$self FindWindow $window]
	if {$tab eq {}} return
	# puts "TreeSelect $w, window $window, tab $tab, current $data(current)"
	if {$tab ne $data(current)} { $self select $window }
    }
    
    # when the value of a treeview option is updated, copy the updated value into the treeview
    method TreeUpdateCurrent {name1 name2 op} {
	set save [$tree selection]
	$tree selection set $name2
	upvar ${name1}($name2) value
	$tree set $name2 current $value
	$tree selection set $save
    }
    # when Return is typed in a treeview, open up an item details view
    method TreeReturn {w} {
	puts "TreeReturn $w, focus [$w focus], [$w set [$w focus]]"
    }
    
    # Removes the tab specified by tabid, unmaps and unmanages the associated window.
    method forget {tabid} {
	puts "$self forget $tabid"
    }

    # Hides the tab specified by tabid.
    # The tab will not be displayed, but the associated window remains managed by the notebook
    # and its configuration remembered.
    # Hidden tabs may be restored with the add command.
    method hide {tabid} {
	puts "$self hide $tabid"
    }

    # Returns the name of the element under the point given by x and y,
    # or the empty string if no component is present at that location.
    # Returns the name of the element at the specified location.
    method {identify element} {x y} {
	puts "$self identify element $x $y"
    }

    # Returns the index of the tab at the specified location.
    method {identify tab} {x y} {
	puts "$self identify tab $x $y"
    }

    # Returns the numeric index of the tab specified by tabid, or the total number of tabs if tabid is the string “end”.
    method index {tabid} { return [$self FindIndex $tabid] }

    # Inserts a pane at the specified position.
    # pos is either the string end, an integer index, or the name of a managed subwindow.
    # If subwindow is already managed by the notebook, moves it to the specified position.
    # See TAB OPTIONS for the list of available options.
    method insert {pos subwindow args} {
	set tab [$self FindWindow $subwindow]
	if {$tab ne {}} {
	    set i [lsearch $data(tabs) $tab]
	    set data(tabs) [lreplace $data(tabs) $i $i]
	} else {
	    set tab [$self NewTab $window {*}$args]
	}
	set i [$self FindIndex $pos]
	if {$i eq {}} {
	    lappend data(tabs) $tab
	} else {
	    set data(tabs) [linsert $data(tabs) $i $tab]
	}
    }

    # See ttk::widget(n).
    method instate {statespec args} {
    }

    # Selects the specified tab.
    # The associated slave window will be displayed,
    # and the previously-selected window (if different) is unmapped.
    # If tabid is omitted, returns the widget name of the currently selected pane.
    method select {{tabid {}}} {
	if {$tabid eq {}} {
	    if {$data(current) ne {}} {
		return [$data(current) get-window]
	    }
	    return {}
	}
	set current [$self FindTab $tabid]
	if {$current eq {}} {
	    return
	}
	set data(current) $current
	set data(menu-select) $current
	$self UpdateCurrent
    }

    # See ttk::widget(n).
    method state {args} {
    }

    # Query or modify the options of the specific tab.
    # If no -option is specified, returns a dictionary of the tab option values.
    # If one -option is specified, returns the value of that option.
    # Otherwise, sets the -options to the corresponding values.
    # See TAB OPTIONS for the available options.
    method tab {tabid args} {
    }

    # Returns the list of windows managed by the notebook.
    method tabs {} {
	set tabs {}
	# puts "dialbook tabs $data(tabs)"
	foreach tab $data(tabs) { lappend tabs [$tab get-window] }
	return $tabs
    }
    
    ##
    ##
    ##
    method Adjust {w step} {
	# puts "$self Adjust $step for $data(current) menu $data(menu)"
	# the units of $step are counts, where [$dial cget -cpr] are the counts per revolution
	$w Rotate $step
	if {$data(menu)} {
	    
	} else {
	    if {$data(current) ne {}} {
		# puts "$self Adjust $w $step [$data(current) get-window] adjust $step"
		[$data(current) get-window] adjust $step
	    }
	}
    }

    method Press {w} {
	puts "$self Press"
	if {0} {
	if {$data(menu)} {
	    # select currently addressed tab
	    # end menu
	} else {
	    # start menu - done as a plain popup, but needs to be
	    # redone in a way that uses the rotational input
	    set data(menu) true
	    if { ! [winfo exists $win.menu]} {
		menu $win.menu -tearoff no
	    } else {
		$win.menu delete 0 end
	    }
	    # okay, change this so that enumerated values present a checkbutton or cascade to radiobutton
	    # and change to use a reverse lru ordering of the tabs
	    set data(menu-select) $data(current)
	    set i 0
	    foreach atab $data(tabs) {
		set text [$atab get-text]
		# puts "$win.menu add radiobutton -label {$text} -value {$atab}"
		# puts "$atab menu-entry -> {[$atab menu-entry $text]}"
		set menu [$atab menu-entry $win.menu.m$i $text]
		if {$menu eq {}} {
		    $win.menu add radiobutton -label $text \
			-value $atab -variable [myvar data(menu-select)] \
			-command [mymethod MenuInvoke $atab]
		} else {
		    $win.menu add {*}$menu
		    incr i
		}
	    }
	    bind $win.menu <<MenuSelect>> +[mymethod MenuSelect]
	    bind $win.menu <Unmap> +[mymethod MenuUnmap]
	    tk_popup $win.menu [winfo pointerx $win] [winfo pointery $win] [lsearch $data(tabs) $data(current)]
	}
    }
    }

    method MenuSelect {} {
	set index [$win.menu index active]
	if {$index ne {none}} { $self DisplayTab [lindex $data(tabs) $index] }
    }

    method MenuInvoke {atab} {
	set data(menu) false
	set data(current) $atab
	$self UpdateCurrent
    }

    method MenuUnmap {} {
	set data(menu) false
	$self UpdateCurrent
    }

    method NewTab {window args} {
	return [sdrtk::dialbook-tab $win.tab[incr data(counter)] $window {*}$args]
    }

    method FindWindow {window} {
	foreach tab $data(tabs) { if {[$tab get-window] eq $window} { return $tab } }
    }

    method FindIndex {tabid} {
	switch -regexp $tabid {
	    {^end$} { return [llength $data(tabs)] }
	    {^current$} {
		if {$data(current) eq {}} { return {} }
		return [lsearch $data(tabs) $data(current)]
	    }
	    {^@\d+} {
		# angular? o'clock?
	    }
	    {^\d+$} {
		if {$tabid >= 0 && $tabid < [llength $data(tabs)]} {
		    return $tabid
		}
	    }
	    {^\..*$} {
		set tab [$self FindWindow $tabid]
		if {$tab ne {}} {
		    return [lsearch $data(tabs) $tab]
		}
	    }
	}
	return {}
    }
	
    method FindTab {tabid} {
	set i [$self FindIndex $tabid]
	if {$i ne {} && $i >= 0 && $i < [llength $data(tabs)]} { return [lindex $data(tabs) $i] }
	return {}
    }

    method IsDisplayedTab {atab} { return $atab eq $data(displayed) }
    method DisplayTab {atab} {
	if {$atab eq $data(displayed)} return
	if {$data(displayed) ne {} && [info commands $data(displayed)] ne {}} {
	    $data(displayed) unmapped
	    grid forget [$data(displayed) get-window]
	}
	set data(displayed) $atab
	grid [$atab get-window] -in $win.tab -sticky ew -row 0 -column 0
	grid columnconfigure $win.tab 0 -minsize $data(wd)
	grid rowconfigure $win.tab 0 -minsize $data(ht)
	$data(displayed) mapped
    }

    method SubwindowMapped {w} {
	bind $w <Map> {}
	$self UpdateLists
    }

    proc makewname {w} {
	# this comes from set w x$comp:$opt in keyer/load-ui
	set result [lindex [split [$w get-window] .] end]
	# puts "makewname $w: label [$w get-label] window [$w get-window] text [$w get-text] result $result"
	return $result
    }

    method LayoutGrid {} {
	set row 0; set col 0; set maxrow 8
	foreach atab $data(tabs) {
	    set button $win.grid.[makewname $atab]
	    if { ! [winfo exist $button] } {
		$atab button-entry $button [$atab get-text]
		if { ! [winfo exist $button] } {
		    ttk::radiobutton $button -text [$atab get-text] \
			-value $atab -variable [myvar data(menu-select)] \
			-command [mymethod MenuInvoke $atab]
		    if { ! [winfo exist $button] } {
			error "no window for $button"
		    }
		}
	    }
	    bind $button <Enter> [mymethod EnterTab $atab]
	    bind $button <Leave> [mymethod LeaveTab $atab]
	    grid $button -row $row -column $col -sticky ew
	    if {[incr row] > $maxrow} { set row 0; incr col }
	}
    }
    method EnterTab {atab} {
	#puts "EnterTab $atab"
	$self DisplayTab $atab
	if {$options(-tree)} {
	    $tree selection set [$atab cget -text]
	    $tree see [$atab cget -text]
	    #puts "EnterTab $atab [$atab info options] [$atab cget -text]"
	}
    }
    method LeaveTab {atab} {
	#puts "LeaveTab $atab"
	$self UpdateCurrent
	# if tree, deselect entry
    }

    method UpdateLists {} {
	set data(wd) 0
	set data(ht) 0
	foreach atab $data(tabs) {
	    set w [$atab get-window]
	    if { ! [winfo ismapped $w]} {
		#update idletasks
		bind $w <Map> [mymethod SubwindowMapped %W]
	    }
	    lappend data(wd) [winfo width $w]
	    lappend data(ht) [winfo height $w]
	}
	set data(wd) [tcl::mathfunc::max {*}$data(wd)]
	set data(ht) [tcl::mathfunc::max {*}$data(ht)]
	grid columnconfigure $win.tab 0 -minsize $data(wd)
	grid rowconfigure $win.tab 0 -minsize $data(ht)
	# puts "$self UpdateLists tabs $data(tabs) wd $data(wd) ht $data(ht)"
	# if { ! $data(menu)} { $self UpdateCurrent }
    }

    method UpdateCurrent {} {
	# puts "$self UpdateCurrent: $data(current) $data(tabs)"
	if {$data(current) eq {} || [lsearch $data(tabs) $data(current)] < 0} {
	    if {[llength $data(tabs)] > 0} {
		set data(current) [lindex $data(tabs) 0]
		$self DisplayTab $data(current)
	    }
	} else {
	    $self DisplayTab $data(current)
	}
    }

    method NextTab {w} {
	set t $data(tabs)
	set c $data(current)
	set j [lsearch $t $c]
	set n [llength $t]
	set i [expr {($j+1+$n)%$n}]
	set data(current) [lindex $t $i]
	$self UpdateCurrent
    }
    method PreviousTab {w} {
	set t $data(tabs)
	set c $data(current)
	set j [lsearch $t $c]
	set n [llength $t]
	set i [expr {($j-1+$n)%$n}]
	set data(current) [lindex $t $i]
	$self UpdateCurrent
    }
}    
