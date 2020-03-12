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
# morse code for cyrillic
# taken from http://en.wikipedia.org/wiki/Other_alphabets_in_Morse_code Tue Jan 17 2012
# minor editing on pasted table, translate &centerdot; into .
#
# the dict returned by morse-cyrillic-dict can be used to initialize a unicode keyer
#   ::sdrtcl::keyer-unicode foo -dict [morse-cyrillic-dict]
#

package provide morse::cyrillic 1.0.0

namespace eval ::morse {}
namespace eval ::morse::cyrillic {
    set dict [dict create]
    foreach {letter roman code} {
	А	A	•−
	Л	L	•−••
	Х	H	••••
	Б	B	−•••
	М	M	−−
	Ц	C	−•−•
	В	W	•−−
	Н	N	−•
 	Ч	Ö	−−−•
	Г	G	−−•
	О	O	−−−
	Ш	CH	−−−−
	Д	D	−••
	П	P	•−−•
	Щ	Q	−−•−
	Е	E	•
	Р	R	•−•
	Ь	X	−••−
	Ж	V	•••−
	С	S	•••
	Ы	Y	−•−−
	З	Z	−−••
	Т	T	−
	Э	É	••−••
	И	I	••
	У	U	••−
	Ю	Ü	••−−
	Й	J	•−−−
	Ф	F	••−•
	Я	Ä	•−•−
	К	K	−•−	
    } {
	set chars {}
	foreach c [split $code {}] {
	    scan $c %c char
	    switch $char {
		8226 { set char . } 
		8722 -
		45 { set char - }
		default { puts "unrecognized character: $char" }
	    }
	    append chars $char
	}
	#puts "table {$letter} {$roman} {$code} {$chars}"
	dict set dict $letter $chars
	dict set dict \#transliterate\# $letter $roman
    }
}

proc morse-cyrillic-dict {} {
    return $::morse::cyrillic::dict
}
