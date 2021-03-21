#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
# binary encoded morse tables up to 6 elements
# 

package provide morse::binary 1.0.0

namespace eval ::morse {}
namespace eval ::morse::binary {}

#
# translate a morse code in dits and dahs to binary
#
proc didah-to-binary {code} {
    set binary 1
    foreach didah [split $code {}] {
	set binary [expr {$binary<<1|($didah eq {-})}]
    }
    return $binary
}

proc binary-to-didah {binary} {
    set code {}
    while {$binary != 1} {
	append code [expr {$binary&1 ? {-} : {.}}]
	set binary [expr {$binary>>1}]
    }
    return $code
}

#
# translate a morse code dictionary to a binary decoding string
#
proc morse-to-string {dict} {
    set binary [dict create]
    dict for {key value} $dict {
	if { ! [string match \#*\# $key] && [didah-to-binary $value] < 128} {
	    dict set binary [didah-to-binary $value] $key
	}
    }
    set string {}
    foreach key [lsort -integer [dict keys $binary]] {
	while {[string length $string] < $key} {
	    append string ~
	}
	append string [dict get $binary $key]
    }
    while {[string length $string] < 128} {
	append string ~
    }
    return $string
}

#
# translate a binary string to a morse dictionary
#
proc string-to-morse {string} {
    set dict [dict create]
    for {set i 0} {$i < [string length $string]} {incr i} {
	set c [string index $string $i]
	if {$c ne {~}} {
	    dict set dict $c [binary-to-didah $i]
	}
    }
    return $dict
}

set morse::binary::codings {
    letters  {~~ETIANMSURWDKGOHVF~L~PJBXCYZQ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    digits   {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~54~3~~~2~~~~~~~16~~~~~~~7~~~8~90~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    punct    {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~+~~~~~~=/~~~~~~~~~~~~~~~~~~~~~~~~~?~~~~~~~~.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~,~~~~~~~~~~~~}
    punct2   {~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~&~~~~~~~~~~~~~(~~~~~~~~~~~~~~~~~~~~~~_~~~~\"~~~~~~~@~~~'~~-~~~~~~~~;!~)~~~~~~~~~~~~~~~~~~}
    letters2 {~~~~~~~~~~~~~~~~~~~Ü~Ä~~~~~~~~Ö~~~~~É~~~~~~~~~~~~~~~Ç~~~~~~Ñ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    fld      "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}~~&~~<~>~~~~~~~~~~~~~~~~~~~~~~~~{~%~~~~~~~~~~~~~~~~~~~~~~~~~~~-~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    cyrillic {~~ЕТИАНМСУРВДКГОХЖФЮЛЯПЙБЬЦЫЗЩЧШ~~~~Э~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    greek    {~~ΕΤΙΑΝΜΣ~ΡΩΔΚΓΟΗ~Φ~Λ~Π~ΒΞΘΥΖΨ~Χ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    arabic   {~~ﺀتيانمسطرودكغخحضف~لع~جبصثظذقزش~~~~ه~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    farsi    {~~هتیانمسطرودکژعحذفغلصپجبخثظزگچش~~~~ض~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ق~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    hebrew   {~~ותיאנמשטרצדכגהח~~~ל~פעב~ס~זק~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
    wabun    {~~ヘム◌゛イタヨラウナヤホワリレヌクチノカロツヲハマニケフネソコ~~~トミ◌゜オヰンテヱ◌̄セ~メモユキサルエ~ヒシア~ス~~~~~~~~~~~~~~~~~~~~~~。、~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~}
}

# names of previously defined morse code dictionaries
# and how to construct them from the codings given above
set morse::binary::dicts {
    builtin {letters digits punct}
    itu {letters digits punct punct2}
    fldigi {letters digits punct punct2 letters2 fld}
    arabic arabic
    farsi farsi
    cyrillic cyrillic
    greek greek
    hebrew hebrew
    wabun wabun
}
