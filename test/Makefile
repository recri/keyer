CFLAGS=-std=c99 -g -O3 
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

