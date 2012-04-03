These wrappers are written using SNIT which is a pure-Tcl object
composition wrapper included in tcllib and described here:

  http://wiki.tcl.tk/3963
  http://tcllib.sourceforge.net/doc/snit.html
  http://tcllib.sourceforge.net/doc/snitfaq.html

I originally started using it to provide widget/object like interfaces
to computations written in Tcl, so they could behave like the
widget/object interfaces provided by the jack-tcl-wrap factories, but
like most object code the logic of refactoring has taken over.

These now provide a wrapper around the jack-tcl-wrap commands which
allow them to be wired into a potential computation graph and then hot
enabled or disabled.  They are connected and disconnected from Jack as
required.  This means that the computation graph does no little thumb
twiddling or dithering about whether x is true or false while
computing the software defined radio graph.  The computation required
just happens, the unrequired parts are sitting on the bench

The wrapper also supports the abstraction of the control interface
away from the details of the computation graph.  So the details of
control are localized between the controller and the controllees.

------------------------------------------------------------------------

[x] debug the failure to enable
[x] stop passing options that can be retrieved or computed from the
  -partof parent pointer, eg
	-server is $options(-partof) cget -server
	-control is $options(-partof) cget -control
	-prefix is $options(-partof) cget -name
[x] rename for functional distinctions
[ ] abstract the pipeline block
[ ] abstract the radiobutton block required for demodulation
[ ] start making a Tk ui block
[ ] implement block-sdrkit-midi
  keyer-debounce
  keyer-iambic
  keyer-dttsp-iambic
  keyer-ptt
[ ] implement block-sdrkit-midi-audio
  keyer-tone
  keyer-ptt-mute
[ ] implement block-sdrkit-audio-midi
  keyer-detone
[ ] add the missing/unimplemented components
  The parts that aren't done should just be inserted as unimplemented
  dummies so I can not worry about how they're supposed to work.
[ ] insert spectrum and meter tap components
[ ] figure out the composite control components
  deconstructing tuning commands into frequency setters
  deconstructing mode commands into demodulation and filter setters
