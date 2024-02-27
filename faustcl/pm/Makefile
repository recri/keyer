TCL_CFLAGS=$(shell pkg-config --cflags tcl)
TCL_LIBS=$(shell pkg-config --libs tcl)

JACK_CFLAGS=$(shell pkg-config --cflags jack)
JACK_LIBS=$(shell pkg-config --libs jack)

CFLAGS=-std=c99 -g -O3 $(TCL_CFLAGS) ${JACK_CFLAGS)
CXXFLAGS= -g -O3 $(TCL_CFLAGS) $(JACK_CFLAGS)

LIBS=$(TCL_LIBS) $(JACK_LIBS) -lm

LIBDIR=../../lib/faust_pm

ALL=	$(LIBDIR)/brass.so \
	$(LIBDIR)/clarinet.so \
	$(LIBDIR)/djembe.so \
	$(LIBDIR)/elecGuitar.so \
	$(LIBDIR)/flute.so \
	$(LIBDIR)/guitar.so \
	$(LIBDIR)/ks.so \
	$(LIBDIR)/marimba.so \
	$(LIBDIR)/modularInterpInst.so \
	$(LIBDIR)/nylonGuitar.so \
	$(LIBDIR)/SFFormantModelBP.so \
	$(LIBDIR)/SFFormantModelFofCycle.so \
	$(LIBDIR)/SFFormantModelFofSmooth.so \
	$(LIBDIR)/violin.so

all:: $(ALL) libdir-all

clean:: libdir-clean
	rm -f *~ *.cpp *.o *.so *.dsp.json *.dsp.h

all-clean:: libdir-all-clean
	rm -f $(ALL)

libdir-all::
	cd $(LIBDIR) && make all

libdir-clean::
	cd $(LIBDIR) && make clean

libdir-all-clean::
	cd $(LIBDIR) && make all-clean

%.cpp: %.dsp ../architecture/faustcl.cpp
	faust -a ../architecture/faustcl.cpp $< -o $@

#	$(CXX) -c -fPIC $(CXXFLAGS) -DTCL_INIT_NAME=Pm_$(shell echo $* | tr [:upper:] [:lower:])_Init \
# 	$(CXX) -c -fPIC $(CXXFLAGS) -DTCL_INIT_NAME=$(shell X=$* bash -c 'echo $${X^}_Init') \

%.o: %.cpp
	$(CXX) -c -fPIC $(CXXFLAGS) -DTCL_INIT_NAME=$(shell X=`echo $* | tr [:upper:] [:lower:]` bash -c 'echo $${X^}_Init') \
	-DTCL_PKG_NAME=\"faust::pm::$*\" -DTCL_PKG_VERSION=\"1.0.0\" -DTCL_CMD_NAME=\"faust::pm::$*\" \
	 $< -o $*.o

$(LIBDIR)/%.so: %.o $(LIBDIR)
	$(CXX) -shared $< $(LIBS) -o $@
