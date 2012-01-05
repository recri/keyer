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
package provide callsigns 1.0.0

namespace eval ::callsigns {
    foreach {country data} {
	{Afghanistan}	{{YA, T6}	{AS}}
	{Agalega & St. Brandon Is.}	{{3B6, 3B7}	{AF}}	
	{Aland Island}	{{OH0}	{EU}}	
	{Alaska}	{{KL7, AL7, NL7, WL7}	{NA}}	
	{Albania}	{{ZA}	{EU}}	
	{Algeria}	{{7T-7Y}	{AF}}	
	{American Samoa}	{{KH8, AH8, NH8, WH8}	{OC}}	
	{Amsterdam & St. Paul Is.}	{{FT5Z}	{AF}}	
	{Andaman & Nicobar Island}	{{VU4}	{AS}}	
	{Andorra}	{{C3}	{EU}}	
	{Angola}	{{D2, D3}	{AF}}	
	{Anguilla}	{{VP2E}	{OC}}	
	{Annobon Island}	{{3C0}	{AF}}	
	{Antarctica}	{{CE9, KC4, VK0, 8J1}	{AN}}	
	{Antigua & Barbuda}	{{V2}	{NA}}	
	{Argentina}	{{LO-LW, L2-L9, AY-AZ}	{SA}}	
	{Armenia}	{{EK}	{AS}}	
	{Aruba}	{{P4}	{SA}}	
	{Ascension Island}	{{ZD8}	{AF}}	
	{Asiatic Russia}	{{UA-UI8, RA-RZ, 9, 0}	{AS}}	
	{Auckland & Campbell Is.}	{{ZL9}	{OC}}	
	{Austral Island}	{{FO}	{OC}}	
	{Australia}	{{VK, VI, AX}	{OC}}	
	{Austria}	{{OE}	{EU}}	
	{Aves Island}	{{YV0, YX0}	{NA}}	
	{Azerbaijan}	{{4J, 4K}	{AS}}	
	{Azores}	{{CU 1-9}	{EU}}	
	{Bahamas}	{{C6}	{NA}}	
	{Bahrain}	{{A9}	{AS}}	
	{Baker & Howland Island}	{{KH1, K1B, AH1, NH1, WH1}	{OC}}	
	{Balearic Island}	{{EA6-EH6}	{EU}}	
	{Banaba Is. (Ocean Is.)}	{{T33}	{OC}}	
	{Bangladesh}	{{S2}	{AS}}	
	{Barbados}	{{8P}	{NA}}	
	{Belarus}	{{EU, EV, EW}	{EU}}	
	{Belgium}	{{ON-OT}	{EU}}	
	{Belize}	{{V3}	{NA}}	
	{Benin}	{{TY}	{AF}}	
	{Bermuda}	{{VP9}	{NA}}	
	{Bhutan}	{{A5}	{AS}}	
	{Bolivia}	{{CP}	{SA}}	
	{Bonaire, Curacao. Netherlands Antilles}	{{PJ2, 4, 9}	{SA}}	
	{Bosnia-Herzegovina}	{{E7 T9}	{EU}}	
	{Botswana}	{{A2, 8O}	{AF}}	
	{Bouvet Island}	{{3Y}	{AF}}	
	{Brazil}	{{PP-PY, ZV-ZZ}	{SA}}	
	{British Virgin Island}	{{VP2V}	{NA}}	
	{Brunei}	{{V8}	{OC}}	
	{Bulgaria}	{{LZ}	{EU}}	
	{Burkina Faso}	{{XT}	{AF}}	
	{Burundi}	{{9U}	{AF}}	
	{Cambodia}	{{XU}	{AS}}	
	{Cameroon}	{{TJ}	{AF}}	
	{Canada}	{{VA-VG, VO, VX-VY, CF-CK, CY-CZ, XJ-XO}	{NA}}	
	{Canary Island}	{{EA8-EH8}	{AF}}	
	{Cape Verde}	{{D4}	{AF}}	
	{Cayman Island}	{{ZF}	{NA}}	
	{Central Africa}	{{TL}	{AF}}	
	{Central Kiribati. (British Phoenix Island)}	{{T31}	{OC}}	
	{Ceuta & Melilla}	{{EA9-EH9}	{AF}}	
	{Chad}	{{TT}	{AF}}	
	{Chagos Island}	{{VQ9}	{AF}}	
	{Chatham Island}	{{ZL7}	{OC}}	
	{Chesterfield Island}	{{TX0, TX9}	{OC}}	
	{Chile}	{{CA-CE, XQ, XR, 3G}	{SA}}	
	{China}	{{BY, BA-BL, BR-BT}	{AS}}	
	{Christmas Island}	{{VK9X}	{OC}}	
	{Clipperton Island}	{{FO}	{NA}}	
	{Cocos Island}	{{TI9}	{NA}}	
	{Cocos-Keeling Island}	{{VK9C}	{OC}}	
	{Colombia}	{{HK, HJ, 5J, 5K}	{SA}}	
	{Comoros}	{{D6}	{AF}}	
	{Congo (Republic of)}	{{TN}	{AF}}	
	{Conway Reef}	{{3D2/C}	{OC}}	
	{Corsica}	{{TK}	{EU}}	
	{Costa Rica}	{{TI, TE}	{NA}}	
	{Cote d'Ivoire}	{{TU}	{AF}}	
	{Crete}	{{SV9}	{EU}}	
	{Croatia}	{{9A}	{EU}}	
	{Crozet Island}	{{FT5W}	{AF}}	
	{Cuba}	{{CO, CL, CM, T4}	{NA}}	
	{Cyprus}	{{5B, C4, H2, P3}	{AS}}	
	{Czech Republic}	{{OK-OL}	{EU}}	
	{Dem. People's Rep. Korea}	{{P5}	{AS}}	
	{Dem. Rep. of Congo}	{{9Q-9T}	{AF}}	
	{Denmark}	{{OZ, OU, OV, OW, XP, 5P, 5Q}	{EU}}	
	{Desecheo Island}	{{KP5, NP5, WP5}	{NA}}	
	{Djibouti}	{{J2}	{AF}}	
	{Dodecanese}	{{SV5}	{EU}}	
	{Dominica}	{{J7}	{NA}}	
	{Dominican Republic}	{{HI}	{NA}}	
	{Ducie Island}	{{VP6D}	{OC}}	
	{East Kiribati (Line Is.)}	{{T32}	{OC}}	
	{East Malaysia}	{{9M6-9M8}	{OC}}	
	{Easter Island}	{{CE0, 3G0}	{SA}}	
	{Ecuador}	{{HC-HD}	{SA}}	
	{Egypt}	{{SU}	{AF}}	
	{El Salvador}	{{YS, HU}	{NA}}	
	{England}	{{G, M, 2E}	{EU}}	
	{Equatorial Guinea}	{{3C}	{AF}}	
	{Eritrea}	{{E3}	{AF}}	
	{Estonia}	{{ES}	{EU}}	
	{Ethiopia}	{{ET, 9E-9F}	{AF}}	
	{European Russia}	{{UA-UI, RA-RZ, 1, 3, 4, 6}	{EU}}	
	{Falkland Island}	{{VP8}	{SA}}	
	{Faroe Islands}	{{OY}	{EU}}	
	{Fed. Rep. of Germany}	{{DA-DL}	{EU}}	
	{Fernando de Noronha}	{{PP0-PY0F}	{SA}}	
	{Fiji}	{{3D2}	{OC}}	
	{Finland}	{{OF-OI}	{EU}}	
	{France}	{{F, TM}	{EU}}	
	{Franz Josef Land}	{{R1FJ}	{EU}}	
	{French Guiana}	{{FY}	{SA}}	
	{French Polynesia}	{{FO}	{OC}}	
	{Gabon}	{{TR}	{AF}}	
	{Galapagos Island}	{{HC8, HD8}	{SA}}	
	{Georgia}	{{4L}	{AS}}	
	{Ghana}	{{9G}	{AF}}	
	{Gibraltar}	{{ZB2}	{EU}}	
	{Glorioso Island}	{{FR/G}	{AF}}	
	{Greece}	{{SV-SZ}	{EU}}	
	{Greenland}	{{OX}	{NA}}	
	{Grenada}	{{J3}	{NA}}	
	{Guadeloupe}	{{FG, TO}	{NA}}	
	{Guam}	{{KH2, AH2, NH2, WH2}	{OC}}	
	{Guantanamo Bay}	{{KG4, KG4AA-AZ}	{NA}}	
	{Guatemala}	{{TG, TD}	{NA}}	
	{Guernsey}	{{GU, GP, MU, 2U}	{EU}}	
	{Guinea}	{{3X}	{AF}}	
	{Guinea-Bissau}	{{J5}	{AF}}	
	{Guyana}	{{8R}	{SA}}	
	{Haiti}	{{HH}	{NA}}	
	{Hawaii}	{{KH6-7, AH6-7, NH6-7, WH6-7}	{OC}}	
	{Heard Island}	{{VK0}	{AF}}	
	{Honduras}	{{HQ, HR}	{NA}}	
	{Hong Kong}	{{VR}	{AS}}	
	{Hungary}	{{HA, HG}	{EU}}	
	{Iceland}	{{TF}	{EU}}	
	{India}	{{VU, AT}	{AS}}	
	{Indonesia}	{{YB-YH, 8A-8I}	{OC}}	
	{Iran}	{{EP-EZ, 9B-9D}	{AS}}	
	{Iraq}	{{YI}	{AS}}	
	{Ireland}	{{EI, EJ}	{EU}}	
	{Isle of Man}	{{GD, GT, MD, 2D}	{EU}}	
	{Israel}	{{4X, 4Z}	{AS}}	
	{Italy}	{{I}	{EU}}	
	{ITU HQ}	{{4U_ITU}	{EU}}	
	{Jamaica}	{{6Y}	{NA}}	
	{Jan Mayen}	{{JX}	{EU}}	
	{Japan}	{{JA-JS, 7JA-7NZ, 8JA-8NZ}	{AS}}	
	{Jersey}	{{GJ, GH, MJ, 2J}	{EU}}	
	{Johnston Island}	{{KH3, K3J, AH3, NH3, WH3}	{OC}}	
	{Jordan}	{{JY}	{AS}}	
	{Juan de Nova, Europa}	{{FR/J, FR/E, TO4}	{AF}}	
	{Juan Fernandez Island}	{{CE0}	{SA}}	
	{Kaliningrad}	{{UA2-UI2, RA2-RZ2}	{EU}}	
	{Kazakhstan}	{{UN-UQ}	{AS}}	
	{Kenya}	{{5Y, 5Z}	{AF}}	
	{Kerguelen Island}	{{FT5X}	{AF}}	
	{Kermadec Island}	{{ZL8}	{OC}}	
	{Kingman Reef}	{{KH5K, AH2, NH2, WH2}	{OC}}	
	{Kure Island}	{{KH7K, K7C, K7K, AH7K, NH7K, WH7K}	{OC}}	
	{Kuwait}	{{9K}	{AS}}	
	{Kyrgyzstan}	{{EX}	{AS}}	
	{Lakshadweep Island}	{{VU7}	{AS}}	
	{Laos}	{{XW}	{AS}}	
	{Latvia}	{{YL}	{EU}}	
	{Lebanon}	{{OD}	{AS}}	
	{Lesotho}	{{7P}	{AF}}	
	{Liberia}	{{EL, A8, D5, 5L, 5M, 6Z}	{AF}}	
	{Libya}	{{5A}	{AF}}	
	{Liechtenstein}	{{HB0}	{EU}}	
	{Lithuania}	{{LY}	{EU}}	
	{Lord Howe lsland}	{{VK9L}	{OC}}	
	{Luxembourg}	{{LX}	{EU}}	
	{Macao}	{{XX9}	{AS}}	
	{Macedonia}	{{Z3}	{EU}}	
	{Macquarie Island}	{{VK0}	{OC}}	
	{Madagascar}	{{5R, 5S, 6X}	{AF}}	
	{Madeira Island}	{{CT3, XX3, 3, 9}	{AF}}	
	{Malawi}	{{7Q}	{AF}}	
	{Maldives}	{{8Q}	{AS,AF}} 	
	{Mali}	{{TZ}	{AF}}	
	{Malpelo Island}	{{HK0/M}	{SA}}	
	{Malta}	{{9H}	{EU}}	
	{Malyj Vysotskij Island}	{{R1MV}	{EU}}	
	{Mariana Island}	{{KH0, AH0, NH0, WH0}	{OC}}	
	{Market Reef}	{{OJ0, OH0M}	{EU}}	
	{Marquesas Island}	{{FO}	{OC}}	
	{Marshall Island}	{{V7}	{OC}}	
	{Martinique}	{{FM, TO}	{NA}}	
	{Mauritania}	{{5T}	{AF}}	
	{Mauritius}	{{3B8}	{AF}}	
	{Mayotte}	{{FH}	{AF}}	
	{Mellish Reef}	{{VK9M}	{OC}}	
	{Mexico}	{{XA-XI, 4A-4C, 6D-6J}	{NA}}	
	{Micronesia}	{{V6}	{OC}}	
	{Midway Island}	{{KH4, AH4, NH4, WH4}	{OC}}	
	{Minami Torishima}	{{JD1}	{OC}}	
	{Moldova}	{{ER}	{EU}}	
	{Monaco}	{{3A}	{EU}}	
	{Mongolia}	{{JT, JU, JV}	{AS}}	
	{Montenegro}	{{4O}	{EU}}	
	{Montserrat}	{{VP2M}	{NA}}	
	{Morocco}	{{CN}	{AF}}	
	{Mount Athos}	{{SV/A}	{EU}}	
	{Mozambique}	{{C8-9}	{AF}}	
	{Myanmar}	{{XY-XZ}	{AS}}	
	{Namibia}	{{V5}	{AF}}	
	{Nauru}	{{C2}	{OC}}	
	{Navassa Island}	{{KP1, NP1, WP1}	{NA}}	
	{Nepal}	{{9N}	{AS}}	
	{Netherlands}	{{PA-PI}	{EU}}	
	{New Caledonia}	{{FK}	{OC}}	
	{New Zealand}	{{ZL-ZM}	{OC}}	
	{Nicaragua}	{{YN, HT, H6, H7}	{NA}}	
	{Niger}	{{5U}	{AF}}	
	{Nigeria}	{{5N, 5O}	{AF}}	
	{Niue}	{{ZK2}	{OC}}	
	{Norfolk Island}	{{VK9N}	{OC}}	
	{North Cook Islands}	{{E5 ZK1}	{OC}}	
	{Northern Ireland}	{{GI, GN, MI, 2I}	{EU}}	
	{Norway}	{{LA-LN}	{EU}}	
	{Ogasawara}	{{JD1}	{AS}}	
	{Oman}	{{A4}	{AS}}	
	{Pakistan}	{{AP-AS, 6P-6S}	{AS}}	
	{Palau}	{{T8 KC6}	{OC}}	
	{Palestine}	{{E4}	{AS}}	
	{Palmyra & Jarvis Island}	{{KH5, K5K, AH2, NH2, WH2}	{OC}}	
	{Panama}	{{HO, HP, H3, 3E, 3F, H8, H9}	{NA}}	
	{Papua New Guinea}	{{P2}	{OC}}	
	{Paraguay}	{{ZP}	{SA}}	
	{Peru}	{{OA-OC, 4T}	{SA}}	
	{Peter I. Island}	{{3Y}	{AN}}	
	{Philippines}	{{DU-DZ, 4D-4I}	{OC}}	
	{Pitcairn Island}	{{VP6}	{OC}}	
	{Poland}	{{SN-SR, HF, 3Z}	{EU}}	
	{Portugal}	{{CT, CQ, CS, 1, 2, 4, 5, 6, 7}	{EU}}	
	{Pratas Island}	{{BV9P}	{AS}}	
	{Prince Edward & Marion Is.}	{{ZS8}	{AF}}	
	{Puerto Rico}	{{KP3, NP3, WP3, KP4, NP4, WP4}	{NA}}	
	{Qatar}	{{A7}	{AS}}	
	{Republic of Korea}	{{HL, DS, DT, D7, 6K}	{AS}}	
	{Reunion Island}	{{FR}	{AF}}	
	{Revillagigedo}	{{XA4-XI4}	{NA}}	
	{Rodrigues Island}	{{3B9}	{AF}}	
	{Romania}	{{YO-YR}	{EU}}	
	{Rotuma Island}	{{3D2/R}	{OC}}	
	{Rwanda}	{{9X}	{AF}}	
	{Sable Island}	{{CY0}	{NA}}	
	{Samoa}	{{5W}	{OC}}	
	{San Andres & Providencia}	{{HK0, HJ0}	{NA}}	
	{San Felix & San Ambrosio}	{{CE0}	{SA}}	
	{San Marino}	{{T7}	{EU}}	
	{Sao Tome & Principe}	{{S9}	{AF}}	
	{Sardinia}	{{IS0, IM0}	{EU}}	
	{Saudi Arabia}	{{HZ, 7Z, 8Z}	{AS}}	
	{Scarborough Reef}	{{BS7}	{AS}}	
	{Scotland}	{{GM, GS, MM, 2M}	{EU}}	
	{Senegal}	{{6V, 6W}	{AF}}	
	{Serbia}	{{YT-YU}	{EU}}	
	{Seychelles}	{{S7}	{AF}}	
	{Sierra Leone}	{{9L}	{AF}}	
	{Singapore}	{{9V, S6}	{AS}}	
	{Slovak Republic}	{{OM}	{EU}}	
	{Slovenia}	{{S5}	{EU}}	
	{Solomon Islands}	{{H4}	{OC}}	
	{Somalia}	{{T5, 6O}	{AF}}	
	{South Africa}	{{ZR-ZU, S8}	{AF}}	
	{South Cook Islands}	{{E5 ZK1}	{OC}}	
	{South Georgia Island}	{{VP8, LU}	{SA}}	
	{South Orkney Island}	{{VP8, LU}	{SA}}	
	{South Sandwich Island}	{{VP8, LU}	{SA}}	
	{South Shetland Island}	{{VP8, CE9, CX0, HF0, 4K1, LZ0, D88}	{SA}}	
	{Sov. Mil. Order of Malta}	{{1A0}	{EU}}	
	{Spain}	{{EA-EH, AM}	{EU}}	
	{Spratly Islands}	{{9M, BV, DX}	{AS}}	
	{Sri Lanka}	{{4P-4S}	{AS}}	
	{St. Barthelmy Island.}	{{FJ}	{NA}}	
	{St. Helena}	{{ZD7}	{AF}}	
	{St. Kitts & Nevis}	{{V4}	{NA}}	
	{St. Lucia}	{{J6}	{NA}}	
	{St. Maarten, Saba, St. Eustatius}	{{PJ5-8}	{NA}}	
	{St. Martin}	{{FS}	{NA}}	
	{St. Paul Island}	{{CY9}	{NA}}	
	{St. Peter & St. Paul Rocks}	{{PP0-PY0S}	{SA}}	
	{St. Pierre & Miquelon}	{{FP}	{NA}}	
	{St. Vincent}	{{J8}	{NA}}	
	{Sudan}	{{ST}	{AF}}	
	{Suriname}	{{PZ}	{SA}}	
	{Svalbard}	{{JW}	{EU}}	
	{Swain's Island}	{{KH8SI, AH8SI, NH8SI, WH8SI}	{OC}}	
	{Swaziland}	{{3DA}	{AF}}	
	{Sweden}	{{SA-SM}	{EU}}	
	{Switzerland}	{{HB, HE}	{EU}}	
	{Syria}	{{YK, 6C}	{AS}}	
	{Taiwan}	{{BV, BM-BQ, BU-BX}	{AS}}	
	{Tajikistan}	{{EY}	{AS}}	
	{Tanzania}	{{5H, 5I}	{AF}}	
	{Temotu Province}	{{H40}	{OC}}	
	{Thailand}	{{HS-E2}	{AS}}	
	{The Gambia}	{{C5}	{AF}}	
	{Timor-Leste}	{{4W}	{OC}}	
	{Togo}	{{5V}	{AF}}	
	{Tokelau Island}	{{ZK3}	{OC}}	
	{Tonga}	{{A3}	{OC}}	
	{Trindade & Martim Vaz Is.}	{{PP0-PY0T}	{SA}}	
	{Trinidad & Tobago}	{{9Y, 9Z}	{SA}}	
	{Tristan da Cunha & Gough Is.}	{{ZD9}	{AF}}	
	{Tromelin Island}	{{FR/T}	{AF}}	
	{Tunisia}	{{3V, TS}	{AF}}	
	{Turkey}	{{TA-TC}	{EU,AS}}	
	{Turkmenistan}	{{EZ}	{AS}}	
	{Turks & Caicos Island}	{{VP5}	{NA}}	
	{Tuvalu}	{{T2}	{OC}}	
	{Uganda}	{{5X}	{AF}}	
	{UK Sov Base Areas on Cyprus}	{{ZC4}	{AS}}	
	{Ukraine}	{{UR-UT, UU-UZ, EM-EO}	{EU}}	
	{United Arab Emirates}	{{A6}	{AS}}	
	{United Nations HQ}	{{4U_UN}	{NA}}	
	{United States of America}	{{K, N, W, AA-AK}	{NA}}	
	{Uruguay}	{{CV-CX}	{SA}}	
	{Uzbekistan}	{{UJ-UM}	{AS}}	
	{Vanuatu}	{{YJ}	{OC}}	
	{Vatican}	{{HV}	{EU}}	
	{Venezuela}	{{YV-YY, 4M}	{SA}}	
	{Vietnam}	{{3W, XV}	{AS}}	
	{Virgin Island}	{{KP2, NP2, WP2}	{NA}}	
	{Wake Island}	{{KH9, AH9, NH9, WH9}	{OC}}	
	{Wales}	{{GW, GC, MW, 2W,}	{EU}}	
	{Wallis & Futuna Island}	{{FW}	{OC}}	
	{West Kiribati (Gilbert Is.)}	{{T30}	{OC}}	
	{West Malaysia}	{{9M2-9M4}	{AS}}	
	{Western Sahara}	{{S0}	{AF}}	
	{Willis Island}	{{VK9W}	{OC}}	
	{Yemen}	{{7O}	{AS}}	
	{Zambia}	{{9I, 9J}	{AF}}	
	{Zimbabwe}	{{Z2}	{AF}}	
    } {
	foreach {prefixlist continent} $data break
	unset continent
	set prefixes {}
	set appendig {}
	set ranges {}
	foreach item $prefixlist {
	    set item [string trim $item ,]
	    switch -regexp $item {
		{^\w+$} -
		{^[\w/]+$} {
		    lappend prefixes $item
		}
		{^\d$} {
		    lappend appendig $item
		}
		{^\w+-\w+$} {
		    lappend ranges $item
		}
		default {
		    puts $item
		}
	    }
	}
	if {[llength $appendig] > 0} {
	    foreach d $appendig {
		foreach p $prefixes {
		    lappend genprefixes $p$d
		}
	    }
	} else {
	    foreach p $prefixes {
		lappend genprefixes $p
	    }
	}
	foreach r $ranges {
	    foreach {l1 l2} [split $r -] break
	}
	unset prefixes
	unset appendig
	unset ranges
    }
    unset country
    unset data
}

