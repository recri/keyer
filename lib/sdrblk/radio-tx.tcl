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

package provide sdrblk::radio-tx 1.0.0

package require snit

#package require sdrblk::tx-af
#package require sdrblk::tx-if
#package require sdrblk::tx-rf

::snit::type sdrblk::radio-tx {
    component block -public block
    component txaf
    component txif
    component txrf

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}

    option -implemented -readonly yes -default yes
    option -suffix -readonly yes -default tx

    option -inport -readonly yes
    option -outport -readonly yes
    
    constructor {args} {
	puts "tx $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-name) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	#install txaf using ::sdrblk::tx-af %AUTO% -partof $self
	#install txif using ::sdrblk::tx-if %AUTO% -partof $self
	#install txrf using ::sdrblk::tx-rf %AUTO% -partof $self
	#$txaf block configure -output $txif
	#$txif block configure -input $txaf -output $txrf
	#$txrf block configure -input $txif
	$block configure -sink $options(-outport) -source $options(-inport)
    }

    destructor {
	catch {$block destroy}
	catch {$txaf destroy}
	catch {$txif destroy}
	catch {$txrf destroy}
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
