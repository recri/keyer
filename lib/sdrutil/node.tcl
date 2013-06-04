# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2013 by Roger E Critchlow Jr, Santa Fe, NM, USA.
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
# dssdr nodes
#
# dssdr organizes itself as a peer to peer network over MIDI, but
# before it can do that it needs to start the jack server.  Since the
# jack server is started as a dbus service under Ubuntu, it makes
# sense for the Linux side components to organize themselves through
# dbus.  That way the organization is idependent of whether jack is
# running or not, or how many times jack gets restarted.
#
# Ah. As a benefit, we get signals from dbus when the jack server
# starts and stops, when clients appear and disappear, when the graph
# changes, when ports appear, disappear, get renamed, get connected,
# or get disconnected.  And we also get a dbus api for doing most of
# our jack management functions.  All I have to do is figure out how
# to enable all of it from dbus-tcl
#
# Okay, that works, but the downside is that dbus doesn't observe the
# same granularity as jack, so while I can open multiple jack clients
# in a single process, only one connection to dbus can be made per
# process.
#
# The basic unit of the network is the fnode which controls one input,
# output, or processing element.  An fnode controls a slider or a dial
# in a user interface or on an embedded controller, or a programmable
# oscillator, or a stepper motor tuning a magloop, or combines
# multiple user interface elements together.
#
# Fnodes are organized into groups according to which process or piece
# of embedded processor they run on.  Each process or embedded
# processor establishes a pnode which connects to the MIDI network.
#
# Hardware or software which doesn't follow this convention, such as a
# DG8SAQ controller for an Si570, will be proxied into the dssdr
# network by a software component.
#
# Each pnode joins the MIDI network at startup and receives a unique
# address on the network.
#
# Each fnode joins its pnode at start up, supplies a receive callback,
# and gets a transmit callback and a unique address on the network. 
#
# Addresses are words from [0-9A-Z]+ interpreted as numbers in base 36
# which are fixed point fractions in the interval [0 .. 1).  Trailing
# zeroes are suppressed, so A, A0, A00, and A000 are all the same address.
# Addresses are allocated shortest first, so all the one digit addresses
# are allocated before the two digit addresses.
#
# Addresses of pnodes are a single word unique among the known pnodes.
# Addresses of fnodes on a given pnode are a single word unique among
# the known fnodes on that pnode.  The complete address of an fnode is
# the address of its pnode concatenated to its pnode local address
# with a dot. So 1.1 or A.B would be typical fully resolved fnode
# addresses. 
#
# Communication uses MIDI SYSEX messages identified with the
# educational SYSEX vendor id, '}', followed by '|' and '{'.
# The message payload consists of a destination address, a source
# address, and a message text.  In addition to specific addresses, the
# asterisk may be used as a wild card, so a destination of *.*
# addresses all fnodes and * addresses all pnodes.
#
# The payload of the message is a subset of Tcl, commands consisting
# of words separated by spaces.  The principle command is 'set' which
# can be used to report or alter variables.
#
# Each fnode and pnode implement a standard set of variables:
#	vars - the full set of variables implemented by the node
#	name - the name of the node, which may be used to distinguish
#		between multiple nodes of the same type
#	type - the type of the node
#	addr - the address of the node
# name and type may be empty strings.
#

#
# oh, how interesting, this immediately runs into the same issue that
# everything else did: how to deal with jack starting and stopping.
# MIDI services that appear and disappear. Addresses that may change
# over the course of the application's life.
#

#
# so the fundamental service which everyone cares about is jack, is jack
# running or not, call me when jack starts or stops.
#

#
# implement a pnode in Tcl
# 
package provide sdrnode 1.0

namespace eval ::sdrnode {
    set name "noname"
    set type "notype"
    set addr "noaddr"
    set fnodes {}
    set pnodes {}
    set vars {name type addr fnodes pnodes}
    set started false
    set midi {}
}

#
# set the name of this node
#
proc ::sdrnode::set-name {newname} {
    variable name
    set name $newname
}

#
# set the type of this node
#
proc ::sdrnode::set-type {newtype} {
    variable type
    set type $newtype
}

#
# start this node
#
proc ::sdrnode::start {} {
    variable started
    if { ! $started} {
	
    }
}
    
#
# the join function
# 
proc ::sdrnode::join {rxcallback} {
    start
}

#
# the send function
#
proc ::sdrnode::send {source dest msg} {
    variable midi
    start
    $midi put [binary format cccca*c 0xF0 0x7D 0x7C 0x7B "$dest $source $msg" 0xF7]
}


