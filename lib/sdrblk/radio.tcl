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

package provide sdrblk::radio 1.0.0

package require snit

package require sdrblk::radio-control
package require sdrblk::radio-rx
package require sdrblk::radio-tx
package require sdrblk::radio-hw
package require sdrblk::radio-ui

::snit::type sdrblk::radio {
    component control
    component rx
    component tx
    component hw
    component ui

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -rx -readonly yes -default true
    option -tx -readonly yes -default false
    option -hw -readonly yes -default true
    option -hw-type -readonly yes -default {softrock-dg8saq}
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {command-line}
    option -rx-inport -readonly yes -default {system:capture_1 system:capture_2}
    option -rx-outport -readonly yes -default {system:playback_1 system:playback_2}
    option -tx-inport -readonly yes -default {}
    option -tx-outport -readonly yes -default {}

    constructor {args} {
	#puts "radio $self constructor $args"
	$self configure {*}$args
	install control using ::sdrblk::radio-control %AUTO% -partof $self
	set options(-control) $control
	if {$options(-rx)} {
	    install rx using ::sdrblk::radio-rx %AUTO% -partof $self -inport $options(-rx-inport) -outport $options(-rx-outport)
	}
	if {$options(-tx)} {
	    install tx using ::sdrblk::radio-tx %AUTO% -partof $self -inport $options(-tx-inport) -outport $options(-tx-outport)
	}
	if {$options(-hw)} {
	    package require sdrblk::radio-hw-$options(-hw-type)
	    install hw using ::sdrblk::radio-hw-$options(-hw-type) %AUTO% -partof $self
	}
	if {$options(-ui)} {
	    # puts "requiring sdrblk::radio-ui-$options(-ui-type)"
	    package require sdrblk::radio-ui-$options(-ui-type)
	    # puts "installing ui using ::sdrblk::radio-ui-$options(-ui-type) %AUTO% -partof $self"
	    install ui using ::sdrblk::radio-ui-$options(-ui-type) %AUTO% -partof $self
	    # puts "ui is $ui"
	}
    }

    destructor {
	catch {$ui destroy}
	catch {$hw destroy}
	catch {$tx destroy}
	catch {$rx destroy}
	catch {$control destroy}
    }

    method repl {} {
	if {$ui ne {}} { $ui repl }
    }
}
