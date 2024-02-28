SUBDIRS= morse sdrkit sdrtk sdrutil sdrtcl sdrtcltk faust

.PHONY: all clean all-clean

all::
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all; done

clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir clean; done

all-clean::
	@find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir all-clean; done
