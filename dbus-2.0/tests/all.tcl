package require Tcl 8.5
set ver [package require tcltest 2.2]
puts [package ifneeded tcltest $ver]
namespace import tcltest::*

set dir [file normalize [file dirname [info script]]]
lappend auto_path [file dirname $dir]
package require dbus-tcl
dbus connect

# Start the dbus responder
exec [info nameofexecutable] [file join $dir responder.tcl] &
after 200

configure {*}$argv -testdir $dir
runAllTests

# Tell the responder to exit
dbus call -dest com.tclcode.test.responder /test com.tclcode.test exit
