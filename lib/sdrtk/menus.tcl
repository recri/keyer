    # since tk on ubuntu 18.04 is using microscopic check/radio/cascade markers
    # rewrite the labels of this menu to do the job
    # ack, tk has totally microscopic check and radio and cascade menu markers
    # ☐ ☑ ☒ ballot box, checked box, x'ed box, ▼ menu?
    # ◉ fisheye, ► menu?, 🔘 radiobutton, ⊙ circled dot, ⊚ circled circle,
    # ○ empty circle, ◉ filled, ◯ bigger empty circle, ◎ hollow
    # not great, the fonts picked by Tk don't preserve widths.
    proc menu-labels-decorate-legibly {m} {
	set n [$m index last]
	# puts "menu $m has $n entries"
	if {$n eq {none}} { set n -1 }
	for {set i 0} {$i <= $n} {incr i} {
	    switch [$m type $i] {
		command - separator - tearoff {
		    # no action required
		}
		checkbutton {
		    set label [$m entrycget $i -label]
		    set var [$m entrycget $i -variable]
		    set onval [$m entrycget $i -onvalue]
		    set offval [$m entrycget $i -offvalue]
		    if {[uplevel \#0 [list set $var]] eq $onval} {
			set label "☑ $label"
		    } else {
			set label "☐ $label"
		    }
		    $m entryconfigure $i -label $label -indicatoron 0
		}
		radiobutton {
		    set label [$m entrycget $i -label]
		    set var [$m entrycget $i -variable]
		    set val [$m entrycget $i -value]
		    if {[uplevel \#0 [list set $var]] eq $val} {
			set label "◉ $label"
		    } else {
			set label "◎ $label"
		    }
		    $m entryconfigure $i -label $label -indicatoron 0
		}
		cascade {
		    set label [$m entrycget $i -label]
		    $m entryconfigure $i -label "  $label ►"
		    menu-labels-decorate-legibly [$m entrycget $i -menu]
		}
		default {
		    puts "$m type $i => [$m type $i]"
		}
	    }
	}
    }
proc menu-labels {win} {
	    menu-labels-decorate-legibly $win.menu
}
