package provide cwack::progressbar 1.0

package require Tk
package require snit

namespace eval cwack:: {}

## cwack::progressbar labelled progress bar
## tk type, but grid into a larger array at -row -column
## show time remaining or percent correct as progress bars
snit::type cwack::progressbar {
    component title
    component value
    component progress
    
    option -window
    option -var
    option -row
    option -column
    option -variable

    option -title -default {}
    option -foreground -default blue
    option -background -default red
    
    constructor {args} {
	$self configurelist $args

	set win $options(-window)
	set var $options(-var)
	set row $options(-row)
	set column $options(-column)

        install title using ttk::label $win.title$var -text $options(-title)
        install value using ttk::label $win.value$var -textvar $options(-variable)
        install progress using ttk::progressbar $win.progress$var -mode determinate -variable $options(-variable)
        grid $win.title$var -column [expr {$column+0}] -row $row -sticky e
        grid $win.value$var -column [expr {$column+1}] -row $row -ipadx 10
        grid $win.progress$var -column [expr {$column+2}] -row $row -sticky ew -columnspan 3
    }
}


