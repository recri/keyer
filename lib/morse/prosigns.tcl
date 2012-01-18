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

#
# morse code prosigns
#
# the dict returned by morse-prosigns-dict can be used to initialize a unicode keyer
#   ::keyer::unicode foo -dict [morse-prosigns-dict]
#

package provide ::morse::prosigns 1.0.0

namespace eval ::morse {}
namespace eval ::morse::prosigns {
    set dict [dict create]
    foreach {sign code} {
	<AA>	.-.-
	<AAA>	.-.-.-
	<AR>    .-.-.
	<AS>    .-...
	<BT>    -...-
	<HH>    ........
	<II>    ....
	<IMI>	..--..
	<NR>	-..-.
	<SK>	...-.-
	<SOS>	...---...
    } {
	# puts "table {$sign} {$code}"
	dict set dict $sign $code
    }
}

proc morse-prosigns-dict {} {
    return $::morse::prosigns::dict
}
