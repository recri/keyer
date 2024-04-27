PKG=stk

LIBDIR=../../lib/faust/$(PKG)

ALL=	$(LIBDIR)/bass.so \
	$(LIBDIR)/NLFeks.so \
	$(LIBDIR)/tibetanBowl.so

include ../Makefile.subdir

sources::
	ln -s /usr/share/faust/examples/physicalModeling/faust-stk/*.dsp .
	ln -s /usr/share/faust/examples/physicalModeling/faust-stk/*.h .
	ln -s /usr/share/faust/examples/physicalModeling/faust-stk/README .

