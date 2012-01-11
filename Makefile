SUBDIRS=keyer sdrkit lib/keyer lib/sdrkit lib/keyer-ui lib/sdrkit-ui lib/wrap
all::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all); done

clean::
	find . -name '*~' -exec rm -f \{} \;
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) clean); done

all-clean::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all-clean); done
