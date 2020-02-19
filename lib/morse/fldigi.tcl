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
# morse code tables from fldigi-4.1.09.tar.gz
# taken from https://svwh.dl.sourceforge.net/project/fldigi/fldigi/fldigi-4.1.09.tar.gz
# on February 13, 2020.
# minor editing and compiling on pasted table
#
# the dict returned by morse-fldigi-dict can be used to initialize a unicode keyer
#   ::sdrtcl::keyer-ascii foo -dict [morse-fldigi-dict]
#

package provide morse::fldigi 1.0.0

namespace eval ::morse {}
namespace eval ::morse::fldigi {
  
    # struct {
    #  int enable;
    #  const char *character;
    #  const char *prosign;
    #  const char *morse;
    #}
    variable table {
	// Prosigns
	{1, "=",	"<BT>",   "-...-" }, // 0
	{0, "~",	"<AA>",   ".-.-" }, // 1
	{1, "<",	"<AS>",   ".-..." }, // 2
	{1, ">",	"<AR>",   ".-.-." }, // 3
	{1, "%",	"<SK>",   "...-.-" }, // 4
	{1, "+",	"<KN>",   "-.--." }, // 5
	{1, "&",	"<INT>",  "..-.-" }, // 6
	{1, "\{",	"<HM>",   "....--" }, // 7
	{1, "\}",	"<VE>",   "...-." }, // 8
	// ASCII 7bit letters
	{1, "A",	"A",	".-" },
	{1, "B",	"B",	"-..." },
	{1, "C",	"C",	"-.-." },
	{1, "D",	"D",	"-.." },
	{1, "E",	"E",	"."	 },
	{1, "F",	"F",	"..-." },
	{1, "G",	"G",	"--." },
	{1, "H",	"H",	"...." },
	{1, "I",	"I",	".." },
	{1, "J",	"J",	".---" },
	{1, "K",	"K",	"-.-" },
	{1, "L",	"L",	".-.." },
	{1, "M",	"M",	"--" },
	{1, "N",	"N",	"-." },
	{1, "O",	"O",	"---" },
	{1, "P",	"P",	".--." },
	{1, "Q",	"Q",	"--.-" },
	{1, "R",	"R",	".-." },
	{1, "S",	"S",	"..." },
	{1, "T",	"T",	"-"	 },
	{1, "U",	"U",	"..-" },
	{1, "V",	"V",	"...-" },
	{1, "W",	"W",	".--" },
	{1, "X",	"X",	"-..-" },
	{1, "Y",	"Y",	"-.--" },
	{1, "Z",	"Z",	"--.." },
	//
	{1, "a",	"A",	".-" },
	{1, "b",	"B",	"-..." },
	{1, "c",	"C",	"-.-." },
	{1, "d",	"D",	"-.." },
	{1, "e",	"E",	"."	 },
	{1, "f",	"F",	"..-." },
	{1, "g",	"G",	"--." },
	{1, "h",	"H",	"...." },
	{1, "i",	"I",	".." },
	{1, "j",	"J",	".---" },
	{1, "k",	"K",	"-.-" },
	{1, "l",	"L",	".-.." },
	{1, "m",	"M",	"--" },
	{1, "n",	"N",	"-." },
	{1, "o",	"O",	"---" },
	{1, "p",	"P",	".--." },
	{1, "q",	"Q",	"--.-" },
	{1, "r",	"R",	".-." },
	{1, "s",	"S",	"..." },
	{1, "t",	"T",	"-"	 },
	{1, "u",	"U",	"..-" },
	{1, "v",	"V",	"...-" },
	{1, "w",	"W",	".--" },
	{1, "x",	"X",	"-..-" },
	{1, "y",	"Y",	"-.--" },
	{1, "z",	"Z",	"--.." },
	// Numerals
	{1, "0",	"0",	"-----" },
	{1, "1",	"1",	".----" },
	{1, "2",	"2",	"..---" },
	{1, "3",	"3",	"...--" },
	{1, "4",	"4",	"....-" },
	{1, "5",	"5",	"....." },
	{1, "6",	"6",	"-...." },
	{1, "7",	"7",	"--..." },
	{1, "8",	"8",	"---.." },
	{1, "9",	"9",	"----." },
	// Punctuation
	{1, "\\",	"\\",	".-..-." },
	{1, "\'",	"'",	".----." },
	{1, "$",	"$",	"...-..-" },
	{1, "(",	"(",	"-.--."	 },
	{1, ")",	")",	"-.--.-" },
	{1, ",",	",",	"--..--" },
	{1, "-",	"-",	"-....-" },
	{1, ".",	".",	".-.-.-" },
	{1, "/",	"/",	"-..-."	 },
	{1, ":",	":",	"---..." },
	{1, ";",	";",	"-.-.-." },
	{1, "?",	"?",	"..--.." },
	{1, "_",	"_",	"..--.-" },
	{1, "@",	"@",	".--.-." },
	{1, "!",	"!",	"-.-.--" },
	// accented characters
	{1, "Ä", "Ä",	".-.-" },	// A umlaut
	{1, "ä", "Ä",	".-.-" },	// A umlaut
	{0, "Æ", "Æ",	".-.-" },	// A aelig
	{0, "æ", "Æ",	".-.-" },	// A aelig
	{0, "Å", "Å",	".--.-" },	// A ring
	{0, "å", "Å",	".--.-" },	// A ring
	{1, "Ç", "Ç",	"-.-.." },	// C cedilla
	{1, "ç", "Ç",	"-.-.." },	// C cedilla
	{0, "È", "È",	".-..-" },	// E grave
	{0, "è", "È",	".-..-" },	// E grave
	{1, "É", "É",	"..-.." },	// E acute
	{1, "é", "É",	"..-.." },	// E acute
	{0, "Ó", "Ó",	"---." },	// O acute
	{0, "ó", "Ó",	"---." },	// O acute
	{1, "Ö", "Ö",	"---." },	// O umlaut
	{1, "ö", "Ö",	"---." },	// O umlaut
	{0, "Ø", "Ø",	"---." },	// O slash
	{0, "ø", "Ø",	"---." },	// O slash
	{1, "Ñ", "Ñ",	"--.--" },	// N tilde
	{1, "ñ", "Ñ",	"--.--" },	// N tilde
	{1, "Ü", "Ü",	"..--" },	// U umlaut
	{1, "ü", "Ü",	"..--" },	// U umlaut
	{0, "Û", "Û",	"..--" },	// U circ
	{0, "û", "Û",	"..--" },	// U circ
	// array termination
	{0, "", "", ""}
    }
    set dict [dict create]
    set prodict [dict create]
    foreach line [split $table \n] {
	# trim comments
	set line [regsub {//.*$} $line {}]
	# trim leading and trailing white space
	set line [string trim $line]
	# if empty
	if {$line eq {}} continue
	# remove internal commas
	set line [regsub -all {,[ \t]+} $line { }]
	# remove trailing commas
	set line [regsub {,$} $line {}]
	# iterate over remaining table
	foreach {enabled char pro code} {*}$line break
	# discard disabled entries
	if {! $enabled} continue
	# discard lower case
	if {[string is lower $char]} continue
	# make the tables
	dict set dict $char $code
	dict set prodict $pro $code
    }
}

proc morse-fldigi-dict {} {
    return $::morse::fldigi::dict
}

proc morse-fldigi-pro-dict {} {
    return $::morse::fldigi::prodict
}
    
