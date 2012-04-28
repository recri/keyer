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
package provide sdrctl::types 1.0.0

package require snit

snit::enum sdrctl::type -values {none ctl dsp jack ui hw}

snit::enum sdrctl::mode -values {USB LSB DSB CWU CWL AM SAM FMN DIGU DIGL}
snit::enum sdrctl::agc-mode -values {off long slow med fast}
snit::enum sdrctl::leveler-mode -values {off leveler}
snit::enum sdrctl::iambic -values {none ad5dz dttsp nd7pa}
snit::enum sdrctl::iq-delay -values {-1 0 1}

snit::double sdrctl::gain -min -200.0 -max 200.0; # gain in decibels
snit::double sdrctl::hertz

snit::boolean sdrctl::debounce
snit::double sdrctl::debounce-period
snit::integer sdrctl::debounce-steps -min 1 -max 32

snit::boolean sdrctl::iq-swap
snit::boolean sdrctl::iq-correct
snit::boolean sdrctl::mute
snit::boolean sdrctl::spot

snit::double sdrctl::sine-phase -min -1.0 -max 1.0
snit::double sdrctl::linear-gain -min 0.125 -max 8.0