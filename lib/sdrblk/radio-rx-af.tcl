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

package provide sdrblk::radio-rx-af 1.0.0

package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::agc
package require sdrblk::demod
package require sdrblk::gain

::snit::type sdrblk::radio-rx-af {
    component block -public block
    component agc
    component demod
    component gain

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}

    option -implemented -readonly yes -default yes
    option -suffix -readonly yes -default af

    constructor {args} {
	puts "rx-af $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	install agc using ::sdrblk::agc %AUTO% -partof $self
	install demod using ::sdrblk::demod %AUTO% -partof $self
	install gain using ::sdrblk::gain %AUTO% -partof $self
	# WSCompand here
	$agc block configure -output $demod
	# RXMETER_POST_AGC here
	# SPEC_POST_AGC here
	$demod block configure -input $agc -output $gain
	# do_rx_squelch here
	# SpotTone here
	# graphiceq here
	# SPEC_POST_DET here
	$gain block configure -input $demod
    }

    destructor {
	catch {$block destroy}
        catch {$agc destroy}
	catch {$demod destroy}
	catch {$gain destroy}
    }

    method Cget {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget $opt]
	}
    }
    
    method Prefix {opt} {
	if {[info exists options($opt)] && $options($opt) ne {}} {
	    return $options($opt)
	} else {
	    return [$options(-partof) cget -name]
	}
    }
}
