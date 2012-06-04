#
# this is a driver for the dg8saq style softrock radio controllers
# and sdr-widget/audio-widget derivatives.
#
# Based entirely on usbsoftrock:
#
# * SoftRock USB I2C host control program
# * Copyright (C) 2009 Andrew Nilsson (andrew.nilsson@gmail.com)
# *
# * This program is free software; you can redistribute it and/or modify
# * it under the terms of the GNU General Public License as published by
# * the Free Software Foundation; either version 2 of the License, or
# * (at your option) any later version.
# *
# * This program is distributed in the hope that it will be useful,
# * but WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# * GNU General Public License for more details.
# * 
# * You should have received a copy of the GNU General Public License along
# * with this program; if not, write to the Free Software Foundation, Inc.,
# * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# *
# * Based on powerSwitch.c by Christian Starkjohann,
# * and usbtemp.c by Mathias Dalheimer
# * of Objective Development Software GmbH (2005)
# * (see http://www.obdev.at/avrusb)
#
# and checked against the DG8SAQ_cmd.c source of sdr-widget.
#
# tested with the Ensemble Rx II, QRP-2000, sdr-widget, and audio-widget.
#

package provide dg8saq 1.0

package require usb
package require handle
#package require udev
package require si570

namespace eval dg8saq {
    namespace eval get {}
    namespace eval put {}
    #
    # usbsoftrock reports:
    #
    # sdr-widget in dg8saq mode identifies as:
    # Version     : 16.100
    # USB SerialID: 1.0.0.0.0.0.A
    #
    # ensemble rx ii identifies as:
    # Version     : 15.12
    # USB SerialID: PE0FKO-0
    #
    # qrp-2000 identifies as:
    # Version     : 14.0
    # USB SerialID: Beta1.1
    #

    # so let us find them all if they're all connected
    # these are the vendor:product ids adopted by the sdr-widget
    set DG8SAQ_VENDOR_ID	0x16c0;	#  DG8SAQ device
    set DG8SAQ_PRODUCT_ID	0x05dc
    set AUDIO_VENDOR_ID		0x16c0;	#  Internal Lab use
    set AUDIO_PRODUCT_ID	0x03e8
    set HPSDR_VENDOR_ID		0xfffe;	# Ozy Device
    set HPSDR_PRODUCT_ID	0x0007

    set ids [list \
		 $DG8SAQ_VENDOR_ID $DG8SAQ_PRODUCT_ID \
		 $AUDIO_VENDOR_ID $AUDIO_PRODUCT_ID \
		 $HPSDR_VENDOR_ID $HPSDR_PRODUCT_ID \
		]

    # DG8SAQ specific values

    set REQUEST_READ_VERSION			0x00
    set REQUEST_SET_DDRB			0x01
    set REQUEST_SET_PORTB			0x04
    set REQUEST_READ_EEPROM			0x11
    set REQUEST_FILTERS				0x17
    set REQUEST_SET_BPF_ADDRESS			0x18
    set REQUEST_READ_BPF_ADDRESS		0x19
    set REQUEST_SET_LPF_ADDRESS			0x1A
    set REQUEST_READ_LPF_ADDRESS		0x1B
    set REQUEST_SET_FREQ			0x30
    set REQUEST_SET_MULTIPLY_LO			0x31
    set REQUEST_SET_FREQ_BY_VALUE		0x32
    set REQUEST_SET_XTALL_FREQ			0x33
    set REQUEST_SET_STARTUP_FREQ		0x34
    set REQUEST_READ_MULTIPLY_LO		0x39	
    set REQUEST_READ_FREQUENCY			0x3A
    set REQUEST_READ_SMOOTH_TUNE_PPM		0x3B
    set REQUEST_READ_STARTUP			0x3C
    set REQUEST_READ_XTALL			0x3D
    set REQUEST_READ_REGISTERS			0x3F
    set REQUEST_SET_SI570_ADDR			0x41
    set REQUEST_SERIAL_ID			0x43
    set REQUEST_SET_PTT				0x50
    set REQUEST_READ_KEYS			0x51
    set REQUEST_FEATURES			0x71
    set FEATURE_SET_NVRAM			3
    set FEATURE_GET_NVRAM			4
    set FEATURE_SET_RAM				5
    set FEATURE_GET_RAM				6
    set FEATURE_GET_INDEX_NAME			7
    set FEATURE_GET_VALUE_NAME			8
    set FEATURE_GET_DEFAULT			9
}

#
# match vendor:product id pairs against the known list
#
proc dg8saq::match_vendor_product {vendor product} {
    variable ids
    foreach {v p} $ids {
	if {$v == $vendor && $p == $product} {
	    return 1
	}
    }
    return 0
}

proc dg8saq::default_values {} {
    return [list si570_addr [si570::default_addr] si570_startup [si570::default_startup] si570_xtal [si570::default_xtal] multiplier 4 ]
}

proc dg8saq::guess_nickname {h} {
    switch [handle::version $h] {
	14.0 { return qrp-2000 }
	15.12 {
	    # should check for lpf
	    return ensemble-rx
	}
	16.100 { return widget }
	default { return [handle::serial $h] }
    }
}

proc dg8saq::close {h} {
    handle::close $h
    usb::close [handle::handle $h]
    usb::unref_device [handle::device $h]
}

proc dg8saq::calibrate {h} {
    ## Si570 RECALL function
    set i2c [usb::device_to_host [handle::handle $h] 0x20 [expr {[handle::si570_addr $h] | (135 << 8)}] 0x01 "xxxxxxxx" 500]
    if {[string length $i2c] != 1} { error "failed resetting to factory frequency: [string length $buff]" }
    binary scan $i2c c i2c
    if {$i2c != 0} { error "failed resetting to factory frequency: $i2c" }
    set regs [get $h registers]
    set newXtallFreq [si570::calculate_xtal $regs [handle::si570_startup $h]]
    return [si570::validate_xtal $newXtallFreq]
}

proc dg8saq::get {h tag args} {
    return [eval get_$tag $h $args]
}

proc dg8saq::get_read_version {h} {
    variable REQUEST_READ_VERSION
    set version [usb::device_to_host [handle::handle $h] $REQUEST_READ_VERSION 0x0E00 0 "xxxxxxxxx" 500]
    if {[string length $version] != 2} { error "failed to read version: [string length $buff]" }
    binary scan $version cc minor major
    return [format %d.%d $major $minor]
}

proc dg8saq::get_frequency_by_value {h} {
    variable REQUEST_READ_FREQUENCY
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_FREQUENCY 0 0 "xxxxxxxxx" 500]
    if {[string length $buff] != 4} { error "failed to read frequency: [string length $buff]" }
    binary scan $buff i ifreq
    return [expr {double($ifreq)/ (1<<21)}]
}

proc dg8saq::get_registers {h} {
    variable REQUEST_READ_REGISTERS
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_REGISTERS [handle::si570_addr $h] 0 "xxxxxxxx" 500]
    if {[string length $buff] != 6} { error "failed to read registers: [string length $buff]" }
    binary scan $buff c* regs
    foreach r $regs {
	lappend result [format 0x%02x [expr {$r&0xFF}]]
    }
    return $result
}

proc dg8saq::get_frequency {h} {
    return [si570::calculate_frequency [get $h registers] [handle::si570_xtal $h]]
}

proc dg8saq::get_read_keys {h} {
    variable REQUEST_READ_KEYS
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_KEYS 0 0 "xxxxxxxx" 500]
    if {[string length $buff] != 1} { error "failed to read keys: [string length $buff]" }
    binary scan $buff c k
    return [expr {$k&0xFF}]
}

proc dg8saq::get_ptt {h} {
    # ptt is active high?  I think that's wrong.
    return [expr {([get $h read_keys] & 0x40) ? 1 : 0}]
}

proc dg8saq::get_keys {h} {
    # keys are active low
    # note we mask in hex but match in decimal
    switch [expr {[get $h read_keys] & 0x22}] {
	0 { return 3 }
	2 { return 1 }
	32 { return 2 }
	34 { return 0 }
    }
}

proc dg8saq::get_startup_freq {h} {
    # note, this is not the si570 startup frequency, it's the operating startup frequency
    variable REQUEST_READ_STARTUP
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_STARTUP 0 0 "xxxxxxxx" 500]
    if {[string length $buff] != 4} { error "failed to read startup: [string length $buff]" }
    # requires config for softrock: multiplier
    binary scan $buff i ifreq
    return [expr {(double($ifreq) / (1<<21)) / [handle::multiplier $h]}]
}

proc dg8saq::get_xtal_freq {h} {
    variable REQUEST_READ_XTALL
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_XTALL 0 0 "xxxxxxxx" 500]
    if {[string length $buff] != 4} { error "failed to read xtall: [string length $buff]" }
    binary scan $buff i ifreq
    return [expr {double($ifreq) / (1<<24)}]
}

proc dg8saq::get_si570_address {h} {
    variable REQUEST_SET_SI570_ADDR
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_SET_SI570_ADDR 0 0 "xxxxxxxx" 500]
    if {[string length $buff] != 1} { error "failed to set si570 addr: [string length $buff]"
    }
    binary scan $buff c addr
    return [expr {$addr & 0xFF}]
}

proc dg8saq::get_multiply_lo {h band} {
    variable REQUEST_READ_MULTIPLY_LO
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_MULTIPLY_LO 0 $band "xxxxxxxx" 500]
    if {[string length $buff] != 8} { error "failed to read multiply LO: [string length $buff]"
    }
    binary scan $buff ii sub mul
    return [list [expr {double($sub) / (1<<21)}] [expr {double($mul) / (1<<21)}]]
}

proc dg8saq::get_smooth_tune_ppm {h} {
    variable REQUEST_READ_SMOOTH_TUNE_PPM
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_SMOOTH_TUNE_PPM 0 0 "xxxxxxxx" 500]
    if {[string length $buff] != 2} {
	error "failed to read smooth tune ppm"
    }
    binary scan $buff s ppm
    return $ppm
}

proc dg8saq::get_filters {h is_lpf} {
    variable REQUEST_FILTERS
    set index [expr {$is_lpf ? 255+256 : 255}]
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_FILTERS 0 $index "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 500]
    binary scan $buff s* crossovers
    return $crossovers
}

proc dg8saq::get_bpf_addresses {h} {
    variable REQUEST_READ_BPF_ADDRESS
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_BPF_ADDRESS 0 0 "xxxxxxxxxxxxxxxx" 500]
    if {[string length $buff] > 0} {
	binary scan $buff c* addrs
	return $addrs
    } else {
	return {}
    }
}

proc dg8saq::get_lpf_addresses {h} {
    variable REQUEST_READ_LPF_ADDRESS
    set buff [usb::device_to_host [handle::handle $h] $REQUEST_READ_LPF_ADDRESS 0 0 "xxxxxxxxxxxxxxxx" 500]
    if {[string length $buff] > 0} {
	binary scan $buff c* addrs
	return $addrs
    } else {
	return {}
    }
}

proc dg8saq::get_bands {h} {
    set crossovers [get $h filters 0]
    if {[llength $crossovers] == 0} {
	return {}
    }
    set enabled [lindex $crossovers end]
    set bands [list enabled $enabled]
    if {$enabled} {
	set start 0
	set index [get $h bpf_addresses]
	if {[llength $index] == 0} {
	    # generate a default list
	    for {set i 0} {$i < [llength $crossovers]} {incr i} {
		lappend index $i
	    }
	}
	foreach b $index c [lrange $crossovers 0 end-1] {
	    foreach {sub mul} [get $h multiply_lo $b] break
	    set band [list start $start]
	    if {[string length $c] > 0} {
		set stop [expr {double($c) / (1 << 5)}]
		lappend band stop $stop
		set start $stop
	    }
	    lappend band sub $sub mul $mul
	    lappend bands $b $band
	}
    }
    return $bands
}

proc dg8saq::get_lpfs {h} {
    set crossovers [get $h filters 1]
    if {[llength $crossovers] == 0} {
	return {}
    }
    set enabled [lindex $crossovers end]
    set bands [list enabled $enabled]
    if {$enabled} {
	set start 0
	set index [get $h bpf_addresses]
	if {[llength $index] == 0} {
	    # generate a default list
	    for {set i 0} {$i < [llength $crossovers]} {incr i} {
		lappend index $i
	    }
	}
	foreach b $index c [lrange $crossovers 0 end-1] {
	    foreach {sub mul} [get $h multiply_lo $b] break
	    set band [list start $start]
	    if {[string length $c] > 0} {
		set stop [expr {double($c) / (1 << 5)}]
		lappend band stop $stop
		set start $stop
	    }
	    lappend bands $b $band
	}
    }
    return $bands
}

proc dg8saq::get_bpf_crossovers {h} {
    set crossovers [get $h filters 0]
    if {[llength $crossovers] == 0} {
	return {}
    }
    set result [list enabled [lindex $crossovers end]]
    foreach c [lrange $crossovers 0 end-1] {
	lappend result [expr {double($c) / (1 << 5)}]
    }
    return $result
}

proc dg8saq::get_lpf_crossovers {h} {
    set crossovers [get $h filters 1]
    if {[llength $crossovers] == 0} {
	return {}
    }
    set result [list enabled [lindex $crossovers end]]
    foreach c [lrange $crossovers 0 end-1] {
	lappend result [expr {double($c) / (1 << 5)}]
    }
    return $result
}

proc dg8saq::put {h tag args} {
    return [eval dg8saq::put_$tag $h $args]
}

proc dg8saq::put_ptt {h ptt} {
    return [usb::device_to_host [handle::handle $h] $ptt 0 "xxxxxxxx" 500]
}

proc dg8saq::put_frequency {h frequency} {
    variable REQUEST_SET_FREQ
    set value [expr {0x700 | [handle::si570_addr $h]}]
    set f [expr {$frequency * [handle::multiplier $h]}]
    set regs [si570::calculate_registers $f [handle::si570_xtal $h]]
    set buffer [binary format c* $regs]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_FREQ $value 0  500]
    if {[string length $result] != 2} { error "failed to set freq: [string length $result]" }
}

proc dg8saq::put_frequency_by_value {h frequency} {
    variable REQUEST_SET_FREQ_BY_VALUE
    set value [expr {0x700 | [handle::si570_addr $h]}]
    set buffer [binary format i [expr {int(round($frequency * (1<<21)))}]]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_FREQ_BY_VALUE $value 0 $buffer 500]
    if {[string length $result] != 4} { error "failed to set freq by value: [string length $result]" }
    binary scan $result i result
    puts "put_frequency_by_value $frequency -> [expr {int(round($frequency * (1<<21)))}] -> $result -> [expr {double($result)/(1<<21)}]"
}

proc dg8saq::put_startup_freq {h startup_freq} {
    variable REQUEST_SET_STARTUP_FREQ
    set buffer [binary format i [expr {int($startup_freq * [handle::multiplier $h] * (1 << 21))}]]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_STARTUP_FREQ 0 0 $buffer 500]
    if {[string length $result] != 2} { error "failed to set startup freq: [string length $result]" }
}

##
## this sets the firmware's value for the si570 crystal frequency
## used to compute the si570 registers for a requested frequency
##
proc dg8saq::put_xtal_freq {h xtal} {
    variable REQUEST_SET_XTALL_FREQ
    set buffer [binary format i [expr {int($xtal * (1<<24))}]]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_XTALL_FREQ 0 0 $buffer 500]
    if {[string length $result] != 2} { error "failed to set xtal freq: [string length $result]" }
}

##
## this sets the firmware's i2c address for the si570
##
proc dg8saq::put_si570_address {h new_addr} {
    variable REQUEST_SET_SI570_ADDR
    set buffer [binary format c $new_addr]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_SI570_ADDR 0 $new_addr $buffer 500]
    if {[string length $result] != 2} { error "failed to set si570 addr: [string length $result]" }
}

##
## this sets the firmware frequency manipulation
##
proc dg8saq::put_multiply_lo {h band mul sub} {
    variable REQUEST_SET_MULTIPLY_LO
    set buffer [binary format ii [expr {int($sub * (1<<21))}] [expr {int($mul * (1<<21))}]]
    set result [usb::host_to_device [handle::handle $h] $REQUEST_SET_MULTIPLY_LO 0 $band $buffer 500]
    if {[string length $result] != 8} { error "failed to set multiply LO $band $mul $sub" }
}

##
## this is used to scramble the order of the band pass filters
##
proc dg8saq::put_bpf_address {h index value} {
    variable REQUEST_SET_BPF_ADDRESS
    set result [usb::device_to_host [handle::handle $h] $REQUEST_SET_BPF_ADDRESS $value $index "xxxxxxxxxxxxxxxxxx" 500]
    if {[string length $result] != 16} { error "failed to set bpf address: [string length $result]" }
}

##
## this sets the band pass crossover frequency for band #index
##
proc dg8saq::put_bpf_crossover {h index freq} {
    variable REQUEST_FILTERS
    ## get the current bandpass crossover points
    set crossovers [get $h bpf_crossover]
    ## is there a place for this new value?
    if {[llength $crossovers] < $index+1} { error "cannot set crossover for band $index" }
    ## put the new value into the set
    set crossovers [lreplace $crossovers $index $index [expr {int($freq * (1<<5))}]]
    ## set them all
    for {set i 0} {$i < [llength $crossovers]-1} {incr i} {
	## no check for return value?
	usb::device_to_host [handle::handle $h] $REQUEST_FILTERS [lindex $crossovers $i] $i "" 500
    }
}

##
## this enables the automatic bandpass filter switching
##
proc dg8saq::put_bpf {h enable} {
    #void setBPF(usb_dev_handle *handle, int enable) {
    #    unsigned short FilterCrossOver[16];        // allocate enough space for up to 16 filters
    #    int nBytes;
    #
    #    // first find out how may cross over points there are for the 1st bank, use 255 for index
    #    nBytes = usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, 0, 255, (char *) FilterCrossOver, sizeof(FilterCrossOver), 500);
    #  
    #    if (nBytes > 2) {
    #
    #	nBytes = usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, enable, (nBytes / 2) - 1, (char *) FilterCrossOver, sizeof(FilterCrossOver), 500);
    #
    #	printf("Filter Bank 1:\n");
    #	int i;
    #	for (i = 0; i < (nBytes / 2) - 1; i++) {
    #						printf("  CrossOver[%d] = %f\n", i, (double) FilterCrossOver[i] / (1UL << 5));
    #					    }
    #	printf("  BPF Enabled: %d\n", FilterCrossOver[(nBytes / 2) - 1]); 
    #
    #    }	
    #}
    #
}

##
## this allows the order of the low pass filters to be scrambled
##
proc dg8saq::put_lpf_address {h index value} {
    variable REQUEST_SET_LPF_ADDRESS
    set result [usb::device_to_host [handle::handle $h] $REQUEST_SET_LPF_ADDRESS $value $index "xxxxxxxxxxxxxxxxxx" 500]
    if {[string length $result] != 16} { error "failed to set lpf address" }
}

##
## this sets the low pass filter crossover frequency for low pass #index
##
proc dg8saq::put_lpf_crossover {h index freq} {
    #void setLPFCrossOver(usb_dev_handle *handle, int index, float newFreq) {
    #    unsigned short FilterCrossOver[16];        // allocate enough space for up to 16 filters
    #    int nFilters;
    #
    #    // first find out how may cross over points there are for the 2nd bank, use 256+255 for index
    #    //nBytes = usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, 0, 256+255, (char *) FilterCrossOver, sizeof(FilterCrossOver), 500);
    #    nFilters = readFilters(handle, TRUE, FilterCrossOver, sizeof(FilterCrossOver));
    #
    #    if (nFilters > 0) {
    #	FilterCrossOver[index] = newFreq * (1<<5);
    #	int i;
    #	// even if we just set one point, we have to set all
    #	for (i = 0; i < nFilters - 1; i++) 
    #	usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, FilterCrossOver[i], 256+i, NULL, 0, 500);
    #	// read out the values when setting the flag.
    #	usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, FilterCrossOver[i], 256+i, (char *) FilterCrossOver, sizeof(FilterCrossOver), 500);
    #	displayLPFtable(handle, FilterCrossOver, nFilters);
    #    }
    #}
    #
}

##
## this enables the automatic low pass filter switching
##
proc dg8saq::put_lpf {h enable} {
    #void setLPF(usb_dev_handle *handle, int enable) {
    #    unsigned short FilterCrossOver[16];        // allocate enough space for up to 16 filters
    #    int nBytes;
    #
    #    // first find out how may cross over points there are for the 2nd bank, use 256+255 for index
    #    nBytes = usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, 0, 256+255, (char *) FilterCrossOver, sizeof(FilterCrossOver), 500);
    #  
    #    if (nBytes > 2) {
    #
    #	nBytes = usb_control_msg(handle, USB_TYPE_VENDOR | USB_RECIP_DEVICE | USB_ENDPOINT_IN, REQUEST_FILTERS, enable, 256 + (nBytes / 2) - 1, NULL, 0, 500);
    #
    #    }	
    #}
    #
}

##
## serial number last digit hacking
##
proc dg8saq::get_serial_id {h} {
    return [put_serial_id $h 0]
}

proc dg8saq::put_serial_id {h b} {
    set buff [usb::device_to_host [handle::handle $h] $dg8saq::REQUEST_SERIAL_ID $b 0 "xxxxxxxx" 500]
    if {[string length $buff] == 1} {
	binary scan $buff c result
	puts [format "dg8saq::put_serial_id: device_to_host returned buffer of length 1 containing %c (0x%02x)" $result $result]
	if {($result >= 48 && $result <= 57) || ($result >= 65 && $result <= 90)} {
	    return [format %c $result]
	} else {
	    return {}
	}
    } else {
	puts "dg8saq::put_serial_id: device_to_host returned buffer of length [string length $buff]"
	return {}
    }
}

##
## feature management for widget
##
proc dg8saq::_get_feature_value {h index offs} {
    set buff [usb::device_to_host [handle::handle $h] $dg8saq::REQUEST_FEATURES $index $offs "xxxxxxxx" 500]
    if {[string length $buff] < 1} {
	return -1
    }
    binary scan $buff c value
    return $value
}
    
proc dg8saq::_get_features {h index} {
    set n [_get_feature_value $h $index 0]
    lappend features $n
    for {set i 1} {$i < $n} {incr i} {
	lappend features [_get_feature_value $h $index $i]
    }
    return $features
}

proc dg8saq::_get_feature_string {h index offs} {
    set buff [usb::device_to_host [handle::handle $h] $dg8saq::REQUEST_FEATURES $index $offs "xxxxxxxxxxxxxxxxxxxx" 500]
    binary scan $buff c* reversed_chars
    set string {}
    foreach s $reversed_chars {
	set string [format %c%s $s $string]
    }
    return $string
}

proc dg8saq::_get_feature_strings {h index max} {
    set strings {}
    for {set i 0} {$i < $max} {incr i} {
	lappend strings [_get_feature_string $h $index $i]
    }
    return $strings
}

proc dg8saq::get_features_ram {h} {
    return [_get_features $h $dg8saq::FEATURE_GET_NVRAM]
}

proc dg8saq::get_features_nvram {h} {
    return [_get_features $h $dg8saq::FEATURE_GET_RAM]
}

proc dg8saq::get_features_default {h} {
    return [_get_features $h $dg8saq::FEATURE_GET_DEFAULT]
}

proc dg8saq::get_feature_index_names {h} {
    return [_get_feature_strings $h $dg8saq::FEATURE_GET_INDEX_NAME [_get_feature_value $h $dg8saq::FEATURE_GET_DEFAULT 0]]
}

proc dg8saq::get_feature_value_names {h} {
    return [_get_feature_strings $h $dg8saq::FEATURE_GET_VALUE_NAME [_get_feature_value $h $dg8saq::FEATURE_GET_DEFAULT 1]]
}

proc dg8saq::_put_feature_value {h index findex fvalue} {
    set buff [usb::device_to_host [handle::handle $h] $dg8saq::REQUEST_FEATURES [expr {$findex | ($fvalue << 8)}] "xxxxxxxx" 500]
    if {[string length $buff] != 1} {
	return -1
    }
    return 0
}

proc dg8saq::_put_features {h index f} {
    for {set i 2} {$i < [llength $f]} {incr i} {
	_put_feature_value $h $index $i [lindex $f $i]
    }
}

proc dg8saq::put_features_nvram {h f} {
    _put_features $h $dg8saq::FEATURE_SET_NVRAM $f
}

proc dg8saq::put_features_ram {h f} {
    _put_features $h $dg8saq::FEATURE_SET_RAM $f
}
