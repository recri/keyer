#!/usr/bin/tclsh

#
# translate json ui descriptor into c table for inclusion
# usage: faustcl.tcl json-file-name h-file-name
#
# only translates the minimum necessary, which is a table
# of names for the controls, where the index into the
# table matches the index into the zonePtrs.
#

package require json

# fetch arguments
set jsonfile [lindex $argv 0]
set headerfile [lindex $argv 1]

# read json file
set fp [open $jsonfile r]
set jsondict [json::json2dict [string trim [read $fp]]]
close $fp

# only the zones with label, shortname, and address
set ::nzones 0
proc traverse {fp dict} { 
    foreach key {type label} { set $key [dict get $dict $key] }
    switch -glob $type {
	*group {
	    set items [dict get $dict items]
	    foreach item $items {
		traverse $fp $item
	    }
	}
	*slider - numentry - button - checkbox - *graph {
	    foreach key {shortname address} { set $key [dict get $dict $key] }
	    puts $fp "    {  \"$label\", \"$shortname\", \"$address\" },"
	    incr ::nzones
	}
	declare - soundfile  { }
    }
}

# open header file
set fp [open $headerfile w]

# copy the ui data to output
puts $fp "typedef struct {"
puts $fp "  const char *label, *shortname, *address;"
puts $fp "} _option_t;"
puts $fp "static const _option_t _options\[] = {"
foreach item [dict get $jsondict ui] { traverse $fp $item }
puts $fp "};"
puts $fp "#define NZONES $::nzones"
close $fp
