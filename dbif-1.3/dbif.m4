#------------------------------------------------------------------------
# TEA_MODULEDIR --
#
#	Determine the location where Tcl modules should be installed
#
# Arguments:
#	none
#
# Results:
#	Defines the following vars:
#		moduledir	Directory where Tcl modules will be
#				installed.
#
#	Sets the following vars:
#		moduledir	Directory path
#------------------------------------------------------------------------

AC_DEFUN([TEA_MODULEDIR], [
    AC_ARG_VAR(moduledir, [directory in which to install Tcl modules])
    if test "${ac_cv_env_moduledir_set}x" = "x"; then
	moduledir='${libdir}/tcl8/tcl8.5'
    fi
])
