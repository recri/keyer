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

##
## build the suite of ui components for a radio
##
package provide sdrui::components 1.0.0

package require Tk
    
namespace eval sdrui {}

snit::widget sdrui::stub {
    option -command {}
    option -controls {}
}

snit::type sdrui::components {
    option -control -readonly yes
    option -root -readonly yes

    constructor {args} {
	$self configure {*}$args
	set need(rx) [$options(-control) exists rx]
	set need(tx) [$options(-control) exists tx]
	set need(keyer) [$options(-control) exists keyer]
	foreach {wantedby name require factory opts} {
	    {rx tx keyer} ui {} sdrui::stub {}
	    {rx} ui-rx {} sdrui::stub {}
	    {rx} ui-rx-rf {} sdrui::stub {}
	    {rx} ui-rx-if {} sdrui::stub {}
	    {rx} ui-rx-af {} sdrui::stub {}
	    {tx} ui-tx {} sdrui::stub {}
	    {tx} ui-tx-rf {} sdrui::stub {}
	    {tx} ui-tx-if {} sdrui::stub {}
	    {tx} ui-tx-af {} sdrui::stub {}
	    {keyer} ui-keyer {} sdrui::stub {}
	    {rx tx} ui-tuner sdrui::vfo sdrui::vfo {}
	    {rx tx} ui-band-select sdrui::band-select sdrui::band-select {}

	    {rx} ui-rx-rf-gain sdrui::rf-gain sdrui::rf-gain {-label {RX RF Gain}}
	    {rx} ui-rx-rf-iq-swap sdrui::iq-swap sdrui::iq-swap {}
	    {rx} ui-rx-rf-iq-delay sdrui::iq-delay sdrui::iq-delay {}
	    {rx} ui-rx-rf-iq-correct sdrui::iq-correct sdrui::iq-correct {}
	    {rx tx} ui-if-mix sdrui::lo-offset sdrui::lo-offset {}
	    {rx tx} ui-if-bpf sdrui::filter-select sdrui::filter-select {}
	    {rx} ui-rx-af-agc sdrui::agc-select sdrui::agc-select {}
	    {rx tx} ui-mode sdrui::mode-select sdrui::mode-select {}
	    {rx} ui-rx-af-gain sdrui::af-gain sdrui::af-gain {-label {RX AF Gain}}

	    {tx} ui-tx-af-gain sdrui::af-gain sdrui::af-gain {-label {TX AF Gain}}
	    {tx} ui-tx-af-leveler sdrui::leveler-select sdrui::leveler-select {}
	    {tx} ui-tx-rf-iq-balance sdrui::iq-balance sdrui::iq-balance {}
	    {tx} ui-tx-rf-gain sdrui::rf-gain sdrui::rf-gain {-label {TX RF Gain}}

	    {keyer} ui-keyer-debounce sdrui::debounce sdrui::debounce {}
	    {keyer} ui-keyer-iambic sdrui::iambic sdrui::iambic {}
	    {keyer} ui-keyer-iambic-wpm sdrui::iambic sdrui::iambic-wpm {}
	    {keyer} ui-keyer-iambic-dah sdrui::iambic sdrui::iambic-dah {}
	    {keyer} ui-keyer-iambic-space sdrui::iambic sdrui::iambic-space {}
	    {keyer rx tx} ui-keyer-tone sdrui::cw-pitch sdrui::cw-pitch {}
	} {
	    foreach x $wantedby {
		if {$need($x)} {
		    sdrui::component %AUTO% -root $options(-root) -control $options(-control) -suffix $name -require $require -factory $factory -parent $self -options $opts
		    break
		}
	    }
	}
    }
}

snit::type sdrui::component {
    option -control -readonly yes -default {}
    option -suffix -readonly yes -default {}
    option -root -readonly yes -default {}
    option -require -readonly yes -default {}
    option -factory -readonly yes -default {}
    option -parent -readonly yes -default {}
    option -options {}
    option -name {}
    option -type ui
    option -enable yes
    option -activate -default no -cgetmethod cget-handler

    constructor {args} {
	$self configure {*}$args
	set options(-name) "$options(-root).$options(-suffix)"
	if {$options(-require) ne {}} {
	    package require $options(-require)
	}
	$options(-factory) $options(-name) -command [mymethod command] {*}$options(-options)
	$options(-control) add $options(-suffix) $self
	if {[catch {
	    # there may be no -add-listeners option defined
	    foreach {name1 var1 var2} [$options(-name) cget -add-listeners] {
		$self command add-listener $name1 $var1 $var2
	    }
	} error] && $options(-suffix) eq {ui-if-bpf}} {
	    puts "error adding listeners for $options(-suffix): $error"
	}
    }
    
    method {cget-handler -activate} {} { return [winfo viewable $options(-name)] }
    method {command report} {opt val} { $options(-control) report $options(-suffix) $opt $val }
    method {command add-listener} {name1 opt1 opt2} { $options(-control) add-listener $name1 $opt1 $options(-suffix) $opt2 }

    # these are the methods the radio controller uses
    method controls {} {
	set options(-controls) [$options(-name) cget -controls]
	set controls {}
	foreach opt [$options(-name) configure] {
	    if {[lindex $opt 0] in $options(-controls)} {
		lappend controls $opt
	    }
	}
	return $controls
    }
    method control {args} { $options(-name) configure {*}$args }
    method controlget {opt} { return [$options(-name) cget $opt] }
}



