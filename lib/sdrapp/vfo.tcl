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

package provide sdrapp::vfo 1.0.0

package require snit

package require sdrctl::vfo-control

namespace eval sdrapp {}

snit::type sdrapp::vfo {

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {ui-vfo}

    constructor {args} {
	$self configure {*}$args
	set options(-control) [::sdrctl::vfo-controller ::vfo-ctl -container $self -server $options(-server)]
	if {$options(-ui)} {
	    package require sdrui::$options(-ui-type)
	    ::sdrui::$options(-ui-type) ::radio-ui -container $self
	}
	::sdrctl::vfo-controls -container $self
	::vfo-ctl part-resolve
    }

    destructor {
	catch {::vfo-ui destroy}
	catch {::vfo-ctl destroy}
    }

    method repl {} { catch {::vfo-ui repl} }

}
