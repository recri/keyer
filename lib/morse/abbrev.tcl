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
# miscellaneous abbreviations, unabbreviated words, used in morse code operation
#

package provide morse::abbrev 1.0.0

namespace eval ::morse {}
namespace eval ::morse::abbrev {
    # prosigns with translations
    # prosigns are procedural signals, some of which are characters concatenated
    # with no letter spacing between them, others of which are characters sent
    # with normal letter spacing.  <xy> indicates a concatenation of x and y with
    # no space, xy indicates x followed by y with normal spacing.
    set prosigns [dict create {*}{
	<AR> {End of message}
	<AS> {Stand by}
	<BK> {Invite receiving station to transmit}
	<BT> {Pause; Break For Text}
	<CL> {Going off the air (clear)}
	<CQ> {Calling any amateur radio station}
	<DO> {Switch to Wabun from ITU}
	<K> {Go, invite any station to transmit}
	<KA> {Beginning of message}
	<KN> {Go only, invite a specific station to transmit}
	<KN> {end of transmission}
	<R> {All received OK}
	<SK> {End of contact (sent before call)}
	<SN> {Switch to ITU from Wabun}
	<VE> {Understood (VE) }
    }]
    set milprosigns [dict create {*}{
	<AA> {Unknown station}
	AA {All after}
	AB {All before}
	<AR> {End of transmission}
	<AS> {Wait}
	B {More to follow}
	<BT> {Long break}
	C {Correct (or correction)}
	CQ {May be used as ALL station call when no other call sign available}
	DE {From}
	<EEEEEEEE> {Error}
	F {Do not answer}
	FM {Originators designator follows}
	G {Repeat back}
	GR {Group count}
	GRNC {Groups not counted}
	<HM> {(three times) Emergency Silence}
	II {Separative sign}
	<IMI> {Repeat}
	INFO {Information addressee(s) designator(s) follow}
	<INT> Interrogative
	<IX> {Execute to follow}
	<IX> {(5 second dash) Executive signal}
	J {Verify with originator and repeat}
	K {Invitation to transmit}
	NR {Number}
	O {Immediate}
	P {Priority}
	<PT> {Call sign follows}
	R Receipt
	R Routine
	T {Transmit to}
	TO {Action addressee (s) designator(s) follow}
	WA {Word after}
	WB {Word before}
	XMT {Exempted addressee(s) designator(s) follow}
	Z Flash
    }]
    # Q codes with translations, from http://ac6v.com/morseaids.htm
    set qcodes [dict create {*}{
	QRA {What is the name of your station? The name of my station is ___.}
	QRB {How far are you from my station? I am ____ km from you station}
	QRD {Where are you bound and where are you coming from? I am bound ___ from ___.}
	QRG {Will you tell me my exact frequency? Your exact frequency is ___ kHz.}
	QRH {Does my frequency vary? Your frequency varies.}
	QRI {How is the tone of my transmission? The tone of your transmission is ___ (1-Good, 2-Variable, 3-Bad.)}
	QRJ {Are you receiving me badly? I cannot receive you, your signal is too weak.}
	QRK {What is the intelligibility of my signals? The intelligibility of your signals is ___ (1-Bad, 2-Poor, 3-Fair, 4-Good, 5-Excellent.)}
	QRL {Are you busy? I am busy, please do not interfere}
	QRM {Is my transmission being interfered with? Your transmission is being interfered with ___ (1-Nil, 2-Slightly, 3-Moderately, 4-Severly, 5-Extremely.)}
	QRN {Are you troubled by static? I am troubled by static ___ (1-5 as under QRM.)}
	QRO {Shall I increase power? Increase power.}
	QRP {Shall I decrease power? Decrease power.}
	QRQ {Shall I send faster? Send faster (___ WPM.)}
	QRR {Are you ready for automatic operation? I am ready for automatic operation. Send at ___ WPM.}
	QRS {Shall I send more slowly? Send more slowly (___ WPM.)}
	QRT {Shall I stop sending? Stop sending.}
	QRU {Have you anything for me? I have nothing for you.}
	QRV {Are you ready? I am ready.}
	QRW {Shall I inform ___ that you are calling? Please inform ___ that I am calling.}
	QRX {When will you call me again? I will call you again at ___ hours.}
	QRY {What is my turn? Your turn is numbered ___.}
	QRZ {Who is calling me? You are being called by ___.}
	QSA {What is the strength of my signals? The strength of your signals is ___ (1-Scarcely perceptible, 2-Weak, 3-Fairly Good, 4-Good, 5-Very Good.)}
	QSB {Are my signals fading? Your signals are fading.}
	QSD {Is my keying defective? Your keying is defective.}
	QSG {Shall I send ___ messages at a time? Send ___ messages at a time.}
	QSJ {What is the charge to be collected per word to ___ including your international telegraph charge? The charge to be collected per word is ___ including my international telegraph charge}
	QSK {Can you hear me between you signals and if so can I break in on your transmission? I can hear you between my signals, break in on my transmission.}
	QSL {Can you acknowledge receipt? I am acknowledging receipt.}
	QSM {Shall I repeat the last message which I sent you? Repeat the last message.}
	QSN {Did you hear me on ___ kHz? I did hear you on ___ kHz.}
	QSO {Can you communicate with ___ direct or by relay? I can communicate with ___ direct (or by relay through ___.)}
	QSP {Will you relay to ___? I will relay to ___.}
	QSQ {Have you a doctor on board? (or is ___ on board?) I have a doctor on board (or ___ is on board.)}
	QSU {Shall I send or reply on this frequency? Send a series of Vs on this frequency.}
	QSV {Shall I send a series of Vs on this frequency? Send a series of Vs on this frequency.}
	QSW {Will you send on this frequency? I am going to send on this frequency.}
	QSY {Shall I change to another frequency? Change to another frequency.}
	QSZ {Shall I send each word or group more than once? Send each word or group twice (or ___ times.)}
	QTA {Shall I cancel message number ___? Cancel message number ___.}
	QTB {Do you agree with my counting of words? I do not agree with your counting of words. I will repeat the first letter or digit of each word or group.}
	QTC {How many messages have you to send? I have ___ messages for you.}
	QTE {What is my true bearing from you? Your true bearing from me is ___ degrees.}
	QTG {Will you send two dashes of 10 seconds each followed by your call sign? I am going to send two dashes of 10 seconds each followed by my call sign.}
	QTH {What is your location? My location is ___.}
	QTI {What is your true track? My true track is ___ degrees.}
	QTJ {What is your speed? My speed is ___ km/h.}
	QTL {What is your true heading? My true heading is ___ degrees.}
	QTN {At what time did you depart from ___? I departed from ___ at ___ hours.}
	QTO {Have you left dock (or port)? I have left dock (or port).}
	QTP {Are you going to enter dock (or port)? I am going to enter dock (or port.)}
	QTQ {Can you communicate with my station by means of the International Code of Signals? I am going to communicate with your station by means of the International Code of Signals.}
	QTR {What is the correct time? The time is ___.}
	QTS {Will you send your call sign for ___ minutes so that your frequency can be measured? I will send my call sign for ___ minutes so that my frequency may be measured.}
	QTU {What are the hours during which your station is open? My station is open from ___ hours to ___ hours.}
	QTV {Shall I stand guard for you on the frequency of ___ kHz? Stand guard for me on the frequency of ___ kHz.}
	QTX {Will you keep your station open for further communication with me? I will keep my station open for further communication with you.}
	QUA {Have you news of ___? I have news of ___.}
	QUB {Can you give me information concerning visibility, height of clouds, direction and velocity of ground wind at ___? Here is the information you requested...}
	QUC {What is the number of the last message you received from me? The number of the last message I received from you is ___.}
	QUD {Have you received the urgency signal sent by ___? I have received the urgency signal sent by ___.}
	QUF {Have you received the distress signal sent by ___? I have received the distress signal sent by ___.}
	QUG {Will you be forced to land? I am forced to land immediately.}
	QUH {Will you give me the present barometric pressure? The present barometric pressure is ___ (units).}
    }]
    # commonly used Q codes in amateur radio
    set hamqcodes { QRL QRM QRN QRS QRT QRZ QSB QSL QSO QSY QTH QRX }
    # common cw abbreviations in amateur radio
    # from http://ac6v.com/morseaids.htm and other sources
    set abbrev {
	/ST
	161 30 33 55 73 88
	+ & = ? /
	AA AB ABT ADEE ADR ADS AGN AM ANI ANS ANT
	B4 BCI BCL BCNU BD BEAM BK BN BTH BTR BTW BUG BURO
	C CB CBA CFM CK CKT CL CLBK CLD CLG CMG CNT CONDX CPI CPY CQ CRD CS CU CUAGN CUD CUL CUM CUZ CW
	DA DE DIFF DLD DLVD DN DR DSW DWN DX
	EL ENUF ES EU EVE
	FB FER FM FONE FQ FREQ FWD
	GA GB GD GE GESS GG GLD GM GN GND GP GS GUD GV GVG
	HI HPE HQ HR HRD HRD HRS HV HVG HVY HW
	II INFO
	JA
	K KA KLIX KN
	LID LNG LOOP LP LSN LTR LV LVG LW
	MA MGR MI MILL MILS MNI MOM MSG MULT
	N NCS ND NIL NM NR NW
	OB OC OK OM OP OPR OT OW
	PBL PKG PKT PSE PT PWR PX
	R RC RCD RCVR RE REF RFI RIG ROTFL RPT RST RTTY RX
	SA SAE SASE SED SEZ SGD SHUD SIG SINE SK SKED SN SP SRI SS SSB STN SUM SVC SWL
	T T/R TEMP TEST TFC TIA TKS TMW TNX TR TRBL TRIX TRX TT TTS TU TVI TX TXT
	U UFB UNLIS UR URL URS
	VE VERT VFB VFO VY
	W WA WATSA WATT WB WD WDS WID WKD WKG WL WPM WRD WRK WUD WW WX
	XCVR XMAS XMTR XTAL XYL
	YAGI YF YL YR YRS
	Z
    }
    
    # Pages 78-104 of https://web.archive.org/web/20150227075623/http://phonetic.org.au/Codes3.pdf downloaded 2020-05-19
    # extensive list of 1, 2, 3, and longer letter abbreviations often with multiple meanings.
    # some are very nice WTG = waiting, ENIBDI = anybody, SUMBDI = somebody 
    # what's here is a combination of ac6v.com/morseaids.htm above and the summerland list, most of the summerland list
    # is over
    # /ST {short timer on check in}
    # T/R {}
    # <AA> {end of line}
    # <AR> {end of message}
    # <AS> {stand by, wait}
    # <AT> {@ sign?  I don't think so}
    # <BT> {separation between address and text, between text and signature}
    # <HH> {error in sending}
    # <II> {short for <HH>}
    # <IMI> {repeat, say again}
    # <SK> {out, clear }
    set summerland [dict create {*}{
	AA {all after}
	AB {all before}
	ABT {about}
	AC {alternating current}
	ADEE {addressee}
	ADR {address}
	ADS {address}
	AF {audio frequency}
	AGN {again}
	AM {amplitude modulation}
	ANI {any}
	ANS {answer}
	ANT {antenna}
	AZ {azimuth}
	BCI {broadcast interference}
	BCL {broadcast listener}
	BCNU {be seeing you}
	BD {bad, buenos dias, board}
	BG {bearing}
	BK {break, back, break in}
	BN {been}
	BT {but}
	BTH {both}
	BTW {by the way}
	BUG {vibroplex key, semi-automatic key}
	BURO {bureau, QSL bureau}
	BW {bandwidth}
	B4 {before}
	C {correct, yes, concour, can, see, celsius, cnts}
	CB {callbook, citizens band}
	CBA {callbook address}
	CFM {confirm, I confirm}
	CK {checknb}
	CKT {circuit}
	CL {call, calling, called, closing}
	CLBK {callbook}
	CLD {called, could}
	CLG {calling}
	CMG {coming}
	CN {can, seen}
	CNT {cannot}
	CNDX {conditions}
	CPI {copy}
	CPY {copy}
	CQ {general call}
	CRD {card}
	CS {call sign}
	CT {cannot}
	CU {see you}
	CUAGN {see you again}
	CUD {could}
	CUL {see you later}
	CUM {come}
	CUZ {because}
	CW {continuous wave, clockwise}
	CY {copy}
	DA {day, yes (Russian)}
	DD {did}
	DE {from}
	DIFF {difference}
	DLD {delivered}
	DLVD {delivered}
	DN {down}
	DR {dear}
	DSW {see you again (Russian)}
	DT {do not}
	DWN {down}
	DX {distance}
	EA {each}
	EL {element}
	ENI {any}
	ENIBDI {anybody}
	ENUF {enough}
	ES {and}
	EU {europe}
	EVE {evening}
	EZ {easy}
	FB {fine business}
	FER {for}
	FM {frequency modulation}
	FONE {phone}
	FQ {frequency}
	FREQ {frequency}
	FU {few}
	FWD {forward}
	GA {good afternoon, go ahead}
	GB {good bye}
	GD {good, good day}
	GE {good evening}
	GESS {guess}
	GG {going}
	GL {good luck}
	GLD {glad}
	GM {good morning}
	GN {good night, gone}
	GND {ground, relative to ground}
	GP {ground plane}
	GS {green stamp, guess}
	GT {got, get}
	GUD {good}
	GV {give}
	GVG {giving}
	HD {had}
	HF {high frequency}
	HI {laughter}
	HPE {hope}
	HQ {headquarters}
	HR {here, hear, hour}
	HRD {heard}
	HRS {hours}
	HS {has}
	HV {have}
	HVG {having}
	HVY {heavy}
	HW {how. how copy}
	HZ {hertz}
	IC {I see}
	ID {identification}
	II {I repeat}
	INFO {information}
	JA {japan}
	K {go ahead, invitation to transmit, over}
	KA {beginning of transmission}
	KG {kilogram}
	KLIX {key clicks}
	KM {kilometer}
	KN {addressed station only transmit, left hand bracket}
	KW {know, kilowatt}
	LB {pound}
	LF {low frequency}
	LID {a poor operator}
	LNG {long}
	LOOP {loop antenna}
	LP {long path}
	LSN {listen}
	LTR {later, letter}
	LV {leave}
	LVG {leaving}
	LW {long wire, long wave}
	MA {milliampere}
	MF {medium frequency}
	MGR {manager}
	MI {my, mile}
	MILL {typewriter}
	MILS {milliamperes}
	MK {make, mark}
	MNI {many}
	MOM {moment}
	MSG {message, prefix to radiogram}
	MT {empty}
	MULT {multiplier}
	N {no, negative, incorrect, no more, nine}
	NCS {net control station}
	ND {nothing doing}
	NF {noise figure}
	NG {no good}
	NH {nothing heard, not at home}
	NIL {nothing, I have nothing for you, not in log}
	NM {no more}
	NO {know, number, negative}
	NR {number, near}
	NT {not}
	NU {new, knew}
	NW {I resume transmission, now, north west}
	OB {old boy}
	OC {old chap}
	OK {we are in agreement}
	OL {old lady}
	OM {old man}
	OP {operator}
	OPR {operator}
	OT {old timer, old top, on time, oscillation transformer}
	OW {old woman}
	PA {power amplifier}
	PBL {preamble}
	PKG {package, parking}
	PKT {packet}
	PM {post meridian}
	PSE {please}
	PT {point, address group or callsign follows}
	PWR {power}
	PX {press, prefix}
	QK {quick}
	R {are, all right, okay, receipt, routine, roger, romeo, received ok}
	RC {rag chew}
	RCD {received}
	RCVR {receiver}
	RD {read, red}
	RE {concerning, regarding}
	REF {refers, refer to, referring to}
	RF {radio frequency}
	RFI {radio frequency interference}
	RIG {station equipment or setup}
	RM {room}
	ROTFL {rolling on the floor laughing}
	RPT {repeat, I repeat, report}
	RR {repeat}
	RST {readability-strength-tone}
	RT {right}
	RTTY {radio teletype}
	RX {receiver}
	SA {say}
	SAE {self-addressed envelope}
	SASE {self-addressed stamped envelope}
	SB {sideband}
	SD {said, should}
	SED {said}
	SEZ {says}
	SGD {signed}
	SHUD {should}
	SIG {signature, signal}
	SINE {operators personal initials or nickname}
	SK {silent key}
	SKED {schedule}
	SL {see you later, shall}
	SM {some, same}
	SN {soon, seen, signal/noise, station, understood}
	SP {short path, speed, silence period, important message}
	SRI {sorry}
	SS {send slower, sweepstakes, solid state}
	SSB {single sideband}
	SU {see you}
	SUM {some}
	SUMBDI {somebody}
	SVC {service}
	SW {short wave}
	SWL {short wave listener}
	SX {simplex}
	T {I understand, the, zero }
	TEMP {temperature}
	TEST {testing, contest}
	TFC {traffic}
	TIA {thanks in advance}
	TK {take}
	TKS {thanks}
	TMW {tomorrow}
	TN {then}
	TNX {thanks}
	TR {there, their, transmit}
	T/R {transmit/receive}
	TRBL {trouble}
	TRIX {tricks}
	TRX {transceiver}
	TS {this}
	TT {that}
	TTS {that is}
	TU {thank you}
	TV {television}
	TVI {television interference}
	TX {transmit, transmitter}
	TXT {text}
	TY {they}
	U {you}
	UFB {ultra fine business}
	UL {you will}
	UM {grunt}
	UNLIS {unlicensed}
	UP {upward}
	UR {your, you're, you are}
	URL {uniform resource locator}
	URS {yours}
	UT {universal time}
	VE {commencing sign, general call, message for you}
	VERT {vertical}
	VFB {very fine business}
	VFO {variable frequency oscillator}
	VY {very}
	W {go on, word, west, watt}
	WA {word after}
	WATSA {what say}
	WB {word before}
	WD {would, word}
	WDS {words}
	WF {word following}
	WH {white}
	WI {why, will, with}
	WID {with}
	WK {weak, week, work}
	WKD {worked}
	WKG {working}
	WL {will, would, well}
	WPM {words per minute}
	WN {when}
	WO {who}
	WR {were, where}
	WRD {word}
	WRK {work}
	WS {was}
	WUD {would}
	WW {would}
	WX {weather}
	XCVR {transceiver}
	XMAS {Christmas}
	XMTR {transmitter}
	XO {crystal oscillator}
	XTAL {crystal}
	XS {atmospherics}
	XYL {wife}
	YD {yard}
	YF {wife}
	YL {young lady}
	YR {year, your}
	YRS {years}
	Z {zulu time}
    }]
    # the commonly used morse code alphabet in amateur radio
    # from several places
    set ham {
	{+} {,} {-} {.} {/}
	{0} {1} {2} {3} {4} {5} {6} {7} {8} {9}
	{=} {?}
	{A} {B} {C} {D} {E} {F} {G} {H} {I} {J} {K} {L} {M} {N} {O} {P} {Q} {R} {S} {T} {U} {V} {W} {X} {Y} {Z}
    }
    
}

proc morse-qcodes {} { return $::morse::abbrev::qcodes }
proc morse-ham-abbrev {} { return $::morse::abbrev::abbrev }
proc morse-ham-qcodes {} { return $::morse::abbrev::hamqcodes }
proc morse-ham {} { return $::morse::abbrev::ham }
proc morse-abbrev-prosigns {} { return [dict keys $::morse::abbrev::prosigns] }
proc morse-abbrev-milprosigns {} { return [dict keys $::morse::abbrev::milprosigns] }
proc morse-abbrev-summerland {} { return [dict keys $::morse::abbrev::summerland] }
