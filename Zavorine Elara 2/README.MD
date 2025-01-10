Zavorine Editions to Elara Mach Instance.

- Added functional Home All button to main screen
- Soft limits turned on at runtime
	- Since z carriage can crash into 4th axis housing (wtf) set a z height soft limit to prevent that as well as regular softlimits near XY limit switches
- Added Soft Limit toggle button to main screen
- In NS_CNC.lua in the tool change script added code to toggle off z soft limit during tool change so that spindle can actually get close enought to drop and pick up tools. If soft limits were turned on before the tool change the z soft limit is turned back on at the end of the tool change
- Added probe protection handler in SigLib block
	- If probe is triggered when Probing signal is not active the machine is stopped.
	- Need to add code to be able to toggle on and off probe protection
- Added probing routing to flatten A axis iteratively.
