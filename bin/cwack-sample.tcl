    #
    # maintain the count of play time and pause time for the current session in milliseconds
    # also maintain the start time and end time in seconds from unix epoch
    #
    proc format-time {millis} {
	# return [format {%d:%02d:%03d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}] [expr {$millis%1000}]]
	return [format {%d:%02d} [expr {($millis/1000)/60}] [expr {($millis/1000)%60}]]
    }
    proc accumulate-playtime {args} {
	#puts "accumulate-playtime $args"
	set playtime 0
	set pausetime 0
	foreach {tag millis} $args {
	    if {[info exists lasttag]} {
		switch [list $lasttag $tag] {
		    {play play} -
		    {play pause} { incr playtime [expr {$millis-$lastmillis}] }
		    {pause pause} -
		    {pause play} { incr pausetime [expr {$millis-$lastmillis}] }
		    default { error "uncaught time interval {$lasttag $tag}" }
		}
	    }
	    set lasttag $tag
	    set lastmillis $millis
	}
	return $playtime
    }
    
    #
    # score the results of a timed session over single characters
    # take the session log with the accumulated time and session parameters
    # the 'summary' is a statistical summary of the responses
    #
    proc sum {args} { tcl::mathop::+ {*}$args }
    proc sum2 {args} { tcl::mathop::+ {*}[lmap {x} $args {expr {$x*$x}}] }
    proc avg {args} { expr {double([sum {*}$args])/[llength $args]} }
    proc avg2 {args} { expr {double([sum2 {*}$args])/[llength $args]} }
    proc var {args} { expr {[avg2 {*}$args]-pow([avg {*}$args],2)} }
    proc quartiles {args} {
	# this is only accidentally correct according to any of the tedious
	# definitions given in wikipedia, but it's easy and obvious to write
	set args [lsort -increasing -real $args]
	set n [llength $args]
	set q1 [expr {max(0,min($n-1,int(round($n*0.25))))}]
	set q2 [expr {max(0,min($n-1,int(round($n*0.50))))}]
	set q3 [expr {max(0,min($n-1,int(round($n*0.75))))}]
	list [lindex $args 0] [lindex $args $q1] [lindex $args $q2] [lindex $args $q3] [lindex $args end]
    }
    proc percent {n m} { expr {$m ? int(round(100.0*$n/$m)) : 0} }
    proc init-summary {tag} { dict create tag $tag times {} chars {} }
    proc tag-summary {sum} { dict get $sum tag }
    proc times-summary {sum} { dict get $sum times }
    proc count-summary {sum} { llength [times-summary $sum] }
    proc time-summary {sum} { sum {*}[times-summary $sum] }
    proc time2-summary {sum} { sum2 {*}[times-summary $sum] }
    proc avg-summary {sum} { avg {*}[times-summary $sum] }
    proc var-summary {sum} { var {*}[times-summary $sum] }
    proc quartiles-summary {sum} { quartiles {*}[times-summary $sum] }
    proc chars-summary {sum} { dict get $sum chars }
    proc char-times-summary {sum char} { if {[dict exists $sum $char]} { dict get $sum $char } else { list } }
    proc char-count-summary {sum char} { llength [char-times-summary $sum $char] }
    proc char-exists-summary {sum char} { dict exists $sum $char }
    proc char-quartiles-summary {sum char} { quartiles {*}[char-times-summary $sum $char] }
    
    proc incr-summary {sum char time} {
	if {$char ni [dict get $sum chars]} { dict lappend sum chars $char }
	dict lappend sum times $time
	dict lappend sum $char $time
	return $sum
    }
    
    proc format-summary {sum} {
	set n [dict get $sum count]
	set tag [dict get $sum tag]
	set avg [dict get $sum avg]
	set var [dict get $sum var]
	set rms [expr {sqrt($var)}]
	set min [dict get $sum min]
	set max [dict get $sum max]
	return [format "%5s %3d min %3.1f avg %3.1f rms %3.1f max %3.1f" $tag $n $min $avg $rms $max]
    }
    proc session-summary {sum morse session} {
	set start [lrange $session 0 2]
	set wpm [lrange $session 3 5]
	set source [lrange $session 6 8]
	set ms [expr {([morse-dit-ms [lindex $wpm 1]]+[morse-dit-ms [lindex $wpm 2]])/2}]
	# this depends on the word end as a ch being spelled END
	if {[lindex $session end-2] eq {end}} {
	    set challenges [lrange $session 9 end-3]
	} else {
	    set challenges [lrange $session 9 end]
	}
	foreach {ch re time} $challenges { 
	    set l [morse-word-length $morse $ch]
	    set time [expr {$time/(2+$l)/$ms}]
	    dict set sum total [incr-summary [dict get $sum total] $ch $time]
	    if {$ch eq $re} {
		dict set sum hit [incr-summary [dict get $sum hit] $ch $time]
	    } elseif {$re eq {}} {
		dict set sum pass [incr-summary [dict get $sum pass] $ch $time]
	    } else {
		# score the correct answer not given as a miss
		dict set sum miss [incr-summary [dict get $sum miss] $ch $time]
		# if an incorrect answer was given, score it as a miss, too
		# should be a prosign and not a #, but details
		#if {$re ne {}} {
		#    dict set sum miss [incr-summary [dict get $sum miss] $re $time]
		#}
	    }
	    # puts $entry
	}
	if {0} {
	    set chars [lsort [chars-summary [dict get $sum total]]]
	    foreach char $chars {
		set hits {}
		set misses {}
		set passes {}
		if {[char-exists-summary [dict get $sum hit] $char]} {
		    set hits [lsort -real -increasing [char-times-summary [dict get $sum hit] $char]]
		}
		if {[char-exists-summary [dict get $sum miss] $char]} {
		    set misses [lmap {x} [char-times-summary [dict get $sum miss] $char] {lindex {-} 0}]
		}
		if {[char-exists-summary [dict get $sum pass] $char]} {
		    set passes [lmap {x} [char-times-summary [dict get $sum pass] $char] {lindex {-} 0}]
		}
	    }
	}
	return $sum
    }
    
    proc init-session-summary {} { dict create total [init-summary total] hit [init-summary hit] miss [init-summary miss] pass [init-summary pass] }
    
    proc history-summary {sessions morse {filter {}}} {
	return {}
	if {$sessions eq {}} { return {} }
	set summary [init-session-summary]
	foreach session $sessions {
	    if {$filter eq {} || [$filter $session]} {
		set summary [session-summary $summary $morse $session]
	    }
	}
	set total [dict get $summary total]
	set hit [dict get $summary hit]
	set miss [dict get $summary miss]
	set stats {}
	lappend stats [list { } [percent [count-summary $hit] [count-summary $total]] {*}[quartiles-summary $hit]]
	set chars [lsort [chars-summary $total]]
	if {1} {
	    # sort chars by dit length
	    set lengths [lmap c $chars {morse-word-length $morse $c}]
	    # puts $lengths
	    set indices [lsort -indices -increasing -integer $lengths]
	    set chars [lmap i $indices {lindex $chars $i}]
	}
	foreach char $chars {
	    set ntot [char-count-summary $total $char]
	    set nhit [char-count-summary $hit $char]
	    set nmiss [char-count-summary $miss $char]
	    # puts "$char total $ntot hit $nhit miss $nmiss"
	    lappend stats [list $char [percent $nhit [expr {$nmiss+$nhit}]] {*}[char-quartiles-summary $hit $char]]
	}
	return $stats
    }
    
    method history-update {} {
	set data(summary) [history-summary $data(history) [$options(-dict)]]
    }
    
    method score-session {} {
	# puts "score-session"
	# record start time, end time, elapsed trial time, session length
	$self append-cwack-history $data(session-log)
	$self history-update
	set s [session-summary [init-session-summary] [$options(-dict)] $data(session-log)]
	return "[percent [count-summary [dict get $s hit]] [count-summary [dict get $s total]]]% correct"
    }
    
    method score-current {} {
	set s [session-summary [init-session-summary] [$options(-dict)] $data(session-log)]
	set total [count-summary [dict get $s total]]
	if {$total == 0} {
	    set data(hitpct) 100
	} else {
	    set data(hitpct) [percent [count-summary [dict get $s hit]] $total]
	}
    }
    
    # score the results of a single challenge
    method score-challenge {} {
	lappend data(session-log) $data(pre-challenge) $data(trimmed-response) $data(response-time)
	# puts "score-challenge {$data(pre-challenge)} {$data(trimmed-response)} $data(response-time) ms"
    }
    
    proc sample-choosei {n} { return [expr {int(rand()*$n)}] }
    proc sample-choose {x} { return [lindex $x [sample-choosei [llength $x]]] }
    proc sample-shuffle {x} {
	set y {}
	while {[llength $x]} {
	    lappend y [lindex $x [set i [sample-choosei [llength $x]]]]
	    set x [lreplace $x $i $i]
	}
	return $y
    }
    
    # make a sample with specified -difficulty and -spread
    # for mean mu and standard deviation sigma evaluate the relative weights
    # for bins centered at the positive odd x
    # puts "about to execute proc weights"
    proc sample-make-weights {mu sigma max} {
	# puts "sample-make-weights $mu $sigma $max"
	set sigma [expr {max(0.01,$sigma)}]
	set bins [dict create sum 0]
	for {set n 1} {$n <= $max} {incr n 2} {
	    set wt [expr {int(101*(ncdf($n-1, $mu, $sigma)-ncdf($n+1, $mu, $sigma)))}]
	    dict set bins $n $wt
	    dict incr bins sum $wt
	}
	set bins [dict map {n wt} $bins { if {$wt} { set wt } else continue }]
	# puts "$bins"
	return $bins
    }
    
    proc sample-make-one-sample {bins} {
	set i [expr {int(rand()*[dict get $bins sum])}]
	foreach j [dict keys $bins {[0-9]*}] {
	    set i [expr {$i-[dict get $bins $j]}]
	    if {$i <= 0} { return $j }
	}
	puts "ran off end of sample bins: $bins"
	return [sample-choose [dict keys $bins {[0-9]*}]]
    }
    
    proc sample-make-sample {bins {n 1}} {
	if {$n == 1} {
	    return [sample-make-one-sample $bins]
	}
	set samps {}
	while {[llength $samps] < $n} {
	    lappend samps [sample-make-one-sample $bins]
	}
	return $samps
    }
    
    method sample-make {} {
	if {$data(dits) eq {}} {
	    # make the dits table
	    # characters by dit length
	    # combinations of characters by dit length
	    # tabulated by length of combination
	    set maxn 31
	    set dits [dict create]
	    set dict [$options(-dict)]
	    # generate unigraphs classified by dit length
	    set cset [dict keys $dict]
	    set cdits [dict create]
	    foreach c $cset { dict lappend cdits [morse-word-length $dict $c] $c }
	    dict set dits 1 $cdits
	    # generate digraphs classified by dit length
	    set nset [lsort -integer [dict keys $cdits]]
	    set wdits [dict create]
	    foreach n1 $nset {
		foreach n2 $nset {
		    set n [expr {$n1+3+$n2}]
		    if {$n > $maxn} continue
		    set ns [lsort -integer [list $n1 $n2]]
		    if { ( ! [dict exists $wdits $n] ) || $ns ni [dict get $wdits $n] } {
			dict lappend wdits $n $ns
		    }
		}
	    }
	    dict set dits 2 $wdits
	    # generate n-graphs classified by dit length up to length 5
	    for {set i 3} {$i <= 5} {incr i} {
		set pdits [dict get $dits [expr {$i-1}]]
		set wdits [dict create]
		foreach n2 [lsort -integer [dict keys $pdits]] {
		    foreach n1 $nset {
			set n [expr {$n1+3+$n2}]
			if {$n > $maxn} continue
			foreach w2 [dict get $pdits $n2] {
			    set ns [lsort -integer [concat $n1 $w2]]
			    if { ( ! [dict exists $wdits $n] ) || $ns ni [dict get $wdits $n] } {
				dict lappend wdits $n $ns
			    }
			}
		    }
		}
		dict set dits $i $wdits
	    }
	    # print out the table
	    if {0} {
		foreach n $nset {
		    set vals [dict values [dict map {k v} $dits {llength [dict get $v $n]}]]
		    if {$vals ne {}} { puts "$n -> $vals" }
		    foreach k [dict keys $dits] { 
			set vals [dict get $dits $k $n]
			if {$vals ne {}} { puts "$n $k -> $vals" }
		    }
		}
	    }
	    set data(dits) $dits
	    set data(mdits) [dict create]
	    dict for {n d} $dits {
		dict for {nd v} $d {
		    dict lappend data(mdits) $nd {*}$v
		}
	    }
	}
	set nset [lsort -integer [dict keys [dict get $data(dits) 1]]]
	# puts "character $nset"
	set nset [lsort -integer [dict keys $data(mdits)]]
	# puts "merged $nset"
	set bins [sample-make-weights $options(-difficulty) $options(-spread) [tcl::mathfunc::max {*}$nset]]
	return $bins
    }
    
    method sample-draw {} {
	set length [sample-make-one-sample $data(sample)]
	# puts "sample-draw length $length"
	set draw [sample-choose [dict get $data(mdits) $length]]
	# puts "sample-draw draw {$draw}"
	# the list/item ambiguity bites us when the item is a "
	if {[string length $draw] == 1 || [regexp {^<[^>]+>$} $draw]} {
	    return $draw
	} elseif {[llength $draw] == 1} {
	    puts "sample-draw {$draw} character didn't match patterns"
	    return $draw
	} else {
	    set draw [join [lmap i [sample-shuffle $draw] {sample-choose [dict get $data(dits) 1 $i]}] {}]
	    return $draw
 	}
    }
