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

package provide sdrblk::rx-if 1.0.0

package require snit

package require sdrkit::jack

package require sdrblk::block
package require sdrblk::validate

package require sdrblk::lo-mixer
package require sdrblk::bandpass

::snit::type sdrblk::rx-if {
    component block -public block
    component mixer -public mixer
    component bpf -public bpf

    option -server -default default -readonly yes -validatemethod Validate -configuremethod Configure
    option -partof -readonly yes -validatemethod Validate -configuremethod Configure
    option -rx-if-mixer-name -default ::rx-if-mixer -readonly yes -validatemethod Validate -configuremethod Configure
    option -rx-if-bpf-name -default ::rx-if-bpf -readonly yes -validatemethod Validate -configuremethod Configure
    
    option -rx-if-mixer-freq -default 10000 -validatemethod Validate -configuremethod Configure
    option -rx-if-bpf-center -default 800 -validatemethod Validate -configuremethod Configure
    option -rx-if-bpf-width -default 200 -validatemethod Validate -configuremethod Configure
    option -rx-if-bpf-length -default 1024 -validatemethod Validate -configuremethod Configure

    constructor {args} {
	puts "rx-if $self constructor $args"
	$self configure {*}$args
	install block using ::sdrblk::block %AUTO% -partof $self
	install mixer using ::sdrblk::lo-mixer $options(-rx-if-mixer-name) -partof $self -server $options(-server) \
	    -freq $options(-rx-if-mixer-freq)
	install bpf using ::sdrblk::bandpass $options(-rx-if-bpf-name) -partof $self -server $options(-server) \
	    -center $options(-rx-if-bpf-center) -width $options(-rx-if-bpf-width) -length $options(-rx-if-bpf-length)
	$mixer block configure -output $bpf
	# SPEC_PRE_FILT	here
	$bpf block configure -input $mixer
	$mixer block configure -internal $mixer
	$bpf block configure -internal $bpf
	# RXMETER_POST_FILT here
	# SPEC_POST_FILT here
    }

    destructor {
	$block destroy
        catch {$mixer destroy}
	catch {$bandpass destroy}
    }

    method Validate {opt val} {
	#puts "rx-if $self Validate $opt $val"
	switch -- $opt {
	    -server -
	    -partof {}
	    default {
		error "unknown validate option \"$opt\""
	    }
	}
    }

    method Configure {opt val} {
	#puts "rx-if $self Configure $opt $val"
	switch -- $opt {
	    -server -
	    -partof {}
	    default {
		error "unknown configure option \"$opt\""
	    }
	}
	set options($opt) $val
    }

}
