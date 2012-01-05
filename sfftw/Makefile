LIBDIR=../lib/sfftw
$(LIBDIR)/sfftw.so: sfftw.c
	mkdir -p $(LIBDIR)
	cc -shared -fPIC -o $(LIBDIR)/sfftw.so sfftw.c -lsfftw -lsrfftw
