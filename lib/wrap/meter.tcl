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
package provide wrap::meter 1.0.0
package require wrap
package require sdrkit::audio-tap
namespace eval ::wrap {}
#
# meter block
# well, what kind of meter?
# dttsp computes in sdr.c/do_rx_meter:
#   RX PRE_CONV meter value, which is
#       ADC_REAL, ADC_IMAG = max(fabs(real)),max(fabs(imag)) over a window
#   RX POST_FILT meter value, which is
#       SIGNAL_STRENGTH = Log10P(sum(Csqrmag(complex))/n) over a window of n samples
#       AVG_SIGNAL_STRENGTH = DamPlus(AVG_SIGNAL_STRENGTH, SIGNAL_STRENGTH)
#   RX POST_AGC meter value, which is
#       AGC_GAIN = dBP(agc.gain.now)
# dttsp computes in sdr.c/do_tx_meter:
#   TX MIC meter value, which is
#       MIC = Log10Q(DamPlus(.,fabs(real)))
#   TX PWR meter value, which is
#	 PWR = sum(Csqrmag(complex))/n
#   TX EQtap = Log10Q(DamPlus(.,fabs(real)))
#   TX LEVELER = Log10Q(DamPlus(.,fabs(real)))
#      LVL_G = dBP(leveler.gain.now)
#   TX COMP = Log10Q(DamPlus(.,fabs(real)))
#   TX CPDR = Log10Q(DamPlus(.,fabs(real)))
# After WaveShape
#   TX WAVS = Log10Q(DamPlus(.,fabs(real)))
#
# epsilon = 1e-16
# Log10P(x) = 10 * log10(x+epsilon)
# decayed_average(x,y) = DamPlus(x,y) = 0.9995 x + 0.0005 y
# dBP(x) = 20 * log10(x+epsilon)
# Log10Q(x) = -10 * log10(x+epsilon)
#
# so we have:
#
#   max(fabs(real)), max(fabs(imag))
#   power = sum(abs2(complex))/n
#   10*log10(power + epsilon)
#   decayed_average(ditto)
#   20*log10(agc_gain)
#   -10*log10(decayed_average(fabs(real)))
#  
proc ::wrap::meter {w} {
    upvar #0 $w data
    default_window $w
    cleanup_func $w [::sdrkit::audio-tap ::wrap::cmd::$w -complex 1]
    return $w
}

