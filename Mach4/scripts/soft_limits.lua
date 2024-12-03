---------------------------------------------------------------
-- Ref All Home() function.
---------------------------------------------------------------
function RefAllHome()
    mc.mcAxisDerefAll(inst)  --Just to turn off all ref leds
    mc.mcAxisHomeAll(inst)
    coroutine.yield() --yield coroutine so we can do the following after motion stops
    ----See ref all home button and plc script for coroutine.create and coroutine.resume
    wx.wxMessageBox('Referencing is complete.\nSoft Limits Set.')
    SetSoftlimits()
end

-------------------------------------------------------
--  Set Soft Limits
-------------------------------------------------------
function SetSoftlimits()
    for v = 0, 5, 1 do --start, end, increment
        mc.mcSoftLimitSetState(inst, v, mc.MC_ON)
        
    end
    scr.SetProperty("tbtnSoftLimits", "Button State", tostring(1))
    scr.SetProperty("tbSoftLimits", "Button State", tostring(1))
    
end