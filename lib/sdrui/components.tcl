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

package require sdrctl::control
package require sdrctl::control-stub
    
namespace eval sdrui {}
namespace eval sdrctlw {}

snit::type sdrui::components {
    option -control -readonly yes
    option -root -readonly yes
    option -name {}

    constructor {args} {
	$self configure {*}$args
	set need(rx) [$options(-control) part-exists rx]
	set need(tx) [$options(-control) part-exists tx]
	set need(keyer) [$options(-control) part-exists keyer]
	foreach {wantedby name require factory opts} {
	    {rx tx keyer} ui {} sdrctl::control-stub {}
	    {rx tx} ui-rxtx {} sdrctl::control-stub {}
	    {rx} ui-rx {} sdrctl::control-stub {}
	    {rx} ui-rx-rf {} sdrctl::control-stub {}
	    {rx} ui-rx-if {} sdrctl::control-stub {}
	    {rx} ui-rx-af {} sdrctl::control-stub {}
	    {tx} ui-tx {} sdrctl::control-stub {}
	    {tx} ui-tx-rf {} sdrctl::control-stub {}
	    {tx} ui-tx-if {} sdrctl::control-stub {}
	    {tx} ui-tx-af {} sdrctl::control-stub {}
	    {keyer} ui-keyer {} sdrctl::control-stub {}

	    {rx tx} ui-rxtx-tuner sdrui::vfo sdrui::vfo {}
	    {rx tx} ui-rxtx-band-select sdrui::band-select sdrui::band-select {}
	    {rx tx} ui-rxtx-mode sdrui::mode-select sdrui::mode-select {}
	    {rx tx} ui-rxtx-if-mix sdrui::lo-offset sdrui::lo-offset {}
	    {rx tx} ui-rxtx-if-bpf sdrui::filter-select sdrui::filter-select {}

	    {rx} ui-rx-rf-gain sdrui::rf-gain sdrui::rf-gain {-label {RX RF Gain}}
	    {rx} ui-rx-rf-iq-swap sdrui::iq-swap sdrui::iq-swap {}
	    {rx} ui-rx-rf-iq-delay sdrui::iq-delay sdrui::iq-delay {}
	    {rx} ui-rx-rf-iq-correct sdrui::iq-correct sdrui::iq-correct {}
	    {rx} ui-rx-af-agc sdrui::agc-select sdrui::agc-select {}
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
	    #foreach x $wantedby {
		#if {$need($x)} {
		    sdrctl::control ::sdrctlw::$name -type ui -root $options(-root) -control $options(-control) -suffix $name -factory-require $require -factory $factory -factory-options $opts
		#    break
		#}
	    #}
	}
    }
}





