VSN_FFTW3=3.2.2
VSN_JACK=1.9.7
VSN_TCL=8.6
VSN_TK=8.6
CURSUBDIRS=sdrtcl faust bin lib

OLDSUBDIRS=
SUBDIRS=$(CURSUBDIRS) $(OLDSUBDIRS)

all::
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all; done

make:: all

ubuntu-deps:
	sudo apt install build-essential git-core jackd2 tk8.6-dev tcllib tklib tcl-udp tcl-thread libasound2-dev libfftw3-dev libjack-jackd2-dev libusb-1.0-0-dev graphviz tkcon faust

clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done

all-clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all-clean; done

distclean:: all-clean

#
# this is the lazy programmer's version of configure/autoconf/automake
#
check::
	@(pkg-config --exists 'fftw3 >= $(VSN_FFTW3)' && \
	pkg-config --exists 'jack >= $(VSN_JACK)' && \
	pkg-config --exists 'tk >= $(VSN_TK)' && \
	pkg-config --exists 'tcl >= $(VSN_TCL)' && \
	test -f /usr/include/tcl/tcl.h && \
	test -f /usr/include/tcl/tk.h) && \
	which faust > /dev/null 2>&1 || \
	echo you seem to be missing required packages, consult the README.org
