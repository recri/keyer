/*
  Copyright (C) 2011, 2012 by Roger E Critchlow Jr, Santa Fe, NM, USA.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/
#ifndef MORSE_CODING_H
/*
** translate queued characters into morse code key transitions
*/
#if 1 				/* still newer version */
/* 
** this is a string representation of a Tcl dict, a list of key value pairs concatenated.
** the dict is the ITU morse dictionary augmented with prosigns for extended characters
** and commented with prosigns for the punctuation characters.
** the " needed an extra \ escape in this representation
** the $ and ; would need to be quoted in a Tcl list representation
**
** Revised to use amateur prosigns in preference to punctuation characters.
*/
static const char morse_coding_dict_string[] = 
  /* "! -.-.-- "			/* <SN> */
  /* "\\\" .-..-. "		/* <RR> */
  /* "$ ...-..- "			/* <SX> */
  /* "& .-... "			/* <AS> */
  /* "' .----. "			/* <WG> */
  /* "( -.--. "			/* <KN> */
  /* ") -.--.- "			/* <KK> */
  "* ...-.- "		/* <SK> */
  "+ .-.-. "			/* <AR> */
  ", --..-- "			/* <MIM> */
  /* "- -....- "			/* <BA> */
  ". .-.-.- "			/* <RK> */
  "/ -..-. "			/* <DN> */
  "0 ----- 1 .---- 2 ..--- 3 ...-- 4 ....- 5 ..... 6 -.... 7 --... 8 ---.. 9 ----. "
  /* ": ---... "			/* <OS> */
  /* "; -.-.-. "			/* <CN> */
  "= -...- "			/* <BT> */
  "? ..--.. "			/* <IMI> */
  /* "@ .--.-. "			/* <AC> */
  "A .- B -... C -.-. D -.. E . F ..-. G --. H .... I .. J .--- K -.- L .-.. M -- "
  "N -. O --- P .--. Q --.- R .-. S ... T - U ..- V ...- W .-- X -..- Y -.-- Z --.. "
  /*  "_ ..--.- "			/* <UK> */
  /* "<AA> .-.- "                  /* <AA>,Ä,Æ,Ą */
  /* "<AR> .-.-. "			/* <AR>,+ */
  /* "<AS> .-... "			/* <AS>,& */
  /* "<CT> -.-.- "                 /* <CT>,<KA> */
  /* "<HM> ....-- "                /* <HM> */
  /* "<INT> ..-.- "                /* <INT> */
  /* "<KN> -.--. "			/* <KN>,( */
  /* "<SK> ...-.- "                /* <SK>,* */
  /* "<VE> ...-. "                 /* <VE>,<SN>,Ŝ */
  /* "<NJ> -..--- "                /* <NJ>,<XM>,<DO> */
  /* "<SOS> ...---... "		/* <SOS> */
  /* "Á .--.- "			/* À,Á,Â  */
  /* "Ñ --.-- "			/* Ń, Ñ */
  /* "Ö ---. "			/* Ó, Ö, Ø */
  /* "Š ---- "			/* CH, Ĥ, Š */
  /* "É ..-.. "			/* Đ, É, Ę */
  /* "Ü ..-- "			/* Ü, Ŭ */
  /* additional from wikipedia 2020-09-30 */
  /* "Ç -.-.. "                    /* Ć, Ĉ, Ç */
  /* "Ð ..--. "                    /* Ð (eth) */
  /* "È .-..- "                    /* È, Ł */
  /* "Ĝ --.-. "                    /* Ĝ */
  /* "Ĵ .---. "                    /* Ĵ */
  /* "Ś ...-... "                  /* Ś */
  /* "Þ .--.. "                    /* Þ */
  /* "Ź --..-. "                   /* Ź */
  /* "Ż --..- "                    /* Ż */
  /* "<AR> .-.-. "		/* + */
  /* "<AS> .-... "		/* * */
  ;
#endif
#if 0				/* new version */
static char *morse_coding_table[][2] = {
					"!", "...-.",	 /* <SN> */
					"\"",  ".-..-.", /* <RR> */
					"$", "...-..-",	 /* <SX> */
					"&", ".-...",	 /* <AS> */
					"'", ".----.",	 /* <WG> */
					"(", "-.--.",	 /* <KN> */
					")", "-.--.-",	 /* <KK> */
					"*", "...-.-",	 /* <SK> */
					"+", ".-.-.",	 /* <AR> */
					",", "--..--",	 /* <MIM> */
					"-", "-....-",	 /* <DU> */
					".", ".-.-.-",	 /* <RK> */
					"/", "-..-.",	 /* <DN> */
					"0", "-----",
					"1", ".----",
					"2", "..---",
					"3", "...--",
					"4", "....-",
					"5", ".....",
					"6", "-....",
					"7", "--...",
					"8", "---..",
					"9", "----.",
					":", "---...", /* <OS> */
					";", "-.-.-.", /* <KR> */
					"=", "-...-",  /* <BT> */
					"?", "..--..", /* <IMI> */
					"@", ".--.-.", /* <AC> */
					"A", ".-",
					"B", "-...",
					"C", "-.-.",
					"D", "-..",
					"E", ".",
					"F", "..-.",
					"G", "--.",
					"H", "....",
					"I", "..",
					"J", ".---",
					"K", "-.-",
					"L", ".-..",
					"M", "--",
					"N", "-.",
					"O", "---",
					"P", ".--.",
					"Q", "--.-",
					"R", ".-.",
					"S", "...",
					"T", "-",
					"U", "..-",
					"V", "...-",
					"W", ".--",
					"X", "-..-",
					"Y", "-.--",
					"Z", "--..",
					"_", "..--.-", /* <UK> */
					"À", ".--.-",  /* <AK> */
					"Á", ".--.-",  /* <AK> */
					"Â", ".--.-",  /* <AK> */
					"Ä", ".-.-",   /* <AA> */
					"Ç", "----",   /* <OT> */
					"È", "..-..",  /* <UI> */
					"É", "..-..",  /* <UI> */
					"Ñ", "--.--",  /* <GM> */
					"Ö", "---.",   /* <OE> */
					"Ü", "..--",   /* <UT> */
};
#endif
#if 0				/* old version */
static char *morse_coding_table[128] = {
  /* 000 NUL */ 0, /* 001 SOH */ 0, /* 002 STX */ 0, /* 003 ETX */ 0,
  /* 004 EOT */ 0, /* 005 ENQ */ 0, /* 006 ACK */ 0, /* 007 BEL */ 0,
  /* 008  BS */ 0, /* 009  HT */ 0, /* 010  LF */ 0, /* 011  VT */ 0,
  /* 012  FF */ 0, /* 013  CR */ 0, /* 014  SO */ 0, /* 015  SI */ 0,
  /* 016 DLE */ 0, /* 017 DC1 */ 0, /* 018 DC2 */ 0, /* 019 DC3 */ 0,
  /* 020 DC4 */ 0, /* 021 NAK */ 0, /* 022 SYN */ 0, /* 023 ETB */ 0,
  /* 024 CAN */ 0, /* 025  EM */ 0, /* 026 SUB */ 0, /* 027 ESC */ 0,
  /* 028  FS */ 0, /* 029  GS */ 0, /* 030  RS */ 0, /* 031  US */ 0,
  /* 032  SP */ 0,
  /* 033   ! */ "...-.",	// [SN]
  /* 034   " */ ".-..-.",	// [RR]
  /* 035   # */ 0,
  /* 036   $ */ "...-..-",	// [SX]
  /* 037   % */ ".-...",	// [AS]
  /* 038   & */ 0,
  /* 039   ' */ ".----.",	// [WG]
  /* 040   ( */ "-.--.",	// [KN]
  /* 041   ) */ "-.--.-",	// [KK]
  /* 042   * */ "...-.-",	// [SK]
  /* 043   + */ ".-.-.",	// [AR]
  /* 044   , */ "--..--",
  /* 045   - */ "-....-",
  /* 046   . */ ".-.-.-",
  /* 047   / */ "-..-.",
  /* 048   0 */ "-----",
  /* 049   1 */ ".----",
  /* 050   2 */ "..---",
  /* 051   3 */ "...--",
  /* 052   4 */ "....-",
  /* 053   5 */ ".....",
  /* 054   6 */ "-....",
  /* 055   7 */ "--...",
  /* 056   8 */ "---..",
  /* 057   9 */ "----.",
  /* 058   : */ "---...",	// [OS]
  /* 059   ; */ "-.-.-.",	// [KR]
  /* 060   < */ 0,
  /* 061   = */ "-...-",	// [BT]
  /* 062   > */ 0,
  /* 063   ? */ "..--..",	// [IMI]
  /* 064   @ */ ".--.-.",       // <AC>
  /* 065   A */ ".-",
  /* 066   B */ "-...",
  /* 067   C */ "-.-.",
  /* 068   D */ "-..",
  /* 069   E */ ".",
  /* 070   F */ "..-.",
  /* 071   G */ "--.",
  /* 072   H */ "....",
  /* 073   I */ "..",
  /* 074   J */ ".---",
  /* 075   K */ "-.-",
  /* 076   L */ ".-..",
  /* 077   M */ "--",
  /* 078   N */ "-.",
  /* 079   O */ "---",
  /* 080   P */ ".--.",
  /* 081   Q */ "--.-",
  /* 082   R */ ".-.",
  /* 083   S */ "...",
  /* 084   T */ "-",
  /* 085   U */ "..-",
  /* 086   V */ "...-",
  /* 087   W */ ".--",
  /* 088   X */ "-..-",
  /* 089   Y */ "-.--",
  /* 090   Z */ "--..",
  /* 091   [ */ 0,
  /* 092   \ */ 0,
  /* 093   ] */ 0,
  /* 094   ^ */ 0,
  /* 095   _ */ "..--.-",	// [UK]
  /* 096   ` */ 0,
  /* 097   a */ ".-",
  /* 098   b */ "-...",
  /* 099   c */ "-.-.",
  /* 100   d */ "-..",
  /* 101   e */ ".",
  /* 102   f */ "..-.",
  /* 103   g */ "--.",
  /* 104   h */ "....",
  /* 105   i */ "..",
  /* 106   j */ ".---",
  /* 107   k */ "-.-",
  /* 108   l */ ".-..",
  /* 109   m */ "--",
  /* 110   n */ "-.",
  /* 111   o */ "---",
  /* 112   p */ ".--.",
  /* 113   q */ "--.-",
  /* 114   r */ ".-.",
  /* 115   s */ "...",
  /* 116   t */ "-",
  /* 117   u */ "..-",
  /* 118   v */ "...-",
  /* 119   w */ ".--",
  /* 120   x */ "-..-",
  /* 121   y */ "-.--",
  /* 122   z */ "--..",
  /* 123   { */ 0,
  /* 124   | */ 0,
  /* 125   } */ 0,
  /* 126   ~ */ 0,
  /* 127 DEL */ "........"
};

static char *morse_coding(Tcl_UniChar ascii) {
  return morse_coding_table[ascii & 127];
}
#endif
#endif
