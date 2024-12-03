(save machine state)
M70

(set the a-axis direction here)
(1 means +ve A moves the top of the work toward the operator)
(-1 if +ve A moves the top of the work away)
#<rotaryDirection> = 1.

(do this in metric)
G21

(Probing control variables)
#<_probeFastSpeed>= 750.0
#<_probeSlowSpeed>= 50.0
#<_probeSlowDistance>= 1.0

(clearance set to 10 mm)
#<clearance> = 10.0
#<feed> = 1500.0

(select the probe)
T99 M6 G43 H99

G90

(probe down to the first touch)
o<f360_probe_z> call [-1.] [2.0 * #<clearance>]

(and record the z coord)
#<zhit1> = #5063

(Retract above the hit)
G90 G1 Z[#<zhit1> + #<clearance>] F#<feed>
(DEBUG,Z touch found at #<zhit1>)

(move across)
o<f360_safe_move_y> call [-2.0 * #5421] [#<feed>]

(probe down to the second touch)
o<f360_probe_z> call [-1.] [2.0 * #<clearance>]

(and record the z coord)
#<zhit2> = #5063

(Retract above the hit)
G90 G1 Z[#<zhit2> + #<clearance>] F#<feed>
(DEBUG,Z touch found at #<zhit2>)
o100 if [#5421 LT 0.0]
    #<angleResult> = [atan [#<zhit1> - #<zhit2>] /  [-2.0 * #5421]]
o100 else
    #<angleResult> = [atan [#<zhit2> - #<zhit1>] /  [2.0 * #5421]]
o100 endif

(DEBUG,Angle was #<angleResult>, should have been #5423)

(now correct the wcs)
G10 L2 P0 A[#<_work_offset_a> - #<rotaryDirection> * #<angleResult> + #5423]
G0 A0.0

(retore machine state)
M72

(end of program)
M30
