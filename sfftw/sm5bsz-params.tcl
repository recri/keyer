package provide sm5bsz-params 1.0

namespace eval ::sm5bsz-params:: {
    
    set PI [expr {atan2(0,-1)}]

    #
    # these are the defined names and values for
    # the general parameters of the sm5bsz dsp program
    # at version 00-14.  note that there are several
    # other "parameters" scattered around the program
    #
    array set dnames {
	0 {FIRST_FFT_BANDWIDTH "First FFT bandwidth (Hz)" scale}
	1 {FIRST_FFT_SINPOW "First FFT window (power of sin)" scale}
	2 {FIRST_FFT_VERNR "First forward FFT version" null}
	3 {FIRST_FFT_MAX_AVGTIM "First FFT max avg time (s)" scale}
	4 {FIRST_FFT_GAIN "First FFT amplitude" scale}

	5 {SECOND_FFT_ENABLE "Enable second FFT" checkbutton}

	6 {FIRST_BCKFFT_VERNR "First backward FFT version" null}
	7 {FIRST_BCKFFT_ATT_N "First backward FFT att. N" scale}

	8 {SELLIM_STON "Selective limiter S/N" scale}

	9 {SECOND_FFT_NINC "Second FFT bandwidth factor in powers of 2" scale}
	10 {SECOND_FFT_SINPOW "Second FFT window (power of sin)" scale}
	11 {SECOND_FFT_VERNR "Second forward FFT version" null}
	12 {SECOND_FFT_ATT_N "Second forward FFT att. N" scale}
	13 {SECOND_FFT_AVGTIM "Second FFT average time (s)" scale}

	14 {AFC_ENABLE "Enable AFC" checkbutton}
	15 {AFC_AVGTIM "AFC averaging time (s)" scale}
	16 {AFC_DELAY "AFC delay (%)" scale}
	17 {AFC_MIN_STON "AFC min S/N (dB)" scale}
	18 {AFC_LOCK_RANGE "AFC lock range Hz" scale}
	19 {AFC_MAX_DRIFT "AFC max drift Hz/minute" scale}

	20 {MIX1_BANDWIDTH_REDUCTION_N "First mixer bandwidth reduction in powers of 2" scale}
	21 {MIX1_NO_OF_CHANNELS "First mixer no of channels" scale}

	22 {BASEBAND_STORAGE_TIME "Baseband storage time (s)" scale}

	23 {OUTPUT_DELAY_MARGIN "Output delay margin (0.1sek)" scale}

	24 {DA_OUTPUT_SPEED "Output sampling speed (Hz)" scale}

	25 {OUTPUT_MODE "Default output mode" scale}

	-1 {INT_PARM}
	26 {FFT1_AVGNUM}
	27 {WATERFALL_AVGNUM}
	28 {FFT2_AVGNUM}
	29 {FFT3_AVGNUM}

	-1 {FLOAT_PARM}
	30 {WATERFALL_DB_ZERO}
	31 {WATERFALL_DB_GAIN}

	-1 {WIDE_GRAPH}
	32 {WG_YSCALE} 
	33 {WG_YZERO}
	34 {WG_FQMIN}
	35 {WG_FQMAX}

	-1 {HIRES_GRAPH}
	36 {HG_BLN} 
	37 {HG_TIMF2_STATUS}

	-1 {BASEBAND_GRAPH}
	38 {BG_YSCALE}
	39 {BG_YZERO}
	40 {BG_RESOLUTION}
	41 {BG_OSCILLOSCOPE}
	42 {BG_OSC_INCREASE}
	43 {BG_OSC_DECREASE}
	44 {BG_PIX_PER_PNT}

	-1 {AFC_GRAPH}
	45 {AG_TIMECALE}
	46 {AG_FQMIN}
	47 {AG_FQMAX}

	-1 {POL_GRAPH}
	48 {PG_ANGLE}
	49 {PG_CIRC}
	50 {PG_AUTO}
    }

    # weak signal cw parameters
    set wcw {200,3,0, 4,D,1,0,6,15, 2,0,0, 7, 5,0, 5,25, 6,150, 100, 4,1,H,5,K,0}
    # minimum parameters
    set min {  0,0,0, 0,1,0,0,0, 2, 0,0,0, 2, 0,0, 0, 1, 1,  1,   0, 1,1,9,0,H,0}
    # maximum parameters
    set max {400,9,B,30,E,1,C,9, F,10,4,G,16,30,1,15,50,30,500,1000,10,A,D,H,E,9}
    # translations of symbols in wcw, min, and max
    array set subst {
	A MAX_MIX1
	B MAX_FFT1_VERNR
	C MAX_FFT1_BCKVERNR
	D 1000
	E 1000000
	F 10000
	G MAX_FFT2_VERNR
	H 60
	K 6000
	MAX_MIX1 8
	MAX_FFT1_VERNR 8
	MAX_FFT1_BCKVERNR 4
	MAX_FFT2_VERNR 4
    }
    # clean up those parameters
    foreach p {wcw min max} {
	set new {}
	set old [set $p]
	foreach v [split $old ,] {
	    set v [string trim $v]
	    while {[info exists subst($v)]} {
		set v $subst($v)
	    }
	    lappend new $v
	}
	set $p $new
	# puts "$p old $old new $new"
    }
    # derived values
    set derived {
	input_sample_rate {inputRate from audio page}
	fft1_interleave_ratio {First FFT adjustment for window}
	fft1_size {First FFT size (points)}
	fft1_n {First FFT power of two}
	fft1_interleave_points {First FFT overlap between transforms}
	fft1_frequency {Number of fft1's per second}
	fft1_min_avg_num {Number of fft1's per display update}
    }
}

#
# the fft's are real or complex depending on whether we're using a plain receiver
# or an I/Q receiver.  The I/Q signals from a dual mixer DC radio are a complex
# data stream which comes in as a stereo channel.  We may have one I/Q
# channel, or we may have several to process.
# 
# the "First FFT bandwidth (Hz)" translates to the number of points
# required for the first fft as 0.5*inputRate / FIRST_FFT_BANDWIDTH,
# however the sin^n windowing alters this.  Default bandwidth is 200.
#
# the "First FFT window (power of sin)" defaults to 3, and that gets
# put into a function called fft0.c/make_window().  This 

proc sm5bsz-params-page {w} {
    set ::sm5bsz-params::w $w
    upvar \#0 ::sm5bsz-params::data data
    upvar \#0 ::sm5bsz-params::dnames dnames
    upvar \#0 ::sm5bsz-params::derived derived
    upvar \#0 ::sm5bsz-params::wcw wcw
    upvar \#0 ::sm5bsz-params::min min
    upvar \#0 ::sm5bsz-params::max max

    # build our table
    foreach i [lsort -integer [array names dnames]] {
	if {$i == -1} continue
	if {$i == 26} break
	foreach {name title widget} $dnames($i) break
	set data($name) [lindex $wcw $i]
	set minv [lindex $min $i]
	set maxv [lindex $max $i]
	grid [label $w.l$i -text "$title:"] -row $i -column 0 -sticky e
	switch $widget {
	    scale {
		grid [label $w.v$i -textvar ::sm5bsz-params::data($name) -width 7] -row $i -column 1
		grid [scale $w.s$i -orient horizontal -from $minv -to $maxv -showvalue no \
			  -variable ::sm5bsz-params::data($name) -command ::sm5bsz-params::update] -row $i -column 2
	    }
	    checkbutton {
		grid [checkbutton $w.e$i -variable ::sm5bsz-params::data($name) -command ::sm5bsz-params::update] -row $i -column 1
	    }
	    null {
		grid [label $w.v$i -text N/A] -row $i -column 1
	    }
	    default {
		error "unknown widget in sm5bsz-params: $dnames($i)"
	    }
	}
    }
    set row 0
    foreach {name title} $derived {
	grid [label $w.x$name -text $name] -row $row -column 3
	incr row
    }
    ::sm5bsz-params::update
}

proc sm5bsz-params-raise {} {
    upvar \#0 ::sm5bsz-params::w w
    upvar \#0 ::sm5bsz-params::data data

    # recompute derived parameters
    ::sm5bsz-params::update-tail
}
proc sm5bsz-params-leave {} {
    upvar \#0 ::sm5bsz-params::w w
    return 1
}

proc sm5bsz-params-get {} {
    upvar \#0 ::sm5bsz-params::data data
    return [array get data]
}

proc ::sm5bsz-params::update {args} {
    variable w
    variable data
    catch {after cancel $data(update-after)}
    set data(update-after) [after 100 ::sm5bsz-params::update-tail]
}

proc ::sm5bsz-params::update-tail {} {   
    variable w
    variable data
    variable derived
    variable PI

    # fetch external parameters
    set data(input_sample_rate) [audio-get inputRate]

    #
    # First find size of first fft, as determined by the bandwidth requested.
    #
    # In case a window was selected we need more points for the bandwidth.
    # Make fft1_interleave_ratio the distance between the points where the
    # window function is 0.5. Assume resolution is reduced by this factor.
    #
    if {$data(FIRST_FFT_SINPOW) == 0} {
	set data(fft1_interleave_ratio) 0
    } else {
	set data(fft1_interleave_ratio) [expr {2*asin(pow(0.5,1.0/$data(FIRST_FFT_SINPOW)))/$PI}]
    }

    #
    # now compute the points needed to supply the bandwidth
    #
    if {$data(FIRST_FFT_BANDWIDTH) == 0} {
	set data(fft1_size) 65536
    } else {  
	set data(fft1_size) [expr {(0.5*$data(input_sample_rate)) / ((1-$data(fft1_interleave_ratio))*$data(FIRST_FFT_BANDWIDTH))}]
    }

    #
    # data(fft1_size) is the number of points we need for the whole transform to get the desired bandwidth.
    # Make data(fft1_size) a power of two.
    #
    for {set data(fft1_n) 0} {1<<$data(fft1_n) < 1.5*$data(fft1_size)} {incr data(fft1_n)} {}

    #
    # Never make the size below n=7 (=128)
    # Note that i becomes small so we arrive at fft1_n=7
    #
    if {$data(fft1_n) < 8} { set data(fft1_n) 8 }
    if {double(1<<$data(fft1_n))/$data(fft1_size) > 1.5} {
	incr data(fft1_n) -1
    }
    set data(fft1_size) [expr {1<<$data(fft1_n)}]
    set data(fft1_window_size) $data(fft1_size)
    
    #
    # Get number of points to overlap transforms so window function does
    # not drop below 0.5.
    # In this way all points contribute by approximately the same amount
    # to the averaged power spectrum.
    #
    set data(fft1_interleave_points) [expr {int(1+$data(fft1_interleave_ratio)*$data(fft1_size))&0xfffe}]
    
    #
    # The value of fft1_interleave_points along with the input sample rate
    # determines how often we compute fft1.
    #
    set data(fft1_frequency) [expr {double($data(input_sample_rate))/$data(fft1_interleave_points)}]
    
    #
    # The refresh rate of the monitor sets an absolute upper limit on the number of updates
    # to the displays driven by fft1.  We should average together everything that cannot be
    # displayed in detail, and by default we only attempt to update the spectrum display at
    # 10hz.
    set data(fft1_min_avg_num) [expr {int($data(fft1_frequency)/10)}]

    # *******************************************************
    # Get the sizes for the second fft and the first mixer
    # The first frequency mixer shifts the signal in timf1 or timf2 to
    # the baseband.
    # Rather tham multiplying with a sin/cos table of the selected frequency
    # we use the corresponding fourier transforms from which a group of lines
    # are selected, frequency shifted and back transformed.
#    set data(mix1_n) [expr {$data(fft1_n)-$data(MIX1_BANDWIDTH_REDUCTION_N)}];
#    if {$data(SECOND_FFT_ENABLE) == 0} {
#	set data(fft2_size) 0
#	set data(timf2_size) 0
#	# If we get signals from back transformation of fft1
#	# we use an interleave ratio that makes the interleave points
#	# go even up in mix1_size.     
#	if {$data(mix1_n) < 3} { set data(mix1_n) 3 }
#	set data(mix1_size) [expr {1<<$data(mix1_n)}]
#	set data(mix1_interleave_points) [expr {int($data(fft1_interleave_ratio)*$data(mix1_size)) & 0xfffffffe}]
#	set data(fft1_interleave_points) [expr {$data(mix1_interleave_points)*($data(fft1_size)/$data(mix1_size))}]
#	fft1_block_timing
#	set data(timf3_sampling_speed) [expr {$data(timf1_sampling_speed)/$data(fft1_size)}]
#    } else {
#	if(fft1_n > 14) goto reduce_fft1_size;
#	# Make the time constant for the blanker noise floor about 1 second.
#	# The first fft outputs data in blocks of fft1_new_points
#	fft1_block_timing
#	set j [expr {double($data(input_sample_rate)+$data(fft1_new_points)/2)/$data(fft1_new_points)}]
#	if {$j < 1} { set j 1 }
#	set data(timf2_noise_floor_avgnum) $j
#	set data(blanker_info_update_counter) 0
#	set data(fft1_lowlevel_fraction) 0.75
#	set j [expr {$j / 8}]
#	if { $j < 1 } { set j 1 }
#	set data(blanker_info_update_interval) $j
#	set data(timf2_display_interval) [expr {$data(timf2_noise_floor_avgnum)/10 }
#	timf2_ovfl=0;
#	timf2_display_counter=0;
#	timf2_display_maxpoint=0;
#	timf2_display_maxval=0;
#	if(genparm[SECOND_FFT_SINPOW] != 0) {
#	    t1=pow(0.5,1.0/genparm[SECOND_FFT_SINPOW]);
#	    fft2_interleave_ratio=2*asin(t1)/PI;
#	} else {
#	    fft2_interleave_ratio=0;
#	}
#	j=bwfac<<(genparm[SECOND_FFT_NINC]+1);
#	# j is the number of points we need for the whole transform to get the
#	# desired bandwidth. (2<<n narrower compared to fft1)
#	# Make j a power of two.
#	fft2_n=1;
#	i=j;
#	while(j != 0) {
#	    j/=2;
#	    fft2_n++;
#	}
#	# Never make the number of points below fft1_n
#	# Note that i is small now so size is reduced one step.
#	if(fft2_n < fft1_n+1)fft2_n=fft1_n+1; 
#	fft2_size=1<<fft2_n;
#	if( (float)(fft2_size)/i > 1.5) {
#	    reduce_fft2_size:;    
#	    fft2_size/=2;
#	    fft2_n--;
#	} 
#	if(fft_cntrl[FFT2_CURMODE].mmx == 0 && fft2_n>16)goto reduce_fft2_size;
#	fft2_interleave_points=1+fft2_interleave_ratio*fft2_size;
#	fft2_interleave_points&=0xfffe;
#	# Keep fft2 transforms for genparm[SECOND_FFT_AVGTIM] seconds.
#	j=genparm[SECOND_FFT_AVGTIM];
#	j*=(ui.input_speed*fft2_size)/(fft2_size-fft2_interleave_points);
#	make_power_of_two(&j);
#	if(j<4*fft2_size)j=4*fft2_size;
#	fft2_na=0;
#	fft2_nb=-1;
#	fft2_nx=0;
#	max_fft2_avgnum=j/fft2_size-1;
#	# Make timf2 hold 2 second of data
#	timf2_size=2*timf1_sampling_speed;
#	make_power_of_two(&timf2_size);
#	# or four fft2 transforms if that is more
#	if(timf2_size < 4*fft2_size) timf2_size = 4*fft2_size;
#	# There are 2 transforms (strong, weak) for each rx channel
#	timf2_mask=4*ui.rx_channels*(timf2_size-1);
#	timf2_input_block=(fft1_size-fft1_interleave_points)*4*ui.rx_channels;
#	make_fft2_status=0;
#	timf2_pa=0;
#	timf2_pn1=0;
#	timf2_pn2=timf2_mask-fft2_size*4*ui.rx_channels;
#	timf2p_fit=0;
#	timf2_px=0;
#	# Set start noise floor 20dB above one bit amplitude
#	# and set channel noise = 1 so sum never becomes zero to avoid
#	# problems with log function.
#	timf2_noise_floor=100; 
#	timf2_despiked_pwr[0]=timf2_noise_floor;
#	timf2_despiked_pwrinc[0]=1;
#	if(ui.rx_channels == 2) {
#	    timf2_despiked_pwr[1]=timf2_noise_floor;
#	    timf2_despiked_pwrinc[1]=1;
#	    timf2_noise_floor*=2;
#	}
#	timf2_fitted_pulses=0;
#	timf2_cleared_points=0;
#	timf2_blanker_points=0;
#	clever_blanker_rate=0;
#	stupid_blanker_rate=0;
#	mix1_n+=fft2_n-fft1_n;
#	if(mix1_n > fft1_n)mix1_n=fft1_n;
#	if(mix1_n < 3)mix1_n=3;
#	mix1_size=1<<mix1_n;
#	mix1_interleave_points=fft2_interleave_ratio*mix1_size;
#	mix1_interleave_points&=0xfffffffe;  
#	fft2_interleave_points=mix1_interleave_points*(fft2_size/mix1_size);
#	fft2_interleave_ratio=(float)(fft2_interleave_points)/fft2_size;
#	timf3_sampling_speed=timf1_sampling_speed/fft2_size;
#    }
#    timf3_sampling_speed*=mix1_size;
#    fft2_new_points=fft2_size-fft2_interleave_points;
#    timf2_output_block=fft2_new_points*4*ui.rx_channels;
#    fft2_blocktime=(float)(fft2_new_points)/timf1_sampling_speed;

    # report results
    foreach {name title} $derived {
	$w.x$name configure -text "$name: $data($name)"
   }
}

proc ::sm5bsz-params::fft1_block_timing {} {
    variable data
    set data(fft1_interleave_ratio) [expr {double($data(fft1_interleave_points))/$data(fft1_size)}]
    set data(fft1_new_points) [expr {$data(fft1_size)-$data(fft1_interleave_points)}]
    set data(timf1_sampling_speed) $data(input_sample_rate)
    set data(fft1_blocktime) [expr {double($data(fft1_new_points))/$data(timf1_sampling_speed)}]
}
