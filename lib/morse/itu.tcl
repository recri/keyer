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
# ITU standard morse code
# taken from http://en.wikipedia.org/wiki/Morse_code Tue Jan 17 2012
# minor editing on pasted table
#
# the dict returned by morse-itu-dict can be used to initialize a unicode keyer
#   ::sdrtcl::keyer-unicode foo -dict [morse-itu-dict]
#

package provide morse::itu 1.0.0

namespace eval ::morse {}
namespace eval ::morse::itu {
    set dict [dict create]
    foreach {character code} {
	!	—·—·——
	\"	·—··—·
	$	···—··—
	&	·—···
	'	·————·
	(	—·——·
	)	—·——·—
	+	·—·—·
	,	——··——
	-	—····—
	.	·—·—·—
	/	—··—·
	0	—————
	1	·————
	2	··———
	3	···——
	4	····—
	5	·····
	6	—····
	7	——···
	8	———··
	9	————·
	:	———···
	;	—·—·—·
	=	—···—
	?	··——··
	@	·——·—·
	A	·—
	B	—···
	C	—·—·
	D	—··
	E	·
	F	··—·
	G	——·
	H	····
	I	··
	J	·———
	K	—·—
	L	·—··
	M	——
	N	—·
	O	———
	P	·——·
	Q	——·—
	R	·—·
	S	···
	T	—
	U	··—
	V	···—
	W	·——
	X	—··—
	Y	—·——
	Z	——··
	_	··——·—
    } {
	set chars {}
	foreach c [split $code {}] {
	    scan $c %c char
	    switch $char {
		46 -
		183 -
		8226 { set char . } 
		8212 -
		45 { set char - }
		default { puts "unrecognized character: $char" }
	    }
	    append chars $char
	}
	# puts "table {$character} {$code} {$chars}"
	dict set dict $character $chars
    }
}

proc morse-itu-dict {} {
    return $::morse::itu::dict
}
