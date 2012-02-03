BINDIR=../bin
CFLAGS=-I/usr/include/jack
LIBS=-lasound -lsamplerate -ljack

all: $(BINDIR)/alsa_in $(BINDIR)/alsa_out


$(BINDIR)/alsa_in: alsa_in.c memops.h memops.o
	$(CC) $(CFLAGS) -o $@ $< memops.o $(LIBS)

$(BINDIR)/alsa_out: alsa_out.c memops.h memops.o
	$(CC) $(CFLAGS) -o $@ $< memops.o $(LIBS)

memops.o: memops.c
