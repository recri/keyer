Don't read this, it's a confusion of many different times in the
development.
------------------------------------------------------------------------
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

Naming

block-*.tcl - a block, ie node, in the computation graph which may be
	    enabled, disabled, or controlled.
comp-*.tcl - a computational component which wraps some unit or units
	   inside a block
radio.tcl - one radio definition
radio-control.tcl - the radio controller
radio-hw-*.tcl - a radio hardware interface
radio-ui-*.tcl - a radio user interface
ui-*.tcl - user interface components

------------------------------------------------------------------------

Now each component is a block, either a container block, an alternate
block, or an audio block.  The audio and alternate blocks register
controls, but it seems that:

[x] all the blocks should register as controls
[x] all the blocks should have the -enabled/-implemented options
[x] only -implemented true blocks can be -enabled true
[x] only blocks with parent -enabled true can be -enabled true
[x] setting a block -enabled false forces all children -enabled false
[ ] someone needs to remember the control values
[x] the block-audio wrappers should use [$widget configure] to
  determine the controls.

------------------------------------------------------------------------

[x] debug the failure to enable
[x] stop passing options that can be retrieved or computed from the
  -partof parent pointer, eg
	-server is $options(-partof) cget -server
	-control is $options(-partof) cget -control
	-prefix is $options(-partof) cget -name
[x] rename for functional distinctions
[x] abstract the pipeline block
[-] abstract the radiobutton block required for demodulation
	not sure where the abstraction really goes
[x] start making a Tk ui block
[ ] implement block-midi
  keyer-debounce
  keyer-iambic
  keyer-dttsp-iambic
  keyer-ptt
[ ] implement block-midi-audio
  keyer-tone
  keyer-ptt-mute
[ ] implement block-audio-midi
  keyer-detone
[ ] add the missing/unimplemented components
  The parts that aren't done should just be inserted as unimplemented
  dummies so I can not worry about how they're supposed to work.
[ ] devise a spectrum block that can be enabled to provide a spectrum
[ ] devise a meter block that can be enabled to provide a meter
[ ] figure out the composite control components
  deconstructing tuning commands into frequency setters
  deconstructing mode commands into demodulation and filter setters

------------------------------------------------------------------------

This is still bugging me in that the implementation is overly
complicated.  It seems that snit is best when the the core
functionality is implemented in a base type, and the variations are
added on in types which embellish the base type.

There are four things going on here:

1) the wiring up of jack components so they can be hot
enabled/disabled and connected/disconnected from the jack process
graph.
2) the hierarchical grouping of components into functional blocks.
3) the hierarchical naming of components
4) the provision of the control interface that avoids the hierarchy.

So we started with 1 and quickly added 2, or vice versa.
3 sort of happened along the way to provide the names used by 4.
Then I generalized the enablement mechanism in a way that turns out to
be more awkward than useful -- the pipelines don't need to be enabled.

But then the alternate/select block threw several more awkwardnesses
into the pot, it has a control, it's imposing a structure, but it's
just trying to clarify the hierarchical structure -- I could simply
throw all the detectors in-line and impose the radiobutton constraint
elsewhere.  The separate demodulation pipelines seem like a good idea
because the noise limiters are different for the different
demodulations.
