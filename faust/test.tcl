
lappend auto_path ../../lib

set pkg $::env(PKG)

if {$pkg eq {tst}} {
    exit 0
}

if {$argv == {}} {
    set argv [lsort -nocase [lmap f [glob *.dsp] {file rootname $f}]]
    if {$argv eq {}} {
	error "run me in a directory with faust .dsp files"
    }
}
foreach root $argv {
    puts "testing $root"
    set stem ${root}1
    puts "command name $stem"
    if {[catch {package require faust::${pkg}::${root}} result]} {
	puts "package require faust::${pkg}::$root $result"
	continue
    }
    puts "package require faust::${pkg}::$root $result"
    puts "faust::${pkg}::$root $stem -midi 1 -> [faust::${pkg}::$root $stem -midi 1]"
    # puts "$stem meta"
    # foreach {key value} [$stem meta] { puts "$key -> $value" }
    # puts "$stem ui -> set [$stem ui]"
    puts "$stem configure -> [$stem configure]"
    puts "$stem cget -gate -> [$stem cget -gate]"
    puts "$stem configure -gate 0 -> [$stem configure -gate 0]"
    set tempo 72
    set beat [expr {int(60*1000/72)}]; # beat in ms
    set tap [expr {$beat/4}]
    for {set i 0} {$i < 8} {incr i} {
	$stem configure -gate 1
	after $tap
	$stem configure -gate 0
	after $tap
    }
    puts "removing $stem"
    rename $stem {}
}
