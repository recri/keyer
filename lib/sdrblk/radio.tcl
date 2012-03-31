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

package require sdrblk::rx
package require sdrblk::tx
package require sdrblk::hw

::snit::type sdrblk::radio {
    component rx
    component tx
    component hw

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -rx -default true -readonly yes -validatemethod Validate -configuremethod Configure
    option -tx -default false -readonly yes -validatemethod Validate -configuremethod Configure
    option -hw -default {softrock ensemble rx ii dg8saq} -readonly yes -validatemethod Validate -configuremethod Configure
    option -rx-inport -readonly yes -default {system:capture_1 system:capture_2} -validatemethod Validate -configuremethod Configure
    option -rx-outport -readonly yes -default {system:playback_1 system:playback_2} -validatemethod Validate -configuremethod Configure
    option -tx-inport -readonly yes -default {} -validatemethod Validate -configuremethod Configure
    option -tx-outport -readonly yes -default {} -validatemethod Validate -configuremethod Configure

    option -rx-iq-swap -default false
    option -rx-iq-delay -default 0
    option -rx-iq-correct -default false
    option -rx-iq-correct-mu -default 0.0125
    option -rx-rf-gain -default 0

    constructor {args} {
	puts "radio $self constructor $args"
	$self configure {*}$args
	install rx using ::sdrblk::rx %AUTO% -partof $self -server $options(-server) -inport $options(-rx-inport) -outport $options(-rx-outport)
	install tx using ::sdrblk::tx %AUTO% -partof $self -server $options(-server) -inport $options(-tx-inport) -outport $options(-tx-outport)
	install hw using ::sdrblk::hw %AUTO% -partof $self -hw $options(-hw)
    }

    destructor {
	catch {$rx destroy}
	catch {$tx destroy}
	catch {$hw destroy}
    }

    method Validate {opt val} {
	#puts "radio $self Validate $opt $val"
	switch -- $opt {
	    -hw -
	    -rx-inport -
	    -rx-outport -
	    -tx-inport -
	    -tx-outport -
	    -server {
	    }
	    -rx -
	    -tx {
		::sdrblk::validate::boolean $opt $val
	    }
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "radio $self Configure $opt $val"
	switch -- $opt {
	    -rx-inport -
	    -rx-outport -
	    -tx-inport -
	    -tx-outport -
	    -server -
	    -rx -
	    -tx {
	    }
	    -hw {
	    }
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }
}
