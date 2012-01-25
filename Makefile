VSN_FFTW3=3.2.2
VSN_JACK=1.9.7
VSN_TCL=8.5
VSN_TK=8.5
SUBDIRS=jack-tcl-wrap lib/wrap lib/morse
all::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all); done

clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) clean); done

all-clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all-clean); done

#
# this is the lazy programmer's version of configure/autoconf/automake
#
check::
	@(pkg-config --exists 'fftw3 >= $(VSN_FFTW3)' && \
	pkg-config --exists 'jack >= $(VSN_JACK)' && \
	test -x /usr/bin/tclsh && \
	test -x /usr/bin/wish && \
	test -f /usr/include/tcl8.5/tcl.h && \
	test -f /usr/include/tcl8.5/tk.h) || \
	echo you seem to be missing required packages, consult the README.org

#
# no tcl.pc or tk.pc until 8.6 release
#	@pkg-config --exists 'tk >= $(VSN_TK)'
#	@pkg-config --exists 'tcl >= $(VSN_TCL)'
#