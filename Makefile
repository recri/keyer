all::
	cd keyers && $(MAKE) all
	cd sdrkit && $(MAKE) all
	cd lib/sdrkit && $(MAKE) all

clean::
	cd keyers && $(MAKE) clean
	cd sdrkit && $(MAKE) clean
	cd lib/sdrkit && $(MAKE) clean

