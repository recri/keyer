# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 

#
# insert window management
# a simple frame which, when focused, generates key events
# for whichever keys you choose.
# take its midi_out to an oscillator for a straight key or
# to an iambic keyer for a squeeze paddle.
#
# would like to get focus from other windows, but cannot take
# the shift keys away from the text entry windows.
#
#
#
# rewrite this as a simple wrapper around sdrtcl::midi-insert
# which simply grabs control, alt, and/or shift events and
# translates them into midi events for the keyer.
# let it take the focus for exactly the specified shift keys
# for the entire app.
# let it put the shift key specification into the dial book options
#
#
package provide sdrtcl::midi-insert-key 0.0.1

# this package is exceptional, all other Tk enabled packages create windows,
# this one doesn't, it places bindings on other windows
package require Tk
package require snit
package require sdrtcl::midi-insert

snit::type sdrtcl::midi-insert-key {
    option -dit -default none -configuremethod ConfigureKey
    option -dah -default none -configuremethod ConfigureKey
    option -key -default none -configuremethod ConfigureKey
    option -ptt -default none -configuremethod ConfigureKey
    option -key-4 -default none -configuremethod ConfigureKey
    option -key-5 -default none -configuremethod ConfigureKey
    option -window -default . -configuremethod Configure

    component insert
    delegate option * to insert
    delegate method * to insert
    variable optinfo -array {
	-dit {}
	-dah {}
	-key {}
	-ptt {}
	-key-4 {}
	-key-5 {}
	-window {}
    }

    method exposed-options {} { return {-chan -note -dit -dah -key -ptt -key-4 -key-5 -window} }
    method is-busy {} { return 0 }
    method ConfigureKey {opt val} { $self rebind-key $opt $val }

    method info-option {opt} {
	if {[info exists optinfo($opt)]} { return $optinfo($opt) }
	return [$insert info option $opt]
    }
    
    method {Configure -window} {val} {
	# nothing to do
	if {$val eq $options(-window)} return
	# remove bindings
	if {$val eq {}} {
	    $self unbind-all
	    set options(-window) $val
	    return
	}
	# new -key-window is not {} and not equal to current window
	$self unbind-all
	set options(-window) $val
	$self bind-all
    }

    method bind-all {} { $self act-on-all bind-key }
    method unbind-all {} { $self act-on-all unbind-key }
    method act-on-all {action} {
	foreach key {-dit -dah -key -ptt -key-4 -key-5} {
	    $self $action $options($key) [string range $key 1 end]
	}
    }

    method bind-key {tag element} {
	if {$tag ne {none}} {
	    bind $options(-window) <KeyPress-$tag> [mymethod insert-key [$self insert-key-message $element down]]
	    bind $options(-window) <KeyRelease-$tag> [mymethod insert-key [$self insert-key-message $element up]]
	}
    }
    
    method unbind-key {tag element} {
	if {$tag ne {none}} {
	    bind $options(-window) <KeyPress-$tag> {}
	    bind $options(-window) <KeyRelease-$tag> {}
	}
    }

    variable map -array {dit 0 dah 1 key 2 ptt 3 key-4 4 key-5 5 up 0x80 down 0x90 velocity-up 0 velocity-down 1}

    method insert-key {message} { $insert puts $message }
    
    method insert-key-message {element updown} {
	set cmd [expr {$map(down)|([$self cget -chan]-1)}]
	set note [expr {[$self cget -note]+$map($element)}]
	set velocity $map(velocity-$updown)
	return [binary format ccc $cmd $note $velocity]
    }

    method rebind-key {opt val} {
	set element [string range $opt 1 end]
	$self unbind-key $options($opt) $element
	set options($opt) $val
	$self bind-key $options($opt) $element
    }

    constructor {args} {
	install insert using sdrtcl::midi-insert $self.insert -client [namespace tail $self]
	$self configurelist $args
    }
    
}

