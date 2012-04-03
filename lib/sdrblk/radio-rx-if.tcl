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

package provide sdrblk::radio-rx-if 1.0.0

package require sdrblk::block-pipeline

namespace eval ::sdrblk {}

proc ::sdrblk::radio-rx-if {name args} {
    # -pipeline {spec_pre_filt sdrblk::lo-mixer sdrblk::filter-overlap-save rxmeter_post_filt spec_post_filt}
    return [::sdrblk::block-pipeline $name -suffix if \
		-pipeline {sdrblk::lo-mixer sdrblk::filter-overlap-save} {*}$args]
}

if {0} {
package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::lo-mixer
package require sdrblk::filter-overlap-save

::snit::type sdrblk::radio-rx-if {
    component block -public block
    component mix
    component bpf

    option -partof -readonly yes
    option -server -readonly yes -default {} -cgetmethod Cget
    option -control -readonly yes -default {} -cgetmethod Cget
    option -prefix -readonly yes -default {} -cgetmethod Prefix
    option -name -readonly yes -default {}

    option -implemented -readonly yes -default yes
    option -suffix -readonly yes -default if

    constructor {args} {
	puts "rx-if $self constructor $args"
	$self configure {*}$args
	set options(-name) [string trim [$self cget -prefix]-$options(-suffix) -]
	install block using ::sdrblk::block %AUTO% -partof $self
	install mix using ::sdrblk::lo-mixer %AUTO% -partof $self
	install bpf using ::sdrblk::filter-overlap-save %AUTO% -partof $self
	$mix block configure -output $bpf
	# SPEC_PRE_FILT	here
	$bpf block configure -input $mix
	# RXMETER_POST_FILT here
	# SPEC_POST_FILT here
    }

    destructor {
	catch {$block destroy}
        catch {$mix destroy}
	catch {$bpf destroy}
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
}