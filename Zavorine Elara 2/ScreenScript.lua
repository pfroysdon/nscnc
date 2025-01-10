-- For ZeroBrane debugging.
package.path = package.path .. ";./ZeroBraneStudio/lualibs/mobdebug/?.lua"

-- For installed profile modules support.
package.path = package.path .. ";./Profiles/NS_CNC_3/Modules/?.lua"
package.path = package.path .. ";./Profiles/NS_CNC_3/Modules/?.luac"
package.path = package.path .. ";./Profiles/NS_CNC_3/Modules/?.mcs"
package.path = package.path .. ";./Profiles/NS_CNC_3/Modules/?.mcc"
package.cpath = package.cpath .. ";./Profiles/NS_CNC_3/Modules/?.dll"

-- For installed global modules support.
package.path = package.path .. ";./Modules/?.lua"
package.path = package.path .. ";./Modules/?.luac"
package.path = package.path .. ";./Modules/?.mcs"
package.path = package.path .. ";./Modules/?.mcc"
package.cpath = package.cpath .. ";./Modules/?.dll"

-- PMC genearated module load code.
package.path = package.path .. ";./Pmc/?.lua"
package.path = package.path .. ";./Pmc/?.luac"


-- PMC genearated module load code.
function Mach_Cycle_Pmc()
end

-- Screen load script (Global)
-- Machine Model --
MACHINE_MODEL = "Mira_6S_AR"


----------screen Load--------------
pageId = 0
screenId = 0
testcount = 0
machState = 0
machStateOld = -1
machEnabled = 0
machWasEnabled = 0
inst = mc.mcGetInstance()

---------------------------------------------------------------
-- Signal Library
---------------------------------------------------------------
SigLib = {
[mc.OSIG_MACHINE_ENABLED] = function (state)
    machEnabled = state;
    ButtonEnable()
end,

[mc.ISIG_PROBE3] = function (state)
    -- adp Add probe protection
    if ((state == 1) and (machState ~= mc.MC_STATE_MRUN_PROBE)) then
        mc.mcCntlEnable(inst, 0)
    end
end,

[mc.ISIG_INPUT0] = function (state)
    
end,

[mc.ISIG_INPUT1] = function (state) -- this is an example for a condition in the signal table.
   -- if (state == 1) then   
--        CycleStart()
--    --else
--        --mc.mcCntlFeedHold (0)
--    end

end,

[mc.OSIG_JOG_CONT] = function (state)
    if( state == 1) then 
      -- scr.SetProperty('inc_cont', 'Label', 'Continuous');
       scr.SetProperty('txtJogInc', 'Bg Color', '#C0C0C0');--Light Grey
       scr.SetProperty('txtJogInc', 'Fg Color', '#808080');--Dark Grey
    end
end,

[mc.OSIG_JOG_INC] = function (state)
    if( state == 1) then
       -- scr.SetProperty('inc_cont', 'Label', 'Incremental');
        scr.SetProperty('txtJogInc', 'Bg Color', '#FFFFFF');--White    
        scr.SetProperty('txtJogInc', 'Fg Color', '#000000');--Black
   end
end,

[mc.OSIG_JOG_MPG] = function (state)
    if( state == 1) then
        scr.SetProperty('inc_cont', 'Label', '');
        scr.SetProperty('txtJogInc', 'Bg Color', '#C0C0C0');--Light Grey
        scr.SetProperty('txtJogInc', 'Fg Color', '#808080');--Dark Grey
        --add the bits to grey jog buttons becasue buttons can't be MPGs
    end
end
}
---------------------------------------------------------------
-- Keyboard Inputs Toggle() function. Updated 5-16-16
---------------------------------------------------------------
function KeyboardInputsToggle()
	local iReg = mc.mcIoGetHandle (inst, "Keyboard/Enable")
    local iReg2 = mc.mcIoGetHandle (inst, "Keyboard/EnableKeyboardJog")
	
	if (iReg ~= nil) and (iReg2 ~= nil) then
        local val = mc.mcIoGetState(iReg);
		if (val == 1) then
            mc.mcIoSetState(iReg, 0);
            mc.mcIoSetState(iReg2, 0);
			scr.SetProperty('btnKeyboardJog', 'Bg Color', '');
            scr.SetProperty('btnKeyboardJog', 'Label', 'Keyboard\nInputs Enable');
		else
            mc.mcIoSetState(iReg, 1);
            mc.mcIoSetState(iReg2, 1);
            scr.SetProperty('btnKeyboardJog', 'Bg Color', '#00FF00');
            scr.SetProperty('btnKeyboardJog', 'Label', 'Keyboard\nInputs Disable');
        end
	end
end
---------------------------------------------------------------
-- Remember Position function.
---------------------------------------------------------------
function RememberPosition()
    local pos = mc.mcAxisGetMachinePos(inst, 0) -- Get current X (0) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "X", string.format (pos)) --Create a register and write the machine coordinates to it
    local pos = mc.mcAxisGetMachinePos(inst, 1) -- Get current Y (1) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "Y", string.format (pos)) --Create a register and write the machine coordinates to it
    local pos = mc.mcAxisGetMachinePos(inst, 2) -- Get current Z (2) Machine Coordinates
    mc.mcProfileWriteString(inst, "RememberPos", "Z", string.format (pos)) --Create a register and write the machine coordinates to it
end
---------------------------------------------------------------
-- Return to Position function.
---------------------------------------------------------------
function ReturnToPosition()
    local xval = mc.mcProfileGetString(inst, "RememberPos", "X", "NotFound") -- Get the register Value
    local yval = mc.mcProfileGetString(inst, "RememberPos", "Y", "NotFound") -- Get the register Value
    local zval = mc.mcProfileGetString(inst, "RememberPos", "Z", "NotFound") -- Get the register Value
    
    if(xval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register xval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    elseif (yval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register yval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    elseif (zval == "NotFound")then -- check to see if the register is found
        wx.wxMessageBox('Register zval does not exist.\nYou must remember a postion before you can return to it.'); -- If the register does not exist tell us in a message box
    else
        mc.mcCntlMdiExecute(inst, "G00 G53 Z0.0000 \n G00 G53 X" .. xval .. "\n G00 G53 Y" .. yval .. "\n G00 G53 Z" .. zval)
    end
end
---------------------------------------------------------------
-- Spin CW function.
---------------------------------------------------------------

function Unclamp()
	local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_OUTPUT32);
	local signal = mc.mcSignalGetState(sigh);
	
	if (signal == 1) then
		mc.mcSignalSetState(sigh, 0);
	else
		mc.mcSignalSetState(sigh, 1);
	end
end

function CoolantOnOff()
	local sigh = mc.mcSignalGetHandle(inst, mc.COOLANT);
	local signal = mc.mcSignalGetState(sigh);
	
	if (signal == 1) then
		mc.mcSignalSetState(sigh, 0);
	else
		mc.mcSignalSetState(sigh, 1);
	end
end

function SpinCW()
    local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    local sigState = mc.mcSignalGetState(sigh);
    
    if (sigState == 1) then 
        mc.mcSpindleSetDirection(inst, 0);
    else 
        mc.mcSpindleSetDirection(inst, 1);
        local range = mc.mcSpindleGetCurrentRange(inst)
        local maxrpm = mc.mcSpindleGetMaxRPM(inst, range)
		ns.MDICommand(string.format("s%dm3", maxrpm))
    end
end
---------------------------------------------------------------
-- Spin CCW function.
---------------------------------------------------------------
function SpinCCW()
    local sigh = mc.mcSignalGetHandle(inst, mc.OSIG_SPINDLEON);
    local sigState = mc.mcSignalGetState(sigh);
    
    if (sigState == 1) then 
        mc.mcSpindleSetDirection(inst, 0);
    else 
        mc.mcSpindleSetDirection(inst, -1);
		--ns.MDICommand(string.format("s20000m3"));
    end
end
---------------------------------------------------------------
-- Open Docs function.
---------------------------------------------------------------
function OpenDocs()
    local major, minor = wx.wxGetOsVersion()
    local dir = mc.mcCntlGetMachDir(inst);
    local cmd = "explorer.exe /open," .. dir .. "\\Docs\\"
    if(minor <= 5) then -- Xp we don't need the /open
        cmd = "explorer.exe ," .. dir .. "\\Docs\\"
    end
	os.execute(cmd)
	scr.RefreshScreen(250); -- Windows 7 and 8 seem to require the screen to be refreshed.  
end

---------------------------------------------------------------
-- Button Jog Mode Toggle() function.
---------------------------------------------------------------
function ButtonJogModeToggle()
    local cont = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_CONT);
    local jogcont = mc.mcSignalGetState(cont)
    local inc = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_INC);
    local joginc = mc.mcSignalGetState(inc)
    local mpg = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_MPG);
    local jogmpg = mc.mcSignalGetState(mpg)
    
    if (jogcont == 1) then
        mc.mcSignalSetState(cont, 0)
        mc.mcSignalSetState(inc, 1)
        mc.mcSignalSetState(mpg, 0)        
    else
        mc.mcSignalSetState(cont, 1)
        mc.mcSignalSetState(inc, 0)
        mc.mcSignalSetState(mpg, 0)
    end

end
---------------------------------------------------------------
-- Ref All Home() function.
---------------------------------------------------------------
function RefAllHome()
    mc.mcAxisDerefAll(inst)  --Just to turn off all ref leds
    mc.mcAxisHomeAll(inst)
    coroutine.yield() --yield coroutine so we can do the following after motion stops
    ----See ref all home button and plc script for coroutine.create and coroutine.resume
    wx.wxMessageBox('Referencing is complete')
end
---------------------------------------------------------------
-- Go To Work Zero() function.
---------------------------------------------------------------
function GoToWorkZero()
    mc.mcCntlMdiExecute(inst, "G00 X0 Y0 A0")--Without Z moves
    --mc.mcCntlMdiExecute(inst, "G00 G53 Z0\nG00 X0 Y0 A0\nG00 Z0")--With Z moves
end

-------------------------------------------------------
--  Seconds to time Added 5-9-16
-------------------------------------------------------
--Converts decimal seconds to an HH:MM:SS.xx format
function SecondsToTime(seconds)
	if seconds == 0 then
		return "00:00:00.00"
	else
		local hours = string.format("%02.f", math.floor(seconds/3600))
		local mins = string.format("%02.f", math.floor((seconds/60) - (hours*60)))
		local secs = string.format("%04.2f",(seconds - (hours*3600) - (mins*60)))
		return hours .. ":" .. mins .. ":" .. secs
	end
end
---------------------------------------------------------------
-- Set Button Jog Mode to Cont.
---------------------------------------------------------------
local cont = mc.mcSignalGetHandle(inst, mc.OSIG_JOG_CONT);
local jogcont = mc.mcSignalGetState(cont)
mc.mcSignalSetState(cont, 1)

---------------------------------------------------------------
--Timer panel example
---------------------------------------------------------------
TimerPanel = wx.wxPanel (wx.NULL, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize( 0,0 ) )
timer = wx.wxTimer(TimerPanel)
TimerPanel:Connect(wx.wxEVT_TIMER,
function (event)
    wx.wxMessageBox("Hello")
    timer:Stop()
end)

function LoadModules()
	---------------------------------------------------------------
	-- Load modules
	---------------------------------------------------------------
	--Master module
	package.loaded.mcMasterModule = nil
	mm = require "mcMasterModule"

	--Probing module
	package.loaded.Probing = nil
	prb = require "mcProbing"
	--mc.mcCntlSetLastError(inst, "Probe Version " .. prb.Version());

	--ErrorCheck module Added 11-4-16
	package.loaded.mcErrorCheck = nil
	mcErrorCheck = require "mcErrorCheck"

	--Trace module
	package.loaded.mcTrace = nil
	trace = require "mcTrace"

	--NS CNC
	package.loaded.NS_CNC = nil
	ns = require "NS_CNC"

	--NS CNC
	package.loaded.WrapperModule = nil
	w = require "WrapperModule"

	local is_ok, err = pcall(ns.ScreenLoadScript)
	if not is_ok then
		wx.wxMessageBox(tostring(err))
	end

    --if package.loaded.GUIModule == nil then
	--	package.loaded.GUIModule = nil
	--	h = require "GUIModule"
	--end
end

LoadModules()

---------------------------------------------------------------
-- Get fixtue offset pound variables function Updated 5-16-16
---------------------------------------------------------------
function GetFixOffsetVars()
    local FixOffset = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_14)
    local Pval = mc.mcCntlGetPoundVar(inst, mc.SV_BUFP)
    local FixNum, whole, frac

    if (FixOffset ~= 54.1) then --G54 through G59
        whole, frac = math.modf (FixOffset)
        FixNum = (whole - 53) 
        PoundVarX = ((mc.SV_FIXTURES_START - mc.SV_FIXTURES_INC) + (FixNum * mc.SV_FIXTURES_INC))
        CurrentFixture = string.format('G' .. tostring(FixOffset)) 
    else --G54.1 P1 through G54.1 P100
        FixNum = (Pval + 6)
        CurrentFixture = string.format('G54.1 P' .. tostring(Pval))
        if (Pval > 0) and (Pval < 51) then -- G54.1 P1 through G54.1 P50
            PoundVarX = ((mc.SV_FIXTURE_EXPAND - mc.SV_FIXTURES_INC) + (Pval * mc.SV_FIXTURES_INC))
        elseif (Pval > 50) and (Pval < 101) then -- G54.1 P51 through G54.1 P100
            PoundVarX = ((mc.SV_FIXTURE_EXPAND2 - mc.SV_FIXTURES_INC) + (Pval * mc.SV_FIXTURES_INC))	
        end
    end
PoundVarY = (PoundVarX + 1)
PoundVarZ = (PoundVarX + 2)
return PoundVarX, PoundVarY, PoundVarZ, FixNum, CurrentFixture
-------------------------------------------------------------------------------------------------------------------
--return information from the fixture offset function
-------------------------------------------------------------------------------------------------------------------
--PoundVar(Axis) returns the pound variable for the current fixture for that axis (not the pound variables value).
--CurretnFixture returned as a string (examples G54, G59, G54.1 P12).
--FixNum returns a simple number (1-106) for current fixture (examples G54 = 1, G59 = 6, G54.1 P1 = 7, etc).
-------------------------------------------------------------------------------------------------------------------
end
---------------------------------------------------------------
-- Button Enable function Updated 11-8-2015
---------------------------------------------------------------
function ButtonEnable() --This function enables or disables buttons associated with an axis if the axis is enabled or disabled.

    AxisTable = {
        [0] = 'X',
        [1] = 'Y',
        [2] = 'Z',
        [3] = 'A',
        [4] = 'B',
        [5] = 'C'}
        
    for Num, Axis in pairs (AxisTable) do -- for each paired Num (key) and Axis (value) in the Axis table
        local rc = mc.mcAxisIsEnabled(inst,(Num)) -- find out if the axis is enabled, returns a 1 or 0
        scr.SetProperty((string.format ('btnPos' .. Axis)), 'Enabled', tostring(rc)); --Turn the jog positive button on or off
        scr.SetProperty((string.format ('btnNeg' .. Axis)), 'Enabled', tostring(rc)); --Turn the jog negative button on or off
        scr.SetProperty((string.format ('btnZero' .. Axis)), 'Enabled', tostring(rc)); --Turn the zero axis button on or off
        scr.SetProperty((string.format ('btnRef' .. Axis)), 'Enabled', tostring(rc)); --Turn the reference button on or off
    end
end
ButtonEnable()
-- PLC script
function Mach_PLC_Script()
    local inst = mc.mcGetInstance()
    local rc = 0;
    testcount = testcount + 1
    machState, rc = mc.mcCntlGetState(inst);
    local inCycle = mc.mcCntlIsInCycle(inst);
    
    -------------------------------------------------------
    --  Set plate align (G68) Led
    -------------------------------------------------------
    local curLedState = math.tointeger(scr.GetProperty("ledPlateAlign", "Value"))
    local curAlignState = math.tointeger((mc.mcCntlGetPoundVar(inst, 4016) - 69))
    curAlignState = math.abs(curAlignState)
    if (curLedState ~= curAlignState) then
    	scr.SetProperty("ledPlateAlign", "Value", tostring(curAlignState))
    end
    -------------------------------------------------------
    --  Coroutine resume
    -------------------------------------------------------
    if (wait ~= nil) and (machState == 0) then --wait exist and state == idle
    	local state = coroutine.status(wait)
        if state == "suspended" then --wait is suspended
            coroutine.resume(wait)
        end
    end
    -------------------------------------------------------
    --  Cycle time label update
    -------------------------------------------------------
    --Requires a static text box named "CycleTime" on the screen
    if (machEnabled == 1) then
    	local cycletime = mc.mcCntlGetRunTime(inst, time)
    	scr.SetProperty("CycleTime", "Label", SecondsToTime(cycletime))
    end
    -------------------------------------------------------
    --  Set Height Offset Led
    -------------------------------------------------------
    local HOState = mc.mcCntlGetPoundVar(inst, 4008)
    if (HOState == 49) then
        scr.SetProperty("ledHOffset", "Value", "0")
    else
        scr.SetProperty("ledHOffset", "Value", "1")
    end
    -------------------------------------------------------
    --  Set Spindle Ratio DRO
    -------------------------------------------------------
    local spinmotormax, rangemax, ratio
    spinmotormax, rc = scr.GetProperty('droSpinMotorMax', 'Value');
    spinmotormax = tonumber(spinmotormax) or 1   
    rangemax, rc = scr.GetProperty('droRangeMax', 'Value')
    rangemax = tonumber(rangemax) or 1
    ratio = (rangemax / spinmotormax)    
    scr.SetProperty('droRatio', 'Value', tostring(ratio))
    
    -------------------------------------------------------
    --  Set Feedback Ratio DRO Updated 5-30-16
    -------------------------------------------------------
    local range, rc = mc.mcSpindleGetCurrentRange(inst)
    local fbratio, rc = mc.mcSpindleGetFeedbackRatio(inst, range)
    scr.SetProperty('droFeedbackRatio', 'Value', tostring(fbratio))
    
    -------------------------------------------------------
    --  PLC First Run
    -------------------------------------------------------
    if (testcount == 1) then --Set Keyboard input startup state
        local iReg = mc.mcIoGetHandle (inst, "Keyboard/Enable")
        mc.mcIoSetState(iReg, 0) --Set register to 1 to ensure KeyboardInputsToggle function will do a disable.
        KeyboardInputsToggle()
    	prb.LoadSettings()
    
    
    
        -- adp turn on soft limits
        mc.mcSoftLimitSetState(inst, mc.Z_AXIS, mc.MC_ON);
        mc.mcSoftLimitSetState(inst, mc.Y_AXIS, mc.MC_ON);
        mc.mcSoftLimitSetState(inst, mc.X_AXIS, mc.MC_ON);
    
    	---------------------------------------------------------------
    	-- Set Persistent DROs.
    	---------------------------------------------------------------
    
    
        DROTable = {
    	[1000] = "droJogRate", 
    	[1001] = "droSurfXPos", 
    	[1002] = "droSurfYPos", 
    	[1003] = "droSurfZPos",
        [1004] = "droInCornerX",
        [1005] = "droInCornerY",
        [1006] = "droInCornerSpaceX",
        [1007] = "droInCornerSpaceY",
        [1008] = "droOutCornerX",
        [1009] = "droOutCornerY",
        [1010] = "droOutCornerSpaceX",
        [1011] = "droOutCornerSpaceY",
        [1012] = "droInCenterWidth",
        [1013] = "droOutCenterWidth",
        [1014] = "droOutCenterAppr",
        [1015] = "droOutCenterZ",
        [1016] = "droBoreDiam",
        [1017] = "droBossDiam",
        [1018] = "droBossApproach",
        [1019] = "droBossZ",
        [1020] = "droAngleXpos",
        [1021] = "droAngleYInc",
        [1022] = "droAngleXCenterX",
        [1023] = "droAngleXCenterY",
        [1024] = "droAngleYpos",
        [1025] = "droAngleXInc",
        [1026] = "droAngleYCenterX",
        [1027] = "droAngleYCenterY",
        [1028] = "droCalZ",
        [1029] = "droGageX",
        [1030] = "droGageY",
        [1031] = "droGageZ",
        [1032] = "droGageSafeZ",
        [1033] = "droGageDiameter",
        [1034] = "droEdgeFinder",
        [1035] = "droGageBlock",
        [1036] = "droGageBlockT"
        }
    	
    	-- ******************************************************************************************* --
    	-- The following is a loop. As a rule of thumb loops should be avoided in the PLC Script.  --
    	-- However, this loop only runs during the first run of the PLC script so it is acceptable.--
    	-- ******************************************************************************************* --                                                           
    
        for name,number in pairs (DROTable) do -- for each paired name (key) and number (value) in the DRO table
            local droName = (DROTable[name]) -- make the variable named droName equal the name from the table above
            --wx.wxMessageBox (droName)
            local val = mc.mcProfileGetString(inst, "PersistentDROs", (droName), "NotFound") -- Get the Value from the profile ini
            if(val ~= "NotFound")then -- If the value is not equal to NotFound
                scr.SetProperty((droName), "Value", val) -- Set the dros value to the value from the profile ini
            end -- End the If statement
        end -- End the For loop
    end
    -------------------------------------------------------
    
    local is_ok, err = pcall(ns.PLCScript)
    if not is_ok then
    	wx.wxMessageBox(tostring(err))
    end
    
    
    --This is the last thing we do.  So keep it at the end of the script!
    machStateOld = machState;
    machWasEnabled = machEnabled;
    
    
end

-- Signal script
function Mach_Signal_Script(sig, state)
    if SigLib[sig] ~= nil then
        SigLib[sig](state);
    end
end

-- Message script
function Mach_Message_Script(msg, param1, param2)
    
end

-- Timer script
-- 'timer' contains the timer number that fired the															 script.
function Mach_Timer_Script(timer)
    
end

-- Screen unload script
function Mach_Screen_Unload_Script()
    local is_ok, err = pcall(ns.ScreenUnLoadScript)
    if not is_ok then
    	wx.wxMessageBox(tostring(err))
    end
    
    
    --Screen unload
    if (Tframe ~= nil) then
    
    	Tframe:Close()
        Tframe:Destroy()
    end
    
end

-- Screen Vision script
function Mach_Screen_Vision_Script(...)
    
end

-- Default-GlobalScript
-- Control-GlobalScript
-- WorkingCoordGroup(1)-GlobalScript
-- JoggingGroup(1)-GlobalScript
function labJogMode_Left_Up_Script(...)
    ButtonJogModeToggle()
end
function droJogRate_2__On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    local val = scr.GetProperty("droJogRate", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droJogRate", string.format (val)) --Create a register and write the machine coordinates to it
end
-- GoToGroup(1)-GlobalScript
function GoToAbsoluteBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetAbsolute, ...)
end
function GoToIncrementalBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetIncremental, ...)
end
function GoToZeroXBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetZero, mc.X_AXIS, ...)
end
function GoToZeroYBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetZero, mc.Y_AXIS, ...)
end
function GoToZeroZBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetZero, mc.Z_AXIS, ...)
end
function GoToZeroABtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetZero, mc.A_AXIS, ...)
end
function GoToZeroBBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToSetZero, mc.B_AXIS, ...)
end
function GoToMoveXBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToMoveToPosition, mc.X_AXIS, ...)
end
function GoToMoveYBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToMoveToPosition, mc.Y_AXIS, ...)
end
function GoToMoveZBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToMoveToPosition, mc.Z_AXIS, ...)
end
function GoToMoveABtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToMoveToPosition, mc.A_AXIS, ...)
end
function GoToMoveBBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.GoToMoveToPosition, mc.B_AXIS, ...)
end
-- CoolantGroup(1)-GlobalScript
function ContinuousCoolantBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantContinuousToggle,nil, ...)
end
function FloodPulseDRO_1__On_Modify_Script(...)
    ns.DROChanged(ns.CoolantPulseDROChanged, ...)
end
function btnSROUp_1__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantPulseInc, 0.01, ...)
end
function btnSRODn_1__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantPulseInc, -0.01, ...)
end
function btnSROUp_2__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantDurationInc, 1, ...)
end
function btnSRODn_2__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantDurationInc, -1, ...)
end
function FloodDurationDRO_1__On_Modify_Script(...)
    ns.DROChanged(ns.CoolantDurationDROChanged, ...)
end
function FloodCoolantBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.CoolantFloodToggle,nil, ...)
end
-- CalibrationGroup(1)-GlobalScript
function MoveA90Btn_1__Clicked_Script(...)
    ns.ButtonCall(ns.MoveAToPosition, 90, ...)
end
function MoveA90BNegtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.MoveAToPosition, -90, ...)
end
function MoveA0Btn_1__Clicked_Script(...)
    ns.ButtonCall(ns.MoveAToPosition, 0, ...)
end
-- ToolGroup(1)-GlobalScript
function SetToolHeightBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.SetToolHeight, nil, ...)
end
-- GCodePctGroup(1)-GlobalScript
-- ControlGroup-GlobalScript
-- ControlGroup(1)-GlobalScript
function btnLoadGcode_2__Clicked_Script(...)
    ns.ButtonCall(ns.LoadGCode, nil, ...)
end
-- ReferencePointsGroup(1)-GlobalScript
function RestoreReferenceBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.RestoreG54FixtureOffsetFromG59,nil, ...)
end
-- MachineCoordGroup(1)-GlobalScript
function btnRefX_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.X_AXIS, ...)
end
function btnRefY_1__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Y_AXIS, ...)
end
function btnRefZ_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Z_AXIS, ...)
end
function btnRefA_1__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.A_AXIS, ...)
end
function btnRefB_1__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.B_AXIS, ...)
end
-- FeedrateGroup(1)-GlobalScript
function btnFROUp_2__Left_Up_Script(...)
    local val = scr.GetProperty('slideFRO(1)', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideFRO(1)', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideFRO(1)', 'Value', tostring(val));
end
function btnFRODn_2__Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideFRO(1)', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideFRO(1)', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideFRO(1)', 'Value', tostring(val));
end
-- GCodeTab(1)-GlobalScript
-- MDITab(1)-GlobalScript
-- SpindleGroup(1)-GlobalScript
function btnSROUp_Left_Up_Script(...)
    -- Up
    local val = scr.GetProperty('slideSRO', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideSRO', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideSRO', 'Value', tostring(val));
end
function btnSRODn_Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideSRO', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideSRO', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideSRO', 'Value', tostring(val));
end
function SpindleFWDBtn_1__Left_Up_Script(...)
    SpinCW()
end
-- RapidRateGroup(1)-GlobalScript
function btnRROUp_1__Left_Up_Script(...)
    -- Up
    local val = scr.GetProperty('slideRRO', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideRRO', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideRRO', 'Value', tostring(val));
end
function btnRRODn_1__Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideRRO', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideRRO', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideRRO', 'Value', tostring(val));
end
-- ControlGroup(2)-GlobalScript
function btnStop_1__Left_Up_Script(...)
    ns.ButtonCall(ns.CycleStop,nil, ...)
end
function btnReset_1__Left_Up_Script(...)
    local inst = mc.mcGetInstance()
    mc.mcCntlReset(inst)
    mc.mcSpindleSetDirection(inst, 0)
    mc.mcCntlSetLastError(inst, '')
end
function btnCycleStart_1__Left_Up_Script(...)
    ns.ButtonCall(ns.CycleStart,nil, ...)
end
-- ATCToolGroup(1)-GlobalScript
function ToolMagToggleBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.MoveToolMagazineToggle, ...)
end
function SetToolHeightBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.SetToolHeight, nil, ...)
end
function UnClampBtn_1__Left_Up_Script(...)
    Unclamp()
end
function SetToolSetterPositionBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.SetToolSetterPosition, nil, ...)
end
-- Diag-GlobalScript
-- Input Signals-GlobalScript
-- Digital Readouts-GlobalScript
-- Output Signals-GlobalScript
-- grp(22)-GlobalScript
function GoToReferencePointXBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.GoToReferencePointPosition, mc.X_AXIS, ...)
end
function GoToReferencePointYBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.GoToReferencePointPosition, mc.Y_AXIS, ...)
end
function GoToReferencePointZBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.GoToReferencePointPosition, mc.Z_AXIS, ...)
end
function SetReferencePointXBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.SetReferencePointPosition, mc.X_AXIS, ...)
end
function SetReferencePointYBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.SetReferencePointPosition, mc.Y_AXIS, ...)
end
function SetReferencePointZBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.SetReferencePointPosition, mc.Z_AXIS, ...)
end
function RestoreReferenceBtn_3__Clicked_Script(...)
    ns.ButtonCall(ns.RestoreG54FixtureOffsetFromG59,nil, ...)
end
-- HomingGroup(1)-GlobalScript
function btnRefX_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.X_AXIS, ...)
end
function btnRefY_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Y_AXIS, ...)
end
function btnRefZ_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Z_AXIS, ...)
end
function btnRefA_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.A_AXIS, ...)
end
function btnRefAllDiag_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAll,nil, ...)
end
function btn_74__Clicked_Script(...)
    ns.ButtonCall(ns.CalibrateDriveBasedHomingPosiiton,mc.A_AXIS, ...)
end
function btn_75__Clicked_Script(...)
    ns.ButtonCall(ns.CalibrateDriveBasedHomingPosiiton,mc.B_AXIS, ...)
end
function RotaryModeBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.RotaryModeToggle, nil, ...)
end
function btnRefB_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.B_AXIS, ...)
end
function btnRefB_4__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.B_AXIS, ...)
end
-- ToolSetterSettingsGroup(1)-GlobalScript
function SetToolSetterPositionBtn_2__Clicked_Script(...)
    ns.ButtonCall(ns.SetToolSetterPosition, nil, ...)
end
-- ToolSetterSettingsGroup(2)-GlobalScript
function EnableToolHeightInTCBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.ToggleBoolSettings, "ToolChanger/MeasureToolLengthDuringToolChange", ...)
end
function EnableToolBreakCheckInTCBtn_1__Clicked_Script(...)
    ns.ButtonCall(ns.ToggleBoolSettings, "ToolChanger/ToolBreakageCheck", ...)
end
-- MachineModelGroup(1)-GlobalScript
function ModelDropDown_1__On_Modify_Script(...)
    ns.ButtonCall(ns.MachineModelChanged,nil, ...)
end
function ReLoadScrip_1__Left_Down_Script(...)
    ns.ButtonCall(ns.ReLoadScripts, nil, ...)
end
-- Settings-GlobalScript
-- ToolChanger-GlobalScript
-- ToolSetter-GlobalScript
-- Tool List-GlobalScript
-- Working Offset-GlobalScript
-- tabProbing-GlobalScript
-- tabPSingleSurf-GlobalScript
-- grpProbeY-GlobalScript
function droSurfYPos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnSurfY_Clicked_Script(...)
    --Single Surface Measure Y button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local ypos = scr.GetProperty("droSurfYPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfY (ypos, work)
end
function btnSurfYHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
-- grpProbeZ-GlobalScript
function droSurfZPos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnSurfZ_Clicked_Script(...)
    --Single Surface Measure Z button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local zpos = scr.GetProperty("droSurfZPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfZ (zpos, work)
end
function btnSurfZHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
-- grpProbeX-GlobalScript
function droSurfXPos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnSurfX_Clicked_Script(...)
    --Single Surface Measure X button
    --PRIVATE
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    --Probing module
    package.loaded.Probing = nil
    
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droSurfXPos", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleSurfX (xpos, work)
end
function btnSurfXHelp_Clicked_Script(...)
    prb.SingleSurfHelp()
    
end
-- tabCorners-GlobalScript
-- grpInsideCorner-GlobalScript
function droInCornerX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droInCornerY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droInCornerSpaceX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droInCornerSpaceY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnInCorner_Clicked_Script(...)
    --Corners inner measure button
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droInCornerX", "Value")
    local ypos = scr.GetProperty("droInCornerY", "Value")
    local xinc = scr.GetProperty("droInCornerSpaceY", "Value")
    local yinc = scr.GetProperty("droInCornerSpaceX", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InternalCorner (xpos, ypos, xinc, yinc, work)
end
function btnInCornerHelp_Clicked_Script(...)
    prb.InsideCornerHelp()
    
end
-- grpOutsideCorner-GlobalScript
function droOutCornerX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOutCornerY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOutCornerSpaceX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOutCornerSpaceY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnOutCorner_Clicked_Script(...)
    -- Outside corner Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droOutCornerX", "Value")
    local ypos = scr.GetProperty("droOutCornerY", "Value")
    local xinc = scr.GetProperty("droOutCornerSpaceY", "Value")
    local yinc = scr.GetProperty("droOutCornerSpaceX", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.ExternalCorner (xpos, ypos, xinc, yinc, work)
    
end
function btnOutCornerHelp_Clicked_Script(...)
    prb.OutsideCornerHelp()
    
end
-- tabCentering-GlobalScript
-- grpInsideCenter-GlobalScript
function droInCenterWidth_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnInCenterX_Clicked_Script(...)
    -- Inside X centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droInCenterWidth", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InsideCenteringX (width, work)
end
function btnInCenterY_Clicked_Script(...)
    -- Inside Y centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droInCenterWidth", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.InsideCenteringY (width, work)
end
function btnInCenterHelp_Clicked_Script(...)
    prb.InsideCenteringHelp()
    
end
-- grpOutsideCenter-GlobalScript
function droOutCenterWidth_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOutCenterAppr_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOutCenterZ_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnOutCenterX_Clicked_Script(...)
    -- Outside X centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droOutCenterWidth", "Value")
    local approach = scr.GetProperty("droOutCenterAppr", "Value")
    local zpos = scr.GetProperty("droOutCenterZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.OutsideCenteringX (width, approach, zpos, work)
end
function btnOutCenterY_Clicked_Script(...)
    -- Outside Y centering
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local width = scr.GetProperty("droOutCenterWidth", "Value")
    local approach = scr.GetProperty("droOutCenterAppr", "Value")
    local zpos = scr.GetProperty("droOutCenterZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.OutsideCenteringY (width, approach, zpos, work)
end
function btnOutCenterHelp_Clicked_Script(...)
    prb.OutsideCenteringHelp()
    
end
-- tabBoreBoss-GlobalScript
-- grpBore-GlobalScript
function droBoreDiam_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnBore_Clicked_Script(...)
    -- Bore Dia Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local diam = scr.GetProperty("droBoreDiam", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.Bore (diam, work)
    
end
function btnInCornerHelp_1__Clicked_Script(...)
    prb.BoreHelp()
    
end
-- grpBoss-GlobalScript
function droBossDiam_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droBossApproach_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droBossZ_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnBoss_Clicked_Script(...)
    -- Boss Diam Measure
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local diam = scr.GetProperty("droBossDiam", "Value")
    local approach = scr.GetProperty("droBossApproach", "Value")
    local zpos = scr.GetProperty("droBossZ", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.Boss (diam, approach, zpos, work)
end
function btnInCornerHelp_2__Clicked_Script(...)
    prb.BossHelp()
    
end
-- tabAngle-GlobalScript
-- grpAngleX-GlobalScript
function droAngleXpos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleYInc_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleXCenterX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleXCenterY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnAngleX_Clicked_Script(...)
    --Single Angle X
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
     
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local pos = scr.GetProperty("droAngleXpos", "Value")
    local inc = scr.GetProperty("droAngleYInc", "Value")
    local xcntr = scr.GetProperty("droAngleXCenterX", "Value")
    local ycntr = scr.GetProperty("droAngleXCenterY", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleAngleX (pos, inc, xcntr, ycntr, work)
end
function btnAngleXHelp_Clicked_Script(...)
    prb.SingleAngleHelp()
    
end
-- grpAngleY-GlobalScript
function droAngleYpos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleXInc_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleYCenterX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droAngleYCenterY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnAngleY_Clicked_Script(...)
    --Single angle Y
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local pos = scr.GetProperty("droAngleYpos", "Value")
    local inc = scr.GetProperty("droAngleXInc", "Value")
    local xcntr = scr.GetProperty("droAngleXCenterX", "Value")
    local ycntr = scr.GetProperty("droAngleXCenterY", "Value")
    local work = scr.GetProperty("ledSetWork", "Value")
    
    prb.SingleAngleY (pos, inc, xcntr, ycntr, work)
end
function btnAngleYHelp_Clicked_Script(...)
    prb.SingleAngleHelp()
    
end
-- tabCalibration-GlobalScript
-- grpZCal-GlobalScript
function droCalZ_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnProbeCalZ_Clicked_Script(...)
    --Calibrate Z
    
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local zpos = scr.GetProperty("droCalZ", "Value")
    
    prb.LengthCal (zpos)
end
function btnCalZHelp_Clicked_Script(...)
    prb.LengthCalHelp()
end
-- grpXYRadCal-GlobalScript
function droGageX_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droGageY_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droGageZ_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droGageSafeZ_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droGageDiameter_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnProbeCalXY_Clicked_Script(...)
    --Calibrate XY Offset
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droGageX", "Value")
    local ypos = scr.GetProperty("droGageY", "Value")
    local diam = scr.GetProperty("droGageDiameter", "Value")
    local zpos = scr.GetProperty("droGageZ", "Value")
    local safez = scr.GetProperty("droGageSafeZ", "Value")
    
    prb.XYOffsetCal (xpos, ypos, diam, zpos , safez) 
end
function btnProbeCalRad_Clicked_Script(...)
    --Calibrate Radius
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    local xpos = scr.GetProperty("droGageX", "Value")
    local ypos = scr.GetProperty("droGageY", "Value")
    local zpos = scr.GetProperty("droGageZ", "Value")
    local diam = scr.GetProperty("droGageDiameter", "Value")
    local safez = scr.GetProperty("droGageSafeZ", "Value")
    
    prb.RadiusCal (xpos, ypos, diam, zpos, safez)
end
function btnXYRadHelp__Clicked_Script(...)
    prb.XYRadCalHelp()
end
-- tabSettings-GlobalScript
function tabSettings_On_Exit_Script(...)
    prb.SaveSettings()
end
function droPrbOffNum_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droPrbGcode_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droSlowFeed_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droFastFeed_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droBackOff_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droOverShoot_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function droPrbInPos_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function btnPrbSettingsHelp_Clicked_Script(...)
    prb.SettingsHelp()
end
-- Zavorine-GlobalScript
-- Flatten A-GlobalScript
function ProbeDepthDro_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function YDistDro_On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    return val
    
end
function FlatAButton_Clicked_Script(...)
    -- Make parallel A axis workpiece to XY plane and correct A coord system
    --PRIVATE
    
    inst = mc.mcGetInstance()
    local profile = mc.mcProfileGetName(inst)
    local path = mc.mcCntlGetMachDir(inst)
    
    package.path = path .. "\\Modules\\?.lua;" .. path .. "\\Profiles\\" .. profile .. "\\Modules\\?.lua;"
    
    --Master module
    package.loaded.MasterModule = nil
    mm = require "mcMasterModule"
    
    --Probing module
    package.loaded.Probing = nil
    local prb = require "mcProbing"
    
    
    local YDist = scr.GetProperty("YDistDro", "Value")
    local ZDist = scr.GetProperty("ProbeDepthDro", "Value")
    --local ZDist = 15
    --local YDist = 30
    local SetWork = scr.GetProperty("ledSetWork", "Value")
    
    
    ------------- Errors -------------
    if (YDist == nil or ZDist== nil) then
    	mc.mcCntlSetLastError(inst, "Probe: Probe distances not input")
    	do return end
    end
    
    ------------- Define Vars -------------
    prb.NilVars(100, 150)
    
    local SlowFeed = mc.mcProfileGetDouble(inst , "ProbingSettings", "SlowFeed", 0.000)
    local FastFeed = mc.mcProfileGetDouble(inst , "ProbingSettings", "FastFeed", 0.000)
    local BackOff = mc.mcProfileGetDouble(inst , "ProbingSettings", "BackOff", 0.000)
    local ProbeCode = mc.mcProfileGetDouble(inst , "ProbingSettings", "GCode", 0.000)
    
    ------------- Get current state -------------
    local CurFeed = mc.mcCntlGetPoundVar(inst, mc.SV_FEEDRATE)
    local CurFeedMode = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_1)
    local CurAbsMode = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_3)
    
    ------------- Check Probe -------------
    rc = prb.CheckProbe(1, ProbeCode); if not rc then; do return end; end
    
    ------------- Measure and Correct Thrice -------------
    for i=0,2,1 
    do
    	
        local rc = mc.mcCntlGcodeExecuteWait(inst, "G0 G91 G40 G80") -- set to incremental mode
        mm.ReturnCode(rc)
    
        ------------- Probe Surface -------------
    
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G%.1f Z%.4f F%.1f", ProbeCode, -ZDist, FastFeed)) -- probe down in Z
    	mm.ReturnCode(rc)
    	rc = prb.CheckProbe(0, ProbeCode); if not rc then; do return end; end
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G1 Z%.4f F%.1f", BackOff, FastFeed))
    	mm.ReturnCode(rc)
    	--Measure
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G%.1f Z%.4f F%.1f", ProbeCode, -BackOff*2, SlowFeed))
    	mm.ReturnCode(rc)
    	rc = prb.CheckProbe(0, ProbeCode); if not rc then; do return end; end
    	local z1 = mc.mcCntlGetPoundVar(inst, mc.SV_PROBE_POS_Z)
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G0 Z%.4f F%.1f", ZDist, FastFeed)) -- retract back up
    	mm.ReturnCode(rc)
    
    	------------- Probe Second Point -------------
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G0 Y%.4f F%.1f", YDist, FastFeed)) -- move to second point in Y
    	mm.ReturnCode(rc)
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G%.1f Z%.4f F%.1f", ProbeCode, -ZDist*2, FastFeed))
    	mm.ReturnCode(rc)
    	rc = prb.CheckProbe(0, ProbeCode); if not rc then; do return end; end
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G1 Z%.4f F%.1f", BackOff, FastFeed))
    	mm.ReturnCode(rc)
    	--Measure
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G%.1f Z%.4f F%.1f", ProbeCode, -BackOff*2, SlowFeed))
    	mm.ReturnCode(rc)
    	rc = prb.CheckProbe(0, ProbeCode); if not rc then; do return end; end
    	local z2 = mc.mcCntlGetPoundVar(inst, mc.SV_PROBE_POS_Z)
    
    	------------- Retract For Correction-----------------
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G0 G91 Y%.1f Z55 F%.1f", -YDist, FastFeed))
    	mm.ReturnCode(rc)
    
    	------------- Calculate Angle -------------
    	local angle = -math.atan((z1-z2)/YDist)*180/math.pi
    
    	------------- Set Angle And Move A-axis To Zero -------------
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G10 L2 P1 A0\n G92 A%.6f", angle))
    	mm.ReturnCode(rc)
    	rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G0 G90 A0"))
    	mm.ReturnCode(rc)
        mc.mcCntlSetLastError(inst, string.format("Corrected A-axis by %.3f degrees", math.abs(angle)))
    
        ------------- Return to Probing Start Point -------------
        if i<2 then 
        rc = mc.mcCntlGcodeExecuteWait(inst, string.format("G0 G91 Z-50 F%.1f", FastFeed))
        mm.ReturnCode(rc)
        end
    
    
    end
    ------------- Reset State ------------------------------------
    mc.mcCntlSetPoundVar(inst, mc.SV_FEEDRATE, CurFeed)
    mc.mcCntlSetPoundVar(inst, mc.SV_MOD_GROUP_1, CurFeedMode)
    mc.mcCntlSetPoundVar(inst, mc.SV_MOD_GROUP_3, CurAbsMode)
    
end
function btnMeasType_Clicked_Script(...)
    --Set probing measurment type
    
    local inst = mc.mcGetInstance()
    local MeasureOnlyLED = scr.GetProperty("ledMeasOnly", "Value")
    
    if (MeasureOnlyLED == "1") then
        scr.SetProperty("ledMeasOnly", "Value", "0")
        scr.SetProperty("ledSetWork", "Value", "1")
    else
        scr.SetProperty("ledMeasOnly", "Value", "1")
        scr.SetProperty("ledSetWork", "Value", "0")
    end
end
-- grpProbeResults-GlobalScript
function btnResultsHelp_Clicked_Script(...)
    prb.ResultsHelp()
end
function dro_161__On_Modify_Script(...)
    local val = select(1,...) -- Get the user supplied value.
    mc.mcProfileWriteDouble(inst, "ProbingSettings", "Radius", var)
end
-- ControlGroup(3)-GlobalScript
function btnStop_2__Left_Up_Script(...)
    ns.ButtonCall(ns.CycleStop,nil, ...)
end
function btnReset_2__Left_Up_Script(...)
    local inst = mc.mcGetInstance()
    mc.mcCntlReset(inst)
    mc.mcSpindleSetDirection(inst, 0)
    mc.mcCntlSetLastError(inst, '')
end
function btnCycleStart_2__Left_Up_Script(...)
    ns.ButtonCall(ns.CycleStart,nil, ...)
end
-- MachineCoordGroup(2)-GlobalScript
function btnRefX_4__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.X_AXIS, ...)
end
function btnRefY_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Y_AXIS, ...)
end
function btnRefZ_4__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.Z_AXIS, ...)
end
function btnRefA_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.A_AXIS, ...)
end
function btnRefAllDiag_3__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAll,nil, ...)
end
function btnRefB_2__Clicked_Script(...)
    ns.ButtonCall(ns.HomeAxis,mc.B_AXIS, ...)
end
-- WorkingCoordGroup(2)-GlobalScript
-- JoggingGroup(2)-GlobalScript
function labJogMode_1__Left_Up_Script(...)
    ButtonJogModeToggle()
end
function droJogRate_3__On_Modify_Script(...)
    local inst = mc.mcGetInstance()
    local val = scr.GetProperty("droJogRate", "Value")
    mc.mcProfileWriteString(inst, "PersistentDROs", "droJogRate", string.format (val)) --Create a register and write the machine coordinates to it
end
function ProbeProtection_Down_Script(...)
    ---local inst = mc.mcGetInstance()
    --src.SetProperty("ProbeProtection","Value", 1);
end
function ProbeProtection_Up_Script(...)
    --local inst = mc.mcGetInstance()
    --src.SetProperty("ProbeProtection","Value", 0);
end
-- FeedrateGroup(2)-GlobalScript
function btnFROUp_3__Left_Up_Script(...)
    local val = scr.GetProperty('slideFRO(1)', 'Value');
    val = tonumber(val) + 10;
    local maxval = scr.GetProperty('slideFRO(1)', 'Max Value')
    if (tonumber(val) >= tonumber(maxval)) then
     val = maxval;
    end
    scr.SetProperty('slideFRO(1)', 'Value', tostring(val));
end
function btnFRODn_3__Left_Up_Script(...)
    -- Down
    local val = scr.GetProperty('slideFRO(1)', 'Value');
    val = tonumber(val) - 10;
    local minval = scr.GetProperty('slideFRO(1)', 'Min Value')
    if (tonumber(val) <= tonumber(minval)) then
     val = minval;
    end
    scr.SetProperty('slideFRO(1)', 'Value', tostring(val));
end
function btn_129__Clicked_Script(...)
    ns.ButtonCall(ns.Theamed,nil, ...)
end
