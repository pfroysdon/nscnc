-- Zavorine Elara 2
-- Aleksey Pavlov 1/10/2025
-- The following code is added to the SigLib block at the beginning of the ScreenScript.lua file via the Screen Editor in Mach
-- Whenever the probe is triggered this signal block checks if the machine is in a probing state. If it is not the machine is disabled
-- For me, my touch probe is PROBE3 hence the signal is mc.ISIG_PROBE3
-- Since my probe is a NC probe, if the probe is unplugged the machine sees the same state as if the probe is triggered. 
-- Which means this code will prevent the machine from running if my probe is unplugged.
--   - Hence need to add further code to allow Probe Protection to be toggled on and off via button.


[mc.ISIG_PROBE3] = function (state)
    -- ADP Add probe protection
    if ((state == 1) and (machState ~= mc.MC_STATE_MRUN_PROBE)) then
        mc.mcCntlEnable(inst, 0)
    end
end,
