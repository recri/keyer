The snit wrappers provide a consistent widget/object interface for the
compositions of sdrkit plugins.

They should also provide a mechanism for maintaining jack connections
as the exact identity of the modules change.  I'm not sure how I want
that to work, yet, but I know that maintaining a global map of what's
active isn't feasible -- it's entirely possible that the input block
for an sdrkit radio will consist of nothing but the audio capture
ports from the hardware, possibly swapped, but with no other
processing involved in the block.

That is, the input block provides IQ swapping, IQ delays, IQ
correction and RF gain, but if none of those functions are active, it
directly connects its inputs to the next stage.

So the input block has defined input ports.  It gets them from
somewhere, it connects them where it will, and has defined output 
ports, which it supplies to output blocks which wish to connect.

And the output block has defined output ports, which may be directly
connected to the outputs of the previous block if no output processing
is required.

Okay, so a "block" is a processing unit which has inputs and outputs
which are implemented as jack ports.  Within the block may be zero or
more processing units which also have inputs and outputs implemented
as jack ports.  So, we instantiate a computation graph by creating
blocks and identifying their input/output connection graph.

So each of my radio block's should have a component which implements
the block connection scheme.  That component will establish
connection(s) with its peer component(s) and identify the input and
output jack ports of the block.

So, we make a radio like:

    set in [sdrkit::input input]
    $in set input ports system:capture_1 system:capture_2
    set lo [sdrkit::lo-mixer lo]
    $lo add input block $in
    set bpf [sdrkit::filter-overlap-save bpf]
    $bpf add input block $lo
    set dem [sdrkit::demod dem]
    $dem add input block $bpf
    $dem set output ports system:playback_1 system:playback_2

where sdrkit::input, sdrkit::lo-mixer, sdrkit::bpf, and sdrkit::demod
are all snit types which delegate to a block component to handle the
connection duties.

The other aspect of the input, lo-mixer, bpf, and demod is their
control interface.  Each of them have a base set of controls.

    
