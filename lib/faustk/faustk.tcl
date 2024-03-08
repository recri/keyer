package require Tk
package provide faustk 1.0

namespace eval ::faustk {
    proc updateProgressValue {w cmd option min} {
	-value [$cmd cget -$option]
    }
}

# name spaces occupied by defined
namespace eval ::faustk::pm {}
namespace eval ::faustk::stk {}
namespace eval ::faustk::tst {}

proc faustk::hgroup {label meta children} {
    upvar w pw t pt cmd cmd
    set w $pw.[string tolower $label]
    set t hgroup
    # if the parent is a tab group, use the label in the tab
    # otherwise use the label on our frame
    if {$pt eq {tgroup}} {
	ttk::frame $w
    } else {
	ttk::labelframe $w -text $label -labelanchor n
    }
    foreach child $children {
	foreach {cw ctext} [eval $child] break;
	pack $cw -side left -expand true -fill y
    }
    return [list $w $label]
}
proc faustk::tgroup {label meta children} {
    upvar w pw t pt cmd cmd;	# retrieve values from caller
    set t tgroup
    set w $pw.[string tolower $label]
    ttk::notebook $w%s
    foreach child $children {
	foreach {cw ctext} [eval $child] break;
	$w add $cw -text $ctext
    }
    return [list $w $label]
}
proc faustk::vgroup {label meta children} {
    upvar w pw		# retrieve the parent window
    upvar t pt		# retrieve the parent type
    upvar cmd cmd	# retrieve the dsp command
    set t vgroup	# define our type
    set w $pw.[string tolower $label]
    if {$pt eq {tgroup}} {
	ttk::frame $w
    } else {
	ttk::labelframe $w -text $label -labelanchor n
    }
    foreach child $children {
	foreach {cw ctext} [eval $child] break;
	pack $cw -side top -expand true -fill x
    }
    return [list $w $label]
}
proc faustk::button {label option meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    ttk::button $w -text $label -command [list $cmd configure -$option]
    bind $w <Button-1> { {*}[%W cget -command] 1 }
    bind $w <ButtonRelease-1> [%W cget -command 0 }
    return [list $w $label]
}
proc faustk::checkbutton {label option meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    ttk::checkbutton $w -text $label -command [list $cmd configure -$option [list set ::$w]]
    return [list $w $label]
}
proc faustk::hslider {label option min max init step meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    set style linear
    if {[dict exists $meta style]} {
	set style [dict gets $meta style]
    }
    ttk::labelframe $w -text $label  -labelanchor n
    switch $style {
	linear {
	    ttk::scale $w.s -orient horizontal -from $min -to $max -value $init \
		-command [list $cmd configure -$option]
	}
	knob {
	    faustk::knob $w.s -from $min -to $max -value $init -by $step \
		-command [list $cmd configure -$option]
	}
    }
    pack $w.s -fill both -expand true
    return [list $w $label]
}
proc faustk::vslider {label option min max init step meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    set style linear
    if {[dict exists $meta style]} {
	set style [dict gets $meta style]
    }
    ttk::labelframe $w -text $label  -labelanchor n
    switch $style {
	linear {
	    ttk::scale $w.s -text $label -orient vertical -from $min -to $max -value $init \
		-command [list $cmd configure -$option]
	}
	knob {
	    faustk::knob $w.s -from $min -to $max -value $init -by $step \
		-command [list $cmd configure -$option]
	}
    }
    pack $w.s -fill both -expand true
    return [list $w $label]
}
proc faustk::nentry {label option min max init step meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    ttk::labelframe $w -text $label -labelanchor n
    ttk::spinbox $w.s -from $min -to $max -value $init -increment $step \
	 -command [list $cmd configure -$option]
    pack $w%s.s -fill both -expand true
    ttk::checkbutton $w -text $label -command [list $cmd configure -$option [list set ::$w]]
    return [list $w $label]
}
proc faustk::hbargraph {label option min max meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    ttk::labelframe $w -text $label  -labelanchor n
    ttk::progressbar $w.p -orient horizontal -maximum [expr {$max-$min}] -mode determinate
    faustk::updateProgressValue $w $cmd $option $min
    pack $w.p -fill both -expand true
    return [list $w $label]
}
proc faustk::vbargraph {label option min max meta} {
    upvar w pw		# retrieve the parent window
    upvar cmd cmd	# retrieve the dsp command
    set w $pw.[string tolower $label]
    ttk::labelframe $w -text $label  -labelanchor n
    ttk::progressbar $w.p -orient vertical -maximum [expr {$max-$min}] -mode determinate \
    faustk::updateProgressValue $w $cmd $option $min
    pack $w.p -fill both -expand true
    return [list $w $label]
}
