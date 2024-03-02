# add architecture to subdir to build a shared library
# doesn't work at present.

SUBDIRS=pm stk tst

.PHONY: all clean all-clean

all::
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all; done

clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done

all-clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all-clean; done

test::
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir test; done
