all::
	cd keyer && $(MAKE) all
	cd sdrkit && $(MAKE) all
	cd lib/keyer && $(MAKE) all
	cd lib/sdrkit && $(MAKE) all
	cd lib/keyer-ui && $(MAKE) all
	cd lib/sdrkit-ui && $(MAKE) all

clean::
	cd keyers && $(MAKE) clean
	cd sdrkit && $(MAKE) clean
	cd lib/keyer && $(MAKE) clean
	cd lib/sdrkit && $(MAKE) clean
	cd lib/keyer-ui && $(MAKE) clean
	cd lib/sdrkit-ui && $(MAKE) clean

