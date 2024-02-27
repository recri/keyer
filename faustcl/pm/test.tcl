#!/usr/bin/tclsh

lappend auto_path ../../lib

if {$argv == {}} {
    set argv [lmap f [glob *.dsp] {file rootname $f}]
}
foreach root $argv {
    puts "testing $root"
    set stem ${root}1
    puts "command name $stem"
    puts "package require faust::pm::$root [package require faust::pm::$root]"
    puts "faust::pm::$root $stem -> [faust::pm::$root $stem]"
    # puts "$stem meta"
    # foreach {key value} [$stem meta] { puts "$key -> $value" }
    # puts "$stem ui -> set [$stem ui]"
    puts "$stem configure -> [$stem configure]"
    puts "$stem cget -gate -> [$stem cget -gate]"
    puts "$stem configure -gate 0 -> [$stem configure -gate 0]"
    set tempo 72
    set beat [expr {int(60*1000/72)}]; # beat in ms
    set halfbeat [expr {$beat/2}]
    for {set i 0} {$i < 16} {incr i} {
	$stem configure -gate 1
	after $halfbeat
	$stem configure -gate 0
	after $halfbeat
    }
    puts "removing $stem"
    rename $stem {}
}
