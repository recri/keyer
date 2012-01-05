package provide sfftw 1.0
package require Sfftw
if {0} {
    package require Ffidl 0.5
}

namespace eval ::sfftw:: {
    # library pointers for linux
    set dir /usr/local/lib
    set lib1 [file join $dir libsfftw.so]
    set lib2 [file join $dir libsrfftw.so]

    # flags for direction
    set FFTW_FORWARD -1
    set FFTW_BACKWARD 1

    # flags for the planner
    set FFTW_ESTIMATE 0
    set FFTW_MEASURE  1
    set FFTW_OUT_OF_PLACE 0
    set FFTW_IN_PLACE 8
    set FFTW_USE_WISDOM 16
    set FFTW_THREADSAFE 128;		# guarantee plan is read-only so that the
				        # same plan can be used in parallel by
				        # multiple threads

    if {0} {
	# complex short float one dimensional transform
	::ffidl::callout ::sfftw::fftw_create_plan_specific {int int int pointer-var int pointer-var int} pointer \
	    [::ffidl::symbol $lib1 fftw_create_plan_specific]
	::ffidl::callout ::sfftw::fftw_create_plan {int int int} pointer \
	    [::ffidl::symbol $lib1 fftw_create_plan]
	::ffidl::callout ::sfftw::fftw_print_plan {pointer} void \
	    [::ffidl::symbol $lib1 fftw_print_plan]
	::ffidl::callout ::sfftw::fftw_destroy_plan {pointer} void \
	    [::ffidl::symbol $lib1 fftw_destroy_plan]
	::ffidl::callout ::sfftw::fftw {pointer int pointer-var int int pointer-var int int} void \
	    [::ffidl::symbol $lib1 fftw]
	::ffidl::callout ::sfftw::fftw_one {pointer pointer-var pointer-var} void \
	    [::ffidl::symbol $lib1 fftw_one]
	
	# wisdom management
	::ffidl::callout ::sfftw::fftw_forget_wisdom {} void \
	    [::ffidl::symbol $lib1 fftw_forget_wisdom]
	::ffidl::callout ::sfftw::fftw_export_wisdom {} pointer-utf8 \
	    [::ffidl::symbol $lib1 fftw_export_wisdom_to_string]
	::ffidl::callout ::sfftw::fftw_import_wisdom {pointer-utf8} pointer-utf8 \
	    [::ffidl::symbol $lib1 fftw_import_wisdom_from_string]
	
	# real short float one dimensional transform
	::ffidl::callout ::sfftw::rfftw_create_plan_specific {int int int pointer-var int pointer-var int} pointer \
	    [::ffidl::symbol $lib2 rfftw_create_plan_specific]
	::ffidl::callout ::sfftw::rfftw_create_plan {int int int} pointer \
	    [::ffidl::symbol $lib2 rfftw_create_plan]
	::ffidl::callout ::sfftw::rfftw_print_plan {pointer} void \
	    [::ffidl::symbol $lib2 rfftw_print_plan]
	::ffidl::callout ::sfftw::rfftw_destroy_plan {pointer} void \
	    [::ffidl::symbol $lib2 rfftw_destroy_plan]
	::ffidl::callout ::sfftw::rfftw {pointer int pointer-var int int pointer-var int int} void \
	    [::ffidl::symbol $lib2 rfftw]
	::ffidl::callout ::sfftw::rfftw_one {pointer pointer-var pointer-var} void \
	    [::ffidl::symbol $lib2 rfftw_one]
	
	# clean up
	unset dir
	unset lib1
	unset lib2
    }
}

proc ::sfftw::rfftw_create_plan {n dir flags} {
    return [::rfftw_create_plan $n $dir $flags]
}
proc ::sfftw::rfftw_one {plan in out} {
    upvar $in inb
    upvar $out outb
    return [::rfftw_one $plan $inb $outb]
}
proc ::sfftw::fftw_export_wisdom {} {
    return [::fftw_export_wisdom]
}
proc ::sfftw::fftw_import_wisdom {wisdom} {
    ::fftw_import_wisdom $wisdom
}
