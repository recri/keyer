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

package provide sdrapp::radio 1.0.0

package require snit

package require sdrctl::control
package require sdrblk::rx
package require sdrblk::tx
package require sdrblk::keyer

namespace eval sdrapp {}

snit::type sdrapp::radio {

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -rx -readonly yes -default true
    option -tx -readonly yes -default true
    option -keyer -readonly yes -default true
    option -hw -readonly yes -default true
    option -hw-type -readonly yes -default {hw-softrock-dg8saq}
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {ui-notebook}
    option -rx-source -readonly yes -default {system:capture_1 system:capture_2}
    option -rx-sink -readonly yes -default {system:playback_1 system:playback_2}
    option -tx-source -readonly yes -default {}
    option -tx-sink -readonly yes -default {}
    option -keyer-source -readonly yes -default {}
    option -keyer-sink -readonly yes -default {}

    constructor {args} {
	$self configure {*}$args
	set options(-control) [::sdrctl::control ::sdrapp::ctl -partof $self]
	if {$options(-rx)} { ::sdrblk::rx ::radio-rx -partof $self -source $options(-rx-source) -sink $options(-rx-sink) }
	if {$options(-tx)} { ::sdrblk::tx ::radio-tx -partof $self -source $options(-tx-source) -sink $options(-tx-sink) }
	if {$options(-keyer)} { ::sdrblk::keyer ::radio-keyer -partof $self -source $options(-keyer-source) -sink $options(-keyer-sink) }
	if {$options(-hw)} {
	    package require sdrhw::$options(-hw-type)
	    ::sdrhw::$options(-hw-type) ::radio-hw -partof $self
	}
	if {$options(-ui)} {
	    package require sdrui::$options(-ui-type)
	    ::sdrui::$options(-ui-type) ::radio-ui -partof $self
	}
    }

    destructor {
	catch {::sdrapp::ui destroy}
	catch {::sdrapp::hw destroy}
	catch {::sdrapp::keyer destroy}
	catch {::sdrapp::tx destroy}
	catch {::sdrapp::rx destroy}
	catch {::sdrapp::ctl destroy}
    }

    method repl {} {
	catch {::sdrapp::ui repl}
    }
}
