#
# connections draws a collapsable tree for components
# and shows which components are connected
# the components and connections are provided by another
# snit component.
#
package provide sdrkit::startup-jconn 1.0

package require Tk
package require snit
#package require sdrtcl::jack; # this must be deferred
package require sdrtk::lvtreeview
package require sdrtk::lcanvas

namespace eval sdrkit {}

snit::type sdrkit::jackconn {

    variable data -array {
	items {}
	connections {}
    }

    option -server -readonly yes -default default

    constructor {args} {
	$self configure {*}$args
	set data(items) [dict create]
	set data(connections) {}
    }

    # get the list of port names
    method get-items {} {
	uplevel #0 [list package require sdrtcl::jack]
	set data(items) [dict create]
	set data(connections) [list]
	foreach {p dict} [sdrtcl::jack -server $options(-server) list-ports] {
	    dict set data(items) $p $dict
	    switch [dict get $dict direction] {
		input {
		    foreach source [dict get $dict connections] {
			puts "$source connects to $p"
			lappend data(connections) $source $p
		    }
		}
		output {
		    foreach dest [dict get $dict connections] {
			puts "$p connects to $dest"
			lappend data(connections) $p $dest
		    }
		}
	    }
	}
	return [dict keys $data(items)]
    }

    # get the list of connections
    method get-connections {} {
	return $data(connections)
    }

    # does the item exist
    method exists-item {item} { return [dict exists $data(items) $item] }

    # get the dictionary for $item
    method get-item-dict {item} { return [dict get $data(items) $item] }

    # get the value for $value at $item
    method get-item-value {item value} { return [dict get $data(items) $item $value] }

    # set the value for $value at $item
    method set-item-value {item value v} { return [dict set data(items) $item $value $v] }

    # unset the value for $value at $item
    method unset-item-value {item value} { dict unset data(items) $item $value }

    proc find-parent {child items} {
	set parent {}
	foreach c [dict keys $items] {
	    if {[string first $c $child] == 0 && [string length $parent] < [string length $c]} {
		set parent $c
	    }
	}
	return $parent
    }

    method find-ports {item} {
	set ports {}
	foreach pair [$options(-control) port-filter [list $item *]] {
	    lappend ports [lindex $pair 1]
	}
	return $ports
    }
    method find-port-connections-from {item} { return [$options(-control) port-connections-from [split $item :]] }
    method find-port-connections-to {item} { return [$options(-control) port-connections-to [split $item :]] }
    
    method find-active {item ports} {
	set active {}
	foreach key [dict keys $ports $item:*] {
	    lappend active $key [dict get $ports $key]
	}
	return $active
    }
    
    method find-opts {item} {
	set opts {}
	foreach pair [$options(-control) opt-filter [list $item *]] {
	    lappend opts [lindex $pair 1]
	}
	return $opts
    }
    method find-opt-connections {item} { return [$options(-control) opt-connections-from [split $item :]] }
    
    proc trim-parent-prefix {parent item} {
	if {[string first $parent- $item] == 0} {
	    return [string range $item [string length $parent-] end]
	} else {
	    return $item
	}
    }
}

snit::widget sdrkit::startup-jconn {
    component pane
    component lft
    component ctr
    component rgt
    component pop
    component jc
    
    option -container -readonly yes
    option -control -readonly yes
    option -server -readonly yes -default default
    option -defer-ms -default 100
    option -filter -default 0 -type snit::boolean
    
    variable data -array {
	update-pending 0
	update-canvas-pending 0
	pop-item {}
	pop-enabled 0
	pop-activated 0
	pop-type {}
    }
    
    constructor {args} {
	$self configure {*}$args
	#set options(-control) [$options(-container) cget -control]
	
	install pane using ttk::panedwindow $win.pane -orient horizontal
	install lft using sdrtk::lvtreeview $win.lft -scrollbar left -width 100 -show tree
	install ctr using sdrtk::lcanvas $win.ctr -width 100
	install rgt using sdrtk::lvtreeview $win.rgt -scrollbar right -width 100 -show tree

	## this should be an option
	install jc using sdrkit::jackconn $win.jc -server $options(-server)
	
	$ctr bind <Configure> [mymethod defer-update-canvas]
	foreach w [list $lft $rgt] {
	    $w bind <Button-3> [mymethod pop-up %W %x %y]
	    $w bind <<TreeviewSelect>> [mymethod item-select %W]
	    foreach e {<<TreeviewOpen>> <<TreeviewClose>> <<TreeviewScroll>>} {
		$w bind $e [mymethod defer-update-canvas]
	    }
	}
	
	grid [ttk::frame $win.top] -row 0 -column 0
	## all this might be irrelevant
	if {0} {
	    pack [ttk::label $win.top.l -text "connections of "] -side left
	    pack [ttk::menubutton $win.top.show -textvar [myvar data(show)] -menu $win.top.show.m] -side left
	    menu $win.top.show.m -tearoff no
	    foreach v {opt port active} l {{option value graph} {potential dsp graph} {active dsp graph}}  {
		$win.top.show.m add radiobutton -label $l -variable [myvar data(show)] -value $l -command [mymethod do-over $v]
		if {$v eq $options(-show)} { set data(show) $l }
	    }
	}
	grid $pane -row 1 -column 0 -sticky nsew
	$pane add $lft -weight 1
	$pane add $ctr -weight 2
	$pane add $rgt -weight 1
	$lft configure -label source -labelanchor n
	$ctr configure -label connect -labelanchor n
	$rgt configure -label sink -labelanchor n
	
	grid [ttk::checkbutton $win.ctl] -row 2 -column 0
	grid [ttk::checkbutton $win.filter -text {filter by selection} -variable [myvar options(-filter)] -command [mymethod defer-update-canvas]] -in $win.ctl -row 0 -column 0
	grid [ttk::button $win.update -text {update view} -command [mymethod update]] -in $win.ctl -row 0 -column 1
	
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure $win 1 -weight 1
	
	install pop using menu $win.pop -tearoff no
	$pop add checkbutton -label enable -variable [myvar data(pop-enabled)] -command [mymethod pop-enable]
	$pop add checkbutton -label activate -variable [myvar data(pop-activated)] -command [mymethod pop-activate]
	#$pop add separator
	#$pop add command -label open -command [mymethod pop-open]
	#$pop add command -label collapse -command [mymethod pop-collapse]
	$pop add separator
	$pop add command -label {open all} -command [mymethod pop-open-all]
	$pop add command -label {collapse all} -command [mymethod pop-collapse-all]
	$pop add separator
	$pop add command -label configuration -command [mymethod pop-configuration]
	$pop add command -label controls -command [mymethod pop-controls]
	
	$self update
    }
    
    method defer-update {} {
	if {$data(update-pending) == 0} {
	    set data(update-pending) 1
	    after $options(-defer-ms) [mymethod update]
	}
    }
    
    method jack-started {} {
	return [$options(-container) jack-started]
    }

    method update {} {
	if { ! [$self jack-started]} return
	# insert system playback, capture, and midi ports
	$self update-canvas
	set data(update-pending) 0
    }
    
    method find-selection {lor} {
	set sel [$win.$lor selection]
	# expand to recursively include children of selected
	foreach item [$jc get-items] {
	    if {[$jc get-item-value $item parent] in $sel} {
		lappend sel $item
	    }
	}
	return $sel
    }
    
    ##
    ## the canvas part of the display shows the connections
    ## which are drawn as splines
    ## uncertain whether connections to offscreen components
    ## are drawn or not
    ##
    method defer-update-canvas {} {
	if {$data(update-canvas-pending) == 0} {
	    set data(update-canvas-pending) 1
	    after $options(-defer-ms) [mymethod update-canvas]
	}
    }
    
    method update-canvas {} {
	# need to figure out if the connection line terminates above or below
	# they get too confusing, just leave them off
	foreach item [$jc get-items] {
	    foreach w {lft rgt} {
		# initialize y coordinate
		$jc set-item-value $item $w-y {}
		# find y coordinate
		if {[$win.$w exists $item]} {
		    set bbox [$win.$w bbox $item] 
		    if {$bbox ne {}} {
			lassign $bbox x y wd ht
			$jc set-item-value $item $w-y [expr {$y+$ht/2.0}]
		    }
		}
		# find parental y coordinate if necessary
		if {[$jc get-item-value $item $w-y] eq {}} {
		    for {set p [$jc get-item-value $item parent]} {$p ne {}} {set p [$jc get-item-value $p parent]} {
			set y [$jc get-item-value $p $w-y]
			if {$y ne {}} {
			    $jc set-item-value $item $w-y $y
			    break
			}
		    }
		}
	    }
	}
	# draw the lines
	$win.ctr delete all
	set wd [winfo width $win.ctr]
	set x0 0
	set x1 [expr {$wd/8.0}]
	set x2 [expr {$wd-1-$wd/8.0}]
	set x3 [expr {$wd-1}]
	if {$options(-filter)} {
	    set slft [$self find-selection lft]
	    set srgt [$self find-selection rgt]
	}
	if {[$self jack-started]} {
	    foreach {i o} [$jc get-connections] {
		# puts "preparing to draw $i ([dict exists $data(items) $i]) -> $o ([dict exists $data(items) $o])"
		if {$options(-filter) && [lsearch $slft $i] < 0} continue
		if {$options(-filter) && [lsearch $srgt $o] < 0} continue
		if { ! [$jc exists-item $i] || ! [$jc exists-item $o]} continue
		set ly [$jc get-item-value $i lft-y]
		set ry [$jc get-item-value $o rgt-y]
		if {$ly eq {} || $ry eq {}} continue
		$win.ctr create line $x0 $ly $x1 $ly $x2 $ry $x3 $ry -smooth true -width 2
		
	    }
	}
	set data(update-canvas-pending) 0
    }
    
    ##
    ## popup menu on right button
    ##
    method pop-enable {} {
	if {$data(pop-enabled)} {
	    $options(-control) part-enable $data(pop-item)
	} else {
	    $options(-control) part-disable $data(pop-item)
	}
	$self defer-update
    }
    
    method pop-activate {} {
	if {$data(pop-activated)} {
	    $options(-control) part-activate-tree $data(pop-item)
	} else {
	    $options(-control) part-deactivate-tree $data(pop-item)
	}
	$self defer-update
    }
    
    method pop-configuration {} {
	if {[$options(-control) part-exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- configuration"
	    foreach c [$options(-control) part-configure $data(pop-item)] {
		puts "-- [lindex $c 0] {[lindex $c end]}"
	    }
	    puts "--"
	}
    }
    
    method pop-controls {} {
	if {[$options(-control) part-exists $data(pop-item)]} {
	    puts "-- $data(pop-item) -- opts"
	    foreach c [$options(-control) opt-filter [list $data(pop-item) *]] {
		set opt [lindex $c 1]
		puts "-- $opt {[$options(-control) part-cget $data(pop-item) $opt]}"
	    }
	    puts "--"
	}
    }
    
    proc item-open {w item true recurse} {
	$w item $item -open $true
	if {$recurse} {
	    foreach child [$w children $item] {
		item-open $w $child $true $recurse
	    }
	}
    }
    
    method pop-open {} { item-open $data(pop-window) $data(pop-item) true false }
    method pop-collapse {} { item-open $data(pop-window) $data(pop-item) false false }
    method pop-open-all {} { item-open $data(pop-window) $data(pop-item) true true }
    method pop-collapse-all {} { item-open $data(pop-window) $data(pop-item) false true }
    
    method pop-up {w x y} {
	set data(pop-window) $w
	set data(pop-item) [$w identify item $x $y]
	set data(pop-enabled) [$jc get-item-value $data(pop-item) enabled]
	set data(pop-activated) [$jc get-item-value $data(pop-item) activated]
	set data(pop-type) [$jc get-item-value $data(pop-item) type]
	set data(pop-parent) [$jc get-item-value $data(pop-item) parent]
	switch $data(pop-type) {
	    dsp {
		$pop entryconfigure 0 -state disabled
		if {$data(pop-parent) eq {}} {
		    $pop entryconfigure 1 -state normal
		} else {
		    $pop entryconfigure 1 -state disabled
		}
	    }
	    jack {
		# how do I decide if this is an alternate entry which must be
		# enabled via select?
		$pop entryconfigure 0 -state normal
		$pop entryconfigure 1 -state disabled
	    }
	    default {
		$pop entryconfigure 0 -state disabled
		$pop entryconfigure 1 -state disabled
	    }
	}
	tk_popup $pop {*}[winfo pointerxy $w]
    }
    
    method item-select {w} {
	# puts "item-select $w -- [$w selection]"
	if {$options(-filter)} { $self defer-update-canvas }
    }
}

