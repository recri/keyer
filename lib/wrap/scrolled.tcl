package provide scrolled 1.0.0

package require Tk

namespace eval ::scrolled {}

proc ::scrolled::treeview {w args} {
    ::ttk::frame $w
    grid [::ttk::treeview $w.text -xscrollcommand [list $w.x set] -yscrollcommand [list $w.y set]] -column 0 -row 0 -sticky nsew
    grid [::ttk::scrollbar $w.x -orient horizontal -command [list $w.text xview]] -column 0 -row 1 -sticky ew
    grid [::ttk::scrollbar $w.y -orient vertical -command [list $w.text yview]] -column 1 -row 0 -sticky ns
    grid rowconfigure $w 0 -weight 100
    grid columnconfigure $w 0 -weight 100
    # megawidget magic
    rename $w ${w}-megawidget-frame
    uplevel #0 [list proc $w args [regsub WINDOW {return [WINDOW.text {*}$args]} $w]]
    $w configure {*}$args
    return $w
}

proc ::scrolled::text {w args} {
    ::ttk::frame $w
    grid [::text $w.text -xscrollcommand [list $w.x set] -yscrollcommand [list $w.y set]] -column 0 -row 0 -sticky nsew
    grid [::ttk::scrollbar $w.x -orient horizontal -command [list $w.text xview]] -column 0 -row 1 -sticky ew
    grid [::ttk::scrollbar $w.y -orient vertical -command [list $w.text yview]] -column 1 -row 0 -sticky ns
    grid rowconfigure $w 0 -weight 100
    grid columnconfigure $w 0 -weight 100
    # megawidget magic
    rename $w ${w}-megawidget-frame
    uplevel #0 [list proc $w args [regsub WINDOW {return [WINDOW.text {*}$args]} $w]]
    $w configure {*}$args
    return $w
}

proc ::scrolled::canvas {w args} {
    ::ttk::frame $w
    grid [::canvas $w.text -xscrollcommand [list $w.x set] -yscrollcommand [list $w.y set]] -column 0 -row 0 -sticky nsew
    grid [::ttk::scrollbar $w.x -orient horizontal -command [list $w.text xview]] -column 0 -row 1 -sticky ew
    grid [::ttk::scrollbar $w.y -orient vertical -command [list $w.text yview]] -column 1 -row 0 -sticky ns
    grid rowconfigure $w 0 -weight 100
    grid columnconfigure $w 0 -weight 100
    # megawidget magic
    rename $w ${w}-megawidget-frame
    uplevel #0 [list proc $w args [regsub WINDOW {return [WINDOW.text {*}$args]} $w]]
    $w configure {*}$args
    return $w
}

