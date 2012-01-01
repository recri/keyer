all::
	cd keyers && $(MAKE) all
	cd sdrkit && $(MAKE) all

clean::
	rm -f *~ */*~
	cd keyers && $(MAKE) clean
	cd sdrkit && $(MAKE) clean

