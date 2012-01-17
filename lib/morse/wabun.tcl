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
# wabun code for Japanese kana
# taken from http://en.wikipedia.org/wiki/Wabun_code Tue Jan 17 14:19:51 MST 2012
# minor editing on pasted table, translate &centerdot; into .
#
# the dict returned by morse-wabun-dict can be used to initialize a unicode keyer
#   ::keyer::unicode foo -dict [morse-wabun-dict]
#

package provide ::morse::wabun 1.0.0

namespace eval ::morse {}
namespace eval ::morse::wabun {
    set dict [dict create]
    foreach {romanji mora wabun} {
	a ア	--•--
	ka カ	•-••
	sa サ	-•-•-
	ta タ	-•
	na ナ	•-•
	ha ハ	-•••
	ma マ	-••-
	ya ヤ	•--
	ra ラ	•••
	wa ワ	-•-
	Dakuten ◌゛	••
	i イ	•-
	ki キ	-•-••
	shi シ	--•-•
	chi チ	••-•
	ni ニ	-•-•
	hi ヒ	--••-
	mi ミ	••-•-
	ri リ	--•
	wi ヰ	•-••-
	Handakuten ◌゜	••--•
	u ウ	••-
	ku ク	•••-
	su ス	---•-
	tsu ツ	•--•
	nu ヌ	••••
	fu フ	--••
	mu ム	-
	yu ユ	-••--
	ru ル	-•--•
	n ン	•-•-•
	{Long vowel} ◌̄	•--•-
	e エ	-•---
	ke ケ	-•--
	se セ	•---•
	te テ	•-•--
	ne ネ	--•-
	he ヘ	•
	me メ	-•••-
	re レ	---
	we ヱ	•--••
	Comma 、	•-•-•-
	o オ	•-•••
	ko コ	----
	so ソ	---•
	to ト	••-••
	no ノ	••--
	ho ホ	-••
	mo モ	-••-•
	yo ヨ	--
	ro ロ	•-•-
	wo ヲ	•---
	{Full stop} 。	•-•-••
    } {
	set chars {}
	foreach c [split $wabun {}] {
	    scan $c %c char
	    switch $char {
		8226 { set char . } 
		45 { set char - }
		default { error "unrecognized character in wabun: $char" }
	    }
	    append chars $char
	}
	# puts "table {$romanji} {$mora} {$wabun} {$chars}"
	dict set dict $mora $chars
	dict set dict transliterate $mora $romanji
    }
}

proc morse-wabun-dict {} {
    return $::morse::wabun::dict
}
