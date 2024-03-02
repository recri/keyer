#!/usr/bin/tclsh

if {$argv eq {}} {
    error "usage: initname.tcl name"
}

set name [lindex $argv 0]

set name [string tolower $name]

set name [string trimright $name {0123456789}]

set name [string toupper [string index $name 0]][string range $name 1 end]_Init

puts $name

