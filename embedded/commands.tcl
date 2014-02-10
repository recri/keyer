# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2014 by Roger E Critchlow Jr, Santa Fe, NM, USA.
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
# prototype the command line hygiene with snit

package require snit

namespace eval ::command {}

snit::type command::command {

    method cget {args} {
	# usage: cget -option-name [ -option-name-2 ... ]
	# returns: option values in a list
    }

    method cset {args} {
	# usage: cset -option-name option-value [ -option-name-2 option-value-2 ... ]
	# retunrs: nothing
    }
    
    method {info command} {} {
	# usage: into
	# returns: information string about command
    }
    
    method {info options} {} {
	# usage: info options
	# returns: list of options implemented by command
    }

    method {info methods} {} {
	# usage: info methods
	# returns: list of methods implemented by command
    }
    
    method {info option} {name} {
	# usage: info option -option-name
	# returns: information string about option
    }

    method {info method} {name} {
	# usage: info option method-name
	# returns: information string about method
    }

    # dimension of option or method argument
    # default unit of option or method argument
    # value sets and patterns
}
