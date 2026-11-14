package provide cwack::lscale 1.0

package require Tk 8.6
package require snit

## cwack::lscale labeled scale
## tk type, but grid into a larger array at -row -column
## to constrain column widths together
snit::type cwack::lscale {

    component label
    component value
    component scale

    option -window
    option -var
    option -row
    option -column
    option -text
    option -variable
    option -format
    option -from
    option -to
    option -command

    proc constrain {var fmt val} { set $var [format $fmt $val] }

    constructor {args} {
	$self configurelist $args

	set win $options(-window)
	set var $options(-var)
	set row $options(-row)
	set column $options(-column)

	install label using ttk::label $win.label$var -text $options(-text)
	install value using ttk::label $win.value$var -textvar $options(-variable)
	install scale using ttk::scale $win.scale$var -orient horizontal \
	    -variable $options(-variable) -from $options(-from) -to $options(-to) \
	    -command [mymethod update]

	grid $win.label$var -row $row -column [expr {$column+0}] -sticky e
	grid $win.value$var -row $row -column [expr {$column+1}] -ipadx 10
	grid $win.scale$var -row $row -column [expr {$column+2}] -sticky ew -columnspan 3
    }
    method update {val} {
	set options(-variable) [format $options(-format) $val]
	if {$options(-command) ne {}} { {*}$options(-command) $options(-variable) }
    }
}

