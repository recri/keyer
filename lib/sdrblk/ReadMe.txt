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

block.tcl - a block, ie node, in the computation graph which may be
	    enabled, activated, or controlled.
comp-*.tcl - a computational component which wraps some unit or units
	   inside a block
radio.tcl - one radio definition
radio-control.tcl - the radio controller
radio-hw-*.tcl - a radio hardware interface
radio-ui-*.tcl - a radio user interface
ti-*.tcl - tk implemented visual displays
ui-*.tcl - user interface components
------------------------------------------------------------------------

Now each component is a block.

A block can be:
 - a sequence of blocks
 - a set of alternates
 - a wrapper around a jack audio or midi component
 - a named spectrum tap point
 - a named meter tap point
 - an input
 - an output
 
[ ] - Skip the input/output blocks, let the unconnected inputs
  and outputs just be there, open for business.
[ ] - Implement virtual named ports that sections can pseudo
  connect to, maybe just an empty sequence.
[ ] - The jack inputs of an enabled module will then propagate
  upstream to the boundary of the section or the next enabled
  component, just like the jack outputs propagate down stream
[ ] - !!! Maybe activation is just the result of being connected
  to a live source, not anything special.
[ ] - Maybe the propagation in either direction is a "connect-me"
  which doesn't immediately displace previous connections, it
  augments them.  A "disconnect-me" follows to undo the previous
  connections if that's what's needed.  Handles split/join with
  no explicit node to handle it, any connector can make a split
  or a join.
[ ] - The result is a bunch of unconnected computational modules,
  jack sources, and jack sinks.  So there will be a need for a
  connection interface.  And the interface that starts jack up
  with the necessary interfaces running at the correct sample
  rates with the necessary resampling.
[ ] - The standard jack/alsa resampling apparently uses raw FIR
  filters rather than FFT overlap/save overlap/add filters.
  Doesn't make much sense, the FIR with N coefficients delays the
  samples, too, much longer because of the cost of the raw FIR
  convolution.
[ ] - So starting jack and connecting hardware ports to enabled
  sections becomes another part of the control module.
