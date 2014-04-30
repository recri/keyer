VSN_FFTW3=3.2.2
VSN_JACK=1.9.7
VSN_TCL=8.6
VSN_TK=8.6
CURSUBDIRS=sdrtcl bin lib/morse lib/sdrkit lib/sdrtk lib/sdrutil
OLDSUBDIRS=
SUBDIRS=$(CURSUBDIRS) $(OLDSUBDIRS)

all::
	cd dbus-2.0 && ./configure --with-tcl=/usr/lib/tcl8.6 && make prefix="`cd .. && pwd`" exec_prefix="`cd .. && pwd`" install-lib-binaries
	cd dbif-1.0 && cp dbif.tcl ../lib/sdrutil
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all); done

clean::
	@find . -name '*~' -exec rm -f \{} \;
	cd dbus-2.0 && make clean
	cd dbif-1.0 && make clean
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) clean); done

all-clean::
	@find . -name '*~' -exec rm -f \{} \;
	cd dbus-2.0 && make distclean
	rm -fr lib/dbus
	cd dbif-1.0 && make distclean
	rm lib/sdrutil/dbif.tcl
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all-clean); done

distclean:: all-clean

#
# this is the lazy programmer's version of configure/autoconf/automake
#
check::
	@(pkg-config --exists 'fftw3 >= $(VSN_FFTW3)' && \
	pkg-config --exists 'jack >= $(VSN_JACK)' && \
	test -x /usr/bin/tclsh$(VSN_TCL) && \
	test -x /usr/bin/wish$(VSN_TK) && \
	test -f /usr/include/tcl$(VSN_TCL)/tcl.h && \
	test -f /usr/include/tcl$(VSN_TK)/tk.h) || \
	echo you seem to be missing required packages, consult the README.org

#
# no tcl.pc or tk.pc until 8.6 release
# even then, the Ubuntu packagers removed the pkg-config support
#	@pkg-config --exists 'tk >= $(VSN_TK)'
#	@pkg-config --exists 'tcl >= $(VSN_TCL)'
#
