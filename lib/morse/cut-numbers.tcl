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
# cut numbers in morse code
# taken from http://www.qsl.net/zs1an/contesting_faq.html Tue Jan 17 MST 2012

# minor editing on pasted table
#
# the dict returned by morse-cut-numbers-dict can be used to initialize a unicode keyer
#   ::sdrtcl::keyer-unicode foo -dict [morse-itu-dict]
# but that would be pretty silly, since it only defines 10 characters, better to
# merge it into another dict.
#

package provide morse::cut-numbers 1.0.0

namespace eval ::morse {}
namespace eval ::morse::cut-numbers {
    set dict [dict create]
    foreach {character code} {
	0	-
	1	.-
	2	..-
	3	...-
	4	....-
	5	.
	6	-....
	7	--.
	8	-..
	9	-.
    } {
	# puts "table {$character} {$code}"
	dict set dict $character $code
    }
}

proc morse-cut-numbers-dict {} {
    return $::morse::cut-numbers::dict
}
