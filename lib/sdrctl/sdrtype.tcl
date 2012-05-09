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

##
## types - snit types for option validation 
## these are also used to supply values for selection menues
## via [sdrctl::<enum-type> cget -values]
##
package provide sdrtype::types 1.0.0

package require snit

snit::enum	sdrtype::type		-values {none ctl dsp jack ui hw}

snit::enum	sdrtype::mode		-values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}
snit::enum	sdrtype::agc-mode	-values {off long slow medium fast}
snit::enum	sdrtype::leveler-mode	-values {off leveler}

snit::enum	sdrtype::iambic		-values {none ad5dz dttsp nd7pa}
snit::boolean	sdrtype::debounce
snit::double	sdrtype::debounce-period
snit::integer	sdrtype::debounce-steps	-min 1 -max 32

snit::boolean	sdrtype::iq-swap
snit::enum	sdrtype::iq-delay	-values {-1 0 1}
snit::double	sdrtype::iq-correct	-min -1e6 -max 1e6
snit::double	sdrtype::sine-phase	-min -1.0 -max 1.0
snit::double	sdrtype::linear-gain	-min 0.125 -max 8.0

snit::double	sdrtype::gain		-min -200.0 -max 200.0; # gain in decibels
snit::double	sdrtype::hertz


snit::boolean	sdrtype::mute
snit::boolean	sdrtype::spot


snit::integer	sdrtype::instance	-min 1 -max 10
snit::double	sdrtype::decibel	-min -200.0 -max 200.0
snit::enum	sdrtype::spec-size	-values {width/8 width/4 width/2 width width*2 width*4 width*8}
snit::integer	sdrtype::fftw-planbits	-min 0 -max 127
snit::enum	sdrtype::fftw-direction	-values {-1 1}
snit::integer	sdrtype::spec-polyphase	-min 1 -max 32
snit::enum	sdrtype::spec-result	-values {coeff mag mag2 dB short char}
snit::enum	sdrtype::spec-palette	-values {0 1 2 3 4 5}
snit::double	sdrtype::zoom		-min 0.5 -max 64
snit::double	sdrtype::pan		-min -200000 -max 200000
snit::boolean	sdrtype::smooth	
snit::integer	sdrtype::multi		-min 1 -max 64
snit::integer	sdrtype::sample-rate	-min 4000 -max 2000000
snit::integer	sdrtype::milliseconds	-min 0 -max 30000
snit::integer	sdrtype::samples	-min 1 -max 32000
snit::double	sdrtype::decay		-min 0.0001 -max 0.9999
snit::enum	sdrtype::meter-reduce	-values {abs_real abs_imag max_abs mag2}
snit::enum	sdrtype::meter-style	-values {s-meter}
