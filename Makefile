all::
	cd keyers && $(MAKE) all

clean::
	rm -f *~ */*~
	cd keyers && $(MAKE) clean
