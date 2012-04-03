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

package provide sdrblk::radio-rx-rf 1.0.0

package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::iq-swap
package require sdrblk::iq-delay
package require sdrblk::iq-correct
package require sdrblk::gain


::snit::type sdrblk::radio-rx-rf {
    component block -public block
    component gain
    component swap
    component delay
    component correct

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}

    option -implemented -readonly yes -default yes
    option -suffix -readonly yes -default rf

    constructor {args} {
	puts "rx-rf $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	install gain using ::sdrblk::gain %AUTO% -partof $self
	install swap using ::sdrblk::iq-swap %AUTO% -partof $self
	install delay using ::sdrblk::iq-delay %AUTO% -partof $self
	install correct using ::sdrblk::iq-correct %AUTO% -partof $self

	$gain block configure -output $swap
	# SPEC_SEMI_RAW here
	# noiseblanker or SDROMnoiseblanker here
	# RXMETER_PRE_CONV here
	$swap block configure -input $gain -output $delay
	$delay block configure -input $swap -output $correct
	$correct block configure -input $delay
    }

    destructor {
	catch {$block destroy}
        catch {$swap destroy}
	catch {$delay destroy}
	catch {$correct destroy}
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
