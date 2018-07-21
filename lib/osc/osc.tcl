#https://github.com/pd-l2ork/pd/blob/master/extensions/gui/ix/osc.tcl
#OSC tcl 2005 ix

# use same transport (udp or tcp) as $::env(NSM_URL)
# liblo has flaky tcp implementation, so udp is most likely
# /nsm/server/announce s:application_name s:capabilities s:executable_name i:api_version_major i:api_version_minor i:pid
# i:api_version_major == 1 i:api_version_minor == 0

package require udp

package provide osc 1.0

namespace eval osc {
    proc encode {type data} {
	switch $type {
	    i {set format I }
	    f {set format R }
	    s {set len [string length $data]
		set format a[expr {$len + 4 - ($len % 4)}]}
	}
	return [binary format $format $data]
    }
    proc message {args} {
	set path [encode s [lindex $args 0]]
	set typetags ","
	set body ""
	foreach arg [lrange $args 1 end] {
	    if {[string is integer $arg]} {
		set type i
	    } elseif {[string is double $arg]} {
		set type f
	    } else {
		set type s
	    }
	    append typetags $type
	    append body [encode $type $arg]
	}
	set typetags [encode s $typetags]
	return $path$typetags$body
    }
    proc connect {host port} {
	set s [udp_open]
	fconfigure $s -remote [list $host $port] -buffering none -translation binary
	return $s
    }
    proc disconnect {socket} {
	close $socket
    }
    proc send {socket msg} {
	puts -nonewline $socket $msg
    }

}
