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
# the callsign list from pileup
#

package provide morse::callsigns 1.0.0

namespace eval ::morse {}

namespace eval ::morse::callsigns {
    # the list of callsigns from pileup
    # The callsigns sent are those worked by M6A in the 1996 CQ WW CW contest.
    set calls {
	S51FA LY2FN EI7M RX3QX M6O DL9GOA OK1EW GM3PPE DF0HQ RX6AM
	SM3GSK DL7QU DL3XD SP3CB OH2WI YT0T DF0DF OH6RA SP2DX DL0KF
	5V7A 9A1A OK1FAU OK1AU YL2VW UT8IM DK5PR OK1TP DF3CB SP6CTC
	PA0LOU SM6CST DL3BUM SM6CTQ SM6OLL OM2XW RN3F OH1NOR S51EA GW3JXN
	OK1MG OK1MNW OZ5WQ DL8YR DJ5AV G3VNG G3KDB DF0HQ SP5GH W9OR
	DK0ZG OM5ZM F6CNI SP5GRM S57O LA8WG YL2GTY DL5SDF G0IVZ OK1DOT
	RU3A OK1KZ DL2GGA DJ7MI YL2UZ EM2I DL7BQ YL2GP PA3APW DJ9LJ
	DK7SU DL6EN UU9J WB9Z PA0HIP TK5NN OK1DXW IK1IPV OK1HCG UA1OZ
	G0KRL DL3JAN F6KEQ DL6RAI UY5EG OY9JD RX1OX/FJL RZ6LJ SP9KRT OK1KH
	OH6KIT F5NQL OM3IAG US4IBU 7S0MG UA2FT SP5JTF LZ2UG GM4SID EU5F
	LY1DQ LA9DFA DL8ZAJ RV1CC GU3HFN OI4JFN G3RZF CT1AOZ OK1BMW YL8M
	LA2O DJ9CN 7X2RO OY1CT 9A2VA SM7DLZ 4X4NJ TK5EP OE1A SP5ALV
	G3UFY OT6T OZ7NB LY7A GI3FJX UT3UZ HA8QC SM5HJZ EI4DW CG1ZZ
	PA0CLN LY2OU ES1RA ON6ZX ES1QD UU5J SM3KOR 4U1ITU GW4BVJ SV8ZC
	UN7JID HA0HW LZ7M ON6YH OK1ABF RZ4HO OH1AJ DL9MH G0PRY OM7DX
	S59AA YT7DX 5V7A OL3A S53X NN4T SP5CJZ RU9CK RU9CZ YL2KO
	RW6XA UT7ND OK1AAZ K8MFO K3ZO S53M K0EJ DL8ZAW RW3FO K3LR
	K8MD W1BIH 9A1A G4KIV 4V2A EU4AA RZ1AWO SP9A W9RE K9DX
	KB1H I0ZUT OK2EC 4N7CA DL8YR VO2WL OE3S J6DX EM2I UA6CBM
	K5TF IU2E W0BV RK9CWY LY2BZ DL5JAN S51NP LX/DF0BK GW3SYL UX1HW
	K3KO DF0IT K1VR K4PI US2YW W5TCX S50U RZ4AY W3GG OK1TJ
	UA4CJJ OI9BVM UT5USX W4VQ UT5UIA 4N1A LZ7M RW6BO K1KI DL6YRM
	OH6KIT DL1LOD DL7ANR S51NU OK1DG VE9DH DL3KWR OZ8AE K2PS K1NG
	3C5A DK4TA OH1NSJ N3NT N6CQ K1ZZ DL4ZBY K2SX/1 K3NZ EU2MM
	K1KP S57NL EA2FBR WX8B N6ZO/MM N2MM SP3GTS RK9CWW RA3AF UX1DZ
	W4PB W0LH OK2PCN K4ZO RZ6LG OI2GB DF4ZL RA3CW N4CW HA1SD
	W4RJC EA2BNU LY2BTS S53EA UX5UO SL0CB K2SHZ EA1DD LZ1PM RZ3FW
	LA2O SP4GFG LY2FN LZ7M DJ8CR W9OA RK4WWA K3II UY4E F5OJL
	OM8A WA1LNP N4XR RZ3Q UT4EK DL1TH DJ9RR OH2BSQ IK5TSS NE3H
	HA2EOA ES1TM W1PL K3ANS K9MA RK3YWA OH2AQ LA8SDA 4U1ITU VO1GO
	HG5M OT6P RW3WM YL3FW 4X7A N3EN DK8TU YL2UZ 9A3QK LY2TX
	UY0MM RV3FF RA4PM G0PRY YU7CB HA4FV N9BP OK2BEE K8LX WA2VYA
	DL7QU F5RAB DF1DV SP9DWT N2BA EA8CN S53CAB N2LT LY3CW SP6BAA
	IG9/AC6WE SP3LPR SP6NIC RN4W OH1SH IK4EWX N4AF WU3A OM3YCA YT0U
	W2UP OH2NQS RW6AW OH1AJ SN8V LZ1BJ RV6ASY W3GN GM4SID N4ZJ
	RZ3DZ KV1W 4V2A UT1YW HA3LI W4XJ DJ2XC UX3ZW K2DM RA1TU
	SP4EEZ 8R1K W2RQ UA2FP OM3ZIR DL8OBC W5WQN OH1TN F6CAV OM3EA
	OZ8NJ K8DO VE3CRG UA1ACG OK2EQ YZ7A UR5ZOS UA1ANA K3JGJ N4YDU
	K5KG RK4B DL8WEM KW2J OK1AJY UR5LF WA0FAX S51EA UY5TE DK8GB
	K5YA K0QC OK2PJW HAM8LKC W2PP UT1PO UA9KAA W4OB S57U 9A11TM
	RA6AF K8UNP N1TT W1WFZ HA5NK S54MM RX6AY 9A3GU UT3WW CT8T
	LZ5W W4RX OM5NA SP7JQQ I3JTE YU7BW OK2PBG YT0E UA6AF OM3EK
	SV1AFA 4N7A W4PRZ K4NA HA5KFU IS0MKU HB0G SQ9BZ N4CM YU1JU
	EA2BNU S57AL HA6IAM UX5QT LZ2KMS EA8EA KN4T W5WA IK0YVV HA8VK
	OK2VWB F6IIE UR4PWC UX6VA UX3M HA1KRR OM1AF UR5ZOS SP6OJE G6D
	UX7QQ S59D 4N7CA S50U UA6JY OM3PQ S52OT YU7KM OH1EH SP5EVW
	HA1KW W3LPL K2BU F6CWA DL9JI UR5UW OE3JOS OK1GM LY3MR N8BR
	LY5A HA5WA GW4HBK K8CC W3EA K4II KL7RA KP3G K4SXT NJ4F
	WT1H J39A N6AR W3GU OI4JFN UU0JM HA8QC WA5QHX DK1RV TI4SU/5
	F6DZB W9RN DF7IS OK1HDU KB2VVU DL1MEV DL1HQE DF9ZP DL4BQE/P K0KX
	DF0DF DL7AOJ N4TY K2ONP LY5W OK2PO F6IIE RZ1AZ N4VV UA1AFG
	RV1AQ N3RW YU1L G5MY W2RQ F5ROX VE1JU YO6KBM DL3SZ HA4FF
	DL1JF HA8IB IK2VJF N2TX OK1MNV K4LTA AA5BT SP2LNW 9A2WJ UA2FJ
	DL1LQA WB2JZK YU1FJK DJ5GW K3KY NB6V UR5XA YU7SF W4BQF G5LP
	OK2HIJ W2FR PA0MIR HB9CZF DL5YCI SV1SV UA0OMS SP9XCN S51M ZD8DEZ
	OM3GB OM5RJ KM9D/C6A 4N7A OK1BB LY2KM OH2LP DL1SP K2LE K4RO
	S51FA SP3FLR OM6AUU OK1XUA HB9KOG RZ9AZA F5NBA W3BGN F5CLP OM3TLO
	OK1CW EK4JJ J39A LZ7M OZ5UR RP3LKN DF3QG HA7JTR YT1BB DL1NF
	N4AF N4TO TU4FF S58MU W9LT N2NT K8AZ YL2GQT F5PRH SK6KKK
	F6BUM EM2I KD2RD OK1KAI YO3FRI V47VJ DL6RAI UN9LY SM7VBX OK1CZ
	S58WW K5RT G3EZZ DL2KAS J45T HA0DBG EA4AMJ EA2CRB ED9EA UT5UJO
	CT3FN UX1UA 9A2AA YO4BBH LK7A RU3DU RK3DH HA1KRR YL2KA HA5FW
	RA4HT JA9NFO YL2CV UU5J RK3AWL HA3FZ EW1EA LY2MV LY2NV 3B8CF
	Y21LY YT7P LZ1TT YU1RE IK6SBE EW8DX YT0X OK2BCZ YO7CKQ HA3LQ
	A61AJ SM0CCE OK2BU SN9C LY2FE OK2ON OK2BBQ EW2DD IK4EWX I7PXV
	S57DX OEM3HM RV6YZ 9A1A A45ZN IK3TXQ S59AV OK2TBC YL2KO OI7T
	RA3GDB HA8TI UT2QT YU7DX A71CW S51KV LZ1IQ LZ3Q S52LW EX9A
	LY3DY 9A2TN I0MWI 4N1N SP9XCN LZ1QZ OM3PQ S57AX EU4AA TU2MA
	HA9PB S56A UN7TX Z32KJV IK5ACO EA7TH LZ7N 4N7EC OM4TC RZ6LG
	YU1KX RU3A S31SV J45DZX G3PJT DL5ZN UX3ZW OM6TX LY2BN LY3BG
	YL2ON UT3QW S58MU PA0JED TA3D OM3TBO RA4PQC SP9YDX PY1DYM Z32XA
	YU1QW UR4PWC HA1CW EA3ANH 9A5I HA5AEX OM8RA DK1RV 9A2NO YB1AQS
	9A5WW UR4LCB IT9VDQ SP4AVG 9A1HBC RA3RN HA5BUB YU1TR IS0LYN IS0XPK
	GM6Z PY5BLG RA3XR OK2BNC EA9UG UT7EG UR4LZA RW2F LY5W SP2LNW
	SP8GD OM3RJB S58AL YT1MP UX5EF OM3TLO YU1KN IK0YVV UU5J 9A5I
	9A5WW UR5QLN IK0WMT HA0GK 9A3MN JA1YXP S59AR ZL1AMO OM9TR EA7MT
	OK2PCN OZ5DX YU7WJ YT1BB YT1DZ OI4JFN OK1BA OE1CLW RN3QO LZ2MP
	OL7Z UX5VK US7RA OH1AJ UA0AGI I5ZUF T93R YZ7A HA8PX SP3MGP
	DL4BQE/P S51EP SV1DOJ 4X/OK1JR SL3ZV SM3OSM OEM1GOA LZ7R ZX1A EA7GP
	LU7FJ UX3M IS0OMH ZL1WX 9H0A ZJ1TU SP5AHZ IK0TXF UT3WW OK2BBQ
	RA2FBC DK4RM 7Z5OO OK2PCL S51TE GM4SID UA6AF OK1BMW RZ9AXA S51EA
	OK1FZM IK8TPJ SP9DWT OE1A DL1HWB EA3CA OK2BVM US0IZ SP2PIK IV3TMM
	OK1XC 9A1AA YU7CB OK1AOV PP1RR 4X6PO OK2PVG PY0FF OK1FHD YO4DCF
	DJ4CF HA7XL S57U UY7P OK1AVY LY1DM OM8ON KH0DQ EA7AAP/QRP OK2PLK
	OE7Z OM3YCA UA6JAD DL1DQ DL2GBB US4IDY S58A UR7R YT1AD UT0IU
	UR5YG OM2SS UR5MTA UR5LM 7S0AG YO6KBM TA2DS RA3SL YO8FR HA5NG
	YU1L UA4LMV OK2WCN LZ1AG G3KYF OK1SI UY5QQ 9A1A OE6RAG S51NU
	TA2IJ Z32KV Z37FCA OM5NA LA9AU RA3RN LZ1BJ LZ2TW IK0TUG LZ6A
	4X6POB UY5OQ UT3WW UA6JAD UY5DX IT9GGW IV3BEI UT7LA IV3IUM P40W
	EM7Q YZ1WG 9A2HF FS5PL S57J UT5UN K1ZZ UX0LP UR5IPD OM3A
	DL2GB IV3JWY UA3RO 9A5EI IK4EWX RN3R YO7YO YO3APJ OM7YX YT1UDH
	YB2UDH A71CW IK2QPR RZ6HX UY5EG RV6LFE IK5ALI SP9HWN OH0MAM LZ2JA
	IV3TYE UA4CW RW6ACF 9Y4VU UT7GTU G5MY IK4ZHH IK0YVV RZ7LJ RW6AWT
	HA5OG RA1QHJ OM3PQ HA2MJ S57U IQ4A UA3TAM 5V7A Z37FRP ES2RJ
	OE5WLL N2BA RK4WWA N2JT 7S0MG SP4EEZ K3IE W4WA K1TTT UN8LF
	UI0IEZ 9A3UF UA9CAX OE3DSA RK9CWW IK5TSS K2LM W8BD HA3HP K4VX
	N8UO UR4QIN RX3RB UX7QD SP7NMW SP6CXH I0KHY IK2AHB N3FF OK1MKU
	SP5NZL OK1FPG EA8ASJ OK1AYY CT1ETT WU3A IK2MRZ OM6VV UA9IH HA0HW
	II2K NF8R RU4WE I3JTE OI2RL K4LTA SP5EKZ K8UR VO2WL W2TZ
	PY2IQ W2WSS K3KO N4IR N3TM KA1TU N3LM UA6LAK W1BIH IK2ILH
	WT1O K1RC VE1JBC WT3W K2LE N2AU KN4T DL2YD G4IFB WD2YQH
	DJ8FR K3ZA WS1E W9AU WF3J K2LP OK2HAT S51EA UN5G K2NV
	KA3VVM ZX2X OZ1HB F3TH W8BD W4IA W4TO W9LNQ WG3U EU1FC
	NY3C KC1DI N2RM N1RJF K4SI N3TCH K5KG NF2K DK5EZ TA2BK
	N2TCH I3JTE AI2C K4MF 4V2A 3G1X VP2ETB J6DX ZF2RF 8R1K
	9Y4H KC1XX K1AR W8KTQ OK2EQ W5FR CG1HA P40W NI4M K3TEJ/C6A
	TI1C LY3MR KH0DQ N1SNB K5IID WP2Z EI8NP DL0LR KD1YN K3PLV
	OK1KZ WD4AHZ WA8DXB K2MN VE3MFP VE3RT D44BC K1RV W3FG WB9AYW
	K3SWZ K5KDG VE3ST KE2WY W4CK N3RR K2WU N4MM N8ZMF K2WS
	N3II W3GG K2BU KJ5TF F6KEQ K9ALP W2XI NA2U W1GD G0KRL
	W4EF DJ2YA CP6AA CX6FM 3E1DX NG8D W3MM K3ZO W3EEE G3HQH
	W3AU WB4TDH GM0MOW K2SWZ K8MR N8JF VE2AYU UN7CW K8GM K3II
	W2EZB WA2C W1CNU AA2UT HA8EK N0XFC JA5GJS W3EVW W1TE K1DD
	KX7J VA3KA W1WFZ K5ZD K2SQ K2JLA GW3JSV W3HVN SP7ELQ W3TWI
	W2YC VA2AM W8ZT KT1H CJ3TEE N3RW W3TVB W1AX N8BJQ W4PNK
	AA3PD KA1A W1NR W2HLI W8CNL NM1Q N1TT K1HI W3GK N1AFC
	W2NCG K2PK W8UPH K8ZBY N6RFM OL3A VE3WZ OX3LK K8UCL N4NO
	KA2GSL K3ONW W0UO K2SHZ KF2O W0PA ND9O KF8TM K9CAN K4RO
	K8BCK AE8T K0RF AD1B VE3OTL KQ2M K3IE K1KI KT1E K4GN
	W3EPR W2VVS K8UPR PY2HQ W3SOH W4GBF W4VP WA1LNP KB5WT WF3M
	K8JK K2GS N4BP K9MMS NJ4F K5VR W9OO KJ9C W2AOY WA3YKI
	N2LBR W8TPS KV8S WA4ZJJ KA1O VA3GW AA2U WA2VYA NO1V K0EJ
	W2HUG VP5EA W4PA OK1NG NT8S NW7E OL2A AA6G NZ1Q K4FW/8
	WS1E 4X7A K3ONW KD6WW DL3JFN OK1JL KC1XX KA2DIV KN3P K4GEL
	WT8P SP6CPF W6DU K3LR K6DT KG0DS ND9O K3ND SP5XMM PA0ABM
	WA9LEY K9MMS KC0EI K2ZA VE5SF N3UMA AD4ZE KP3S SP3BNC N4NO
	NY3C W2II K4TWJ AA2U N4XO K1HI W9OP W5FO N5ZX N0KM
	DL2DSD W8UPH W3NO PY2NQ X51AV KC1XX XO7A VE2FF K1DD N4AF
	K2MFY N1SNB W8UD W1RH F5AIB WD5K 9A1EZA W3GK OE1NYO OY1CT
	W0TM W3DKT OM5NA N9GG WA2VQV OK2EC SM3KOR W3SOH OK2PTU W4PRO
	N3KR DL5ZB SP9RVP PZ1DV SP9HXA ZL3CW K3II LU4HH OK1GM K3KK
	WG8Y WT3P SP9PEX YO4GDP OK1ACF PI4CC K4VX DF0HQ N2FF K5ZD
	YU7AV N3RR NP4Z N2LT K3ZZ K5MA SP9SOI K1SM K1OZ W9OF
	K3KO AA3D K1KI DL3JAN DL5JRA AE8T WN9O W1BIH AA5GY HA5DQ/7
	N1AC OK1DG VE3WZ K2SX/1 9K2/YO9HP YO5CUU A71CW OK1TJ K1EFI KV4P
	K2NV HA2MJ KE4JLN AD8J F5AIL OE3DSA K1TI WB2ZZG W1AX K3AN
	NK3U OK1FBV 8P9Z HA2MJ US2WV US9KW HA2EOA EA3AJR UR5WX IK6SNQ
	F6GCP OL4M UX5UO DL8YR IK0TUM K1DOX UY4WWA UT3UY EA4ML OM3WM
	UA3UA LZ7N DK4RM OK1KSD DL3JAN HA3GE OM3EA EM7Q DF0HTE OH0JJS
	K1AM OK2DA/P OK1FAE WA4D 9A3KQ UT4NW UT7W HA6NA UE1ZJ OM8RA
	ER5GB K3LR DL8NBJ I5RFD N2FF W8JGU UT2UB K0WMT S54A OM1AW
	S52SK 9A4D W2BA F6VK RW9USA DF4ZL HA1TX N2RM K8DC 4N7A
	DK5PD OM3BT 9A2WJ IG9/I2VXJ IV3FEW OM3TU EA1PO UY5QO S53EO HAM5BPC
	OZ5ABD LY1FM YU1WR OK1XNF SP3CNP DL1DTC DL1AKZ OH0MMF DK1BA SP4BOS
	HA8PG S51UJ DL2BWG GM3YOR HG6V OH1XT SM3AHM RA3PP OK1KUO IK4MED
	VE9DH RA3DN 7X2RO IN6DCH DL0QW SP3LPR DL3JMK RW3QT DL3JAN RW4FZ
	I4FTU RA4HUQ YU1BL DL7VMM UA1AFT SP2FGO DJ6DO EI4MM OZ7BW LZ1ZF
	DL0KFM DL6CGT S57NGR HB9HQX SP2MHC DL3KVR EA6IB OK2BBQ CT3/DL5YM DL3DBY
	ON4XG PA0SNG DL7BQ UA6LQ OI3MF OZ4OC OE6HZG OK2BND DL6AG G4OIG
	UX1UA LZ6A EU5F OK1FCA OH6FW DL4FDM F5MOY UA1QV DL6MHW LY2KM
	DL8KUB OM5KP VP2EEB SP9DWT JH4CPC SM7BHM RW3FO DL1AOQ DA2OL UY5ZZ
	JS3VNC US6UN UX2VA OZ1HG F6GR OK1FHI PY0FF EW5P VK6LW OH1NOR
	OI3MF OI5N OM8A S57X DK0EFA LA8LA YU1AO OK1DKR SM0CSX CT1AOZ
	XX9X OK1KF UA3MM Z37EF DF3CB PA0RCT M6B CE3F RV6HA HB9BGI
	DL2JX RA1QN DL9XY RW1A OH7RJ DK5MV OZ5WQ UA6JAD JH7RNJ I1HJT
	RZ4AYT DL1ZQ OH5LAQ DL4UF I2VRF RK6AM DK4QT DL6UNF DL8SCO JJ1DLT
	DL9CUG F5RBG 9A3NU W1MK DL1HQE JA5QJD T99W RU3A JH1TG US2YW
	UY7P UX3IW DL0KF JA0RUG UR4PWC HB9BAT G3DLH IK1RQQ OH4YR US4EX
	RZ1AWD YL3AD OK1FKV JH1ROW G3LIK 9A3SM IK0WMT OH3MEO K3UA UT1WZ
	HA6NA RV6YZ LZ1VA G3RKJ OK2QX DL7VAF DK8FS SM5HJZ SM0BDS G3GLL
	SP5ALV YT7TY F5MPS YT0E OK1FHL 9H0A SP2QOD EC5CFQ F6CRP LY7A
	YL2ON OK1MPM T9DX DL3XG DL0AF EA8PP RZ3Q YW1A RU4WE 3V8BB
	HA8CQ OM8AA W0AIH 9A2JK IK8TPE SV1SV RN3R HA2MV UR4UF 7X2RO
	Z31AA OK2PHC HA3PT YT0X DL8WN 7Z5OO IT9AJP IK6SNQ IK0YVV ON7CC
	HAM6VA IK2AHB K3TEJ/C6A OK1BA OI3KCB SM5AOE OM3PQ UX4UA F6HNX EA5KB
	RZ3DY EA1FBJ W1WEF UY5QQ DL5ARM PA3CBA ON6CW RK6AYN F6CNN UR2CZ
	S53W K8CC DL1HSL RZ1AWT F5AKL F5JGB G3CCO DK5EZ OE3AKA EX9A
	SP8NCS US4IDY K8SSA CT1DRB DL4FMA UA9OC T94YT OK1HX G3SSO SP3NX
	RA4FW OZ5RM W1EVT RA3XD DJ1TO DK7ZH DJ7AA HA8PO IQ7A W1DEO
	EA5FV ES1QD EA7BJ UA9KW OK2DU LU1IU RV3GW UX3MF DL1NEO HA8BE
	HB9DCA V26LN HB9CAT RQ4L RZ4AYT RA3XO DL8YTM OE1A SM6NM DJ7AO
	S54E DL2AMD DF1DB G8PW PA3AFF OM3A DA8IE DK4QT G3USE G4BJM
	OK1KIR OK1PG SP3JGV SP9MOV DL1HRY OK2PCN OI2OT DL5AWI T9DX II1R
	VP5EA W1GD RK9CX KC1XX VP2EEB X5AU RW3AH YU7NU V47VJ LA9VDA
	WU1ITU FS5PL DF7CB W1NG YT0X F9OQ RU6LAZ 9A4RU W3MM K4ABX
	SP2UKB DA0KD RW6BJ IK8SMZ N2RM N1TT K1TTT N3OC LY2BM N8TR
	W9YSX UR4UGT N2LDR DA0RP KS9K K2SG SP9XCN YO8FR DL9GFB NW3H
	ZS6P W8PC DL5AJO PA3GNO DA0ES N4MM OK2PUG OM3TA AA1ON K4OF
	YT1I N4AR F4JYC 5V7A OH7NVU K5ZD N1TE EA3GHB K4DTT 9Y4H
	W1EQ K2UFT AA1V YO4WP EC3AAF W1KM K1AR UA9CAX OM3GB RK3SWX
	N2FF OL3A OK1DT KT3Y W9CS OK1KZ IK4GNM ES0NW/QRP RA1QFY WY4E
	5X4F GI4SNC EX9A WP2Z W2KA F6EIM W1QK RA9AE S53AK 3E1DX
	W4WW N2WK N3UN UX9ZX K4DY RA9LT RU4CO EW1MN SM6NM K2MP
	OK2RZ J45T K1TR OK1VD OK2ABU W1OO LY2GV HI3JH G3JKY KN4T
	N4RV J6DX K4AAA S53EO SP1FJZ EM7Q W1MR UA9XS CT1AOZ N3OS
	N4XM EA4AAF W1RH K1MO GW4BVJ W0GL W1AX SM4BNZ OK1MKI LA9GX
	SM5IMO VE3RM DL1CC S57MRG K2NV W4YE I4ZMH RV6LFE K1HI OK4QKD
	HG1G UT2QT II2K EA6IB LA2UA OK1TXB EA8AK LA2KD RN4W D44BC
	K9UWA WD8AK OM7RU S51DQ OK2EC UT5EH RW6XA LY3AV SP5ES 9A4RC
	N2RD EA5KK K3ND W3UJ EA7HDO UU5J YT1AD UP2GUC N8BJQ DL4MT
	N1JAC ZF2RF DL7USW/P DF3OL Z31JA UT0MF DL6MTA NF8R OK1DNR HB9AFH
	OH2BJG RA6AAD HA7CY UY1HY UA4CDG DL2TG UY2IZ UA6AF I3JTE EA3DA
	K2QAR HB9CDG OM6TX OK2PBG N4CC W3RJ W4RX OK2KR UT7W W1EYT
	F6FII DL2ZN Y21RM/QRP UY5AB SP5ES K3OO OK2WM HA3FTA HB9Y 8P9Z
	HG9Y F6YAR DK3ARX J39A DL3AR DL7RV W4PRO HB9ZE LA6MP OK2PMN
	K4VX N4TZ S53M F5POJ HA8KW ER3DX W4TO UA3DGA/QRP K5GN OM3BT
	K3YD K4XG DL2HQ UR7QM KQ2M OK1PFM UP5ELA DL1AMQ W6XR SM0DSF
	J87GU YL3IG S51NY UT4QT HA8DD K2SWP K2SS K2GZ UA3AGW SP2QCH
	RV3GW DJ6QT II1R K9UWA YT0E SM0DJZ UY0CA RW3VU N0NI CP6AA
	DF2PI UX4UM 9A2JK OK1FV D44BC DL8OBC G0NOA LY2FE/QRP OZ5WQ DL3BQD
	OM5DW I2FUG DL3MGK 9A5A OK1DJK SP2AOB S59A DJ3RA KP2A DF0IT
	DJ2ZS IK1GPG YT1AD OI1SJ OK1TC OK2KOD PA3BUD DL3HXX DL1UU S57U
	DL1CC F5RAB IK4BRY S53M DL1HQE DL9NDV TM2Y F5LQ F6KAR IQ4A
	PI4COM SL3ZV UR6QA LU1IV EW8WA HA9BVK CN7BK EN2H EM1KA IQ4T
	ZM2K IK0VXG RX3AMG OK2BJT HC8N K9NW EA7HAT I3BBK HA1RB HA1DKS
	OEM1KYW HA0IT HA6NL DL0ER P40W OH1KAG TF50IRA OH8BQT DK5IM OI6YF
	9Y4H TA3D RV6LFE RK9CWY RW3QT RA4HVQ UA4UU RK3MWU HG5A HA6NF
	SP8HXN UT4UH HA2SX LZ2ZA 9X4WW S51DF OI2GB 3C5A EX9A YU7BJ
	YL2TW YU1ZD HA3OU IK6MNB SP5FLB UX1KR RK6AYN OK2AJ 4N7CA JA3DEO
	RW3BW ON4AUC LZ1BJ SV1SV OH0JJS UT7L OH1NOR HG5M DL0VM EA4ML
	UK7F VU2MTT US1E YL8M HS0AC UR4E 5X4F YB0ASI HK6KKK RA6LW
	ES5Q SV1SV RN6BZ UA3IAK US4EX RK3FM HB9DX RW6MW RA3DJA LY2BKT
	IK1ZOD UA9AOL SP9JCN 3Z6RF ZC4EE YT7A OK1PR ZB2EO YZ1AA OK1FPS
	IK4HLQ HG6Y DL7UWL OH2BN OK2QX RU6LWZ SM4TU S57XX PY2WA DL3JAN
	S50O CN8BK TF50IRA D44BC S58A ER0F GI0SAP CT9U PY2TI ON6KW
	S50U JO1YAO EA2CLU UX2IJ LA8PF UY5WA UA0SAU RA0SS UR4UF EA5DNO
	S51EC YU1GC HL1CG ES7FU HB9AMZ UT5UN I0WBT OI6NEV UX5TT 9A4DU
	UR5MTA IV3DRP UK8AAZ S51NP RU4WE S51WP UA1PAC DF4SA LY3KB OK2BJT
	F5IJP I5LHY HA7MB OM4TC EW2DD US4LWM RU0SU S59AV OK2PBG OH6FW
	UA0KL/6 RW3BK UY4E UA2CZ HA5FA JH6V S57T OK2XTE IT9AJP HB9ZE
	OH8NLC GW3VVU OK1VD UA3TAH YU1YE RV3ZD YU1LM/QRP RA3VA RU9CI I2OGV
	LY2BWJ IK3TXK 8S0FRO T94VA PA3CNK SP2AP UN7FW RW3VM OK2BND RA2FZ
	RA4UU OH1BJJ UA3LIZ/QRP EA2CR RA1TU RA1QN G3IGU 9A3ZO S41AFA RX3DTN
	OL2A EA3ADS OK2KOD RA4UU UR4GH 9U5DX LY1FM HA7QI DF7TU HAM4FB
	OH5LP/4 YL2TW OH7NVU SM5BUH JH5ZJ UK4K OE6HZG RA6LAE RW4FX YB5YZ
	I3TXQ OK2PHC LY2OX SM5HJZ RA3BN YO8FR UA1AC RA3VY OM3GB EW2CR
	UA9OA UA2WV SP6SYF PY2SP OH6MM OH1XT RN9XA OM1AF RX9JC SP5ELA
	8S0FRO OH4YR YU7LA UR5MBB IS0URA OH1MYA SQ6EPL UA1OMZ YB5QZ UX5UO
	UT5UML UA1AIR ER0F UT7EG HA7YS IV4CK RK3AY VK2AYD HA2SX VU2PAI
	UX8ZA I8BIO CT3/DL5YM RW9OWD HZ1HZ SP2GUV UA4YJ OH8LC EW4AM YT1AD
	WB2P N1AFC HA3JB DL8NBJ YO8DQ I2BAD YO6BA UY2MQ IK0XGI YL2MR
	SP5ICS F6BQY W1NG EA3BOW S41JA ER2WDK DJ9MH YB1AQS 3C5A OI1HS
	KT3Y LY3BA RA9DG RA9XF GM3DZB WA1LNP EA1AK/7 HB9HQW JA3YFG UN8FB
	YL2UZ SM0DJZ SM3USM OH2MO RZ3TZL RZ9SIP 9X4WW LZ1FJ UA9EJ SM0TGG
	K1VR RN4W SK6FM RX9CAO K1MO WT1O SP2FWC/P SP2JGK K2ONP NO2T
	NA3AQ F6DDR W1OO UT2UB OM6TC K2SG RA9JW YO4GHW HA3LI W1EQ
	AA4S AA4S LY3MR N3AF I3BBK OM3RRC VK3AMK RX4CT W1EYT S59D
	GM3CFS UA4ZA W0VU NA2U VE2ETY VE2AYU CT3FT EA4AAF SP2UKB W3LPL
	NA2Q N3OSY OY1CT W1UU W4IS HA7CY SM0BDS N2ED K1NO ZP6VT
	WA2YSJ VE3XN EC8AUZ UA9SGN K4UK W2KA K9QVB UT3LL I6NOA UA1ADQ
	WA8CLT KE3C N4PN WA2VYA DJ4TPT N1DIQ UA3RO EM1KA SP9RTI EA8AMW
	W4AFS VE3ST KT2E UX8IX RA3DJA HA8DD WA2VRF K5YAA IK0DWJ W3CP
	RA4JUF W4JHO W8PC W3EA S51TB N4ONI 8P9Z UA9CAX K5SBU K4ZI
	K8SWE W3DKT W3AU AC4PQ K0EJ WB3AAL W2YC AA1HB NP4Z W4/G4BKI
	N4YDU KB3TS KL7HIL EW3EO K4RO K2TR KC3M LY2FN UR2SOU W4ZYT
	K9UQN W9IL S59PA K2DYB K4RZ KS1L UA3DEV PY8JA K8GT RA4PI
	N3AM 9A3GU DK6OR K4QD AC4Q WB9SRO N3TG KC4PN PR7FB W5HJ
	AA8OY S51CA KC8EG W8AV DK4SY K2PH N2RM W9OA SM4TRE RK4HWZ
	N2FX ZW2A RA1ZF UT8IM N3AM N3EN W9NTU F5PLC PI4TUE ZF2RF
	KM1X W2UP K8SWE DL7MAS N1ET W1OO WB2RRJ OH1BZ W9XT W8FDV
	N2ED KS9U W3AG KS9K OK3KOD JY8B WB4UBD KS9Z NE1V KS1L
	K1AE W1RR RZ3BW WT3P CI2AWR K2JL K2TE W1QJR RK3DM W4BXI
	KT4GU W9MHE W3LPL SV1CAL W9GIL F5OEV K9RN K0HT W8PC KD9NMU
	W5ZO WA4BPL U5MZ N1DCM N2CTL N3NT W2FXA N2WK KA2CCU WD3AAL
	LU5UE WA1YLP W4WN WA3SLN K3KY W3KV KC2X KA1CLV N4KW AJ3K
	N1RCT PY3CJI DL1AV K3ND N3UN PY1KN N3LFC W8KJP G0CFQ KA5W
	NN3Q KB3TS N4ZJ N2JT W5KN NG9J N5DX NE3F WA4IKZ K3LR
	N3MKZ K3CP W2YE LU9EDY K1VSJ WM9X KA2HTU K5YAA KB2NU NG3O
	N4UU N3OC W1RH WA4JUK N1CC N4VV N8AA N2BA NR0X KK4QD
	G4BJM W3HR K4WA W3VT N4AF N2OO KF2O AA3JU W1RFW AA4EL
	KL7HIR VE2AYU PI4GLD N2JJ KD4FAZ W3AP N1SOH W1EQ YV5JDP K8CW
	AB2E N8ET K3DI W3AZ W3TA K9MA N2CQ WA2DKJ LU3WEU J87GU
	WA1R G6D K4FPF W8QKQ J39A WB2KDD KS7T KK4UP K2WM K2LU
	WA8YRS W2FXA W3SOH W1EM K8CV EI9UK AC5HF N3NT KA1CZF FS5PL
	K7NW K9PPW K2AW YU2ZZ W4MYA F6DKV K8HO VE3RM PY4DHG K6YK
	W9KN/7 W6NL W0ML EA5AGW WR3L K6JG G0ATR V26LN K6UT KJ9C
	W0AIH K0HB KC9TV G5LP K4FPF VE3JC AA9AT W2HCA N3KRN EA7BJ
	W4NF N3FZ N2CQ W2EZB W3HR K2FU K6ATV KJ9O W1NR K7LJ
	9Y4KB CT1DRB 6W1AE WB2ZMK I0ZUT N6AO W4YDD K2BU VO1SA K2DB
	W2UP HC8N WD3PM W7OO N3OC K1TH N4ZJ NE3F WA4JUK OK1BXE
	W1NMB EA9IU VO1GO EA1AB W1CX K9JD K7ADV NJ2L NO1V K2VV
	W4OX W7NF G4LRO W6OAT WB6BD NR1F K4NA WA8SAE 5V7A K5IID
	WD6Z WX8T K2TW W8TA W2QIP NF4Y ND5S PY2SQ K8EJ VA2EE
	AE2N EA1GT K1RC K4RDU W3UJ LU1DZ W3EVW NG2V K2OPJ LU3FSP
	OT6P WA2HZO K3CP W3GU N8ET N2MM ZW2Z AA8E W7NN WB6A
	K7FR K2UUT W5UDA WA8WV LW5EWQ W7RG N3AD YT7A 9A4DA HA8LKB
	II1R RA6AR YU7FY K1KI LY7A SM4CFL 9A1EMA OH4OC A1TT 9A1EZA
	HA0EQ SM6DER SM0BDS LY5W YU1L EU5F 6Y6A EC5FCQ OZ8AE IS4AA
	OK1VD HA8DM HA8FW UA1QBE YL2GN UR7TA HB9GCD OH2BNH DK4QT J39A
	HG9G ZZ2E 8P9Z RU4SP EA9UG 9A2XJ YO3BWK HZ1HZ VU2MTT RZ3BYN
	RU6AR OI3JF LA9SKI YO3AWJ OK2SI RW1ZZ OI6MI DK5MV RU6LWZ SV2BBJ
	VK3APN DF3IAL YT1ADY OH2BJG DJ3XG OM8AU OK2QX IK8UDV S51EA IK6OIN
	OK2PO RA6FV W3EA SP5HPA DL9GCG N4CW KB2JOI K4AMC W2HDW W9CC
	W4LM KM2L K7ZI N8WXQ W4IF K9CAN LW2DFM LH0I KO9Y W4RC
	N3KCJ GD4UOL W2AXZ LW2ESE WA4FTM K5SI PY2BW VE1GZV WA5SOG VE1AI
	6W1AE N8YYS WD4AHZ N4AR W8ILC W3QIR VE1NB NF9V NI5S LU7EAR
	AF5Z VE2AYU KW2J K0SW W8RSW WF3J LU2YA WI6E/1 N3RW AA2FB
	UX5DW S50A UX1BZ YU7SF NF8L HA8TP NF1R NF8R HA5DQ S53BB
	N4HF DL8HCO DL2ZN K3ANS WP2Z OK1AOV YO2BBX SP7GIQ WT3W YO4DKF
	W3EEE 4V2A DL4BQE/P OK1YM DF3SD SP5CCC N0GG W3RPL DJ4PT DL6UNF
	W3AP SM5IMO RA2FZ HAM0NAP AA1HB RU6FZ W8WW K2SWP NL1AKZ W2RQ
	HA9HH OM3A DL3DRN S58DX UR3IOB DF6NV DL9SX DK5OS YU7CF IK3SUG
	IK4EWX I5VVA RU3QE LZ1KNP DK4WD SP1AEN DL4FMA 9A4AA RW4WY SL3GV
	UT5US SP6CYX DL3DQL LA9MB OH1BV DL1HQV DL3GGT DL6AG DL1AOQ DF2HL
	DF1DV N3OC LA1K RZ3AM DL7ANR SK5AA W1OO SP4GHL 4Z9A OZ5WQ
	UU5J XZ1N W8PX DL7UKA PA3ECJ DJ5OW RV6AF YU7WJ K2BU DL2GBB
	G5LP EA1FBJ K5KG WW3S DL5JRA WI1E T94GB OZ5ABD RV3GW K4DY
	HA1AG RX3AP DF0DF DL1VTL S51CA RA3DJA W1BIH HA1CW RK4WWA UA4SMM
	DK3GI W0HW N4XR IT9ORA DJ2YH N2RDR K2TS 9A3GO DL2SRN DL7VZF
	DL7QU J87GU DK8FS UU4JA CW5W EM1KA DL3OAU RV3LU K1VR V47VJ
	DL1JF DL9MA SK6FM EW7LO US3IZ DL9OCI RN3RA DK3YD YU7EA DL6NW
	4Z4DX HA9SB K2NV G3JTO W4IX K5ZD OL2A YO4WP W3GU W4SM
	WA1PFC W4HM W3TMZ HA5AF GU3HFN IK2AHB N4ZR YB1AQS OZ1SX A71CW
	UY7P HA9PB DL2MA OM4DN G0KRL UN8FB DL8OBC RN4W S58A RW4AA
	SP6CPF DL1SNO RW6FS OL7A IV3OQR RW3DW HA5JP UA6XGL/3 HA6NF K8JK
	I0ZUT WA1ITU HA1FU KA2HMJ OE1A DL7CF N4KDU OL3A IK9YUJ IV3TQE
	RW6AWT IN2B NP9DA J45T OH2BDP G4IUZ LZ9A ES4AA IV3WRK RU4IAN
	SP5CTY G3GIQ F6EZV EA3CA DK3YD IK6BAK G3OCA UA9WZ UY4E HC8N
	SP2SPB K9AWC EU5F W3DA W3LPL 3V8BB N3JFF F5RO IS4AA GM3CIX
	VE3DW HA6NF HA3MY SM3EVR DK0NT DL7VOX WV1C RA4HT VE3WT UA4YG
	UN6P S57U SM7MS HB9QA YZ1AU YU7FN OK2RU NP4Z G0HGA DL6NBY
	DL6FDB DL6MBA YT7YA
    }
}

#
# the list of callsigns from pileup
#
proc morse-pileup-callsigns {} {
    return $::morse::callsigns::calls
}

