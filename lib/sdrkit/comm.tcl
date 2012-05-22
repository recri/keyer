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

package provide sdrkit::comm 1.0.0

#package require comm

namespace eval sdrkit {}
namespace eval sdrkit::comm {}

#
# okay, ignore this for a moment
# because using comm for all communication is extremely slow
# and the semantics of the local call differ from the remote
# call because comm::comm send does some mangling.
#
# ideally, we can identify the targets which are remote and
# arrange to remote the calls.
#
# a remote module will be passed a controller handle which
# embeds the remote call and clues the module to send a module
# callback handle which also embeds the remote call.  or everyone
# will embed a remote call, but those which are local will be
# short circuited.
#
# the semantics can be finessed by performing an echo loop here
# on every send and verifying that the result of the echo is
# the same, in sublist lengths, to the original.
#
proc sdrkit::comm::send {target args} {
    # set result [comm::comm send {*}$target {*}$args]
    set result [$target {*}$args]
    # puts "comm::comm send $target $args => $result"
    return $result
}

proc sdrkit::comm::wrap {command} {
    #return [list [comm::comm self] {*}$command]
    return $command
}

