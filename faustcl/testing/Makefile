TCL_CFLAGS=$(shell pkg-config --cflags tcl)
TCL_LIBS=$(shell pkg-config --libs tcl)

JACK_CFLAGS=$(shell pkg-config --cflags jack)
JACK_LIBS=$(shell pkg-config --libs jack)

CFLAGS=-std=c99 -g -O3 $(TCL_CFLAGS) ${JACK_CFLAGS)
CXXFLAGS= -g -O3 $(TCL_CFLAGS) $(JACK_CFLAGS)

LIBS=$(TCL_LIBS) $(JACK_LIBS) -lm

LIBDIR=../../lib/faustcl

ALL=	$(LIBDIR)/miditester.so

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

%.dsp.json: %.dsp architecture/faustcl.cpp
	faust -json $< > /dev/null

# tip of the hat to stack overflow for the string to title case conversion hack
%.o: %.cpp
	$(CXX) -c -fPIC $(CXXFLAGS) -DTCL_INIT_NAME=$(shell X=$* bash -c 'echo $${X^}_Init') \
	-DTCL_PKG_NAME=\"faustcl::$*\" -DTCL_PKG_VERSION=\"1.0.0\" -DTCL_CMD_NAME=\"faustcl::$*\" \
	$< -o $@

$(LIBDIR)/%.so: %.o
	$(CXX) -shared $< $(LIBS) -o $@
