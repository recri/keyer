package provide spectrum 1.0.0

package require Tk
package require sdrkit

namespace eval ::spectrum {}

proc spectrum::capture {w n p tap fft} {
    foreach {f b} [$tap $n] break
    set l [$fft $b]
    binary scan $l f* levels
    set x 0
    foreach y $levels {
	lappend xy $x $y
	incr x
    }
    $w.c coords spectrum $xy
    after $p [list spectrum::capture $w $n $tap $fft]
}

proc spectrum {w n p} {
    ttk::frame $w
    ::sdrkit::atap spectrum_tap
    ::sdrkit::spectrum spectrum_fft $n
    pack [canvas $w.c -width 512 -height 128] -side top -fill both -expand true
    $w.c create line 0 0 0 0 -tag spectrum
    spectrum::capture $w $n $p spectrum_tap spectrum_fft]
}