# Note: plugindir is set in configure

plugin_LTLIBRARIES = \
	libgstdemodam.la \
	libgstdemodfm.la \
	libgstdemodsam.la \
	libgstdttspagc.la \
	libgstiqcorrect.la \
	libgstlomixer.la \
	libgstovsvfilter.la

# sources used to compile these plug-ins
libgstdemodam_la_SOURCES = gstdemodam.c gstdemodam.h
libgstdemodfm_la_SOURCES = gstdemodfm.c gstdemodfm.h
libgstdemodsam_la_SOURCES = gstdemodsam.c gstdemodsam.h
libgstdttspagc_la_SOURCES = gstdttspagc.c gstdttspagc.h
libgstiqcorrect_la_SOURCES = gstiqcorrect.c gstiqcorrect.h
libgstlomixer_la_SOURCES = gstlomixer.c gstlomixer.h
libgstovsvfilter_la_SOURCES = gstovsvfilter.c gstovsvfilter.h

# headers we need but don't want installed
noinst_HEADERS = \
	gstdemodam.h \
	gstdemodfm.h \
	gstdemodsam.h \
	gstdttspagc.h \
	gstiqcorrect.h \
	gstlomixer.h \
	gstovsvfilter.h

# compiler and linker flags used to compile these plugins, set in configure.ac
libgstdemodam_la_CFLAGS = $(GST_CFLAGS)
libgstdemodam_la_LIBADD = $(GST_LIBS)
libgstdemodam_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstdemodam_la_LIBTOOLFLAGS = --tag=disable-static

libgstdemodfm_la_CFLAGS = $(GST_CFLAGS)
libgstdemodfm_la_LIBADD = $(GST_LIBS)
libgstdemodfm_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstdemodfm_la_LIBTOOLFLAGS = --tag=disable-static

libgstdemodsam_la_CFLAGS = $(GST_CFLAGS)
libgstdemodsam_la_LIBADD = $(GST_LIBS)
libgstdemodsam_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstdemodsam_la_LIBTOOLFLAGS = --tag=disable-static

libgstdttspagc_la_CFLAGS = $(GST_CFLAGS)
libgstdttspagc_la_LIBADD = $(GST_LIBS)
libgstdttspagc_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstdttspagc_la_LIBTOOLFLAGS = --tag=disable-static

libgstiqcorrect_la_CFLAGS = $(GST_CFLAGS)
libgstiqcorrect_la_LIBADD = $(GST_LIBS)
libgstiqcorrect_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstiqcorrect_la_LIBTOOLFLAGS = --tag=disable-static

libgstlomixer_la_CFLAGS = $(GST_CFLAGS)
libgstlomixer_la_LIBADD = $(GST_LIBS)
libgstlomixer_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstlomixer_la_LIBTOOLFLAGS = --tag=disable-static

libgstovsvfilter_la_CFLAGS = $(GST_CFLAGS)
libgstovsvfilter_la_LIBADD = $(GST_LIBS)
libgstovsvfilter_la_LDFLAGS = $(GST_PLUGIN_LDFLAGS)
libgstovsvfilter_la_LIBTOOLFLAGS = --tag=disable-static

