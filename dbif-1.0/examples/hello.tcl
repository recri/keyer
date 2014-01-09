#!/usr/bin/wish

set auto_path [linsert $auto_path 0\
  [file join [file normalize [file dirname [info script]]] .. ..]]
package require dbus-intf

# Create a very simple GUI
button .b -textvariable text
pack .b -padx 20 -pady 20

# Connect to the session message bus and steal the com.tclcode.hello name
# away from any other application that may currently have it.
#
dbif connect -replace -yield com.tclcode.hello

# Setup an event handler for the case that some other application takes away
# the com.tclcode.hello name
#
dbif listen -interface org.freedesktop.DBus \
  /org/freedesktop/DBus NameLost name {
    global sig
    dbif generate $sig "Goodbye cruel world!"
    exit
}

# Provide a number of methods for other applications to invoke
#
dbif method /Counter Set {{num:i 0}} {global counter; set counter $num}
dbif method / GetConfiguration {} data:aas {.b configure}
# Send a response before quitting to keep the caller happy
dbif method / Quit {dbif return $msgid {};exit}

# Define a couple of properties that can be remotely accessed
#
dbif property / Message text
dbif property -access read /Counter Value:i counter
dbif property / BackgroundColor color(bg) {.b configure -background $value}
dbif property / ForegroundColor color(fg) {.b configure -foreground $value}

# Initialize the variables that hold the properties
set color(bg) [.b cget -background]
set color(fg) [.b cget -foreground]
set text "Hello World!"
set counter 0

# Define the signals that the application may emit
set sig [dbif signal / Goodbye str]
# Attach a signal directly to the command for the button
.b configure -command [list count [dbif signal / Hello str {} {.b cget -text}]]

proc count {sig} {
    global counter
    incr counter
    dbif generate $sig
}
