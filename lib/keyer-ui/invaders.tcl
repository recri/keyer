package provide invaders 1.0.0

namespace eval invaders {

    array set data {
	game-w6rec-letter-sets {
	    EISH5 TMO0 AWJ1 NDB6 AUV4
	}

	game-words {
	    QRL QRM QRN QRS QRT QRZ QSB QSL QSO QSY QTH QRX
	    / 73 88 ?
	    ABT ADR AGE AGN ANT BEAM BK BN
	    C CL CPY CQ CUL DE DSW DX
	    EL ES FB GA GB GE GM GN GND GUD
	    HI HR HV HW
	    K
	    LID LOOP
	    N NAME NR NW
	    OM OP 
	    PKT PSE PWR
	    R RCVR RIG RPT RST
	    SAN SK SRI SSB
	    TEMP TEST TKS TMW TNX TU
	    UR
	    VERT VY
	    WATT WX 
	    XYL
	    YAGI YL YRS
	}

	game-all-letters {
	    "\"" "\b" {!} {$} {%} {'} {(} {)} {*} {+} {,} {-} {.} {/} 
	    {0} {1} {2} {3} {4} {5} {6} {7} {8} {9}
	    {:} {;} {=} {?} {@}
	    {A} {B} {C} {D} {E} {F} {G} {H} {I} {J} {K} {L} {M} {N} {O} {P} {Q} {R} {S} {T} {U} {V} {W} {X} {Y} {Z}
	    {_}
	}

	game-play-letters {
	    {+} {,} {-} {.} {/}
	    {0} {1} {2} {3} {4} {5} {6} {7} {8} {9}
	    {=} {?}
	    {A} {B} {C} {D} {E} {F} {G} {H} {I} {J} {K} {L} {M} {N} {O} {P} {Q} {R} {S} {T} {U} {V} {W} {X} {Y} {Z}
	}
	game-play-max-interval 5000
	game-play-level 14
	play 0

	game-session-size 50
	game-session-beacon-velocity 50
	game-session-beacon-frequency 50
	game-session-beacon-volume -30
    }

    #
    # morse code table
    # . indicates key down, space indicates key up
    # there is no key transition between adjacent
    # dots or spaces.
    # A space extends the end of letter off by two.
    # The end of letter space is added by code-get
    # Only used to count dits to restrict the length of "words".
    #
    array set code {
	\b {. . . . . . . .}
	{ } {  }
	{!} {. . . ... .}
	\" {. ... . . ... .}
	{$} {. . . ... . . ...}
	{%} {. ... . . .} 
	{'} {. ... ... ... ... .}
	{(} {... . ... ... .}
	    {)} {... . ... ... . ...}
	{*} {. . . ... . ...}
	{+} {. ... . ... .}
	{,} {... ... . . ... ...}
	{-} {... . . . . ...}
	{.} {. ... . ... . ...}
	{/} {... . . ... .}
	{0} {... ... ... ... ...}
	{1} {. ... ... ... ...}
	{2} {. . ... ... ...}
	{3} {. . . ... ...}
	{4} {. . . . ...}
	{5} {. . . . .}
	{6} {... . . . .}
	{7} {... ... . . .}
	{8} {... ... ... . .}
	{9} {... ... ... ... .}
	{:} {... ... ... . . .}
	{;} {... . ... . ... .}
	{=} {... . . . ...}
	{?} {. . ... ... . .}
	{@} {. ... ... . ... .}
	{A} {. ...}
	{B} {... . . .}
	{C} {... . ... .}
	{D} {... . .}
	{E} {.}
	{F} {. . ... .}
	{G} {... ... .}
	{H} {. . . .}
	{I} {. .}
	{J} {. ... ... ...}
	{K} {... . ...}
	{L} {. ... . .}
	{M} {... ...}
	{N} {... .}
	{O} {... ... ...}
	{P} {. ... ... .}
	{Q} {... ... . ...}
	{R} {. ... .}
	{S} {. . .}
	{T} {...}
	{U} {. . ...}
	{V} {. . . ...}
	{W} {. ... ...}
	{X} {... . . ...}
	{Y} {... . ... ...}
	{Z} {... ... . .}
	{_} {. . ... ... . ...}
	{a} {. ...}
	{b} {... . . .}
	{c} {... . ... .}
	{d} {... . .}
	{e} {.}
	{f} {. . ... .}
	{g} {... ... .}
	{h} {. . . .}
	{i} {. .}
	{j} {. ... ... ...}
	{k} {... . ...}
	{l} {. ... . .}
	{m} {... ...}
	{n} {... .}
	{o} {... ... ...}
	{p} {. ... ... .}
	{q} {... ... . ...}
	{r} {. ... .}
	{s} {. . .}
	{t} {...}
	{u} {. . ...}
	{v} {. . . ...}
	{w} {. ... ...}
	{x} {... . . ...}
	{y} {... . ... ...}
	{z} {... ... . .}
	{À} {. ... ... . ...}
	{Á} {. ... ... . ...}
	{Â} {. ... ... . ...}
	{Ä} {. ... . ...}
	{Ç} {... ... ... ...}
	{È} {. . ... . .}
	{É} {. . ... . .}
	{Ñ} {... ... . ... ...}
	{Ö} {... ... ... .}
	{Ü} {. . ... ...}
	{à} {. ... ... . ...}
	{á} {. ... ... . ...}
	{â} {. ... ... . ...}
	{ä} {. ... . ...}
	{ç} {... ... ... ...}
	{è} {. . ... . .}
	{é} {. . ... . .}
	{ñ} {... ... . ... ...}
	{ö} {... ... ... .}
	{ü} {. . ... ...}
    }
    
    #
    # read an code string out of the code elements
    # pass multiple characters as individual arguments
    # to concatenate their codes
    #
    proc code-get {args} {
	global code
	set result {}
	foreach c $args {
	    append result $code($c)
	}
	return "$result   "
    }
    
    proc code-for-text {text} {
	return {}
	foreach c [split $text {}] {
	    set up 0
	    set down 0
	    set ccode [code-get $c]
	    foreach d [split $ccode {}] {
		if {$d eq {.}} {
		    incr down
		    if {$up == 1} {
			append code {}
		    } elseif {$up == 3} {
			append code { }
		    } elseif {$up == 7} {
			append code "\n"
		    }
		    set up 0
		} elseif {$d eq { }} {
		    incr up
		    if {$down == 1} {
			append code {.}
		    } elseif {$down == 3} {
			append code {-}
		    } else {
			error "code-get returned a $down length element in $ccode"
		    }
		    set down 0
		}
	    }
	}
	return $code
    }
    
    
    #
    # initialize the code lengths
    #
    proc code-init {} {
	global data
	global code
	foreach c [array names code] {
	    set length($c) [string length [code-get $c]]
	}
	set data(game-play-letter-lengths) [array get length]
    }
    
    #
    # load the cumulative game score from disk
    #
    proc game-score-load {} {
	global score
	global data
	if { ! [file exists $data(score-file)]} {
	    set fp [open $data(score-file) w]
	    close $fp
	    array set score {}
	} else {
	    set fp [open $data(score-file) r]
	    array set score [read $fp]
	    close $fp
	}
	# game-score-summarize
    }
    
    #
    # write the cumulative game score to disk
    #
    proc game-score-save {} {
	global score
	global data
	set fp [open $data(score-file) w]
	puts $fp [array get score]
	close $fp
    }
    
    #
    # summarize the game score
    #
    proc game-score-summarize {} {
	global score
	foreach {name value} [array get score] {
	    puts " {$name} {$value}"
	}
    }
    
    #
    # score a play in the game
    #
    proc game-score {text result} {
	global score
	foreach c [split $text {}] {
	    if {$c eq "\b"} {
		append newtext "\\b"
	    } else {
		append newtext $c
	    }
	}
	lappend score($newtext) $result
    }
    
    #
    # game sprite display
    #
    proc game-play-text {w text} {
	play-text $text
    }
    
    #
    # clear whatever might be displayed
    #
    proc game-clear-screen {w} {
	$w delete all
	update idletasks
    }
    
    #
    # form the game texts which fit into $n dot clocks.
    # take all combinations of letters that are shorter
    # or equal to $n.
    #
    proc game-texts {n} {
	global data
	# get the dot lengths of the base letter set
	array set length $data(game-play-letter-lengths)
	# prune to the letter set and to the chosen length
	# form the base set of texts
	foreach c [array names length] {
	    if {[lsearch $data(game-play-letters) $c] < 0 || $length($c) > $n} {
		unset length($c)
	    } else {
		lappend texts $c
	    }
	}
	# iteratively accumulate new texts
	set ntexts [llength $texts]
	while {1} {
	    foreach c [array names length] {
		foreach t $texts {
		    if {[lsearch $texts $c$t] < 0} {
			set lct $length($c)
			incr lct $length($t)
			if {$lct <= $n} {
			    set length($c$t) $lct
			    lappend texts $c$t
			}
		    }
		}
	    }
	    if {[llength $texts] == $ntexts} break
	    set ntexts [llength $texts]
	}
	return $texts
    }
    
    proc canvas-width {w} {
	return [winfo width $w]
    }
    
    proc canvas-height {w} {
	return [winfo height $w]
    }
    
    proc canvas-random-x {w {inset 0.1}} {
	set wd [canvas-width $w]
	return [expr {$wd*($inset + (1-2*$inset)*rand())}]
    }
    
    proc canvas-random-y {w {inset 0.1}} {
	set ht [canvas-height $w]
	return [expr {$ht*($inset + (1-2*$inset)*rand())}]
    }
    
    proc canvas-state-tag {w tag state} {
	foreach i [$w find withtag $tag] {
	    $w itemconfig $i -state $state
	}
    }
    
    proc canvas-show-tag {w tag} { canvas-state-tag $w $tag normal }
    
    proc canvas-hide-tag {w tag} { canvas-state-tag $w $tag hidden }
    
    proc canvas-color-tag {w tag color} {
	foreach i [$w find withtag $tag] {
	    catch {$w itemconfig $i -outline $color}
	    $w itemconfig $i -fill $color
	}
    }
    
    proc sprite-hide {w id} { canvas-hide-tag $w sprite-$id-part }
    
    proc sprite-show {w id} { canvas-show-tag $w sprite-$id-part }
    
    proc sprite-tailor {w id showtext showcode} {
	foreach {show tag} [list $showtext sprite-$id-text $showcode sprite-$id-code] {
	    if {$show} {
		canvas-show-tag $id $tag
	    } else {
		canvas-hide-tag $id sprite-$id-$tag
	    }
	}
    }
    
    proc sprite-move {w id dx dy} {
	$w move sprite-$id-part $dx $dy
    }
    
    proc sprite-move-to {w id x y} {
	foreach {x1 y1 x2 y2} [$w bbox sprite-$id-part] break
	sprite-move $w $id [expr {$x-($x1+$x2)/2}] [expr {$y-($y1+$y2)/2}]
    }
    
    proc sprite-color {w id color} { canvas-color-tag $w sprite-$id-part $color }
    
    proc sprite-ball {w id} {
	foreach {x1 y1 x2 y2} [$w bbox sprite-$id-part] break
	set wd [expr {$x2-$x1}]
	set ht [expr {$y2-$y1}]
	set x [expr {($x1+$x2)/2}]
	set y [expr {($y1+$y2)/2}]
	set r [expr {1.5*max($wd/2, $ht/2)}]
	return [list $x $y $r]
    }
    
    proc sprite-in-bounds {w id} {
	set wd [canvas-width $w]
	set ht [canvas-height $w]
	foreach {x1 y1 x2 y2} [$w bbox sprite-$id-part] break
	set out {}
	if {$x1 < 0} { lappend out w }
	if {$x2 >= $wd} { lappend out e }
	# if {$y1 < 0} { lappend out n }
	if {$y2 >= $ht} { lappend out s}
	return $out
    }
    
    proc sprite-x {w id} { return [lindex [sprite-ball $w $id] 0] }
    proc sprite-y {w id} { return [lindex [sprite-ball $w $id] 1] }
    proc sprite-r {w id} { return [lindex [sprite-ball $w $id] 2] }
    
    proc sprite-make-code {w id text} {
	set x 0
	set s { }
	foreach c [split $text {}] {
	    foreach d [split [code-get $c] {}] {
		if {$d ne $s} {
		    set s $d
		    lappend ys $x
		}
		incr x
	    }
	}
	#puts $ys
	foreach {x1 x2} $ys {
	    $w create rectangle $x1 1 $x2 0 -fill black -outline black -tags [list sprite-$id-part sprite-$id-code]
	}
	$w scale sprite-$id-code 0 0 2 2
    }
    
    proc sprite-make-text {w id text} {
	foreach {x1 y1 x2 y2} [$w bbox sprite-$id-part] break
	set x [expr {($x1+$x2)/2}]
	return [$w create text $x $y1 -text $text -anchor s -tags [list sprite-$id-part sprite-$id-text]]
    }
    
    proc sprite-make-token {w id} {
	foreach {x y r} [sprite-ball $w $id] break
	return [$w create oval [expr {$x-$r}] [expr {$y-$r}] [expr {$x+$r}] [expr {$y+$r}] -fill {} -outline black -tags [list sprite-$id-part sprite-$id-token]]
    }
    
    proc sprite-make {w id text code} {
	global data
	sprite-make-code $w $id $text
	sprite-make-text $w $id $text
	$w lower sprite-$id-text sprite-$id-code
	sprite-make-token $w $id
	$w lower sprite-$id-token sprite-$id-text
	sprite-move $w $id -1000 -1000
	set data(game-sprite-$id) [list $id $text $code]
    }
    
    proc sprite-text {w id} {
	global data
	return [lindex $data(game-sprite-$id) 1]
    }
    
    proc sprite-code {w id} {
	global data
	return [lindex $data(game-sprite-$id) 2]
    }
    
    proc sprite-sound {w id} {
	game-play-text $w [sprite-text $w $id]
    }
    
    #
    # play one step in the life of a sprite
    #
    proc game-play-step {w} {
	global data
	if { ! $data(play)} {
	    # game cancelled
	    return
	}
	if {$data(game-play-sprite) eq {}} {
	    # no sprite in play
	    if {[llength $data(game-play-sprites)] == 0} {
		# no sprites left, session over
		puts "game-play-next session over"
		set data(play) 0
		return
	    } else {
		# no sprite in play, start one
		set data(game-play-sprite) [lindex $data(game-play-sprites) 0]
		set data(game-play-sprites) [lrange $data(game-play-sprites) 1 end]
		set data(game-play-sprite-dx) [expr {rand() > 0.5 ? 5 : -5}]
		set data(game-play-sprite-dy) 5
		set data(game-play-stimulus) {}
		set data(game-play-stimulus-last) {}
		set data(game-play-stimulus-played) {}
		set data(game-play-stimulus-repeat) 1500
		set data(game-play-response) {}
		set data(game-play-response-last) {}
		set data(game-play-response-played) {}
		
		set r [sprite-r $w $data(game-play-sprite)]
		sprite-move-to $w $data(game-play-sprite) [canvas-random-x $w] [expr {-$r}]
		sprite-sound $w $data(game-play-sprite)
		after 100 [list game-play-step $w]
		puts "game-play-step started new sprite"
	    }
	} else {
	    # sprite in play
	    append data(game-play-stimulus) [plug-read ascii_decode]
	    if {$data(game-play-stimulus) ne {}} {
		if {$data(game-play-stimulus-last) ne $data(game-play-stimulus)} {
		    puts "stimulus $data(game-play-stimulus)"
		    set data(game-play-stimulus-last) $data(game-play-stimulus)
		    set data(game-play-stimulus-played) [clock milliseconds]
		} elseif {[clock milliseconds] - $data(game-play-stimulus-played) > $data(game-play-stimulus-repeat)} {
		    sprite-sound $w $data(game-play-sprite)
		    set data(game-play-stimulus) {}
		    set data(game-play-stimulus-last) {}
		    set data(game-play-stimulus-played) {}
		}
	    }
	    append data(game-play-response) [plug-read iambic_decode]
	    if {$data(game-play-response) ne {}} {
		if {$data(game-play-response-last) ne $data(game-play-response)} {
		    puts "response $data(game-play-response)"
		    set data(game-play-response-last) $data(game-play-response)
		    set $data(game-play-response-played) [clock milliseconds]
		    if {[string first $data(game-play-stimulus) $data(game-play-response)] >= 0} {
			# kaboom - correctly answered
			sprite-move-to $w $data(game-play-sprite) -1000 -1000
			set data(game-play-sprite) {}
			after 100 [list game-play-step $w]
			return;
		    }
		}
	    }
	    set out [sprite-in-bounds $w  $data(game-play-sprite)]
	    if {[lsearch $out {s}] >= 0} {
		# kaboom - hit the ground
		sprite-move-to $w $data(game-play-sprite) -1000 -1000
		set data(game-play-sprite) {}
	    } elseif {[llength $out] > 0} {
		set data(game-play-sprite-dx) [expr {-$data(game-play-sprite-dx)}]
		sprite-move $w $data(game-play-sprite) $data(game-play-sprite-dx) $data(game-play-sprite-dy)
	    } else {
		sprite-move $w $data(game-play-sprite) $data(game-play-sprite-dx) $data(game-play-sprite-dy)
	    }
	    after 100 [list game-play-step $w]
	    # puts "game-play-step incremented step"
	}
    }
    
    #
    # set up the next session of game play
    #
    proc game-play-start {w} {
	global data
	if {$data(play)} {
	    game-clear-screen $w
	    foreach name [array names data game-sprite-*] {
		unset data($name)
	    }
	    set sprites {}
	    for {set i 0} {$i < $data(game-session-size)} {incr i} {
		set id [expr {int([llength $data(game-play-texts)]*rand())}]
		set text [string tolower [lindex $data(game-play-texts) $id]]
		set code [code-for-text $text]
		sprite-make $w $i $text $code
		# puts "sprite-make $w $id $text $code"
		lappend sprites $i
	    }
	    #update idletasks; after 5000
	    #foreach i $sprites { sprite-hide $w $i }
	    #update idletasks; after 5000
	    #foreach i $sprites { sprite-show $w $i }
	    #update idletasks; after 5000
	    #foreach i $sprites { sprite-color $w $i red }
	    #update idletasks; after 5000
	    #foreach i $sprites { sprite-move $w $i -1000 -1000 }
	    set data(game-play-sprites) $sprites
	    set data(game-play-sprite) {}
	    after 100 [list game-play-step $w]
	    puts "game-play-start started game"
	}
    }
    
    #
    #
    #
    proc game-play-level-change {level} {
	global data
	switch -regexp $level {
	    {^\d+$} {
		set data(game-play-texts) [game-texts $level]
	    }
	    {^words$} {
		set data(game-play-texts) $data(words)
	    }
	    default {
		set data(game-play-texts) {}
		foreach i [split $level {}] {
		    lappend data(game-play-texts) $i
		    foreach j [split $level {}] {
			lappend data(game-play-texts) $i$j
		    }
		}
	    }
	}
    }
    #
    # game panel user interface
    #
    proc ui-game-panel {w} {
	global data
	set data(game-play-canvas) $w.c
	ttk::frame $w
	pack [canvas $w.c] -side top -fill both -expand true
	pack [ttk::frame $w.m] -side bottom
	pack [ttk::menubutton $w.m.playlevel -text Level -menu $w.m.playlevel.m] -side left
	pack [ttk::radiobutton $w.m.start -text Start -variable data(play) -value 1 -command [list game-play-start $w.c]] -side left
	pack [ttk::radiobutton $w.m.stop -text Stop -variable data(play) -value 0 -command [list game-play-start $w.c]] -side left
	menu $w.m.playlevel.m -tearoff no
	foreach i {EISH5 TMO0 AWJ1 NDB6 AUV4 12 14 16 18 20 words} {
	    $w.m.playlevel.m add radiobutton -label $i -variable data(play-level) -value $i -command [list game-play-level-change $i]
	}
	pack [ttk::checkbutton $w.m.showcode -text {Show Code} -variable data(play-show-code)] -side left
	pack [ttk::checkbutton $w.m.showtext -text {Show Text} -variable data(play-show-text)] -side left
	return $w
    }
    
    if {0} {
    --score { set data(score-file) $value }
    --level { set data(game-play-level) $value }
    }
    game-score-load
    game-play-level-change $data(game-play-level)
    code-init
}
