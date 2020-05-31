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
package provide sdrtk::orca-text 1.0.0

#
# orca implementation in a Tk text window
# first order, simply manage a text view of an underlying grid
# which may be larger, smaller or the same size as the window
# so -grid-height {} -grid-width {} means the grid tracks the window
# explicitly setting -grid-height and/or -grid-width 
#
# okay, there are an enormous number of Text class bindings in
# /usr/share/tcltk/tk8.6/text.tcl which implement lots of the
# text behavior.  Not sure how I'm going to merge with all that.
#

package require Tk
package require snit

namespace eval ::sdrtk {}

snit::type sdrtk::orca-op {
    option -char {}
    option -inputs {}
    option -ouputs {}
    option -script {}
}

snit::widgetadaptor sdrtk::orca-text {
    option -grid-width -default {} -configuremethod Configure -cgetmethod Cget
    option -grid-height -default {} -configuremethod Configure -cgetmethod Cget

    variable data -array {
	handler {}
	keypress {
	    op {
		a b c d e f g h i j k l m n o p q r s t u v w x y z
		0 1 2 3 4 5 6 7 8 9
		equals 
		\# * : ! ? = ;
	    }
	    shift-op {
		A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
		numbersign asterisk colon exclam question equal semicolon
	    }
	    cmd {
		up down Left Right Insert Escape
		apostrophe grave parenleft parenright bracketleft bracketright
		' ` ~ ( ) _ + [ ] \{ \} < >
	    }
	    shift-cmd {
		Up Down Left Right Insert Escape
		asciitilde underscore plus braceleft braceright less greater
	    }
	    control-cmd {
		control-q control-d F1 control-z control-u control-x control-c control-s control-f control-r control-i 
	    }
	    alt-cmd {
		Up Down Left Right Insert Escape
	    }
	}
    }
    
    proc iota {from length} { 
	set seq {}; for {incr length $from} {$from < $length} {incr from} { lappend seq $from }; return $seq
    }

    method {Cget -grid-width} {} {
	return [expr {$options(-grid-width) eq {} ? [$self cget -width] : $options(-grid-width) }]
    }
    method {Cget -grid-height} {} {
	return [expr {$options(-grid-height) eq {} ? [$self cget -height] : $options(-grid-height) }]
    }
    method {Configure -grid-width} {val} {
	if {$val ne $options(-grid-width)} {
	    $self resize-grid $options(-grid-height) $val
	    set options(-grid-width) $val
	}
    }
    method {Configure -grid-height} {val} {
	if {$val ne $options(-grid-height)} {
	    $self resize-grid $val $options(-grid-width)
	    set options(-grid-height) $val
	}
    }

    delegate method * to hull
    delegate option * to hull
    
    constructor {args} {
	# puts "cw-decode-view constructor {$args}"
	installhull using text -wrap none -background black -foreground grey -blockcursor true
	$self configurelist $args
	# insert initial grid
	$self make-grid [$self cget -grid-height] [$self cget -grid-width]
	# bind window destroy
	bind $win <Destroy> [mymethod destroy-window %W]
	# bind window size config
	bind $win <Configure> [mymethod resize-window %W %h %w]
	# bind control characters
	#bind $win <KeyPress> [mymethod keypress %K %k %A %s]
	#bind $win <Control-KeyPress> [mymethod control-keypress %K]
	#bind $win <Shift-KeyPress> [mymethod shift-keypress %K]
	#bind $win <Alt-KeyPress> [mymethod alt-keypress %K]
	foreach ctl {q d z u x c v i} {
	    bind $win <Control-$ctl> [mymethod control $ctl]
	    bind $win <Control-[string toupper $ctl]> [mymethod control $ctl]
	}
	# bind arrows, plain arrows are correct
	# oops the arrow keys are already bound to generate <<PrevLine>>, etc
	bind $win <<PrevChar>> [mymethod cursor-move  0 -1]
	bind $win <<NextChar>> [mymethod cursor-move  0 +1]
	bind $win <<PrevLine>> [mymethod cursor-move -1  0]
	bind $win <<NextLine>> [mymethod cursor-move +1  0]
	bind $win <<SelectPrevChar>> [mymethod cursor-select  0 -1]
	bind $win <<SelectNextChar>> [mymethod cursor-select  0 +1]
	bind $win <<SelectPrevLine>> [mymethod cursor-select -1  0]
	bind $win <<SelectNextLine>> [mymethod cursor-select +1  0]
	bind $win <Alt-Left>  [mymethod cursor-drag  0 -1]
	bind $win <Alt-Right> [mymethod cursor-drag  0 +1]
	bind $win <Alt-Up>    [mymethod cursor-drag -1  0]
	bind $win <Alt-Down>  [mymethod cursor-drag +1  0]
	
    }
  
    method exposed-options {} { return {-grid-width -grid-height -width -height -font} }

    method info-option {opt} {
	switch -- $opt {
	    -font { return {font of grid} }
	    -width { return {width of window} }
	    -height { return {height of window} }
	    -grid-width { return {width of grid} }
	    -grid-height { return {height of grid} }
	    default { puts "no info-option for $opt" }
	}
    }
    # keypress dispatch
    method keypress {keysym keycode unicode state} { 
	# $state == 1 for shift
	# $state == 2 for capslock
	# $state == 4 for control
	# $state == 8 for alt
	puts "keypress $state $keysym"
    }
    method control-keypress {key} { puts control-keypress-$key }
    method shift-keypress {key} { puts shift-keypress-$key }
    method alt-keypress {key} { puts alt-keypress-$key }

    # cursor motions
    method cursor-move {drow dcol} {
	puts "cursor-move $drow $dcol, [$hull index insert]"
	return -code break;	# disable less specific bindings
    }
    method cursor-select {drow dcol} {
	puts "cursor-select $drow $dcol, [$hull index insert]"
	return -code break;	# disable less specific bindings
    }
    method cursor-drag {drow dcol} {
	puts "cursor-drag $drow $dcol, [$hull index insert]"
	return -code break;	# disable less specific bindings
    }
    # controls
    method control {which} {
	puts "control-$which"
    }
    
    # getters and setters dealing with change of row numbering
    method insert-string {row col string} {
	incr row; $hull insert $row.$col $string
    }
    method insert-line {row line} {
	incr row; $hull insert $row.0 $line\n
    }
    method overwrite-string {row col string} {
	incr row; $hull insert $row.$col $string; $hull delete $row.[expr {$col+[string length $string]}] $row.[expr {$col+2*[string length $string]}]
    }
    method overwrite-line {row line} {
	incr row; $hull delete $row.0 $row.lineend; $hull insert $row.0 $line
    }
    method overwrite-rectangle {row col height width list} {
	foreach r [iota $row $height] line $list { $self overwrite-string $r $col $width $line }
    }
    method get-char {row col} { 
	incr row; return [$hull get $row.$col]
    }
    method get-string {row col width} {
	incr row; return [$hull get $row.$col $row.[expr {$col+$width}]]
    }
    method get-line {row} {
	incr row; return [$hull get $row.0 $row.lineend]
    }
    method get-rectangle {row col height width} {
	return [lmap r [iota $row $height] [$self get-string $r $col $width]]
    }
    method make-grid {ht wd} {
	$hull delete 1.0 end
	set string [string repeat . $wd]
	foreach row [iota 0 $ht] {
	    $self insert-line $row $string
	}
    }
    method resize-grid {ht wd} {
	set oh [$self cget -grid-height]
	set ow [$self cget -grid-width]
	if {$ow < $wd} {
	    # get wider
	    set string [string repeat . [expr {$wd-$ow}]]
	    foreach r [iota 0 $oh] {
		$self set-line $r "[$self get-line $r]$string"
	    }
	} elseif {$ow > $wd} {
	    # get narrower
	    foreach r [iota 0 $oh] {
		$self set-line $r [string range [$self get-line $r] 0 $wd]
	    }
	}
	if {$oh < $ht} {
	    # get taller
	    set string [string repeat . $wd]
	    foreach r [iota $oh [expr {$ht-$oh}]] {
		$self insert-line $r $string
	    }
	} elseif {$oh > $ht} {
	    # get shorter
	    foreach r [iota $ht [expr {$oh-$ht}]] {
		$self delete-line $r
	    }
	}
    }
    method resize-window {w ht wd} {
	if {$wd != [$self cget -width]} {
	}
	if {$ht != [$self cget -height]} {
	}
    }
    method destroy-window {w} {
	if {$w eq $win} { 
	    after cancel $data(handler)
	    destroy .
	}
    }
}
