CFLAGS=-std=c99 -g -O3 
all: test-osc2

test-osc2: test-osc2.c
	cc -o test-osc2 $(CFLAGS) test-osc2.c -lm

test-ovsv: test-ovsv.c ../sdrkit/filter_overlap_save.h
	cc $(CFLAGS) -o test-ovsv test-ovsv.c -lfftw3f

OBJ=test-osc.o test-osc-fd.o test-osc-td.o test-osc-zd.o test-osc-f.o test-osc-t.o test-osc-z.o
test-osc: $(OBJ)
	cc -o test-osc $(OBJ) -lm

clean:
	rm -f $(OBJ)

test-osc.o: test-osc.c
	cc -c -o $@ $(CFLAGS) $<

test-osc-f.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_F $<

test-osc-fd.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_F -DOSCILLATOR_D $<

test-osc-t.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_T $<

test-osc-td.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_T -DOSCILLATOR_D $<

test-osc-z.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_Z $<

test-osc-zd.o:  test-osc.c
	cc -c -o $@ $(CFLAGS) -DOSC_MAKE -DOSCILLATOR_Z -DOSCILLATOR_D $<

