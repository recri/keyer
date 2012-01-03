all:: pkgIndex.tcl

clean::
	rm -f *~

pkgIndex.tcl: $(wildcard *.so) $(filter-out pkgIndex.tcl, $(wildcard *.tcl))
	echo 'pkg_mkIndex .' | tclsh

