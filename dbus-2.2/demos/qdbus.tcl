#!/usr/bin/env tclsh

# This dbus-tcl demo program mimics the functionality of the qdbus command
# that is part of Qt. It can for instance be used as a drop-in replacement
# on headless systems that need the functionality of qdbus without dragging
# in all of Qt.

package require dbus 2.0b2
package require tdom

# Translations from dbus signature to Qt type names
set typename {
    {} void i int s QString b bool a{sv} QVariantMap v QDBusVariant
    x qlonglong d double as QStringList ay QByteArray q ushort y uchar
    g QDBusSignature n short o QDBusObjectPath t qulonglong u uint
}

# List all names on the dbus
proc names {} {
    global bus
    set svc [dbus info service]
    set path [dbus info path]
    foreach n [dbus call $bus -dest $svc $path $svc ListNames] {
	set o [dbus call $bus -dest $svc $path $svc GetNameOwner $n]
	if {$o eq $n} {
	    lappend owner($o)
	} else {
	    lappend owner($o) $n
	}
    }
    foreach o [lsort [array names owner]] {
	puts $o
	foreach n [lsort $owner($o)] {
	    puts " $n"
	}
    }
}

# List all node paths of an application on the dbus 
proc tree {name {path /}} {
    global bus
    puts $path
    if {$path eq "/"} {set prefix ""} else {set prefix $path}
    set svc [dbus info service]
    set xml [dbus call $bus -dest $name $path $svc.Introspectable Introspect]
    dom parse $xml doc
    foreach n [$doc selectNodes /node/node] {
	tree $name $prefix/[$n getAttribute name]
    }
}

# Obtain the xml specification for a node of the application
proc introspect {name path} {
    global bus
    set svc [dbus info service]
    return [dbus call $bus -dest $name $path $svc.Introspectable Introspect]
}

# Determine the signature of a method call or property
proc getsig {name path intf member {type property} {argc 1}} {
    # Errors are caught one level up
    set xml [introspect $name $path]
    dom parse $xml doc
    set query [format {/node/interface[@name="%s"]/%s[@name="%s"]} \
      $intf $type $member]
    set match [$doc selectNodes $query]
    if {[llength $match] == 0} {
	return -code error -errorcode org.freedesktop.DBus.Error.UnknownObject
    }
    # Look for an entry with the same amount of input arguments (methods only)
    set node ""
    foreach n $match {
	if {$type eq "method"} {
	    set arglist [$n selectNodes {./arg[@direction="in"]}]
	    if {[llength $arglist] != $argc} continue
	} else {
	    set arglist [list $n]
	}
	set node $n
    }
    if {$node eq ""} {
	return -code error -errorcode org.freedesktop.DBus.Error.InvalidArgs
    }
    # Build the signature from the input argument types
    set sig ""
    foreach a $arglist {
	append sig [$a getAttribute type s]
    }
    return $sig
}

# List the properties, methods and signals for a specific path
proc query {name path} {
    dom parse [introspect $name $path] doc
    foreach n [$doc selectNodes /node/interface] {
	set intf [$n getAttribute name]
	set prop {}
	set slot {}
	foreach s [$n childNodes] {
	    # Skip comments
	    if {[$s nodeType] ne "ELEMENT_NODE"} continue

	    if {[$s nodeName] eq "property"} {
		dict set prop [$s getAttribute name ""] $s
	    } else {
		dict set slot [$s getAttribute name ""] $s
	    }
	}
	# properties
	foreach name [lsort [dict keys $prop]] {
	    set p [dict get $prop $name]
	    set access [$p getAttribute access readwrite]
	    set t [$p selectNodes {./annotation[@name="com.trolltech.QtDBus.QtTypeName"]}]
	    if {[llength $t]} {
		set type [$t getAttribute value ""]
	    } else {
		set type [typename [$p getAttribute type ""]]
	    }
	    puts "property $access $type $intf.$name"
	}
	# methods and signals
	foreach name [lsort [dict keys $slot]] {
	    set s [dict get $slot $name]
	    set str [$s nodeName]
	    set out ""
	    set args {}
	    foreach a [$s selectNodes ./arg] {
		set dir [$a getAttribute direction in]
		if {$dir eq "out"} {
		    set out [$a getAttribute type ""]
		} else {
		    set arg [typename [$a getAttribute type ""]]
		    if {[$a hasAttribute name]} {
			append arg " " [$a getAttribute name]
		    }
		    lappend args $arg
		}
	    }
	    append str " " [typename $out] " " $intf.$name
	    puts [format {%s(%s)} $str [join $args ", "]]
	}
    }
}    

# Invoke a dbus method_call
proc call {name path method args} {
    global bus dbusresult
    set intf [join [lreverse [lassign [lreverse [split $method .]] method]] .]
    set sig ""
    set argc [llength $args]
    # Use dbus introspection to determine the argument types, if any
    # Skip this when no arguments were provided to allow autostarting the app
    if {$argc > 0} {
	if {[catch {getsig $name $path $intf $method method $argc} sig]} {
	    switch [lindex $::errorCode end] {
		org.freedesktop.DBus.Error.ServiceUnknown {
		    puts [format {Cannot find '%s.%s' in object %s at %s} \
		      $intf $method $path $name]
		    exit 1
		}
		org.freedesktop.DBus.Error.UnknownObject {
		    # Retry as org.freedesktop.DBus.Properties.Set
		    if {$argc != 1 || \
		      [catch {getsig $name $path $intf $method} prop]} {
			puts [format {Cannot find '%s.%s' in object %s at %s} \
			  $intf $method $path $name]
			exit 1
		    }
		    set sig ssv
		    set args [list $intf $method [list $prop [lindex $args 0]]]
		    set intf org.freedesktop.DBus.Properties
		    set method Set
		}
		org.freedesktop.DBus.Error.InvalidArgs {
		    puts stderr "Invalid number of parameters"
		    exit 1
		}
		default {
    		    puts $::errorInfo
		    exit 1
    		}
	    }
	}
    }
    # Actually invoke the method_call. Use a handler to get the signature of
    # the result in addition to the actual values
    if {![catch {dbus call $bus -details -dest $name -signature $sig \
      -handler result $path $intf $method {*}$args} result]} {
	# Wait for the result
	vwait dbusresult
	# Report any errors
	switch [lindex $dbusresult 0] {
	    {} {
		# Method call succeeded
	    }
	    org.freedesktop.DBus.Error.NameHasNoOwner {
		puts "Service '$name' does not exist."
	    }
	    org.freedesktop.DBus.Error.UnknownMethod {
		# Retry as org.freedesktop.DBus.Properties.Get
		if {$argc == 0} {
		    if {![catch {dbus call $bus -details -dest $name \
		      -handler result $path org.freedesktop.DBus.Properties \
		      Get $intf $method} result]} {
			vwait dbusresult
			# If the Get succeeded, we're done
			if {[llength $dbusresult] == 0} exit
			# Otherwise report the original error
		    }
		}
		puts [format {Cannot find '%s.%s' in object %s at %s} \
		  $intf $method $path $name]
	    }
	    default {
		lassign $dbusresult errorname errormsg
		puts "Error: $errorname"
		puts $errormsg
	    }
	}
	exit
    }
    puts $::errorCode
}

# Process the results from a dbus method_call
proc result {info args} {
    global dbusresult
    # Check that the call was successful
    if {[dict get $info messagetype] ne "error"} {
	# Report the result of the method call
    	if {[llength $args] == 1} {set args [lindex $args 0]}
	catch {report [dict get $info signature] $args} result
	puts $result
	set dbusresult ""
    } else {
	set dbusresult [list [dict get $info errorname] [lindex $args 0]]
    }
}

# Report the result returned from a method call
proc report {sig value} {
    global literal
    if {[string match {[synqiuxtgo]} $sig]} {
	return $value
    } elseif {$sig eq "d"} {
	# Format double without trailing zeroes and trailing decimal point
	return [format %.12g $value]
    } elseif {$sig eq "b"} {
	# Boolean is either 'true' or 'false'
	return [lindex {true false} [expr {!$value}]]
    } elseif {$literal} {
	return [literal $sig $value]
    } else {
	set rc ""
    	if {$sig eq "v"} {
    	    lassign [lindex $value 0] sig result
	}
	switch -- $sig {
	    {} {
		# No return value
	    }
	    as {
		foreach val $value {
		    lappend rc $val
		}
	    }
	    a{sv} {
		foreach {key val} $value {
		    if {[llength $val] != 2} {
			lappend rc [format {%s: %s} $key $val]
		    } else {
    			lappend rc [format {%s: %s} $key [report {*}$val]]
		    }
		}
	    }
	    default {
		puts "qdbus.tcl: I don't know how to display an argument\
		  of type '$sig', run with --literal."
		exit
	    }
	}
	return [join $rc \n]
    }
}

# Split a signature in individual components
proc sigsplit {sig} {
    foreach c [split $sig ""] {
	if {[dbus validate signature [append str $c]]} {
	    lappend rc $str
	    set str ""
	}
    }
    return $rc
}

# Return a literal representation of the result
proc literal {signature value} {
    set list [sigsplit $signature]
    if {[llength $list] == 1} {set value [list $value]}
    set rc {}
    foreach n $list v $value {
	switch -glob $n {
	    a{*} {
		# Array of dict entries
		set arr {}
		lassign [sigsplit [string range $n 2 end-1]] key val
		puts "key=$key, val=$val"
		foreach {v1 v2} $v {
		    lappend arr [format {%s = %s} \
		      [literal $key $v1] [literal $val $v2]]
		}
		lappend rc [format {{%s}} [join $arr {, }]]
	    }
	    a* {
		# Array
		set arr {}
		foreach v1 $v {
		    lappend arr [literal [string range $n 1 end] $v1]
		}
		lappend rc [format {{%s}} [join $arr {, }]]
	    }
	    (*) {
		# Structure
		set struct {}
		foreach n1 [sigsplit [string range $n 1 end-1]] v1 $v {
		    lappend struct [literal $n1 $v1]
		}
		lappend rc [join $struct {, }]
	    }
	    v {
		# Variant
		lassign $v sig val
		if {[string length $sig] == 1 || $sig in {as}} {
		    lappend rc [format {[Variant(%s): %s]} \
		      [typename $sig] [literal $sig $val]]
		} else {
		    lappend rc [format {[Variant: %s]} [literal $sig $val]]
		}
	    }
	    b {
		# Boolean is either 'true' or 'false'
		lappend rc [lindex {true false} [expr {!$v}]]
	    }
	    d {
		# Print double without trailing zeroes and without a
		# trailing decimal point
		lappend rc [format %.6g $v]
	    }
	    y - n - q - i - u - x - t {
		# Print integers without any formatting
		lappend rc $v
	    }
	    s - g - o {
		# Print strings in quotes
		lappend rc [format {"%s"} $v]
	    }
	}
    }
    if {[string length $signature] == 1 || $signature in {as}} {
	return [join $rc]
    } else {
	return [format {[Argument: %s %s]} $signature [join $rc]]
    }
}

# Create a description of the argument type
proc typename {sig} {
    global typename
    if {[dict exists $typename $sig]} {
	return [dict get $typename $sig]
    } else {
	return [format {QDBusRawType::%s} $sig]
    }
}

# Simple word wrap
proc wrap {str} {
    global cols
    while {[string length $str] > $cols} {
	set x [string last " " $str $cols]
	lappend rc [string trimright [string range $str 0 $x]]
	set str [string trimleft [string replace $str 0 $x]]
    }
    return [join [lappend rc $str] \n]
}

# Provide instructions to the user
proc help {} {
    global argv0
    set cmd [file tail $argv0]
    set fmt {  %-18s%s}
    puts [format {Usage: %s [--system | --address ADDRESS] [--literal]\
      [servicename] [path] [method] [args]} $cmd]
    puts ""
    puts [format $fmt servicename \
      "the service to connect to (e.g., org.freedesktop.DBus)"]
    puts [format $fmt path "the path to the object (e.g., /)"]
    puts [format $fmt method \
      "the method to call, with or without the interface"]
    puts [format $fmt args "arguments to pass to the call"]
    puts [wrap "With 0 arguments, $cmd will list the services available\
      on the bus"]
    puts [wrap "With just the servicename, $cmd will list the object paths\
      available on the service"]
    puts [wrap "With service name and object path, $cmd will list the methods,\
      signals and properties available on the object"]
    puts ""
    puts "Options:"
    puts [format $fmt --system "connect to the system bus"]
    puts [format $fmt "--address ADDRESS" "connect to the given bus"]
    puts [format $fmt --literal "print replies literally"]
    exit
}

# Parse the options passed to the program
set dbus session
set literal 0
set cols 80
if {[info exists env(COLUMNS)]} {set cols $env(COLUMNS)}
while {[string match --* [lindex $argv 0]]} {
    set argv [lassign $argv option]
    switch -- $option {
	--address {
	    set argv [lassign $argv dbus]
	    incr argc -1
	}
	--system {
	    set dbus system
	}
	--literal {
	    set literal 1
	}
	default {
	    help
	}
    }
    incr argc -1
}

# Connect to the selected dbus
set bus [dbus connect $dbus]
set args [lassign $argv name path method]
if {$argc == 0} {
    # Called without arguments: list all names on the dbus
    names
} elseif {$argc == 1} {
    # Called with one argument: list all node paths of the application
    tree $name
} elseif {$argc == 2} {
    # Called with two arguments: list all members at the specified path
    query $name $path
} else {
    # More than 2 arguments: call the specified method and report the result
    call $name $path $method {*}$args
}
