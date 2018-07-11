lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
package require dbus

set last ""

proc stdin {f} {
    read $f
    if {[eof $f]} exit
}

proc namelost {args} {
    exit
}

proc quit {args} {
    after idle exit
    return OK
}

proc run {cmd args} {
    return [$cmd]
}

proc pong {args} {
    return pong
}

proc call {data arglist} {
    dict with data {
	dbus call 
    }
}

proc foo {data args} {
    global last
    set last $data
}

proc dump {data args} {
    global last
    dict with data {
	dbus return -signature a{ss} $sender $serial $last
    }
}

proc signal {args} {
    dbus signal /test com.tclcode.test testsignal
}

proc mistake {data args} {
    dict with data {
	after 100
	dbus error $sender $serial "Error message"
    }
    return
}

proc unknown {data args} {
    dict with data {
	dbus error $sender $serial "Unknown method"
    }
    return
}

proc echo {data args} {
    dict with data {
	dbus return -signature a{ss}as $sender $serial $data $args
    }
}

proc variant {data args} {
    dict with data {
	set sig [regexp -all -inline {a*[sbynqiuxtdgov]} $signature]
	if {[llength $sig] != [llength $args]} {
	    error "Signature too complex"
	}
	foreach c $sig v $args {
	    lappend ret [list $c $v]
	}
    	dbus return -signature av $sender $serial $ret
    }
}

fconfigure stdin -blocking 0
fileevent stdin readable {stdin stdin}

dbus connect
dbus name -yield -replace com.tclcode.test.responder
catch {dbus name -noqueue com.tclcode.test.noyield}

dbus filter add -interface com.tclcode.test

dbus listen /org/freedesktop/DBus org.freedesktop.DBus.NameLost namelost
dbus listen /test/foo foo foo
dbus method /test exit quit
dbus method /test pwd {run pwd}
dbus method /test pid {run pid}
dbus method /test ping pong
dbus method /test call call
dbus method -async /test dump dump
dbus method /test signal signal
dbus method -async /test error mistake
dbus method -async /test echo echo
dbus method -async /test vecho variant
dbus unknown /test unknown

vwait forever
