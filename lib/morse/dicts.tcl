#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
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
# dictionaries suitable for translating into and out of morse
#

package provide morse::dicts 1.0.0

package require morse::arabic
package require morse::cyrillic
package require morse::farsi
package require morse::fldigi
package require morse::greek
package require morse::hebrew
package require morse::itu
package require morse::wabun

namespace eval ::morse {}
proc morse-dicts {} {
    return {arabic cyrillic farsi fldigi greek hebrew itu wabun}
}
proc arabic {} { return [morse-arabic-dict] }
proc cyrillic {} { return [morse-cyrillic-dict] }
proc farsi {} { return [morse-farsi-dict] }
proc fldigi {} { return [morse-fldigi-dict] }
proc greek {} { return [morse-greek-dict] }
proc hebrew {} { return [morse-hebrew-dict] }
proc itu {} { return [morse-itu-dict] }
proc wabun {} { return [morse-wabun-dict] }
