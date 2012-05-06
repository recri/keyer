package provide usb 1.0

##
## usb strings come back as utf16
## convert to tcl utf8 format
##

namespace eval usb {}

proc usb::convert_string {usb_string} {
    binary scan $usb_string ccs* count type chars
    set string {}
    foreach c $chars {
	append string [format %c $c]
    }
    # puts "got string $count bytes of $type type $chars and made \"$string\""
    return $string
}

# control transfers with specific request types
proc usb::device_to_host {handle request value index buffer timeout} {
    return [control_transfer $handle [expr {$usb::REQUEST_TYPE_VENDOR|$usb::RECIPIENT_DEVICE|$usb::ENDPOINT_IN}] $request $value $index $buffer $timeout]
}

proc usb::host_to_device {handle request value index buffer timeout} {
    return [control_transfer $handle [expr {$usb::REQUEST_TYPE_VENDOR|$usb::RECIPIENT_DEVICE|$usb::ENDPOINT_OUT}] $request $value $index $buffer $timeout]
}

