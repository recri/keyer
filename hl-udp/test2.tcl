#!/usr/bin/tclsh
package require TclOO
package require tcl::chan::events
package require tcl::chan::fifo

proc readable {chan} {
    set data [read $chan 5]
    if {[eof $chan]} { 
	close $chan
	set ::forever 1
	return
    }
    binary scan $data c5 bytes
    foreach b $bytes { puts -nonewline " [expr {$b&255}]" }
    puts {}
}

set i 0
proc writable {chan} {
    global i
    set bytes {}
    for {set j 0} {$j < 5} {incr j} {
	lappend bytes [expr {($i+$j)&255}]
    }
    puts -nonewline $chan [binary format c5 $bytes]
    incr i 5
    if {$i > 100} {
	fileevent $chan writable {}
    }
}

set chan [tcl::chan::fifo]
fconfigure $chan -translation binary -blocking 0 -buffering none
fileevent $chan readable [list readable $chan]
fileevent $chan writable [list writable $chan]

vwait forever

