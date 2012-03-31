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

package provide sdrblk::rx-af 1.0.0

package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::agc
package require sdrblk::demod
package require sdrblk::gain

::snit::type sdrblk::rx-af {
    component block -public block
    component agc
    component demod
    component gain

    option -server -default default -readonly yes
    option -partof -readonly yes
    option -gain-name -default ::rx-af-gain -readonly yes
    option -agc-name -default ::rx-agc -readonly yes
    option -demod-name -default ::rx-demod -readonly yes
    
    constructor {args} {
	puts "rx-af $self constructor $args"
	$self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
	install agc using ::sdrblk::agc %AUTO% -partof $self -server $options(-server) -name $options(-agc-name)
	install demod using ::sdrblk::demod %AUTO% -partof $self -server $options(-server) -name $options(-demod-name)
	install gain using ::sdrblk::gain %AUTO% -partof $self -server $options(-server) -name $options(-gain-name)
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

    method Validate {opt val} {
	#puts "rx-af $self Validate $opt $val"
	switch -- $opt {
	    -partof {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "rx-af $self Configure $opt $val"
	switch -- $opt {
	    -partof {}
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }

}
