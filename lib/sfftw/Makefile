all:: pkgIndex.tcl

clean::
	rm -f *~

all-clean::
	rm pkgIndex.tcl

pkgIndex.tcl: $(wildcard *.so) $(filter-out pkgIndex.tcl, $(wildcard *.tcl))
	echo 'pkg_mkIndex .' | tclsh

