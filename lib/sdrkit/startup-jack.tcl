# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.
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
# the jack startup manager
#
package provide sdrkit::startup-jack 1.0.0

package require snit
package require dbus-jack

snit::type sdrkit::startup-jack {

    variable data -array {
	enabled 0
	active 0
	parts {}
    }

    option -alsa {}

    option -primary-card {}
    option -primary-rate {}
    option -secondary-card {}
    option -secondary-rate {}
    option -duplex false
    option -onchange {}

    constructor {args} {
	$self configure {*}$args
    }

    destructor { }

    #
    # select primary and secondary audio interfaces
    # primary sets the jack clock, listens to and talks to radio
    # secondary adapts to primary clock, listens to microphone and talks to speakers or headphones
    # select primary and secondary sample rate, preferably the same
    #
    # provide feedback on server status, overruns, connections, etc 
    #

    method status {} { return [expr {[$self started]?"started":"stopped"}] }
    method started {} { return [dbus-jack::is-started] }

    method start {w} {
	set options(-primary-card) [option-menu-selected $w.pam]
	set options(-primary-rate) [option-menu-selected $w.prm]
	set options(-secondary-card) [option-menu-selected $w.sam]
	set options(-secondary-rate) [option-menu-selected $w.srm]
	dbus-jack::set-driver alsa
	dbus-jack::set-driver-param device $options(-primary-card)
	dbus-jack::set-driver-param capture $options(-primary-card)
	dbus-jack::set-driver-param playback $options(-primary-card)
	dbus-jack::set-driver-param rate $options(-primary-rate)
	dbus-jack::set-driver-param midi-driver raw
	dbus-jack::set-internal-param {internals audioadapter} device $options(-secondary-card)
	dbus-jack::set-internal-param {internals audioadapter} capture $options(-secondary-card)
	dbus-jack::set-internal-param {internals audioadapter} playback $options(-secondary-card)
	dbus-jack::set-internal-param {internals audioadapter} rate $options(-secondary-rate)
	dbus-jack::start-server
	dbus-jack::load-internal audioadapter 
	if {$options(-onchange) ne {}} { $options(-onchange) start }
    }

    method stop {w} {
	if {$options(-onchange) ne {}} { $options(-onchange) stop }
	dbus-jack::unload-internal audioadapter
	dbus-jack::stop-server
    }

    method panel {w args} {
	upvar #0 $w data
	ttk::frame $w
	set primary [$self alsa-card-primary-default]
	set secondary [$self alsa-card-secondary-default]
	grid [ttk::label $w.pal -text {primary}] [option-menu $w.pam [$self alsa-card-list] $primary] \
	    [ttk::label $w.prl -text {@}] [option-menu $w.prm [$self alsa-rate-list] [$self alsa-rate-default $primary]] -sticky ew
	grid [ttk::label $w.sal -text {secondary}] [option-menu $w.sam [$self alsa-card-list] $secondary] \
	    [ttk::label $w.srl -text {@}] [option-menu $w.srm [$self alsa-rate-list] [$self alsa-rate-default $primary]] -sticky ew
	grid [ttk::frame $w.s] -columnspan 4
	pack [ttk::label $w.s.status -textvar ${w}(status)] -side left
	pack [ttk::button $w.s.start -text start -command [mymethod start $w]] -side left
	pack [ttk::button $w.s.stop -text stop -command [mymethod stop $w]] -side left
	$self update-status $w
	return $w
    }

    method alsa-card-list {} { return [$options(-alsa) card-list] }
    method alsa-card-primary-default {} { return [$options(-alsa) card-primary-default] }
    method alsa-card-secondary-default {} { return [$options(-alsa) card-secondary-default] }
    method alsa-rate-list {} { return [$options(-alsa) rate-list] }
    method alsa-rate-default {card} { return [$options(-alsa) rate-default $card] }

    # this should use dbus-jack signals rather than polling
    # though polling through dbus directly is better than launching a process

    method update-status {w} {
	upvar #0 $w data
	set data(status) [$self status]
	if {$data(status) eq {stopped}} {
	    $w.s.start configure -state normal
	    $w.s.stop configure -state disabled
	} else {
	    $w.s.start configure -state disabled
	    $w.s.stop configure -state normal
	}
	after 100 [mymethod update-status $w]
    }

    method update {w} {
    }

    #
    # this should show the additional options necessary
    # to start the jack server as we need it to run
    #
    method details-panel {w args} {
	ttk::frame $w
	return $w
    }

    method details-update {w} {
    }

}

