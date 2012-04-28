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

package provide sdrapp::radio 1.0.0

package require snit

package require sdrctl::radio-control

namespace eval sdrapp {}

snit::type sdrapp::radio {

    option -server -readonly yes -default default
    option -control -readonly yes
    option -name -readonly yes -default {}
    option -enable -readonly yes -default true
    option -rx -readonly yes -default true
    option -tx -readonly yes -default true
    option -keyer -readonly yes -default true
    option -hw -readonly yes -default true
    option -hw-type -readonly yes -default {hw-softrock-dg8saq}
    option -ui -readonly yes -default true
    option -ui-type -readonly yes -default {ui-notebook}
    option -ports -readonly yes -default yes

    option -rx-source -readonly yes -default {system:capture_1 system:capture_2}
    option -rx-sink -readonly yes -default {system:playback_1 system:playback_2}
    option -tx-source -readonly yes -default {}
    option -tx-sink -readonly yes -default {}
    option -keyer-source -readonly yes -default {}
    option -keyer-sink -readonly yes -default {}

    option -activate-hw -readonly yes -default no
    option -enable-rx -readonly yes -default no
    option -activate-rx -readonly yes -default no

    constructor {args} {
	$self configure {*}$args
	set options(-control) [::sdrctl::radio-controller ::radio-ctl -container $self -server $options(-server)]
	if {$options(-ui)} {
	    package require sdrui::$options(-ui-type)
	    ::sdrui::$options(-ui-type) ::radio-ui -container $self
	}
	::sdrctl::radio-controls -container $self
	if {$options(-hw)} {
	    sdrctl::control ::sdrctlw::hw -type hw -prefix {} -suffix hw -factory sdrctl::control-stub -container $self
	    if {$options(-hw)} {
		package require sdrhw::$options(-hw-type)
		::sdrhw::$options(-hw-type) ::radio-hw -container ::sdrctlw::hw
	    }
	}
	if {$options(-ports)} {
	    package require sdrdsp::dsp-hw
	    ::sdrdsp::dsp-hw ::radio-ports -container $self
	}
	if {$options(-rx)} {
	    package require sdrdsp::dsp-rx
	    ::sdrdsp::rx ::radio-rx -container $self
	    $self connect $options(-rx-source) rx $options(-rx-sink)
	}
	if {$options(-keyer)} {
	    package require sdrdsp::dsp-keyer
	    ::sdrdsp::keyer ::keyer -container $self
	    $self connect $options(-keyer-source) keyer $options(-keyer-sink)
	}
	if {$options(-tx)} {
	    package require sdrdsp::dsp-tx
	    ::sdrdsp::tx ::radio-tx -container $self
	    $self connect $options(-tx-source) tx $options(-tx-sink)
	}
	::radio-ctl part-resolve
	#::radio-ctl part-configure ctl-rxtx-mode -mode CWU
	if {$options(-activate-hw)} {
	    {*}$options(-control) part-activate hw
	}
	if {$options(-enable-rx)} {
	    foreach name {rx-rf-gain rx-rf-iq-correct rx-if-mix rx-if-bpf rx-af-agc} {
		{*}$options(-control) part-enable $name
	    }
	}
	if {$options(-activate-rx)} {
	    {*}$options(-control) activate rx
	}
    }

    method connect {source part sink} {
	set ports [$options(-control) port-filter [list $part *]]
	if {[llength $source]+[llength $sink] == [llength $ports]} {
	    foreach s $source t [lrange $ports 0 1] {
		$options(-control) port-connect {*}[split $s :] {*}$t
	    }
	    foreach s [lrange $ports 2 end] t $sink {
		$options(-control) port-connect {*}$s  {*}[split $t :]
	    }
	}
    }
    destructor {
	catch {::radio-ui destroy}
	catch {::radio-hw destroy}
	catch {::keyer destroy}
	catch {::radio-tx destroy}
	catch {::radio-rx destroy}
	catch {::radio-ctl destroy}
    }

    method repl {} { catch {::radio-ui repl} }
}
