package provide cwack::lradiobutton 1.0

package require Tk
package require snit
package require sdrtk::radiomenubutton

snit::type cwack::lradiomenubutton {
    component label
    component radiomenubutton

    option -window
    option -var
    option -row
    option -column

    delegate option -text to label
    delegate option -values to radiomenubutton
    delegate option -labels to radiomenubutton
    delegate option -defaultvalue to radiomenubutton
    delegate option -command to radiomenubutton
    delegate option -variable to radiomenubutton

    constructor {args} {
	set win [set options(-window) [from args -window]]
	set var [set options(-var) [from args -var]]
	install label using ttk::label $win.lbl$var
	install radiomenubutton using sdrtk::radiomenubutton $win.rbm$var
	$self configurelist $args
	grid $win.lbl$var -row $options(-row) -column [expr {$options(-column)+0}]
	grid $win.rbm$var -row $options(-row) -column [expr {$options(-column)+1}]
    }
}

