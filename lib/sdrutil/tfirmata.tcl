#
# tfirmata.tcl
#
# Arduino Firmata implementation
#
package provide tfirmata 1.0

namespace eval tfirmata {
    variable pinModes {in out analog pwm servo shift twi}
    variable idCount 0
    variable command ""
    variable wakeup 0
}

# open serial port and return reference command
proc tfirmata::open {port} {
    variables idCount command
    set cmd [namespace current]::tfirmata#[incr idCount]
    set command $cmd

    # open and configure serial port
    set fd [::open $port r+]
    fconfigure $fd -mode 57600,n,8,1 -translation binary -blocking 0
    fileevent $fd readable [list [namespace current]::parseSerialReadData $fd]

    # create access command
    proc $cmd {args} [format {subCmd %s {*}$args} $cmd] 

    # set up command variables
    namespace eval __#$idCount {
        # file descriptor for arduino, and buffer for reading serial
        variable fd ""
        variable rxBuf ""

        # arduino configuration. Device config is a dictionary, where keys
        # are arduino pin numbers, values are lists of supported modes and 
        # their resolutions. Analog mapping is a dictionary, where keys are 
        # analog channel numbers, values are arduino pins.
        variable deviceConfig ""
        variable analogMapping ""

        # firmata version
        variable firmwareVersion ""
        variable firmwareName ""

        # digital ports and analog inputs
        variable digitalIns 0
        variable digitalOuts ""
        variable analogIns ""

        # for pin state command
        variable pin ""
        variable mode ""
        variable state ""

        # for counting errors in received messages
        variable errorCount 0

        # message callbacks
        variable digitalCallback ""
        variable analogCallback ""

        # twi callbacks, stored in a dict, where keys are TWI device address,
        # values are a list of dicts, where each dict specifies the callback
        # code, whether the callback is repeating, TWI control byte sequence, 
        # and the number of TWI bytes to retrieve.
        variable twiCallbacks ""
        
        # holds bytes from TWI reply message when using blocking read
        variable twiReplyBytes ""
    }
    set [ns]::fd $fd

    # send reset so digital reporting works correctly without a board reset 
    puts -nonewline [set [ns]::fd] [binary format H2 ff]
    flush [set [ns]::fd]

    # get firmware name and version
    puts -nonewline $fd [binary format H2H2H2 f0 79 f7] 
    flush $fd
    vwait [ns]::firmwareName

    # get board capabilities
    puts -nonewline $fd [binary format H2H2H2 f0 6b f7] 
    flush $fd
    vwait [ns]::deviceConfig

    # get board analog mapping
    puts -nonewline $fd [binary format H2H2H2 f0 69 f7] 
    flush $fd
    vwait [ns]::analogMapping

    # create lists for i/o values
    set [ns]::analogIns [lrepeat [dict size [set [ns]::analogMapping]] 0]
    set numPorts [getNumPorts]
    set [ns]::digitalIns [lrepeat $numPorts 0]
    set [ns]::digitalOuts [lrepeat $numPorts 0]

    return $cmd
}

# parse sub command
proc tfirmata::subCmd {cmd args} {
    variables command
    set args [lassign $args subCmd]
    if {$subCmd == ""} {
        error "no tfirmata sub command provided"
    }
    if {$subCmd ni {mode dstream astream dget dset aget aset version state \
            amapping errors dcommand acommand period servolimits twiconfig 
            twiget twiset close}} {
        error "unknown tfirmata subcommand '$subCmd'"
    }
    set command $cmd
    if {[llength $args] == 0} {
        $subCmd 
    } else {
        $subCmd {*}$args
    }
}

# configure pin mode(s) to in, out, analog, pwm, or servo
proc tfirmata::mode {args} {
    variables pinModes
    if {[llength $args] < 2} {
        error "mode expects pin numbers followed by pin mode"
    }
    while {1} {
        if {$args == ""} {
            break
        }
        set pins [list]
        while {1} {
            if {$args == ""} {
                error "mode expects pin mode to follow pin numbers"
            }
            set args [lassign $args i]
            if {$i in [lrange $pinModes 0 4]} {
                break
            }
            lappend pins $i
        }
        if {$pins == ""} {
            error "mode expects pin numbers before '$i'"
        }
        set mode $i
        foreach pin $pins {
            if {![dict exists [set [ns]::deviceConfig] $pin]} {
                error "invalid pin '$pin'"
            }
            set modeId [lsearch $pinModes $mode]
            set modeIds [dict get [set [ns]::deviceConfig] $pin]
            if {![dict exists $modeIds $modeId]} {
                error "invalid mode '$mode' for pin '$pin'"
            }
            puts -nonewline [set [ns]::fd] [binary format H2cc f4 $pin $modeId] 
            flush [set [ns]::fd]
        }
    }
}

# enable/disable streaming of digital port(s)
proc tfirmata::dstream {args} {
    if {[llength $args] < 2} {
        error "dstream expects port numbers followed by 'on' or 'off'"
    }
    while {1} {
        if {$args == ""} {
            break
        }
        set ports [list]
        while {1} {
            if {$args == ""} {
                error "dstream expects 'on' or 'off' to follow pin numbers"
            }
            set args [lassign $args i]
            if {$i in {on off}} {
                break
            }
            lappend ports $i
        }
        if {$ports == ""} {
            error "dstream expects port numbers before '$i'"
        }
        set en 0
        if {$i == "on"} {
            set en 1
        }
        foreach port $ports {
            if {![string is integer $port] || $port < 0 || $port > [getNumPorts]} {
		puts "$port - [string is integer $port] = string is integer $port"
		puts "$port - [expr {$port < 0}] = $port < 0"
		puts "$port - [expr {$port > [getNumPorts]}] = $port > [getNumPorts] = getNumPorts"
                error "invalid port '$port'"
            }
            puts -nonewline [set [ns]::fd] \
                    [binary format cc [expr 0xd0 + $port] $en] 
            flush [set [ns]::fd]
        }
    }
}

# enable/disable streaming of analog input(s).
proc tfirmata::astream {args} {
    if {[llength $args] < 2} {
        error "astream expects pin numbers followed by 'on' or 'off'"
    }
    while {1} {
        if {$args == ""} {
            break
        }
        set pins [list]
        while {1} {
            if {$args == ""} {
                error "astream expects 'on' or 'off' to follow pin numbers"
            }
            set args [lassign $args i]
            if {$i in {on off}} {
                break
            }
            lappend pins $i
        }
        if {$pins == ""} {
            error "astream expects pin numbers before '$i'"
        }
        set en 0
        if {$i == "on"} {
            set en 1
        }
        foreach pin $pins {
            if {![dict exists [set [ns]::analogMapping] $pin]} {
                error "invalid analog pin '$pin'"
            }
            puts -nonewline [set [ns]::fd] \
                    [binary format cc [expr 0xc0 + $pin] $en] 
            flush [set [ns]::fd]
        }
    }
}

# get digital pin value(s)
proc tfirmata::dget {args} {
    set bitVals {}
    foreach pin $args {
        if {![dict exists [set [ns]::deviceConfig] $pin]} {
            error "invalid pin '$pin'"
        }
        set port [expr {$pin >> 3}]
        set bit [expr {$pin & 0x7}]
        set portVal [lindex [set [ns]::digitalIns] $port]
        lappend bitVals [expr {($portVal & (1 << $bit)) != 0}] 
    }
    return $bitVals
}

# set digital pin value(s)
proc tfirmata::dset {args} {
    set ports {}
    foreach {pin val} $args {
        if {![dict exists [set [ns]::deviceConfig] $pin]} {
            error "invalid pin '$pin'"
        }
        if {$val ni {0 1}} {
            error "value should be 0 or 1"
        }
        set port [expr {$pin >> 3}]
        set pin [expr {$pin & 0x7}]
        set v [lindex [set [ns]::digitalOuts] $port]
        if {$val} {
            set v [expr $v | (1 << $pin)]
        } else {
            set v [expr $v & ~(1 << $pin)]
        }
        lset [ns]::digitalOuts $port $v
        if {$port ni $ports} {
            lappend ports $port
        }
    }
    foreach port $ports {
        set v [lindex [set [ns]::digitalOuts] $port]
        set ls [expr {$v & 0x7f}]
        set ms [expr {($v >> 7) & 0x7f}]
        puts -nonewline [set [ns]::fd] \
                [binary format ccc [expr 0x90 + $port] $ls $ms]
        flush [set [ns]::fd]
    }
}

# get analog in value(s)
proc tfirmata::aget {args} {
    set analogVals {}
    foreach ain $args {
        if {![dict exists [set [ns]::analogMapping] $ain]} {
            error "invalid analog in '$ain'"
        }
        lappend analogVals [lindex [set [ns]::analogIns] $ain]
    }
    return $analogVals
}

# set analog output(s)
proc tfirmata::aset {args} {
    foreach {pin val} $args {
        set lsb [expr {$val & 0x7f}]
        set msb [expr {($val >> 7) & 0x7f}]
        puts -nonewline [set [ns]::fd] \
                [binary format H2H2cccH2 f0 6f $pin $lsb $msb f7] 
        flush [set [ns]::fd]
    }
}

# get version information
proc tfirmata::version {} {
    return [set [ns]::firmwareVersion]
}

# get pin state(s). State includes the mode a pin is set to.
proc tfirmata::state {args} {
    variable pinModes
    if {$args == ""} {
        error "state expects a pin number, list of pin numbers, or 'all'"
    } elseif {$args == "all"} {
        set pins [dict keys [set [ns]::deviceConfig]]
    } else {
        set pins $args
    }
    set states [list]
    foreach pin $pins {
        if {![dict exists [set [ns]::deviceConfig] $pin]} {
            error "invalid pin '$pin'"
        }
        puts -nonewline [set [ns]::fd] [binary format H2H2cH2 f0 6d $pin f7] 
        flush [set [ns]::fd]
        vwait [ns]::state
        if {[set [ns]::pin] != $pin} {
            error "error reading back pin '$pin' state"
        }
        set mode [lindex $pinModes [set [ns]::mode]]
        lappend states $pin [list $mode {*}[set [ns]::state]]
    }
    return $states
}

# get analog channel mapping(s)
proc tfirmata::amapping {args} {
    set mappings [list]
    foreach arg $args {
        if {![dict exists [set [ns]::analogMapping] $arg]} {
            error "error getting mapping for analog input '$arg'"
        }
        lappend mappings [dict get [set [ns]::analogMapping] $arg]
    }
    return $mappings
}

# set digital message event command 
proc tfirmata::dcommand {cmd} {
    set [ns]::digitalCallback $cmd
}

# set analog message event command 
proc tfirmata::acommand {cmd} {
    set [ns]::analogCallback $cmd
}

# set sampling period
proc tfirmata::period {ms} {
    if {[string is integer $ms] && $ms >= 0 && $ms <= 0x3fff} {
        set lsb [expr {$ms & 0x7f}]
        set msb [expr {($ms >> 8) & 0x7f}]
        puts -nonewline [set [ns]::fd] \
                [binary format H2H2ccH2 f0 7a $lsb $msb f7] 
        flush [set [ns]::fd]
    } else {
        error "analog sampling period should be between 0 and 0x3fff"
    }
}

# set servo limits for pin(s)
proc tfirmata::servolimits {args} {
    if {$args == {}} {
        error "servolimits expects pin numbers followed by limits"
    }
    while {1} {
        set pins {}
        set limits {}
        while {1} {
            set args [lassign $args arg]
            if {$arg == {}} {
                break
            }
            if {[llength $arg] == 1} {
                lappend pins $arg
            } elseif {[llength $arg] == 2} {
                set limits $arg
                break
            } else {
                error "servolimits argument list length error"
            }
        }
        if {$pins == {} && $limits == {}} {
            return
        }
        if {$pins == {}} {
            error "servolimits expects pins before limits"
        }
        if {$limits == {}} {
            error "servolimits expects limits after pins"
        }
        foreach pin $pins {
            if {![dict exists [set [ns]::deviceConfig] $pin]} {
                error "invalid pin '$pin'"
            }
            set modeIds [dict get [set [ns]::deviceConfig] $pin]
            if {![dict exists $modeIds 4]} {
                error "invalid servo mode setting servo limits for pin '$pin'"
            }
            set min [lindex $limits 0]
            set max [lindex $limits 1]
            if {![string is integer $min] || $min < 0 || $min > 0x3fff || \
                    ![string is integer $max] || $max < 0 || $max > 0x3fff || \
                    $min >= $max} {
                error "invalid servolimits limits"
            }
            set minLsb [expr {$min & 0x7f}]
            set minMsb [expr {($min >> 7) & 0x7f}]
            set maxLsb [expr {$max & 0x7f}]
            set maxMsb [expr {($max >> 7) & 0x7f}]
            puts -nonewline [set [ns]::fd] [binary format H2H2cccccH2 f0 70 \
                    $pin $minLsb $minMsb $maxLsb $maxMsb f7] 
            flush [set [ns]::fd]
        }
    }
}

# configure twi interface pins with optional delay
proc tfirmata::twiconfig {{delay 0}} {
    if {![string is integer $delay] || $delay < 0 || $delay > 0x3fff} {
        error "twiconfig delay error"
    }
    set delay [decompose $delay]
    puts -nonewline [set [ns]::fd] [binary format H2H2ccH2 f0 78 {*}$delay f7]
    flush [set [ns]::fd]
}

# perform read messages on TWI. Returns list of bytes read if blocking read,
# otherwise returns {} and later runs
proc tfirmata::twiget {args} {
    if {$args == {}} {
        error "twiget arguments error"
    }
    set repeat 0
    set bytes {}
    set codeSpecified 0
    set code {}
    set i 0
    while {1} {
        if {$i == [llength $args]} {
            break
        }
        set arg [lindex $args $i]
        if {$arg == "-repeat"} {
            if {$i != 0} {
                error "twiget arguments error"
            }
            set repeat 1
        } elseif {$arg == "-stop"} {
            if {$i != 0 || [llength $args] != 2]} {
                error "twiget arguments error"
            }
            set address [lindex $args 1]
            if {![dict exists [set [ns]::twiCallbacks] $address]} {
                error "twiget -stop address error"
            }

            # send message to arduino to clear read
            set bytes [decompose $address]
            lset bytes 1 0x18
            puts -nonewline [set [ns]::fd] [binary format \
                    H2H2ccH2 f0 76 {*}$bytes f7]
            flush [set [ns]::fd]

            dict unset [ns]::twiCallbacks $address
            return
        } elseif {$arg == "-command"} {
            if {$bytes == {}} {
                error "twiget arguments error"
            }
            if {$i + 2 != [llength $args]} {
                error "twiget arguments error"
            }
            set codeSpecified 1
            set code [lindex $args $i+1]
            break
        } else {
            # otherwise parse bytes for TWI device
            if {![string is integer $arg] || $arg < 0 || $arg > 0xff} {
                error "twiget bytes error"
            }
            lappend bytes [expr {$arg}]
        }
        incr i
    }

    if {$bytes == {}} {
        error "twiget bytes error"
    }

    set twiAddr [lindex $bytes 0]
    set twiControl [lrange $bytes 1 end-1]
    set numTwiReadBytes [lindex $bytes end]

    if {[lindex $bytes 0] > 0x7f} {
        error "twiget device address out of range"
    }
    
    # update TWI callbacks if TWI callback provided
    if {$codeSpecified} {
        set entriesIndex [searchTwiCallbacks $twiAddr $twiControl]
        if {$entriesIndex != -1} {
            deleteTwiCallback $twiAddr $entriesIndex
        }
        set d [dict create twiControl $twiControl \
                numBytes $numTwiReadBytes repeat $repeat code $code]
        addTwiCallback $twiAddr $d
    }

    # send message to arduino to set up read
    set bytes [decompose {*}$bytes]
    if {$repeat} {
        lset bytes 1 0x10
    } else {
        lset bytes 1 0x08
    }
    puts -nonewline [set [ns]::fd] [binary format \
            H2H2[string repeat c [llength $bytes]]H2 f0 76 {*}$bytes f7]
    flush [set [ns]::fd]

    # block for response from arduino if no TWI callback provided
    if {!$codeSpecified} {
        while {1} {
            vwait [ns]::twiReplyBytes
            set replyBytes [set [ns]::twiReplyBytes]
            set replyAddr [lindex $replyBytes 0]
            set replyControl [lrange $replyBytes 1 [llength $twiControl]]
            if {$replyAddr == $twiAddr && $replyControl == $twiControl} {
                set offs [expr {$numTwiReadBytes - 1}]
                return [lrange $replyBytes end-$offs end]
            }
        }
    }

    return {}
}

# perform write message on TWI
proc tfirmata::twiset {args} {
    if {[llength $args] < 2} {
        error "twiget arguments error"
    }
    set twiAddr [lindex $args 0]
    if {![string is integer $twiAddr] || $twiAddr < 0 || $twiAddr > 0x7f} {
        error "twiget address error"
    }
    foreach arg [lrange $args 1 end] {
        if {![string is integer $arg] || $arg < 0 || $arg > 0xff} {
            error "twiget bytes error"
        }
    }
    set data [decompose {*}$args]
    puts -nonewline [set [ns]::fd] [binary format \
            H2H2[string repeat c [llength $data]]H2 f0 76 {*}$data f7]
    flush [set [ns]::fd]
}

# get number of receive errors
proc tfirmata::errors {} {
    return [set [ns]::errorCount]
}

# close serial port associated with command and delete command
proc tfirmata::close {} {
    variables command
    ::close [set [ns]::fd]
    namespace delete [ns]
    rename $command {}
}

# sleep for ms milliseconds by waiting on the Tcl event loop 
proc tfirmata::sleep {ms} {
    after $ms [list set [namespace current]::wakeup 1]
    vwait [namespace current]::wakeup
}

# -----------------------------------------------------------------------------

# parse serial data received from Arduino
proc tfirmata::parseSerialReadData {fd} {
    namespace upvar [ns] rxBuf rxBuf

    # read all received serial port bytes and append to rxBuf
    set a [read $fd]
    binary scan $a H[expr {[string length $a] * 2}] bytes
    append rxBuf $bytes

    while 1 {
        # find start of message
        set skippedBytes 0
        while {1} {
            if {$rxBuf == ""} {
                return
            }
            set b [expr 0x[string range $rxBuf 0 1]]
            if {$b == 0xf9 || ($b >=0x90 && $b <= 0x9f) || \
                    ($b >= 0xe0 && $b <= 0xef) || $b == 0xf0} {
                break
            } else {
                set rxBuf [string range $rxBuf 2 end]
                set skippedBytes 1
            }
        }

        if {$skippedBytes} {
            incr [ns]::errorCount
        }

        # parse message
        if {$b == 0xf9} {
            set rv [parseVersionMsg $rxBuf]
        } elseif {$b >= 0x90 && $b <= 0x9f} {
            set rv [parseDigitalMsg $rxBuf]
        } elseif {$b >= 0xe0 && $b <= 0xef} {
            set rv [parseAnalogMsg $rxBuf]
        } elseif {$b == 0xf0} {
            if {[string length $rxBuf] < 6} {
                return
            }
            set b [expr 0x[string range $rxBuf 2 3]]
            if {$b == 0x79} {
                set rv [parseFirmwareMsg $rxBuf]
            } elseif {$b == 0x6c} {
                set rv [parseCapabilitiesMsg $rxBuf]
            } elseif {$b == 0x6a} {
                set rv [parseAnalogMappingMsg $rxBuf]
            } elseif {$b == 0x6e} {
                set rv [parsePinStateMsg $rxBuf]
            } elseif {$b == 0x77} {
                set rv [parseTwiMsg $rxBuf]
            } else {
                set rv 0
            }
        }

        # if no characters consumed, try again later
        if {$rv == 0} {
            return
        } 
        
        # if error parsing message, trim buffer for searching for next message
        if {$rv == -1} {
            set rxBuf [string range $rxBuf 2 end]
            incr [ns]::errorCount
            continue
        }
        
        # otherwise trim buffer to account for consumed bytes
        set rxBuf [string range $rxBuf $rv end]
    }
}

# parses buf for version message. Returns -1 if format error, 0 if not enough 
# bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parseVersionMsg {buf} {
    if {[string length $buf] < 6} {
        return 0
    }
    set major [expr 0x[string range $buf 2 3]]
    set minor [expr 0x[string range $buf 4 5]]
    if {$major & 0x80 || $minor & 0x80} {
        return -1
    }
    set [ns]::firmwareVersion $major.$minor
    return 6
}

# parses buf for digital message. Returns -1 if format error, 0 if not enough 
# bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parseDigitalMsg {buf} {
    if {[string length $buf] < 6} {
        return 0
    }
    set i [expr 0x[string range $buf 0 1] - 0x90]
    set ls [expr 0x[string range $buf 2 3]]
    set ms [expr 0x[string range $buf 4 5]]
    if {$ls & 0x80 || $ms & 0x80} {
        return -1
    }
    if {[set [ns]::deviceConfig] != ""} {
        lset [ns]::digitalIns $i [expr $ms << 7 | $ls]
    }
    if {[set [ns]::digitalCallback] != ""} {
        uplevel #0 [set [ns]::digitalCallback]
    } 
    return 6
}

# parses buf for analog message. Returns -1 if format error, 0 if not enough 
# bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parseAnalogMsg {buf} {
    if {[string length $buf] < 6} {
        return 0
    }
    set i [expr 0x[string range $buf 0 1] - 0xe0]
    set ls [expr 0x[string range $buf 2 3]]
    set ms [expr 0x[string range $buf 4 5]]
    if {$ls & 0x80 || $ms & 0x80} {
        return -1
    }
    if {[set [ns]::deviceConfig] != ""} {
        lset [ns]::analogIns $i [expr $ms << 7 | $ls]
    }
    if {[set [ns]::analogCallback] != ""} {
        uplevel #0 [set [ns]::analogCallback]
    } 
    return 6
}

# parses buf for SysEx firmware message. Returns -1 if format error, 0 if not 
# enough bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parseFirmwareMsg {buf} {
    set i 4
    while {$i < [string length $buf]} {
        set b [string range $buf $i $i+1]
        if {$b == "f7"} {
            if {$i < 10} {
                return -1
            }
            set [ns]::firmwareVersion $major.$minor
            set [ns]::firmwareName $name
            return $i
        } elseif {[expr 0x$b] & 0x80} {
            return -1
        } else {
            if {$i == 4} {
                set major [expr $b]
            } elseif {$i == 6} {
                set minor [expr $b]
            } else {
                append name [format %c 0x$b]
            }
        }
        incr i 2
    }
    return 0
}

# parses buf for SysEx capabilites response message. Returns -1 if format 
# error, 0 if not enough bytes in buf, or number of bytes consumed if 
# successfully parsed
proc tfirmata::parseCapabilitiesMsg {buf} {
    set config [dict create]
    set pinNum 0
    set i 4
    while {1} {
        set modes [list]
        while {1} {
            if {$i + 4 > [string length $buf]} {
                return 0
            }
            set b [expr 0x[string range $buf $i $i+1]] 
            if {$b & 0x80} {
                return -1
            }
            if {$b == 0x7f} {
                dict set config $pinNum $modes
                incr i 2
                break
            }
            set mode $b
            set resolution [expr 0x[string range $buf $i+2 $i+3]]
            if {$mode ni {0 1 2 3 4 5 6} || $resolution > 16} {
                return -1
            }
            lappend modes $mode $resolution
            incr i 4
        }
        if {[string range $buf $i $i+1] eq "f7"} {
            if {$modes == {}} {
                return -1
            }
            incr i 2
            break
        }
        incr pinNum
    }
    set [ns]::deviceConfig $config
    return $i
}

# parses buf for SysEx analog mapping message. Returns -1 if format error, 0 
# if not enough bytes in buf, or number of bytes consumed if successfully 
# parsed
proc tfirmata::parseAnalogMappingMsg {buf} {
    set mapping {}
    set pin 0
    set i 4
    while {1} {
        if {$i + 2 > [string length $buf]} {
            return 0
        }
        set channel [expr 0x[string range $buf $i $i+1]]
        if {$channel == 0xf7} {
            if {$mapping == {}} {
                return -1
            }
            incr i 2
            break
        }
        if {$channel & 0x80} {
            return -1
        }
        if {$channel != 0x7f} {
            dict set mapping $channel $pin
        }
        incr pin
        incr i 2
    }
    set [ns]::analogMapping $mapping
    return $i
}

# parses buf for SysEx pin state message. Returns -1 if format error, 0 if not 
# enough bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parsePinStateMsg {buf} {
    if {[string length $buf] < 12} {
        return 0
    }
    set pin [expr 0x[string range $buf 4 5]]
    set mode [expr 0x[string range $buf 6 7]]
    if {$pin & 0x80 || $mode & 0x80} {
        return -1
    }
    set state 0
    set count 0
    set i 8
    while {1} {
        if {$i + 2 > [string length $buf]} {
            return 0
        }
        set b [expr 0x[string range $buf $i $i+1]]
        if {$b == 0xf7} {
            if {$i == 8} {
                return -1
            }
            set [ns]::pin $pin
            set [ns]::mode $mode
            set [ns]::state $state
            incr i 2
            break
        }
        if {$b & 0x80} {
            return -1
        }
        set state [expr {$state + ($b << (8 * $count))}]
        incr count
        incr i 2
    }
    return $i
}

# parses buf for SysEx TWI reply message. Returns -1 if format error, 0 if not 
# enough bytes in buf, or number of bytes consumed if successfully parsed
proc tfirmata::parseTwiMsg {buf} {
    if {[string length $buf] < 18} {
        return 0
    }
    set bytes [list]
    set i 4
    while {1} {
        if {$i + 2 > [string length $buf]} {
            return 0 
        }
        if {[string range $buf $i $i+1] == "f7"} {
            break
        }
        if {$i + 4 > [string length $buf]} {
            return 0 
        }
        set ls [expr 0x[string range $buf $i $i+1]]
        set ms [expr 0x[string range $buf $i+2 $i+3]]
        if {$ls & 0x80 || $ms & 0x80} {
            return -1
        }
        lappend bytes [expr {$ms << 7 | $ls}]
        incr i 4
    }
    set twiAddr [lindex $bytes 0]
    set len [getTwiControlLen $twiAddr]
    if {$len != -1} {
        set twiControl [lrange $bytes 1 $len]
        set index [searchTwiCallbacks $twiAddr $twiControl]
        if {$index != -1} {
            set code [getTwiCallbackCode $twiAddr $index]
            if {![getTwiCallbackRepeat $twiAddr $index]} {
                deleteTwiCallback $twiAddr $index
            }
            regsub -all %D $code [lrange $bytes 1+$len end] code
            namespace eval :: $code
        }
    }
    set [ns]::twiReplyBytes $bytes
    return [incr i 2]
}

# -----------------------------------------------------------------------------

# returns index of callback in TWI callbacks, or -1 if it doesn't exists
proc tfirmata::searchTwiCallbacks {twiAddr twiControl} {
    set cbs [set [ns]::twiCallbacks]
    if {![dict exists $cbs $twiAddr]} {
        return -1
    }
    set entries [dict get $cbs $twiAddr] 
    for {set i 0} {$i < [llength $entries]} {incr i} {
        set e [lindex $entries $i]
        if {$twiControl == [dict get $e twiControl]} {
            return $i
        }
    }
    return -1
}

# delete callback from TWI callbacks
proc tfirmata::deleteTwiCallback {twiAddr index} {
    set entries [dict get [set [ns]::twiCallbacks] $twiAddr] 
    set entries [lreplace $entries $index $index]
    if {[llength $entries] == 0} {
        dict unset [ns]::twiCallbacks $twiAddr
    } else {
        dict set [ns]::twiCallbacks $twiAddr $entries
    }
}

# add callback to TWI callbacks
proc tfirmata::addTwiCallback {twiAddr callback} {
    dict lappend [ns]::twiCallbacks $twiAddr $callback
}

# returns length of control bytes for TWI device with address twiAddr. Returns
# -1 if TWI address isn't in TWI callbacks
proc tfirmata::getTwiControlLen {twiAddr} {
    set cbs [set [ns]::twiCallbacks]
    if {![dict exists $cbs $twiAddr]} {
        return -1
    }
    set entries [dict get $cbs $twiAddr] 
    set e [lindex $entries 0]
    return [llength [dict get $e twiControl]]
}

# returns code for TWI callback, or {} if callback isn't in TWI callbacks
proc tfirmata::getTwiCallbackCode {twiAddr index} {
    set cbs [set [ns]::twiCallbacks]
    if {![dict exists $cbs $twiAddr]} {
        return {}
    }
    set entries [dict get $cbs $twiAddr] 
    set e [lindex $entries $index]
    return [dict get $e code]
}

# returns repeat status of TWI callback, or -1 if callback isn't in TWI 
# callbacks
proc tfirmata::getTwiCallbackRepeat {twiAddr index} {
    set cbs [set [ns]::twiCallbacks]
    if {![dict exists $cbs $twiAddr]} {
        return -1
    }
    set entries [dict get $cbs $twiAddr] 
    set e [lindex $entries $index]
    return [dict get $e repeat]
}

# -----------------------------------------------------------------------------

# returns number of device ports
proc tfirmata::getNumPorts {} {
    set config [set [ns]::deviceConfig]
    set numPorts [expr [dict size $config] / 8]
    if {[dict size $config] % 8} {
        incr numPorts
    }
    return $numPorts
}

# returns data namespace for current executing access command
proc tfirmata::ns {} {
    variable command
    return [namespace current]::__#[lindex [split $command #] 1]
}

# separates values provided into two 7-bit integers
proc tfirmata::decompose {args} {
    set l [list]
    foreach arg $args {
        lappend l [expr {$arg & 0x7f}] [expr {($arg >> 7) & 0x7f}]
    }
    return $l
}

# alternative to Tcl variable
proc tfirmata::variables {args} {
    foreach var $args {
        uplevel 1 [list variable $var]
    }
}

