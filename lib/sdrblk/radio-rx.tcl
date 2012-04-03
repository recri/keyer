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

package provide sdrblk::radio-rx 1.0.0

package require snit

package require sdrblk::radio-rx-rf
package require sdrblk::radio-rx-if
package require sdrblk::radio-rx-af

::snit::type sdrblk::radio-rx {
    component block -public block
    component rxrf
    component rxif
    component rxaf

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}

    option -implemented -readonly yes -default yes
    option -suffix -readonly yes -default rx

    option -inport -readonly yes
    option -outport -readonly yes
    
    constructor {args} {
	puts "rx $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	#puts "radio-rx block = $block"
	install rxrf using ::sdrblk::radio-rx-rf %AUTO% -partof $self
	#puts "radio-rx rxrf = $rxrf"
	install rxif using ::sdrblk::radio-rx-if %AUTO% -partof $self
	#puts "radio-rx rxif = $rxif"
	install rxaf using ::sdrblk::radio-rx-af %AUTO% -partof $self
	puts "radio-rx rxaf = $rxaf"
	$rxrf block configure -output $rxif
	$rxif block configure -input $rxrf -output $rxaf
	$rxaf block configure -input $rxaf
	$block configure -sink $options(-outport) -source $options(-inport)
    }

    destructor {
	catch {$block destroy}
	catch {$rxrf destroy}
	catch {$rxif destroy}
	catch {$rxaf destroy}
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
