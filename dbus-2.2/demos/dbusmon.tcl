#!/usr/bin/env tclsh

# Default dbus to monitor
set bus session

# Default filters
set filter {
    {-eavesdrop true -type signal}
    {-eavesdrop true -type method_call}
    {-eavesdrop true -type method_return}
    {-eavesdrop true -type error}
}

# Names of the different argument types
array set type {
    b	boolean
    y	byte
    n	int16
    q	uint16
    i	int32
    u	uint32
    x	int64
    t	uint64
    d	double
    s	string
    g	sig
    o	path
}

# Need at least version 2.0 of the Tcl dbus library
package require dbus 2.0

# Assign signature elements to variables, similar to lassign
proc sigassign {sig args} {
    foreach n $args {
	upvar 1 $n v
	set a ""
	set ch [string index $sig 0]
	while {$ch eq "a"} {
	    append a a
	    set sig [string range $sig 1 end]
	    set ch [string index $sig 0]
	}
	if {$ch in {s b y n q i u x t d g o}} {
	    # Basic type
	    set v $a$ch
	    set sig [string range $sig 1 end]
	} elseif {$ch eq "v"} {
	    # Variant
	    set v $a$ch
	    set sig [string range $sig 1 end]
	} elseif {$ch eq "("} {
	    # Struct
	    set x [nesting $sig ( )]
	    set v $a[string range $sig 0 $x]
	    set sig [string replace $sig 0 $x]
	} elseif {$ch eq "\{"} {
	    # Dict
	    set x [nesting $sig "{" "}"]
	    set v $a[string range $sig 0 $x]
	    set sig [string replace $sig 0 $x]
	} else {
	    puts "Error: Invalid signature: $sig"
	    set sig ""
	}
    }
    return $sig
}

# Handle, possibly nested, braced parts
proc nesting {str c1 c2} {
    # Find the first open brace (should normally be at position 0)
    set x1 [string first $c1 $str]
    # Find the next closing brace
    set x2 [string first $c2 $str $x1]
    # Check if there are any more open braces before the current closing brace
    while {[set x1 [string first $c1 $str [expr {$x1 + 1}]]] > 0 \
      && $x1 < $x2} {
	# Need to find the subsequent closing brace
	set x2 [string first $c2 $str [expr {$x2 + 1}]]
    }
    # Return the position of the closing brace matching the first opening brace
    return $x2
}

# Called for every received dbus message
proc monitor {info args} {
    try {
	set now [clock milliseconds]
	set str [clock format [expr {$now / 1000}] -format {%Y-%m-%d %T}]
	append str . [format %03d [expr {$now % 1000}]] \n
	set msgtype [dict get $info messagetype]
	switch -- $msgtype {
	    signal {
		append str "signal"
	    }
	    method_call {
		append str "method call"
	    }
	    method_return {
		append str "method return"
	    }
	    error {
		append str "error"
	    }
	}
	append str " " sender= [dict get $info sender] 
	append str " -> " dest= [dict get $info destination]
	if {[dict get $info destination] eq ""} {
	    append str "(null destination)"
	}
	if {$msgtype in {method_return error}} {
	    append str " " reply_serial= [dict get $info replyserial]
	} else {
	    if {[dict get $info serial] ne ""} {
		append str " " serial= [dict get $info serial]
	    }
	    append str " " path= [dict get $info path] ";"
	    append str " " interface= [dict get $info interface] ";"
	    append str " " member= [dict get $info member]
	}
	# Provide a summary of the dbus message
	puts $str
	# Dump the arguments of the dbus message
	showargs [dict get $info signature] $args
	puts ""
    } on error err {
	puts $::errorInfo
    }
}

# Dump dbus arguments according to a signature
proc showargs {sig args {tab "   "} {variant 0}} {
    global type
    if {$variant} {
	set vartab [format %s%-26s [string range $tab 3 end] variant]
    } else {
	set vartab $tab
    }
    while {$sig ne ""} {
	set sig [sigassign $sig c]
	set args [lassign $args val]
	switch -glob -- $c {
	    s - g - o {
		puts [format {%s%s "%s"} $vartab $type($c) $val]
	    }
	    v {
		# variant
		lassign $val vsig vval
		showargs $vsig [list $vval] "$tab   " 1
	    }
	    a{*} {
		# dict
		puts [format {%sarray [} $vartab]
		showdict [string range $c 2 end-1] $val "$tab   "
		puts [format {%s]} $tab]
	    }
	    ay {
		# array of bytes
		puts [format {%sarray of bytes [} $vartab]
		bytearray $val "$tab   "
		puts [format {%s]} $tab]
	    }
	    a* {
		# other array
		puts [format {%sarray [} $vartab]
		showarray [string range $c 1 end] $val "$tab   "
		puts [format {%s]} $tab]
	    }
	    (*) {
		# struct
		puts [format "%sstruct \{" $vartab]
		set sig [showargs [string range $c 1 end-1] $val "$tab   "]
		puts [format "%s\}" $tab]
	    }
	    default {
		puts [format {%s%s %s} $vartab $type($c) $val]
	    }
	}
    }
    return $sig
}

# Dump a dbus array
proc showarray {sig args tab} {
    foreach n $args {
	showargs $sig [list $n] $tab
    }
}

# Dump a dbus dict
proc showdict {sig args tab} {
    sigassign $sig ksig vsig
    dict for {key val} $args {
	puts [format {%sdict entry(} $tab]
	showargs $ksig [list $key] "$tab   "
	showargs $vsig [list $val] "$tab   "
	puts [format {%s)} $tab]
    }
}

# Special treatment for an array of bytes
proc bytearray {bytes tab} {
    set cnt [expr {(78 - [string length $tab]) / 3}]
    set i 0
    foreach n $bytes {
	if {$i % $cnt == 0} {
	    if {$i > 0} {puts $str}
	    set str [string range $tab 1 end]
	}
	append str " " [format %02x $n]
	incr i
    }
    if {$i != 0} {puts $str}
}

proc errormsg {msg} {
    puts stderr $msg
    exit 1
}

# Parse the command line used to invoke the program
if {$argc > 0} {
    set filter ""
    foreach arg $argv {
	if {$arg eq "--system"} {
	    set bus system
	    continue
	}
	if {$arg eq "--session"} {
	    set bus session
	    continue
	}
	# Eavesdrop unless overridden by the user
	set term [list -eavesdrop true]
	foreach n [split $arg ,] { 
	    if {[scan $n {%[a-z]=%s} option value] != 2} {
		errormsg "invalid match rule"
	    } elseif {$option ni {destination interface member path sender type eavesdrop}} {
		errormsg "unknown key in match rule"
	    }
	    lappend term -$option $value
	}
	lappend filter $term
    }
}

# Connect to the dbus
dbus connect $bus

# Prevent returning errors for methods received due to eavesdropping
proc dummy args {}
dbus unknown $bus "" dummy

# Install the filters
foreach n $filter {
    if {[catch {dbus filter $bus add {*}$n} err]} {
	errormsg "failed to setup match: $err"
    }
}

# Start monitoring. Details are needed for a full report of variant arguments.
dbus monitor $bus -details monitor

# Start the event loop
vwait forever
