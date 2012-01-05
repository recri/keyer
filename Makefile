SUBDIRS=keyer sdrkit lib/keyer lib/sdrkit lib/keyer-ui lib/sdrkit-ui
all::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all); done

clean::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) clean); done

all-clean::
	for dir in $(SUBDIRS); do (cd $$dir && $(MAKE) all-clean); done
