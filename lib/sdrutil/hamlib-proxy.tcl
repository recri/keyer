# -*- mode: Tcl; tab-width: 8; -*-
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
# provide a hamlib-proxy which processes hamlib net rigctl commands
# over socket connections and translates them into commands in an
# arbitrary language over an arbitrary transport.
#
# our primary arbitrary language and arbitrary transport will be dbus
# properties over dbus, built up elsewhere.
#
# the translation is built up by telling the proxy what it can do
# the proxy maintains the overall idea of what can be done and responds
# to the netlib dump_caps and get_info commands appropriately
#

package provide hamlib-proxy 1.0

package require snit

#
# a few puzzles about hamlib
# 1) VFO mode appears to modify every command to take a VFO argument
# which allows you to specify a different radio for each VFO.
# 2) Transceive mode probably has to do with radios spontaneously reporting
# meter readings or such, but I haven't found an explanation or example.
# 3) ...
#

namespace eval ::hamlib-proxy:: {
}

# a type for describing the values which a hamlib property can take
# a few favorites and then many customized radio button sets
snit::type ::hamlib-proxy::value-set {
    option -values
    constructor {args} {
	$self configure {*}$args
    }
    method is-valid {value} {
	switch -glob $options(-values) {
	    integer { return [string is integer -strict $value] }
	    float { return [string is double -strict $value] }
	    unit-interval { return [expr {[string is double -strict $value] && $value >= 0.0 && $value <= 1.0}] }
	    number { return [string is double -strict $value] }
	    * {
		if {$value in $options(-value)} {
		    return 1
		}
		if {[llength $options(-value)] < 2} {
		    error "no values in $options(-value)"
		}
		return 0
	    }
	}
    }
}

# a type for describing the hamlib commands that the proxy might know
# how to do.  Hmm, the level/func/parm commands should be sub-commands,
# "set_level CWPITCH" and "get_level CWPITCH" need to be separate so
# the other side can bind to them.
# not to mention the extra level/func/parm commands that the backend might
# add.

snit::type ::hamlib-proxy::command {
    option -name
    option -short-name
    option -get-name
    option -short-get-name
    option -set-name
    option -short-set-name
    option -param
    option -values
    option -enable -default 0
    option -function
    option -get-function
    option -set-function
    option -min {}
    option -max {}
    option -step {}
    option -limits {};		# (0..0/0) format (min..max/step)

    constructor {args} {
	$self configure {*}$args
    }
    method perform {args} {
	if {$options(-function) ne {}} {
	    return [$options(-function) {*}$args]
	} else {
	    return "RPRT 11"
	}
    }
    method set {args} {
	if {$options(-set-function) ne {}} {
	    return [$options(-set-function) {*}$args]
	} else {
	    return "RPRT 11"
	}
    }
    method get {args} {
	if {$options(-get-function) ne {}} {
	    return [$options(-get-function) {*}$args]
	} else {
	    return "RPRT 11"
	}
    }
    method eval {command args} {
	puts "[clock milliseconds] eval {$command} {$args}"
	if {$command eq $options(-get-name) || $command eq $options(-short-get-name)} {
	    if {$options(-get-function) eq {}} {
		return "RPRT 7"
	    }
	    return [{*}$options(-get-function) {*}$args]
	}
	if {$command eq $options(-set-name) || $command eq $options(-short-set-name)} {
	    if {$options(-set-function) eq {}} {
		return "RPRT 7"
	    }
	    return [{*}$options(-set-function) {*}$args]
	}
	if {$command eq $options(-name) || $command eq $options(-short-name)} {
	    if {$options(-function) eq {}} {
		return "RPRT 7"
	    }
	    return [{*}$options(-function) {*}$args]
	}
	return "RPRT 7"
    }
}

snit::type ::hamlib-proxy::proxy {
    variable names -array {}
    variable commands -array {}
    variable valuesets -array {}
    variable connection -array {}

    option -port 4532
    option -modes {}
    option -filters {}
    option -bandwidths {}
    option -tuning-steps {}

    constructor {args} {
	$self init
	$self configure {*}$args
    }

    method init {} {

	# initialize the hamlib value sets - these should be snit types
	# AM CW USB LSB RTTY FM WFM CWR RTTYR
	$self value-set mode {AM AMS CW CWR DSB ECSSLSB ECSSUSB FAX FM LSB PKTFM PKTLSB PKTUSB RTTY RTTYR SAH SAL SAM USB WFM}
	$self value-set vfo {VFOA VFOB VFOC currVFO VFO MEM Main Sub TX RX}
	# these appear to be octal numbers, sometimes written with leading 0's, too
	$self value-set dcs-code {
	    6	 50	 125	 174	 255	 343	 445	 526	 703
	    7	 51	 131	 205	 261	 346	 446	 532	 712
	    15	 53	 132	 212	 263	 351	 452	 546	 723
	    17	 54	 134	 214	 265	 356	 454	 565	 731
	    21	 65	 141	 223	 266	 364	 455	 606	 732
	    23	 71	 143	 225	 271	 365	 462	 612	 734
	    25	 72	 145	 226	 274	 371	 464	 624	 743
	    26	 73	 152	 243	 306	 411	 465	 627	 754
	    31	 74	 155	 244	 311	 412	 466	 631
	    32	 114	 156	 245	 315	 413	 503	 632
	    36	 115	 162	 246	 325	 423	 506	 654
	    43	 116	 165	 251	 331	 431	 516	 662
	    47	 122	 172	 252	 332	 432	 523	 664
	}
	# need to distinguish read/write from read/only and write/only functions, levels, and parameters
	# can-get standard: FAGC NB COMP VOX TONE TSQL SBKIN FBKIN ANF NR AIP APF MON MN RF ARO LOCK MUTE VSC REV SQL ABM BC MBC AFC SATMODE SCOPE RESUME TBURST
	# can-set standard: FAGC NB COMP VOX TONE TSQL SBKIN FBKIN ANF NR AIP APF MON MN RF ARO LOCK MUTE VSC REV SQL ABM BC MBC AFC SATMODE SCOPE RESUME TBURST
	# TUNER
	$self value-set func {
	    FAGC NB COMP VOX TONE TSQL SBKIN FBKIN ANF NR AIP APF
	    MON MN RF ARO LOCK MUTE VSC REV SQL ABM BC MBC AFC SATMODE
	    SCOPE RESUME TBURST TUNER
	}
	$self value-set func-get-only {}
	# can-get standard: PREAMP(0..0/0) ATT(0..0/0) VOX(0..0/0) AF(0..0/0) RF(0..0/0) SQL(0..0/0) IF(0..0/0) APF(0..0/0) NR(0..0/0) PBT_IN(0..0/0)
	#	PBT_OUT(0..0/0) CWPITCH(0..0/10) RFPOWER(0..0/0) MICGAIN(0..0/0) KEYSPD(0..0/0) NOTCHF(0..0/0) COMP(0..0/0) AGC(0..0/0) BKINDL(0..0/0)
	#	BAL(0..0/0) METER(0..0/0) VOXGAIN(0..0/0) ANTIVOX(0..0/0) SLOPE_LOW(0..0/0) SLOPE_HIGH(0..0/0) BKIN_DLYMS(0..0/0)
	#	RAWSTR(0..0/0) SWR(0..0/0) ALC(0..0/0) STRENGTH(0..0/0)
	# can-set standard: PREAMP(0..0/0) ATT(0..0/0) VOX(0..0/0) AF(0..0/0) RF(0..0/0) SQL(0..0/0) IF(0..0/0) APF(0..0/0) NR(0..0/0) PBT_IN(0..0/0)
	#	PBT_OUT(0..0/0) CWPITCH(0..0/10) RFPOWER(0..0/0) MICGAIN(0..0/0) KEYSPD(0..0/0) NOTCHF(0..0/0) COMP(0..0/0) AGC(0..0/0) BKINDL(0..0/0)
	#	BAL(0..0/0) METER(0..0/0) VOXGAIN(0..0/0) ANTIVOX(0..0/0) SLOPE_LOW(0..0/0) SLOPE_HIGH(0..0/0) BKIN_DLYMS(0..0/0)
	$self value-set level {
	    PREAMP ATT VOX AF RF SQL IF APF NR PBT_IN PBT_OUT
	    CWPITCH RFPOWER MICGAIN KEYSPD NOTCHF COMP AGC BKINDL BAL
	    METER VOXGAIN ANTIVOX SLOPE_LOW SLOPE_HIGH SQLSTAT
	}
	$self value-set level-get-only {
	    RAWSTR SWR ALC STRENGTH
	}
	# can-get standard: ANN(0..0/0) APO(0..0/0) BACKLIGHT(0..0/0) BEEP(0..0/0) TIME(0..0/0) BAT(0..0/0) KEYLIGHT(0..0/0)
	# can-set standard: ANN(0..0/0) APO(0..0/0) BACKLIGHT(0..0/0) BEEP(0..0/0) TIME(0..0/0) KEYLIGHT(0..0/0)
	$self value-set parm {ANN APO BACKLIGHT BEEP TIME KEYLIGHT}
	$self value-set parm-get-only {BAT}

	$self value-set mem-vfo-op {CPY XCHG FROM_VFO TO_VFO MCL UP DOWN BAND_UP BAND_DOWN LEFT RIGHT TUNE TOGGLE}
	$self value-set scan-function {STOP MEM SLCT PRIO PROG DELTA VFO PLT}
	$self value-set tranceive-mode {OFF RIG POLL}
	$self value-set reset-code {1 2 4 8}
	$self value-set power-status {0 1 2}
	$self value-set digits {0 1 2 3 4 5 6 7 8 9}
	$self value-set boolean {0 1}

	# initialize the hamlib command table
	$self set-get  F set_freq f get_freq Frequency Hz
	$self set-get2 M set_mode m get_mode {Mode Passband} {mode_list Hz}
	$self set-get  V set_vfo v get_vfo VFO vfo_list
	$self set-get  J set_rit j get_rit RIT Hz
	$self set-get  Z set_xit z get_xit XIT Hz
	$self set-get  T set_ptt t get_ptt PTT boolean
	$self get-only \x8b get_dcd DCD boolean
	$self set-get  R set_rptr_shift r get_rptr_shift RptrShift shift
	$self set-get  O set_rptr_offs o get_rptr_offs RptrOffset Hz
	$self set-get  C set_ctcss_tone c get_ctcss_tone CTCSSTone deciHz
	$self set-get  D set_dcs_code d get_dcs_code DCSCode dcs_codes
	$self set-get  \x90 set_ctcss_sql \x91 get_ctcss_sql CTCSSSql deciHz
	$self set-get  \x92 set_dcs_sql \x93 get_dcs_sql DCSSql dcs-code
	$self set-get  I set_split_freq i get_split_freq TXFrequency Hz
	$self set-get2 X set_split_mode x get_split_mode {TXMode TXPassband} {mode Hz}
	$self set-get2 S set_split_vfo s get_split_vfo {Split TXVFO} {boolean vfo}
	$self set-get  N set_ts n get_ts TuningStep Hz
	foreach func [$valuesets(func) cget -values] {
	    $self set-get "U $func" "set_func $func"  "u $func" "get_func $func" FuncStatus boolean
	}
	foreach func [$valuesets(func-get-only) cget -values] {
	    $self get-only "u $func" "get_func $func" FuncStatus boolean
	}
	foreach level [$valuesets(level) cget -values] {
	    $self set-get "L $level" "set_level $level" "l $level" "get_level $level" LevelValue number
	}
	foreach level [$valuesets(level-get-only) cget -values] {
	    $self get-only "l $level" "get_level $level" LevelValue number
	}
	foreach parm [$valuesets(parm) cget -values] {
	    $self set-get "P $parm" "set_parm $parm" "p $parm" "get_parm $parm" ParmValue number
	}
	foreach parm [$valuesets(parm-get-only) cget -values] {
	    $self get-only "p $parm" "get_parm $parm" ParmValue number
	}
	$self set-only B set_bank Bank integer
	$self set-get  E set_mem e get_mem MemoryNumber integer
	$self perform  G vfo_op MemVFOOp mem-vfo-op
	$self perform2 g scan {ScanFct ScanChannel} {scan-function integer}
	$self set-get2 H set_channel h get_channel {Channel ChannelData} {integer unknown}
	$self set-get  A set_trn a get_trn Transceive tranceive-mode
	$self set-get  Y set_ant y get_ant Antenna integer
	$self perform  * reset Reset reset-code
	$self perform  b send_morse Morse morse-character
	$self set-get  \x87 set_powerstat \x88 get_powerstat PowerStatus power-status
	$self perform  \x89 send_dtmf Digits digits
	$self perform0 \x8a recv_dtmf
	$self perform0 _ get_info 
	$self perform0 1 dump_caps
	$self perform3 2 power2mW {Power Frequency Mode} {unit-interval Hz mode}
	$self perform3 4 mW2power {milliwatts Frequency Mode} {integer Hz mode}
	$self perform  w send_cmd Cmd string
	$self perform0 {} chk_vfo 
	
	$self enable 1 [mymethod dump_caps]
	$self enable _ [mymethod get_info]
    }

    # command definition helpers
    method value-set {name values} {
	set valuesets($name) [::hamlib-proxy::value-set $name -values $values]
    }
    method make-command {name args} {
	set commands($name) [::hamlib-proxy::command $name {*}$args]
	foreach opt {-name -short-name -set-name -short-set-name -get-name -short-get-name} {
	    set n [$commands($name) cget $opt]
	    if {$n ne {}} {
		set names($n) $commands($name)
	    }
	}
    }
    method set-get {set1 set2 get1 get2 parm value} {
	if {[llength $parm] != 1} { error "get-set $set1 $set2 $get1 $get2 has wrong number of parms: $parm" }
	if {[llength $value] != 1} { error "get-set $set1 $set2 $get1 $get2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-set-name $set1 -set-name $set2 -short-get-name $get1 -get-name $get2 -param $parm -values $value
    }
    method set-get2 {set1 set2 get1 get2 parm value} {
	if {[llength $parm] != 2} { error "get-set2 $set1 $set2 $get1 $get2 has wrong number of parms: $parm" }
	if {[llength $value] != 2} { error "get-set2 $set1 $set2 $get1 $get2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-set-name $set1 -set-name $set2 -short-get-name $get1 -get-name $get2 -param $parm -values $value
    }
    method get-only {get1 get2 ret value} {
	if {[llength $ret] != 1} { error "get-only $get1 $get2 has wrong number of ret: $ret" }
	if {[llength $value] != 1} { error "get-only $get1 $get2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-get-name $get1 -get-name $get2
    }
    method set-only {set1 set2 parm value} {
	if {[llength $parm] != 1} { error "set-only $set1 $set2 has wrong number of parms: $parm" }
	if {[llength $value] != 1} { error "set-only $set1 $set2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-set-name $set1 -set-name $set2 -param $parm -values $value
    }
    method perform0 {perf1 perf2} {
	$self make-command %AUTO% -short-name $perf1 -name $perf2
    }
    method perform {perf1 perf2 parm value} {
	if {[llength $parm] != 1} { error "perform $perf1 $perf2 has wrong number of parms: $parm" }
	if {[llength $value] != 1} { error "perform $perf1 $perf2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-name $perf1 -name $perf2 -param $parm -values $value
    }
    method perform2 {perf1 perf2 parm value} {
	if {[llength $parm] != 2} { error "perform2 $perf1 $perf2 has wrong number of parms: $parm" }
	if {[llength $value] != 2} { error "perform2 $perf1 $perf2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-name $perf1 -name $perf2 -param $parm -values $value
    }
    method perform3 {perf1 perf2 parm value} {
	if {[llength $parm] != 3} { error "perform3 $perf1 $perf2 has wrong number of parms: $parm" }
	if {[llength $value] != 3} { error "perform3 $perf1 $perf2 has wrong number of values: $value" }
	$self make-command %AUTO% -short-name $perf1 -name $perf2 -param $parm -values $value
    }

    # server
    #	Open the server listening socket
    #
    # Arguments:
    #	port	The server's port number

    method server {} {
	socket -server [mymethod accept] $options(-port)
    }

    # accept --
    #	Accept a connection from a new client.
    #	This is called after a new socket connection
    #	has been created by Tcl.
    #
    # Arguments:
    #	sock	The new socket connection to the client
    #	addr	The client's IP address
    #	port	The client's port number
	
    method accept {sock addr port} {

	# Record the client's information

	puts "[clock milliseconds] accept $sock from $addr port $port"
	set connection(addr,$sock) [list $addr $port]

	# Ensure that each "puts" by the server
	# results in a network transmission

	fconfigure $sock -buffering line

	# Set up a callback for when the client sends data

	fileevent $sock readable [mymethod respond $sock]
    }

    # respond --
    #	This procedure is called when the server
    #	can read data from the client
    #
    # Arguments:
    #	sock	The socket connection to the client

    method respond {sock} {

	# Check end of file or abnormal connection drop,
	# then echo data back to the client.
    
	if {[eof $sock] || [catch {gets $sock line}]} {
	    close $sock
	    puts "[clock milliseconds] close $connection(addr,$sock)"
	    unset connection(addr,$sock)
	} else {
	    #puts $sock $line
	    puts "[clock milliseconds] command: $line"
	    if {[catch {$self eval $line} result]} {
		puts "[clock milliseconds] internal error: $result\n$::errorInfo"
		# internal error
		set result "RPRT 7"
	    } else {
		puts "[clock milliseconds] result: $result"
		# success
	    }
	    puts $sock $result
	}
    }

    # hamlib error codes
    # enum rig_errcode_e {
    #    RIG_OK=0,		/*!< No error, operation completed successfully */
    #    RIG_EINVAL=1,		/*!< invalid parameter */
    #    RIG_ECONF=2,		/*!< invalid configuration (serial,..) */
    #    RIG_ENOMEM=3,		/*!< memory shortage */
    #    RIG_ENIMPL=4,		/*!< function not implemented, but will be */
    #    RIG_ETIMEOUT=5,	/*!< communication timed out */
    #    RIG_EIO=6,		/*!< IO error, including open failed */
    #    RIG_EINTERNAL=7,	/*!< Internal Hamlib error, huh! */
    #    RIG_EPROTO=8,		/*!< Protocol error */
    #    RIG_ERJCTED=9,		/*!< Command rejected by the rig */
    #    RIG_ETRUNC=10,		/*!< Command performed, but arg truncated */
    #    RIG_ENAVAIL=11,	/*!< function not available */
    #    RIG_ENTARGET=12,	/*!< VFO not targetable */
    #    RIG_BUSRROR=13,	/*!< Error talking on the bus */
    #    RIG_BUSBUSY=14,	/*!< Collision on the bus */
    #    RIG_EARG=15,		/*!< NULL RIG handle or any invalid pointer parameter in get arg */
    #    RIG_EVFO=16,		/*!< Invalid VFO */
    #    RIG_EDOM=17		/*!< Argument out of domain of func */
    #}
    #

    method eval {args} {
	if {$args eq {}} {
	    return "RPRT 0"
	}
	foreach command [list [lrange $args 0 1] [lindex $args 0]] argv [list [lrange $args 2 end] [lrange $args 1 end]] {
	    if {[info exist names($command)] && [$names($command) cget -enable]} {
		return [$names($command) eval $command {*}$argv]
	    }
	}
	return "RPRT 11"
    }

    method enable {command function} {
	if {$function eq {}} {
	    $names($command) configure -enable 0 -function {}	    
	} else {
	    $names($command) configure -enable 1 -function $function
	}
    }

    method is-enabled {command} {
	if {[info exists names($command)] && [$names($command) cget -enable]} {
	    return {Y}
	} else {
	    return {N}
	}
    }

    # this gets standard and extras
    method can-get {which} {
	switch $which {
	    functions {
		set pairs [array get names get_func*]
		set standard [concat $valuesets(func) $valuesets(func-get-only)]
	    }
	    levels {
		set pairs [array get names get_level*]
		set standard [concat $valuesets(level) $valuesets(level-get-only)]
	    }
	    parameters {
		set pairs [array get names get_parm*]
		set standard [concat $valuesets(parm) $valuesets(parm-get-only)]
	    }
	    default { error "unknown which: $which in proxy can-get" }
	}
	set result {}
	foreach pair $pairs {
	    set item [lindex $pair 1]
	    if {$item ni $result && $item in $standard} { lappend result $item }
	}
	return $result
    }
    
    # this gets standard and extras
    method can-set {which} {
	switch $which {
	    functions {
		set pairs [array get names set_func*]
		set standard $valuesets(func)
	    }
	    levels {
		set pairs [array get names set_level*]
		set standard $valuesets(level)
	    }
	    parameters {
		set pairs [array get names set_parm*]
		set standard $valuesets(parm)
	    }
	    default { error "unknown which: $which in proxy can-set" }
	}
	set result {}
	foreach pair $pairs {
	    set item [lindex $pair 1]
	    if {$item ni $result && $item in $standard} { lappend result $item }
	}
	return $result
    }
    
    method extra {which} {
	# this should distinguish set, get, and both but the "protocol" doesn't
	switch $which {
	    functions {
		set pairs [array get names *_func*]
		set standard [concat $valuesets(func) $valuesets(func-get-only)]
	    }
	    levels {
		set pairs [array get names *_level*]
		set standard [concat $valuesets(level) $valuesets(level-get-only)]
	    }
	    parameters {
		set pairs [array get names *_parm*]
		set standard [concat $valuesets(parm) $valuesets(parm-get-only)]
	    }
	    default { error "unknown which: $which in proxy extra" }
	}
	set result {}
	foreach pair $pairs {
	    set item [lindex $pair 1]
	    if {$item ni $result && $item ni $standard} { lappend result $item }
	}
	return $result
    }

    #
    # implement standard functions
    #
    method dump_caps {args} {
	puts "[clock milliseconds] dump_caps {$args}"
	set caps {}
	lappend caps {Caps dump for model: 2}
	lappend caps {Model name:	sdrkit}
	lappend caps {Mfg name:	sdrkit.org}
	lappend caps {Backend version:	0.1}
	lappend caps {Backend copyright:	LGPL}
	lappend caps {Backend status:	Beta}
	lappend caps {Rig type:	Other}
	lappend caps {PTT type:	Rig capable}
	lappend caps {DCD type:	Rig capable}
	lappend caps {Port type:	None}
	lappend caps {Write delay: 0ms, timeout 0ms, 0 retry}
	lappend caps {Post Write delay: 0ms}
	lappend caps {Has targetable VFO: N}
	lappend caps {Has transceive: N}
	lappend caps {Announce: 0x0}
	lappend caps {Max RIT: -9.990kHz/+9.990kHz}
	lappend caps {Max XIT: -9.990kHz/+9.990kHz}
	lappend caps {Max IF-SHIFT: -10.0kHz/+10.0kHz}
	lappend caps {Preamp: 0dB}
	lappend caps {Attenuator: 0dB}
	lappend caps {CTCSS: 0 tones}
	lappend caps {DCS: 0 codes}
	lappend caps "Get functions: [$self can-get functions]"
	lappend caps "Set functions: [$self can-set functions]"
	lappend caps "Get level: [$self can-get levels]"
	lappend caps "Set level: [$self can-set levels]"
	lappend caps "Extra levels: [$self extra levels]"
	lappend caps "Get parameters: [$self can-get parameters]"
	lappend caps "Set parameters: [$self can-set parameters]"
	lappend caps "Extra parameters: [$self extra parameters]"
	lappend caps "Mode list: [$self cget -modes]"
	lappend caps {VFO list: MEM VFOA VFOB }
	lappend caps {VFO Ops: CPY XCHG FROM_VFO TO_VFO MCL UP DOWN BAND_UP BAND_DOWN LEFT RIGHT TUNE TOGGLE }
	lappend caps {Scan Ops: MEM SLCT PRIO PROG DELTA VFO PLT }
	lappend caps {Number of banks:	0}
	lappend caps {Memory name desc size:	0}
	lappend caps {Memories:}
	lappend caps {	0..18:   	MEM}
	lappend caps {	  Mem caps: BANK ANT FREQ MODE WIDTH TXFREQ TXMODE TXWIDTH SPLIT RPTRSHIFT RPTROFS TS RIT XIT FUNC LEVEL TONE CTCSS DCSCODE DCSSQL SCANGRP FLAG NAME EXTLVL }
	lappend caps {	19..19:   	CALL}
	lappend caps {	  Mem caps: }
	lappend caps {	20..21:   	EDGE}
	lappend caps {	  Mem caps: }
	lappend caps {TX ranges status, region 1:	OK (0)}
	lappend caps {RX ranges status, region 1:	OK (0)}
	lappend caps {TX ranges status, region 2:	OK (0)}
	lappend caps {RX ranges status, region 2:	OK (0)}
	lappend caps {Tuning steps:}
	foreach item [$self cget -tuning-steps] { lappend caps "\t$item" }
	# lappend caps {	1 Hz:   	AM CW USB LSB RTTY FM WFM CWR RTTYR }
	# lappend caps {	ANY:   	AM CW USB LSB RTTY FM WFM CWR RTTYR }
	lappend caps {Tuning steps status:	OK (0)}
	lappend caps {Filters:}
	foreach item [$self cget -filters] { lappend caps "\t$item" }
	# lappend caps {	2.4 kHz:   	CW USB LSB RTTY }
	# lappend caps {	500 Hz:   	CW }
	# lappend caps {	8 kHz:   	AM }
	# lappend caps {	2.4 kHz:   	AM }
	# lappend caps {	15 kHz:   	FM }
	# lappend caps {	8 kHz:   	FM }
	# lappend caps {	230 kHz:   	WFM }
	lappend caps {Bandwidths:}
	foreach item [$self cget -bandwidths] { lappend caps "\t$item" }
	# lappend caps {	AM	Normal: 8 kHz,	Narrow: 2.4 kHz,	Wide: 0 Hz}
	# lappend caps {	CW	Normal: 2.4 kHz,	Narrow: 500 Hz,	Wide: 0 Hz}
	# lappend caps {	USB	Normal: 2.4 kHz,	Narrow: 0 Hz,	Wide: 0 Hz}
	# lappend caps {	LSB	Normal: 2.4 kHz,	Narrow: 0 Hz,	Wide: 0 Hz}
	# lappend caps {	RTTY	Normal: 2.4 kHz,	Narrow: 0 Hz,	Wide: 0 Hz}
	# lappend caps {	FM	Normal: 15 kHz,	Narrow: 8 kHz,	Wide: 0 Hz}
	# lappend caps {	WFM	Normal: 230 kHz,	Narrow: 0 Hz,	Wide: 0 Hz}
	lappend caps "Has priv data:	N"
	lappend caps "Has Init:	N"
	lappend caps "Has Cleanup:	N"
	lappend caps "Has Open:	N"
	lappend caps "Has Close:	N"
	lappend caps "Can set Conf:	N"
	lappend caps "Can get Conf:	N"
	lappend caps "Can set Frequency:	[$self is-enabled set_freq]"
	lappend caps "Can get Frequency:	[$self is-enabled get_freq]"
	lappend caps "Can set Mode:	[$self is-enabled set_mode]"
	lappend caps "Can get Mode:	[$self is-enabled get_mode]"
	lappend caps "Can set VFO:	[$self is-enabled set_vfo]"
	lappend caps "Can get VFO:	[$self is-enabled get_vfo]"
	lappend caps "Can set PTT:	[$self is-enabled set_ptt]"
	lappend caps "Can get PTT:	[$self is-enabled get_ptt]"
	lappend caps "Can get DCD:	[$self is-enabled get_dcd]"
	lappend caps "Can set Repeater Duplex:	[$self is-enabled set_rptr_shift]"
	lappend caps "Can get Repeater Duplex:	[$self is-enabled get_rptr_shift]"
	lappend caps "Can set Repeater Offset:	[$self is-enabled set_rptr_offs]"
	lappend caps "Can get Repeater Offset:	[$self is-enabled oget_rptr_offs]"
	lappend caps "Can set Split Freq:	[$self is-enabled set_split_freq]"
	lappend caps "Can get Split Freq:	[$self is-enabled get_split_freq]"
	lappend caps "Can set Split Mode:	[$self is-enabled set_split_mode]"
	lappend caps "Can get Split Mode:	[$self is-enabled get_split_mode]"
	lappend caps "Can set Split VFO:	[$self is-enabled set_split_vfo]"
	lappend caps "Can get Split VFO:	[$self is-enabled get_split_vfo]"
	lappend caps "Can set Tuning Step:	[$self is-enabled set_ts]"
	lappend caps "Can get Tuning Step:	[$self is-enabled get_ts]"
	lappend caps "Can set RIT:	[$self is-enabled set_rit]"
	lappend caps "Can get RIT:	[$self is-enabled get_rit]"
	lappend caps "Can set XIT:	[$self is-enabled set_xit]"
	lappend caps "Can get XIT:	[$self is-enabled get_xit]"
	lappend caps "Can set CTCSS:	[$self is-enabled set_ctcss_tone]"
	lappend caps "Can get CTCSS:	[$self is-enabled get_ctcss_tone]"
	lappend caps "Can set DCS:	[$self is-enabled set_dcs_code]"
	lappend caps "Can get DCS:	[$self is-enabled get_dcs_code]"
	lappend caps "Can set CTCSS Squelch:	[$self is-enabled set_ctcss_sql]"
	lappend caps "Can get CTCSS Squelch:	[$self is-enabled get_ctcss_sql]"
	lappend caps "Can set DCS Squelch:	[$self is-enabled set_dcs_sql]"
	lappend caps "Can get DCS Squelch:	[$self is-enabled get_dcs_sql]"
	lappend caps "Can set Power Stat:	[$self is-enabled get_powerstat]"
	lappend caps "Can get Power Stat:	[$self is-enabled set_powerstat]"
	lappend caps "Can Reset:	[$self is-enabled reset]"
	lappend caps "Can get Ant:	[$self is-enabled get_ant]"
	lappend caps "Can set Ant:	[$self is-enabled set_ant]"
	lappend caps "Can set Transceive:	[$self is-enabled set_trn]"
	lappend caps "Can get Transceive:	[$self is-enabled get_trn]"
	# weird, these should specialize on function, level, and param
	lappend caps {Can set Func:	Y}
	lappend caps {Can get Func:	Y}
	lappend caps {Can set Level:	Y}
	lappend caps {Can get Level:	Y}
	lappend caps {Can set Param:	Y}
	lappend caps {Can get Param:	Y}
	
	lappend caps "Can send DTMF:	[$self is-enabled send_dtmf]"
	lappend caps "Can recv DTMF:	[$self is-enabled recv_dtmf]"
	lappend caps "Can send Morse:	[$self is-enabled send_morse]"
	lappend caps {Can decode Events:	N}
	lappend caps "Can set Bank:	[$self is-enabled set_bank]"
	lappend caps "Can set Mem:	[$self is-enabled set_mem]"
	lappend caps "Can get Mem:	[$self is-enabled get_mem]"
	lappend caps "Can set Channel:	[$self is-enabled set_channel]"
	lappend caps "Can get Channel:	[$self is-enabled get_channel]"
	lappend caps "Can ctl Mem/VFO:	[$self is-enabled vfo_op]"
	lappend caps "Can Scan:	[$self is-enabled scan]"
	lappend caps "Can get Info:	[$self is-enabled get_info]"
	lappend caps "Can get power2mW:	[$self is-enabled power2mW:]"
	lappend caps "Can get mW2power:	[$self is-enabled mW2power]"
	lappend caps {}
	lappend caps {Overall backend warnings: 0}
	return [join $caps \n]
    }

    method get_info {} {
	set info {}
	return [join $info \n]
    }

}
