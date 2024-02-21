#!/usr/bin/tclsh

lappend auto_path ../lib

foreach i {brass clarinet djembe elecguitar flute guitar
    ks marimba modularinterpinst nylonguitar sfformantmodelbp
    sfformantmodelfofcycle sfformantmodelfofsmooth violin} {
    puts "testing $i"
    package require faustcl::$i
    faustcl::$i ${i}1
}
