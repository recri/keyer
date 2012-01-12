SUBDIRS=sdrkit lib/sdrkit lib/wrap
all::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all); done

clean::
	find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) clean); done

all-clean::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all-clean); done
