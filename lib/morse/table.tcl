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
# morse code table
#

package provide morse::table 1.0.0

namespace eval ::morse {}
namespace eval ::morse::table {}

set ::morse::table::table {
          |           |               |                   |
          |           |               | . . . .           |
          |           | . . .         |                   |
          |           |               | . . . ...         |
          | . .       |               |                   |
          |           |               | . . ... .         |
          |           | . . ...       |                   |
          |           |               | . . ... ...       |
    .     |           |               |                   |
          |           |               | . ... . .         |
          |           | . ... .       |                   |
          |           |               | . ... . ...       |
          | . ...     |               |                   |
          |           |               | . ... ... .       |
          |           | . ... ...     |                   |
          |           |               | . ... ... ...     |
          |           |               |                   |
          |           |               | ... . . .         |
          |           | ... . .       |                   |
          |           |               | ... . . ...       |
          | ... .     |               |                   |
          |           |               | ... . ... .       |
          |           | ... . ...     |                   |
          |           |               | ... . ... ...     |
    ...   |           |               |                   |
          |           |               | ... ... . .       |
          |           | ... ... .     |                   |
          |           |               | ... ... . ...     |
          | ... ...   |               |                   |
          |           |               | ... ... ... .     |
          |           | ... ... ...   |                   |
          |           |               | ... ... ... ...   |
          |           |               |                   |
}

# eitsanhurdm5vflbwkgo'u'axczp'oqyj
set ::morse::table::bylength {
|   .   |
|   . .   |
|   ...   |
|   . . .   |
|   . ...   |
|   ... .   |
|   . . . .   |
|   . . ...   |
|   . ... .   |
|   ... . .   |
|   ... ...   |
|   . . . . .   |
|   . . . ...   |
|   . . ... .   |
|   . ... . .   |
|   ... . . .   |
|   . ... ...   |
|   ... . ...   |
|   ... ... .   |
|   ... ... ...   |
|   . . ... ...   |
|   . ... . ...   |
|   ... . . ...   |
|   ... . ... .   |
|   ... ... . .   |
|   . ... ... .   |
|   ... ... ... .   |
|   ... ... . ...   |
|   ... . ... ...   |
|   . ... ... ...   |
|   ... ... ... ...   |
}
set morse::table::alt {
.   e   <e>
. .   i   <ee>
...   t   <t>
. . .   s   <ie>
. ...   a   <et>
... .   n   <te>
. . . .   h   <se>
. . ...   u   <it>
. ... .   r   <ae>
... . .   d   <ne>
... ...   m   <tt>
. . . . .   5   <he>
. . . ...   v   <st>
. . ... .   f   <ue>
. ... . .   l   <re>
. ... ...   w   <at>
... . . .   b   <de>
... . ...   k   <nt>
... ... .   g   <me>
. . . . ...   4   <ht>
. . . ... .       <ve>
. . ... . .       <fe>
. . ... ...       <ut>
. ... . . .       <le>
. ... . ...       <rt>
. ... ... .   p   <we>
... . . . .   6   <be>
... . . ...   x   <ut>
... . ... .   c   <ke>
... ... . .   z   <ge>
... ... ...   o   <mt>
. . . ... ...   3   <vt>
. . ... . ...       <ft>
. . ... ... .       <un>
. ... . . ...       <lt>
. ... . ... .   +   <ar>
. ... ... . .       <pe>
. ... ... ...   j   <wt>
... . . . ...   =   <bt>
... . . ... .   /   <xe>
... . ... . .       <ce>
... . ... ...   y   <kt>
... ... . . .   7   <ze>
... ... . ...   q   <gt>
... ... ... .       <oe>
. . ... ... ...   2   <um>
. ... . ... ...       <rm>
. ... ... . ...       <pt>
. ... ... ... .       <je>
... . . ... ...       <xt>
... . ... . ...       <ct>
... . ... ... .       <ye>,<kn>
... ... . . ...       <zt>
... ... . ... .       <qe>
... ... ... . .   8   <oi>
... ... ... ...       <ot>
. ... ... ... ...   1   <jt>
... . ... ... ...       <yt>
... ... . ... ...       <qt>
... ... ... . ...       <oa>
... ... ... ... .   9   <on>
... ... ... ... ...   0   <om>
}    
# generate the nth level of an m level table
proc ::morse::table::generate {n m {table {}}} {
    if {$n < $m} {
	if {$n == 1} {
	    return { {.   } {...   } }
	}
    }

}
proc ::morse::table::generate-tree1 {n} {
    set tree [dict create {} [dict create level 0]]
    for {set i 1} {$i < $n} {incr i} {
	dict for {key value} [dict filter $tree script {k v} {expr {[dict get $v level] == $i-1}}] {
	    dict set tree "${key}. " [dict create level $i]
	    dict set tree "${key}... " [dict create level $i]
	}
    }
    return $tree
}

proc ::morse::table::generate-tree-in-order {n i key} {
    #puts "generate-tree-in-order $n $i {$key}"
    if {$i <= $n} {
	incr i
	set head [generate-tree-in-order $n $i "${key}0"]
	set tail [generate-tree-in-order $n $i "${key}1"]
	#puts "generate-tree-in-order $n $i {$key}, [llength $head], head: $head"
	#puts "generate-tree-in-order $n $i {$key}, [llength $tail], tail: $tail"
	return [concat $head "${key}  " $tail]
    }
    return {}
}    
proc ::morse::table::generate-tree {n} {
    # generate tree in order
    set tree [lmap row [::morse::table::generate-tree-in-order $n 0 {}] {
	# translate 0-1 into . and ...
	regsub -all {0} $row {. } row
	regsub -all {1} $row {... } row
	append row {  }
	# now pad out for missing columns
	set m [llength $row]
	for {set i 1} {$i < $m} {incr i} {
	    set row "[string repeat { } [expr {4*$i+2}]]$row"
	}
	set row
    }]
    return $tree
}

