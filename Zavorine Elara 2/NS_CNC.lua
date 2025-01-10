local NS_CNC = {}
LUA_CHUNK = "Screen"
PLC_SCRIPT_FIRST_RUN = false
PLC_SCRIPT_TIME = os.clock() * 1000
COOLANT_DURATION_START = PLC_SCRIPT_TIME
COOLANT_PULSE_START = PLC_SCRIPT_TIME
COOLANT_CONTINUOUS = false
COOLANT_DURATION_ACTIVE = false
COOLANT_PULSE_ACTIVE = false
NS_CNC.Settings = {}


-- Machine Models
--	Elara
--		4 Axis X,Y,Z,A
--		No ATC

--	Elara ATC
--		3 Axis X,Y,Z,A

--	Mira_6S_AR
--		5 Axis X,Y,Z,A,B
--		No ATC

--	Mira_6S_AZ
--		5 Axis X,Y,Z,A,B
--		No ATC
--		ABS Encoders on Axis A and B

--	Mira_7S_AR
--		6 Axis X,Y,Z,A,B,C
--		ATC

--	Mira_7S_AZ
--		6 Axis X,Y,Z,A,B,C
--		ATC
--		ABS Encoders on Axis A and B

--	Mira_J9
--		6 Axis X,Y,Z,A,B,C
--		ATC with swivel cover

function NS_CNC.GetMachineModel()
	local val = mm.GetRegister("MachineModel")
	if val == "" or val == "0.000" then
		wx.wxMessageBox("Set the machine model number in the 'Diagnostics Page'")
		val = "Mira_6S_AR"
	end
	return val
end

function NS_CNC.GetMachineDescription()
	local description = ""

	local model = ns.GetMachineModel()
	if model == "Elara" then
		description = "Elara Motion Control"
	elseif model == "Elara ATC" then
		description = "Elara ATC Motion Control"
	elseif model == "Mira_6S_AR" or model == "Mira_6S_AZ" then
		description = "Mira 6S Motion Control"
	elseif model == "Mira_7S_AR" or  model == "Mira_7S_AZ" then
		description = "Mira 7S Motion Control"
	elseif model == "Mira_J9" then
		description = "Mira J9 Motion Control"
	end
		
	return description
end

function NS_CNC.ReLoadScripts()
	ns.SaveRegisters()
	LoadModules()
end

function NS_CNC.MachineModelInitialize()
	ns.CreatRegister("MachineModel", "Machine Model")
	ns.CreatRegister("MachineDescription", "Machine Description")
	
	
	-- Update the model drop down
	local val = scr.GetProperty("ModelDropDown(1)", "Selected")
	scr.SetProperty("ModelDropDown(1)", "Strings", "Elara|Elara ATC|Mira_6S_AR|Mira_6S_AZ|Mira_7S_AR|Mira_7S_AZ|Mira_J9")
	scr.SetProperty("ModelDropDown(1)", "Selected", val)
end

function NS_CNC.InitializeBoolSettings()
	table.insert(ns.Settings, {["buttonName"] = "EnableToolHeightInTCBtn(1)", ["regName"] = "ToolChanger/MeasureToolLengthDuringToolChange", ["description"] = "MeasureToolLengthDuringToolChange", ["createReg"] = false})
	table.insert(ns.Settings, {["buttonName"] = "EnableToolBreakCheckInTCBtn(1)", ["regName"] = "ToolChanger/ToolBreakageCheck", ["description"] = "MeasureToolLengthDuringToolChange", ["createReg"] = false})
	
	for i = 1, #ns.Settings do
		if ns.Settings[i]["createReg"] then
			ns.CreatRegister(ns.Settings[i]["regName"], ns.Settings[i]["description"])
		end
	end
end

function NS_CNC.UpdateBoolSettings()
	for i = 1, #ns.Settings do
		local val = mm.GetRegister(ns.Settings[i]["regName"], 1)
		if val == 1 then
			scr.SetProperty(ns.Settings[i]["buttonName"], "Bg Color", BTN_COLOR_GREEN)
		else
			scr.SetProperty(ns.Settings[i]["buttonName"], "Bg Color", BTN_COLOR_OFF)
		end
	end
end

function NS_CNC.SetBoolSettings(regname)
	mm.SetRegister(regname, 1, 1)
	ns.UpdateBoolSettings()
end

function NS_CNC.ReSetBoolSettings(regname)
	mm.SetRegister(regname, 0, 1)
	ns.UpdateBoolSettings()
end

function NS_CNC.ToggleBoolSettings(regname)
	if ns.GetBoolSettings(regname) then
		ns.ReSetBoolSettings(regname)
	else
		ns.SetBoolSettings(regname)
	end
end

function NS_CNC.GetBoolSettings(regname)
	local val = mm.GetRegister(regname, 1)
	if val == 1 then 
		return true 
	else
		return false 
	end
end

-- Outputs for drive based homing
function NS_CNC.GetDriveBasedHomingOutput(AxisID)
	local DriveBasedHomingOutputs = {
		mc.OSIG_OUTPUT40,
		mc.OSIG_OUTPUT41,
		mc.OSIG_OUTPUT42,
		mc.OSIG_OUTPUT43,
		mc.OSIG_OUTPUT44,
		mc.OSIG_OUTPUT45,
	}
	return DriveBasedHomingOutputs[AxisID + 1]
end

-- Inputs for drive based homing
function NS_CNC.GetDriveBasedHomingInput(AxisID)
	local DriveBasedHomingInputs = {
		mc.ISIG_INPUT40,
		mc.ISIG_INPUT41,
		mc.ISIG_INPUT42,
		mc.ISIG_INPUT43, --11-14
		mc.ISIG_INPUT44, --11-15
		mc.ISIG_INPUT45,
	}
	return DriveBasedHomingInputs[AxisID + 1]
end


-- Configure which axes use drive based homing
function NS_CNC.UseDriveBasedHoming(AxisID)
	local DriveBasedHomingEnabled
	
	local model = ns.GetMachineModel()
	if model == "Elara" or model == "Elara ATC" or model == "Mira_6S_AR" or model == "Mira_7S_AR" or model == "Mira_J9" then
		DriveBasedHomingEnabled = {
			false,
			false,
			false,
			false,
			false,
			false,
		}
	elseif model == "Mira_6S_AZ" or model == "Mira_7S_AZ" then
		DriveBasedHomingEnabled = {
			false,
			false,
			false,
			true,
			true,
			false,
		}
	end
	return DriveBasedHomingEnabled[AxisID + 1]
end

-- Outputs for drive based homing
function NS_CNC.GetDriveBasedHomingCalibrationOutputs(AxisID)
	local DriveBasedHomingCalibrationOutputs = {
		mc.OSIG_OUTPUT50,
		mc.OSIG_OUTPUT51,
		mc.OSIG_OUTPUT52,
		mc.OSIG_OUTPUT53,
		mc.OSIG_OUTPUT54,
		mc.OSIG_OUTPUT55,
	}
	return DriveBasedHomingCalibrationOutputs[AxisID + 1]
end

function NS_CNC.UpdateGCodeLinePercent()
	if mc.mcCntlGetGcodeFileName(inst) ~= "" then
		local GcodeLineMax = mc.mcCntlGetGcodeLineCount(inst)
		local GcodeLineCur = mc.mcCntlGetGcodeLineNbr(inst)
		local GcodeLinePercentage = w.Round(((GcodeLineCur/(GcodeLineMax-1)) * 100), 0, -1)
		scr.SetProperty("TotalTimeGauge(1)", "Value", tostring(GcodeLinePercentage))
		scr.SetProperty("TotalLineDRO(1)", "Value", tostring(GcodeLineMax))
	else
		scr.SetProperty("TotalTimeGauge(1)", "Value", tostring(0))
		scr.SetProperty("TotalLineDRO(1)", "Value", tostring(0))
	end
end

function NS_CNC.CoolantDurationInc(value)
	local new_value
	local coolant_duration = mm.GetRegister("CoolantDuration", 1)
	if (coolant_duration <= 1 and value == -1) or coolant_duration < 1 and value == 1 then
		new_value = coolant_duration + (value / 10)
	else
		new_value = coolant_duration + value
	end
	
	if new_value > 5 then
		new_value = 5
	end
	
	if new_value < 0.1 then
		new_value = 0.1
	end
	
	mm.SetRegister("CoolantDuration", new_value, 1)
end

function NS_CNC.CoolantPulseInc(value)
	local coolant_pulse = mm.GetRegister("CoolantPulse", 1)
	local new_value = coolant_pulse + value
	if new_value > 0.1 then
		new_value = 0.1
	end
	
	if new_value < 0.01 then
		new_value = 0.01
	end
	
	mm.SetRegister("CoolantPulse", new_value, 1)
end

function NS_CNC.IsCoolantFloodOn()
	return w.GetSignalState(mc.OSIG_COOLANTON)
end

function NS_CNC.CoolantFloodToggle()
	if ns.IsCoolantFloodOn() then
		ns.SetCoolantFloodOff()
	else
		ns.SetCoolantFloodOn()
	end
	ns.CoolantButtonsUpdate()
end

function NS_CNC.SetCoolantFloodOn()
	w.SetSignalState(mc.OSIG_COOLANTON, true)
	w.SetSignalState(mc.OSIG_OUTPUT0, true)
end

function NS_CNC.SetCoolantFloodOff()
	w.SetSignalState(mc.OSIG_COOLANTON, false)
	w.SetSignalState(mc.OSIG_OUTPUT0, false)
end

function NS_CNC.IsCoolantContinuousOn()
	return COOLANT_CONTINUOUS
end

function NS_CNC.CoolantContinuousToggle()
	if ns.IsCoolantContinuousOn() then
		ns.SetCoolantContinuousOff()
	else
		ns.SetCoolantContinuousOn()
	end
	ns.CoolantButtonsUpdate()
end

function NS_CNC.SetCoolantContinuousOn()
	COOLANT_CONTINUOUS = true
	w.SetSignalState(mc.OSIG_OUTPUT0, true)
end

function NS_CNC.SetCoolantContinuousOff()
	COOLANT_CONTINUOUS = false
	w.SetSignalState(mc.OSIG_OUTPUT0, false)
end

function NS_CNC.CoolantButtonsUpdate()
	local btn_color = BTN_COLOR_OFF
	if ns.IsCoolantFloodOn() then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("FloodCoolantBtn(1)", "Bg Color", btn_color)
	
	local btn_color = BTN_COLOR_OFF
	if ns.IsCoolantContinuousOn() then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("ContinuousCoolantBtn(1)", "Bg Color", btn_color)
end

function NS_CNC.CoolantInitialize()
	ns.CreatRegister("CoolantDuration", "Coolant Duration")
	ns.CreatRegister("CoolantPulse", "Coolant Pulse")
end

function NS_CNC.ToolChangerGetListOfSettings()
	local toolchanger_list = {
		["ToolChanger/ToolTrayOpenCloseFeedrate"] = {["description"] = "Tool Tray Open and Close Feedrate", ["value"] = nil },
		["ToolChanger/ZToolClampPosition"] = {["description"] = "Z Tool Clamp Position", ["value"] = nil },
		["ToolChanger/ZToolClearancePosition"] = {["description"] = "Z Tool Clearance Position", ["value"] = nil },
		["ToolChanger/ZToolSlowZonePosition"] = {["description"] = "Z Tool Slow Zone Position", ["value"] = nil },
		["ToolChanger/ZSafePosition"] = {["description"] = "Z Safe Position", ["value"] = nil },
		["ToolChanger/SlowZoneFeedrate"] = {["description"] = "Slow Zone Feedrate", ["value"] = nil },
		["ToolChanger/ToolBreakageCheck"] = {["description"] = "Tool Breakage Check 1 = On, 0 = Off", ["value"] = nil },
		["ToolChanger/ToolBreakageTolerance"] = {["description"] = "Tool Breakage Tolerance", ["value"] = nil },
		["ToolChanger/MeasureToolLengthDuringToolChange"] = {["description"] = "Measure Tool Length During Tool Change 1 = On, 0 = Off", ["value"] = nil },
	}
	return toolchanger_list
end
	
function NS_CNC.ToolChangerInitialize()
	local toolchanger_list = ns.ToolChangerGetListOfSettings()
	
	for regname, values in pairs(toolchanger_list) do
		ns.CreatRegister(regname, values.description)
	end
	
	local a,b,c = w.AddToolTableUserFieldList({["LastMeasuredLength"] = {["Description"] = "Last Measured Length", ["FieldType"] = "Float(-1, 4)"}})
	if b ~= true then wx.wxMessageBox(tostring(c)) end
end

function NS_CNC.ToolChangerGetSettings()
	local toolchanger_list = ns.ToolChangerGetListOfSettings()
	
	local settings = {}
	for k, v in pairs(toolchanger_list) do
		local shortname = string.gsub(k, "ToolChanger/", "")
		settings[shortname] = ns.GetRegisterValue(k)
	end
	return settings
end


function NS_CNC.ToolSetterGetListOfSettings()
	local toolsetter_list = {
		["ToolSetter/XPosition"] = {["description"] = "X Setter Position", ["value"] = nil },
		["ToolSetter/YPosition"] = {["description"] = "Y Setter Position", ["value"] = nil },
		["ToolSetter/ZProbeStartPosition"] = {["description"] = "Z Probe Start Position", ["value"] = nil },
		["ToolSetter/ZProbeEndPosition"] = {["description"] = "Z Probe End Position", ["value"] = nil },
		["ToolSetter/ZSlowZonePosition"] = {["description"] = "Z Slow Zone Position", ["value"] = nil },
		["ToolSetter/SlowZoneFeedrate"] = {["description"] = "Slow Zone Feedrate", ["value"] = nil },
		["ToolSetter/ZFirstTouchFeedrate"] = {["description"] = "Z First Touch Feedrate", ["value"] = nil },
		["ToolSetter/ZSecondTouchFeedrate"] = {["description"] = "Z Second Touch Feedrate", ["value"] = nil },
		["ToolSetter/ZFirstTouchBackoffDistance"] = {["description"] = "Z First Touch Backoff Distance", ["value"] = nil },
	}
	return toolsetter_list
end

function NS_CNC.ToolSetterInitialize()
	local toolsetter_list = ns.ToolSetterGetListOfSettings()
	
	for regname, values in pairs(toolsetter_list) do
		ns.CreatRegister(regname, values.description)
	end
end

function NS_CNC.ToolSetterGetSettings()
	local toolsetter_list = ns.ToolSetterGetListOfSettings()
	
	local settings = {}
	for k, v in pairs(toolsetter_list) do
		local shortname = string.gsub(k, "ToolSetter/", "")
		settings[shortname] = ns.GetRegisterValue(k)
	end
	return settings
end


function NS_CNC.IsToolSetterProbeActive()
	if w.GetSignalState(mc.ISIG_PROBE1) then
		return true
	else
		return false
	end
end

function NS_CNC.CoolantDurationDROChanged(value)
	if value > 5 then
		value = 5
	end
	
	if value < 1 then
		value = 1
	end
	
	mm.SetRegister("CoolantDuration", value, 1)
	return value
end

function NS_CNC.CoolantPulseDROChanged(value)
	if value > 0.1 then
		value = 0.1
	end
	
	if value < 0.01 then
		value = 0.01
	end
	
	mm.SetRegister("CoolantPulse", value, 1)
	return value
end

function NS_CNC.CoolantDurationTimer()
	if ns.IsCoolantFloodOn() then
		-- Set Coolant Pules Output to true
		w.SetSignalState(mc.OSIG_OUTPUT0, true)
	else
		w.SetSignalState(mc.OSIG_OUTPUT0, false)
	end
end

function NS_CNC.CoolantPulseTimer()
	if ns.IsCoolantContinuousOn() == false then
		-- Set Coolant Pules Output to true
		local coolant_pulse = w.GetSignalState(mc.OSIG_OUTPUT0)
		if coolant_pulse then
			w.SetSignalState(mc.OSIG_OUTPUT0, false)
		end
	end
end

function NS_CNC.CoolantTimersUpdate()
	local coolant_duration = mm.GetRegister("CoolantDuration", 1)
	coolant_duration = coolant_duration * 1000
	local coolant_pulse = mm.GetRegister("CoolantPulse", 1)
	coolant_pulse = coolant_pulse * 1000
	
	local current_time = os.clock() * 1000
	
	if current_time > COOLANT_DURATION_START + coolant_duration and COOLANT_DURATION_ACTIVE == false then
		ns.CoolantDurationTimer()
		COOLANT_DURATION_ACTIVE = true
	elseif current_time > COOLANT_DURATION_START + coolant_duration + coolant_pulse and COOLANT_DURATION_ACTIVE then
		ns.CoolantPulseTimer()
		COOLANT_DURATION_START = current_time
		COOLANT_DURATION_ACTIVE = false
	end
end

-- function NS_CNC.HomeAll()
	-- if ns.UseDriveBasedHoming() then
		-- ns.DriveBasedHomeAll()
	-- else
		-- ns.api("mcAxisHomeAll", inst)
	-- end
-- end

-- mc.X_AXIS
function NS_CNC.HomeAxis(AxisID)
	if ns.UseDriveBasedHoming(AxisID) then
		ns.DriveBasedHomeAxis(AxisID)
	else
		ns.StartMachBasedHoming(AxisID)
	end
end

function NS_CNC.StartDriveBasedHoming(AxisID)
	mc.mcAxisSetHomeInPlace(inst, AxisID, 1)
	w.SetSignalState(ns.GetDriveBasedHomingOutput(AxisID), true)
	w.Log(string.format("Start -> Drive Based Homing: %s", AXIS_LETTER_ARRAY_0[AxisID]))
end

function NS_CNC.StartMachBasedHoming(AxisID)
	mc.mcAxisSetHomeInPlace(inst, AxisID, 0)
	ns.api("mcAxisHome", inst, AxisID)
	w.Log(string.format("Start -> Mach Based Homing: %s", AXIS_LETTER_ARRAY_0[AxisID]))
end

function NS_CNC.HomeAll()
	-- Turn off Homing Outputs
	for i = mc.X_AXIS, mc.MC_MAX_COORD_AXES -1 do
		if ns.UseDriveBasedHoming(i) then
			w.SetSignalState(ns.GetDriveBasedHomingOutput(i), false)
		end
	end
	
	-- Check to see if all axes are setup for mach homing
	local machbasedhoming = true
	for i = mc.X_AXIS, mc.MC_MAX_COORD_AXES -1 do
		if ns.UseDriveBasedHoming(i) then
			machbasedhoming = false
		end
	end
	if machbasedhoming then
		ns.api("mcAxisHomeAll", inst)
		return
	end

	local start_time = os.clock() * 1000
	local loop_time = os.clock() * 1000
	local homeOrderIndex = 1
	local machHomingActive = {[mc.X_AXIS] = false,[mc.Y_AXIS] = false,[mc.Z_AXIS] = false,[mc.A_AXIS] = false,[mc.B_AXIS] = false,[mc.C_AXIS] = false}
	local driveHomingActive = {[mc.X_AXIS] = false,[mc.Y_AXIS] = false,[mc.Z_AXIS] = false,[mc.A_AXIS] = false,[mc.B_AXIS] = false,[mc.C_AXIS] = false}
		
	function IsMachHoming()
		local machState = mc.mcCntlGetState(inst)
		if machState == mc.MC_STATE_IDLE then
			for i = mc.X_AXIS, #machHomingActive do
				if machHomingActive[i] then
					machHomingActive[i] = false
					w.Log(string.format("Finished -> Mach Based Homing: %s", AXIS_LETTER_ARRAY_0[i]))
				end
			end
			--w.Log("Is Mach Based Homing == false")
			return false
		else
			--w.Log("Is Mach Based Homing == true")
			return true
		end
	end
	
	function IsDriveHoming()
		for i = mc.X_AXIS, #driveHomingActive do
			if driveHomingActive[i] then
				local homing = w.GetSignalState(ns.GetDriveBasedHomingInput(i))
				if homing then
					driveHomingActive[i] = false
					w.SetSignalState(ns.GetDriveBasedHomingOutput(i), false)
					ns.api("mcAxisHome", inst, i)
					w.Log(string.format("Finished -> Drive Based Homing: %s", AXIS_LETTER_ARRAY_0[i]))
				end
			end
		end
		
		-- Check if all homing is done
		for i = mc.X_AXIS, #driveHomingActive do
			if driveHomingActive[i] == true then
				--w.Log(string.format("Drive Based Homing: %0.0f == true", i))
				return true
			end
		end
		--w.Log("Drive Based Homing == false")
		return false
	end
	
	HomingPleaseWaitTable =	{	
								["Type"]				= w.PleaseWaitType.Function,
								["Message"] 			= "Home All...",
								["IgnoreStopStatus"]	= false,
								["Value"] 				= true,
								["Function"]			= 	function()
																local _now = os.clock() * 1000
																
																if IsMachHoming() == false and IsDriveHoming() == false then
																	for i = mc.X_AXIS, mc.MC_MAX_COORD_AXES -1 do
																		local enabled = ns.api("mcAxisIsEnabled", inst, i)
																		if enabled == 1 then
																			local homeOrder = ns.api("mcAxisGetHomeOrder", inst, i)
																			if homeOrder == homeOrderIndex then
																				if ns.UseDriveBasedHoming(i) then
																					driveHomingActive[i] = true
																					ns.StartDriveBasedHoming(i)
																				else
																					machHomingActive[i] = true
																					ns.StartMachBasedHoming(i)
																				end
																			end
																		end
																	end
																	homeOrderIndex = homeOrderIndex + 1
																end
																
																if IsMachHoming() == false and IsDriveHoming() == false and homeOrderIndex > 6 then
																	return true
																end
																
																local total_elapsed = _now - start_time
																if total_elapsed >= 20000 then
																	return true
																end
																
																return false
															end
							}

	local a,b,c = w.PleaseWaitDialog(HomingPleaseWaitTable)
	if b ~= true then
		ns.CancelDriveBasedHoming()
	end
end

function NS_CNC.DriveBasedHomeAxis(AxisID)
	local homing_canceled = false
	
	if AxisID == nil then
		ns.api("mcAxisDerefAll", inst)
	else
		ns.api("mcAxisDeref", inst, AxisID)
	end
	
	if w.GetSignalState(ns.GetDriveBasedHomingOutput(AxisID)) then
		w.SetSignalState(ns.GetDriveBasedHomingOutput(AxisID), false)
		w.Sleep(100)
	end
	
	ns.StartDriveBasedHoming(AxisID)
	
	--wx.wxMessageBox(tostring(w.GetSignalState(ns.GetDriveBasedHomingInput(AxisID))))
	local a,b,c = w.WaitForSignal(ns.GetDriveBasedHomingInput(AxisID), true, 20000, "Drive Based Homing " .. AXIS_LETTER_ARRAY_0[AxisID])
	if b ~= true then
		homing_canceled = true
		ns.CancelDriveBasedHoming(AxisID)
	end
	
	local a,b,c = w.SetSignalState(ns.GetDriveBasedHomingOutput(AxisID), false)
	if b ~= true then
		wx.wxMessageBox(w.FunctionError(c))
	end
	
	if homing_canceled == false then
		ns.api("mcAxisHome", inst, AxisID)
	end
end

function NS_CNC.CancelDriveBasedHoming(AxisID)
	w.SetSignalState(mc.OSIG_OUTPUT49, true)
	w.Sleep(250)
	w.SetSignalState(mc.OSIG_OUTPUT49, false)
end

function NS_CNC.CalibrateDriveBasedHomingPosiiton(AxisID)
	local output = ns.GetDriveBasedHomingCalibrationOutputs(AxisID)
	w.SetSignalState(output, true)
	w.PleaseWaitDialog(6, "Calibrating Home Position...", false, 500)
	w.SetSignalState(output, false)
	w.FunctionCompleted()
end

function NS_CNC.GoToSetZero(AxisID)
	scr.SetProperty(string.format("GoToPosition%sDRO(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value", "0.0")
end

function NS_CNC.ZeroAll()
	for AxisID = mc.X_AXIS, mc.B_AXIS do
		ns.api("mcAxisSetPos", inst, AxisID, 0)
	end
end

function NS_CNC.RestoreG54FixtureOffsetFromG59()
	ns.MDICommand("G10 L2 P1 X#5321 Y#5322 Z#5323 A#5324 B#5325 C#5326")
	w.FunctionCompleted()
end

function NS_CNC.SetReferencePointPosition(AxisID)
	local position = ns.api("mcAxisGetMachinePos", inst, AxisID)
	scr.SetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value", tostring(position))
end

function NS_CNC.SetReferencePointPositionAll()
	for AxisID = mc.X_AXIS, mc.B_AXIS do
		local position = ns.api("mcAxisGetMachinePos", inst, AxisID)
		scr.SetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value", tostring(position))
	end
end

function NS_CNC.GoToReferencePointPositionAll()
	local gcode_string = ""
	
	local model = ns.GetMachineModel()
	if model == "Mira_6S_AZ" or model == "Mira_7S_AZ" then
		local AxisID = mc.B_AXIS
		local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
		gcode_string = string.format("%s G90 G53 G00 %s %0.6f", gcode_string, AXIS_LETTER_ARRAY_0[AxisID], tonumber(position))
	end
	
	local AxisID = mc.A_AXIS
	local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	gcode_string = string.format("%s %s %0.6f\n", gcode_string, AXIS_LETTER_ARRAY_0[AxisID], tonumber(position))
	
	local AxisID = mc.X_AXIS
	local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	gcode_string = string.format("%s G90 G53 G00 %s %0.6f", gcode_string, AXIS_LETTER_ARRAY_0[AxisID], tonumber(position))
	
	local AxisID = mc.Y_AXIS
	local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	gcode_string = string.format("%s %s %0.6f\n", gcode_string, AXIS_LETTER_ARRAY_0[AxisID], tonumber(position))
	
	local AxisID = mc.Z_AXIS
	local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	gcode_string = string.format("%s G90 G53 G00 %s %0.6f\n", gcode_string, AXIS_LETTER_ARRAY_0[AxisID], tonumber(position))
	
	ns.MDICommand(gcode_string)
end

function NS_CNC.GoToReferencePointPosition(AxisID)
	local position = scr.GetProperty(string.format("ReferencePoint%sDro(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	ns.MDICommand(string.format("G90 G53 G00 %s %0.6f", AXIS_LETTER_ARRAY_0[AxisID], tonumber(position)))
end

function NS_CNC.MoveAToPosition(position)
	ns.MDICommand(string.format("G90 G00 A %0.6f", position))
end

function NS_CNC.MoveBToPosition(position)
	ns.MDICommand(string.format("G91 G00 B %0.6f\nG90", position))
end

function NS_CNC.GoToMoveToPosition(AxisID)
	local position = scr.GetProperty(string.format("GoToPosition%sDRO(1)", AXIS_LETTER_ARRAY_0[AxisID]), "Value")
	if ns.IsGoToAbsolute() then
		ns.MDICommand(string.format("G90 G00 %s %0.6f", AXIS_LETTER_ARRAY_0[AxisID], tonumber(position)))
	else
		ns.MDICommand(string.format("G91 G00 %s %0.6f", AXIS_LETTER_ARRAY_0[AxisID], tonumber(position)))
	end
end

function NS_CNC.IsGoToAbsolute()
	local absolute_btn = ns.api("mcProfileGetInt", inst, "NS_CNC", "GoToAbsolute", 1)
	if absolute_btn == 1 then
		return true
	else
		return false
	end
end

---------------------------------------------------------------
-- Cycle Start() function.
---------------------------------------------------------------
function NS_CNC.CycleStart()	
	local rc
    local tab, rc = scr.GetProperty("Program", "Current Tab")
    local tabG_Mdione, rc = scr.GetProperty("GCodeTabs(1)", "Current Tab")
	local tabG_Mditwo, rc = scr.GetProperty("nbGCodeMDI2", "Current Tab")
	local state = mc.mcCntlGetState(inst)
	--mc.mcCntlSetLastError(inst,"tab == " .. tostring(tab))
	
	if (state == mc.MC_STATE_MRUN_MACROH) then 
		mc.mcCntlCycleStart(inst)
	elseif ((tonumber(tab) == 0 and tonumber(tabG_Mdione) == 1)) then  
		scr.ExecMdi('MDIPanel(1)')
	elseif ((tonumber(tab) == 5 and tonumber(tabG_Mditwo) == 1)) then  
		scr.ExecMdi('mdi2')
	else
		mc.mcCntlCycleStart(inst)    
	end
end

---------------------------------------------------------------
-- Cycle Stop function.
---------------------------------------------------------------
function NS_CNC.CycleStop()
    mc.mcCntlCycleStop(inst);
    mc.mcSpindleSetDirection(inst, 0);
    mc.mcCntlSetLastError(inst, "Cycle Stopped");
	ns.SetCoolantFloodOff()
	if(wait ~=  nil) then
		wait =  nil;
	end
end

function NS_CNC.UpdateButtons()
	local btn_color = BTN_COLOR_OFF
	if w.GetSignalState(mc.OSIG_OUTPUT32) then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("UnClampBtn(1)", "Bg Color", btn_color)
	
	-- local btn_color = BTN_COLOR_OFF
	-- if w.GetSignalState(mc.ISIG_PROBE2) then
		-- btn_color = BTN_COLOR_ON
	-- end
	-- scr.SetProperty("ToolMagCloseBtn(1)", "Bg Color", btn_color)
	
	-- local btn_color = BTN_COLOR_OFF
	-- if w.GetSignalState(mc.ISIG_PROBE) then
		-- btn_color = BTN_COLOR_ON
	-- end
	-- scr.SetProperty("ToolMagOpenBtn(1)", "Bg Color", btn_color)
	
	local btn_color = BTN_COLOR_OFF
	if NS_CNC.IsToolMagazineOpen() then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("ToolMagToggleBtn(1)", "Bg Color", btn_color)

	
	local btn_color = BTN_COLOR_OFF
	if w.GetSignalState(mc.OSIG_SPINDLEON) then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("SpindleFWDBtn(1)", "Bg Color", btn_color)
	
	
	local btn_color = BTN_COLOR_OFF
	if NS_CNC.IsToolSetterProbeActive() then
		btn_color = BTN_COLOR_ON
	end
	scr.SetProperty("SetToolHeightBtn(1)", "Bg Color", btn_color)
	scr.SetProperty("SetToolHeightBtn(2)", "Bg Color", btn_color)
end

function NS_CNC.UpdateGoToAbsoluteIncrementalButtons()
	if ns.IsGoToAbsolute() then
		scr.SetProperty("GoToAbsoluteBtn(1)", "Bg Color", BTN_COLOR_YELLOW)
		scr.SetProperty("GoToIncrementalBtn(1)", "Bg Color", BTN_COLOR_YELLOW_OFF)
	else
		scr.SetProperty("GoToAbsoluteBtn(1)", "Bg Color", BTN_COLOR_YELLOW_OFF)
		scr.SetProperty("GoToIncrementalBtn(1)", "Bg Color", BTN_COLOR_YELLOW)
	end
end

function NS_CNC.GoToSetAbsolute()
	ns.api("mcProfileWriteInt", inst, "NS_CNC", "GoToAbsolute", 1)
	ns.UpdateGoToAbsoluteIncrementalButtons()
end

function NS_CNC.GoToSetIncremental()
	ns.api("mcProfileWriteInt", inst, "NS_CNC", "GoToAbsolute", 0)
	ns.UpdateGoToAbsoluteIncrementalButtons()
end

function NS_CNC.MachineModelChanged()
	ns.ScreenLoadScript()
end


function NS_CNC.InitializeScreenControls()
	local screen_controls_hidden = {}
	local screen_controls_shown = {}
	
	local description = ns.GetMachineDescription()
	scr.SetProperty("MachineDescriptionLabel(1)", "Label", description)
	scr.SetProperty("MachineDescriptionLabel(2)", "Label", description)
	
	
	-- Here we can hide or show screen objects based on model
	local model = ns.GetMachineModel()
	
	if model == "Elara" or model == "Elara ATC" then
		table.insert(screen_controls_hidden, "BPosText(1)")
		table.insert(screen_controls_hidden, "droCurrentPosition B(1)")
		table.insert(screen_controls_hidden, "GoToZeroBBtn(1)")
		table.insert(screen_controls_hidden, "GoToPositionBDRO(1)")
		table.insert(screen_controls_hidden, "GoToMoveBBtn(1)")
		table.insert(screen_controls_hidden, "JogBNegBtn(1)")
		table.insert(screen_controls_hidden, "JogBPlusBtn(1)")
		table.insert(screen_controls_hidden, "MoveB90Btn(1)")
		table.insert(screen_controls_hidden, "MoveB180Btn(1)")
		table.insert(screen_controls_hidden, "MoveBNeg90Btn(1)")
		table.insert(screen_controls_hidden, "MoveBNeg180Btn(1)")
		table.insert(screen_controls_hidden, "MoveBText(1)")
	else
		table.insert(screen_controls_shown, "BPosText(1)")
		table.insert(screen_controls_shown, "droCurrentPosition B(1)")
		table.insert(screen_controls_shown, "GoToZeroBBtn(1)")
		table.insert(screen_controls_shown, "GoToPositionBDRO(1)")
		table.insert(screen_controls_shown, "GoToMoveBBtn(1)")
		table.insert(screen_controls_shown, "JogBNegBtn(1)")
		table.insert(screen_controls_shown, "JogBPlusBtn(1)")
		table.insert(screen_controls_shown, "MoveB90Btn(1)")
		table.insert(screen_controls_shown, "MoveB180Btn(1)")
		table.insert(screen_controls_shown, "MoveBNeg90Btn(1)")
		table.insert(screen_controls_shown, "MoveBNeg180Btn(1)")
		table.insert(screen_controls_shown, "MoveBText(1)")
	end
	if model == "Elara" or model == "Elara ATC" or model == "Mira_6S_AR" or model == "Mira_7S_AR" then
		table.insert(screen_controls_hidden, "btnRefB(1)")
		table.insert(screen_controls_hidden, "ledRefB(1)")
		table.insert(screen_controls_hidden, "BMachineCoordDRO(1)")
	end
	if model == "Mira_6S_AZ" or model == "Mira_7S_AZ" or model == "Mira_7S_AR" then
		table.insert(screen_controls_shown, "btnRefB(1)")
		table.insert(screen_controls_shown, "ledRefB(1)")
		table.insert(screen_controls_shown, "BMachineCoordDRO(1)")
	end
	
	if model == "Mira_J9" then
		table.insert(screen_controls_shown, "btnRefB(1)")
		table.insert(screen_controls_shown, "ledRefB(1)")
		table.insert(screen_controls_shown, "BMachineCoordDRO(1)")
	end
	
	-- Hide or show ATC Groups
	if model == "Elara ATC" or  model == "Mira_7S_AR" or model == "Mira_7S_AZ" or model == "Mira_J9" then
		scr.SetProperty("ToolGroup(1)", "Left", "10306")
		scr.SetProperty("ATCToolGroup(1)", "Left", "306")
	else
		scr.SetProperty("ATCToolGroup(1)", "Left", "10306")
		scr.SetProperty("ToolGroup(1)", "Left", "306")
	end
	
	
	-- Update Controls
	for i = 1, #screen_controls_hidden do
		scr.SetProperty(screen_controls_hidden[i], "Hidden", "1")
	end
	
	for i = 1, #screen_controls_shown do
		scr.SetProperty(screen_controls_shown[i], "Hidden", "0")
		w.Log(screen_controls_shown[i])
	end
end

function NS_CNC.ScreenLoadScript()
	ns.MachineModelInitialize()
	ns.InitializeScreenGlobals()
	ns.UpdateGoToAbsoluteIncrementalButtons()
	ns.CoolantInitialize()
	ns.InitializeScreenControls()
	ns.InitializeBoolSettings()
	ns.ToolChangerInitialize()
	ns.ToolSetterInitialize()
	
	-- local is_ok, msg = pcall(ns.ToolChange)
	-- if not is_ok then
		-- wx.wxMessageBox(tostring(msg))
	-- end
end

function NS_CNC.ScreenUnLoadScript()
	ns.SaveRegisters()
end

function NS_CNC.PLCScript()
	if PLC_SCRIPT_FIRST_RUN == false then
		PLC_SCRIPT_FIRST_RUN = true
		ns.ScreenLoadScript()
	end
	ns.CoolantTimersUpdate()
	ns.CoolantButtonsUpdate()
	ns.UpdateGCodeLinePercent()
	ns.UpdateButtons()
	ns.UpdateBoolSettings()
end

function NS_CNC.api(api_func, ... )
	local api_fn = mc[api_func]
	if (api_fn == nil) then
		--w.Log(string.format("No Mach API function named '%s'",api_func))
		w.Error(string.format("No Mach API function named '%s'",api_func))
	end
	
	local result = table.pack( pcall( api_fn, ... ) )

	-- Lua error (syntax, bad data, etc.; NOT an "error" return value, MERROR_*)
	local is_ok = result[1]
	if not is_ok then
		w.Error(string.format("Error calling MachAPI '%s(%s)': %s",api_func,w.TableToString({...},0,true),result[2]))
	end

	-- Mach Error returned (the last return value)
	local rc = result[result.n]

 	if (rc ~= mc.MERROR_NOERROR) then
		local msg = string.format("Error returned from MachAPI '%s(%s)': (%d) %s",
											  api_func,w.table.concat({...},","),
											  rc, w.mcError:GetMsg(rc))
		w.Error(msg)
	end
	
	-- Everything's OK. Return whatever values are still there.
	-- We're going to use table unpack to return a list
	--   result[1] is pcall()'s 'is_ok'
	--   result[#result] is the API return code
	--   result['n'] is used by table.unpack
	local retval = {}
	local count = 0
	for i = 2, result.n-1 do
		if (result[i] ~= nil) then
			-- Don't bother inserting nil into the table. It's already "there."
			table.insert(retval,result[i])
		end
		count = count + 1
	end
	retval.n = count
	if (count == 0) then
		-- Return nothing if there's nothing left.
		return
	end
	return table.unpack(retval)
end

function NS_CNC.MDICommand(GCode)
	ns.api("mcCntlMdiExecute", inst, GCode)
end

function NS_CNC.LoadGCode()
	local DefaultDirectory = ns.api("mcProfileGetString", inst, "NS_CNC", "DefaultDirectory", "")

	if DefaultDirectory == nil or DefaultDirectory == "" then
		DefaultDirectory =  MACH_DIRECTORY .. "/GcodeFiles"
	end
	
	local dummyframe = wx.wxFrame(wx.NULL, wx.wxID_ANY,	"", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_FRAME_STYLE)
	local fileDialog = wx.wxFileDialog(dummyframe,
									   "Open GCode File",
									   DefaultDirectory,
									   "",
									   "",
									   wx.wxFD_OPEN + wx.wxFD_OVERWRITE_PROMPT)
	local rc, shown = w.Formatting.ShowModalDialog(fileDialog)
	if shown and rc == wx.wxID_OK and w.FileExists(fileDialog:GetPath()) then
		FileNamePath = fileDialog:GetPath()
		ns.api("mcProfileWriteString", inst, "NS_CNC", "DefaultDirectory", FileNamePath)
		ns.api("mcCntlLoadGcodeFile", inst, FileNamePath)
	end
	if dummyframe then
		dummyframe:Destroy()
	end
end

function NS_CNC.IsAxisEnabled(AxisID)
	local enabled = ns.api("mcAxisIsEnabled", inst, AxisID)
	if enabled == 1 then
		return true
	else
		return false
	end
end

function NS_CNC.IsToolTrayEnabled()
	return ns.IsAxisEnabled(mc.C_AXIS)
end

function NS_CNC.SetToolHeight()
	mc.mcCntlGcodeExecute(inst, "M900")
end

function NS_CNC.IsToolMagazineOpen()
	if w.GetSignalState(mc.ISIG_PROBE) then
		return true
	else
		return false
	end
end

function NS_CNC.MoveToolMagazineToggle()
	if NS_CNC.IsToolMagazineOpen() then
		NS_CNC.MoveToolMagazine("close")
	else
		NS_CNC.MoveToolMagazine("open")
	end
end

function NS_CNC.MoveToolMagazine(direction)
	local probe = ""
	if direction == "close" then
		direction = -1000
		probe = "G31.2"
	else
		direction = 1000
		probe = "G31"
	end
	
	local inst = mc.mcGetInstance() --Get the instance of Mach4
	
	--Initial State
	local Initial_Feed = mc.mcCntlGetPoundVar(inst, mc.SV_FEEDRATE)
	local Initial_Mode = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_3)
	
	local tc = ns.ToolChangerGetSettings()
	local magazinefeedrate = tc.ToolTrayOpenCloseFeedrate
	
	
	
	
	local gcode = ""
	
	gcode = string.format("%s\nG90\n", gcode)
	
	gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
	
	if model ~= "Elara" and model ~= "Elara ATC" then
		gcode = string.format("%s\nG00 A0\n", gcode)
	end

	gcode = string.format("%s\n%s C%0.4f F%0.4f\n", gcode, probe, direction, tc.ToolTrayOpenCloseFeedrate)
	
	gcode = gcode .. string.format("G%2.0f\nF%4.0f\n", Initial_Mode, Initial_Feed) --Restore initial settings
	
	rc = mc.mcCntlGcodeExecute(inst, gcode)		
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to open or close the tool magazine")
	end
end


function NS_CNC.ButtonCall(func, val, ...) 
	local button_name = tostring(select(1, ...))
	w.Log(button_name .. " Pressed")
	
	local is_ok, err = pcall(func, val, ...)
	if not is_ok then
		wx.wxMessageBox(tostring(err))
	end
end

function NS_CNC.DROChanged(func, ...) 
	local dro_value = select(1, ...)
	local dro_name = select(2, ...)
	
	w.Log(dro_name .. " Changed, Value: " .. dro_value)
	
	dro_value = tonumber(dro_value)
	
	local is_ok, err = pcall(func, dro_value, ...)
	if not is_ok then
		wx.wxMessageBox(tostring(err))
	else
		return tostring(is_ok)
	end
end

function NS_CNC.CreatRegister(register_name, desc)
	if NS_CNC.Registers == nil then
		NS_CNC.Registers = {}
	end
	
	if NS_CNC.Registers.register_name == nil then
		NS_CNC.Registers[register_name] = register_name
	end
	
	local hreg = mc.mcRegGetHandle(inst, string.format("iRegs0/%s", register_name))
	if hreg == 0 then
		local result, rc = mm.mcRegAddDel(inst, "ADD", "iRegs0", register_name, desc, 0, 1)
		if rc ~= mc.MERROR_NOERROR then
			wx.wxMessageBox(tostring(result))
		end
	end
	
	mm.LoadRegister("NS_CNC", register_name)
end

function NS_CNC.SaveRegisters()
	if NS_CNC.Registers ~= nil then
		for _,regname in pairs(NS_CNC.Registers) do
			mm.SaveRegister("NS_CNC", regname)
		end
	end
end

function NS_CNC.SetRegisterValue(register_name, value)
	local hreg = mc.mcRegGetHandle(inst, string.format("iRegs0/%s", register_name))
	if hreg == 0 then
		return nil, false, string.format("Error Register: %s was not found", register_name)
	else
		return mc.mcRegSetValue(hreg,tonumber(val)), true, string.format("Set Register: %s Successfully", register_name)
	end
end

function NS_CNC.GetRegisterValue(register_name)
	local hreg = mc.mcRegGetHandle(inst, string.format("iRegs0/%s", register_name))
	if hreg == 0 then
		return nil, false, string.format("Error Register: %s was not found", register_name)
	else
		return mc.mcRegGetValue(hreg), true, string.format("Set Register: %s Successfully", register_name)
	end
end


function NS_CNC.InitializeScreenGlobals()	
	w.Log("InitializeScreenGlobals")
	inst = mc.mcGetInstance("NS_CNC Screen")
	SOFTWARE_NAME = "Mach4"
	MACH_DIRECTORY = mc.mcCntlGetMachDir(inst)
	MACH_PROFILE_NAME = mc.mcProfileGetName(inst)
	MCODE_DIRECTORY = string.format("%s/Profiles/%s/Macros/", MACH_DIRECTORY, MACH_PROFILE_NAME)
	FIRST_RUN = false
	MACHINE_DEFAULT_UNITS = mc.mcProfileGetInt(inst,"Preferences","SetupUnits",-1)
	MACHINE_CURRENT_UNITS = mc.mcCntlGetUnitsCurrent(inst)
	MACHINE_TYPE = {}
	MACHMOTION_BUILD = 0 
	MACHMOTION_BUILD_STR = "" 
	MACHMOTION_VERSION_STR = "" 
	AXIS_ENABLED = {}
	AXIS_IS_SHOWN = {}
	AXIS_LETTER_ARRAY = {"X","Y","Z","A","B","C","OB1","OB2","OB3","OB4","OB5","OB6"}
	AXIS_LETTER_ARRAY_INC = {"U","V","W","","","H"}
	AXIS_LETTER_ARRAY_0 = {	[mc.X_AXIS] = "X",[mc.Y_AXIS] = "Y",[mc.Z_AXIS] = "Z",[mc.A_AXIS] = "A",[mc.B_AXIS] = "B",[mc.C_AXIS] = "C",
							[mc.AXIS6] = "OB1",[mc.AXIS7] = "OB2",[mc.AXIS8] = "OB3",[mc.AXIS9] = "OB4",[mc.AXIS10] = "OB5",[mc.AXIS11] = "OB6"
						  }
	AXIS_LETTER_ARRAY_INC_0 = {	[mc.X_AXIS] = "U",[mc.Y_AXIS] = "V",[mc.Z_AXIS] = "W",[mc.C_AXIS] = "H"}
	AXIS_LETTER_ARRAY_TEXT = {"X","Y","Z","A/U","B/V","C/W","OB1","OB2","OB3","OB4","OB5","OB6"}
	AXIS_LETTER_ARRAY_TEXT_0 = { [mc.X_AXIS] = "X",[mc.Y_AXIS] = "Y",[mc.Z_AXIS] = "Z",[mc.A_AXIS] = "A/U",[mc.B_AXIS] = "B/V",[mc.C_AXIS] = "C/W",
								 [mc.AXIS6] = "OB1",[mc.AXIS7] = "OB2",[mc.AXIS8] = "OB3",[mc.AXIS9] = "OB4",[mc.AXIS10] = "OB5",[mc.AXIS11] = "OB6"
							   }
	BTN_COLOR_ON = "#eaef10"  --"#6E6E6E"
	BTN_COLOR_OFF = "#b4b4b4"
	BTN_COLOR_RED = "#FF0000"
	BTN_COLOR_GREEN = "#00FF00"
	BTN_COLOR_LIGHT_GREEN = "#90EE90"
	BTN_COLOR_YELLOW = "#eaef10"
	BTN_COLOR_YELLOW_OFF = ""
	BTN_COLOR_ORANGE = "#FFA500"
	DRO_COLOR_BLACK = "#000000"
	DRO_COLOR_RED = "#FF0000"
	DRO_COLOR_GREEN = "#00FF00"
	DRO_COLOR_YELLOW = "#FFFF00"
	DRO_COLOR_MACHINE_COORDS = "#FF6600"
	DRO_COLOR_PART_COORDS = "#00FF00"
	DRO_COLOR_READ_ONLY = "#DDDDDD"
	DRO_COLOR_EDITABLE = "#FFFFFF"
	
	w.CheckStopStatus = function()
		local returnmessage = ""
		local FunctionName = "w.CheckStopStatus"
		Filename = type(Filename) == "string" and Filename or "nil"
		LineNumber = type(LineNumber) == "number" and tostring(LineNumber) or " nil "


		local CurrentStopNumber,b,c = w.GetRegValue("core/inst", "CmdStopAndDisable")
		if b == false then 
			w.FunctionError("Error: " .. tostring(c), FunctionName, 519, "WrapperModule")
			returnmessage = FunctionName .. " Error On Line 250: " .. c
			return nil, false, returnmessage
		end

		-- local LastStopNumber,b,c = w.GetRegValue("MachMotion", "mm_StopStatus")
		-- if b == false then 
			-- w.FunctionError("Error: " .. tostring(c), FunctionName, 526, "WrapperModule")
			-- returnmessage = FunctionName .. " Error On Line 256: " .. c
			-- return nil, false, returnmessage
		-- end

		-- if LastStopNumber ~= CurrentStopNumber then
			-- return CurrentStopNumber, false, FunctionName .. ":Machine Has Been Disabled"
		-- end
		return CurrentStopNumber, true, FunctionName .. " Ran Successfully"
	end
	
	w.IsMachShuttingDown = function()
		return false
	end
end

function NS_CNC.ToolChange()
	local inst = mc.mcGetInstance("m6 ToolChange") --Get the instance of Mach
	
	w.Log("Start -> ToolChange")
	-- local toolchanger_list = {
		-- ["ToolTrayOpenCloseFeedrate"] = {["description"] = "Tool Tray Open and Close Feedrate", ["value"] = nil },
		-- ["ZToolClampPosition"] = {["description"] = "Z Tool Clamp Position", ["value"] = nil },
		-- ["ZToolClearancePosition"] = {["description"] = "Z Tool Clearance Position", ["value"] = nil },
		-- ["ZToolSlowZonePosition"] = {["description"] = "Z Tool Slow Zone Position", ["value"] = nil },
		-- ["ZSafePosition"] = {["description"] = "Z Safe Position", ["value"] = nil },
		-- ["SlowZoneFeedrate"] = {["description"] = "Slow Zone Feedrate", ["value"] = nil },
		-- ["ToolBreakageCheck"] = {["description"] = "Tool Breakage Check 1 = On, 0 = Off", ["value"] = nil },
		-- ["ToolBreakageTolerance"] = {["description"] = "Tool Breakage Tolerance", ["value"] = nil },
		-- ["MeasureToolLengthDuringToolChange"] = {["description"] = "Measure Tool Length During Tool Change 1 = On, 0 = Off", ["value"] = nil },
	-- }
	
	local tc = ns.ToolChangerGetSettings()
	local ts = ns.ToolSetterGetSettings()
	
	local model = ns.GetMachineModel()

	--Initial Positions and Modes
	local Initial_X = mc.mcAxisGetPos(inst, mc.X_AXIS) 
	local Initial_Y = mc.mcAxisGetPos(inst, mc.Y_AXIS)
	local Initial_Z = mc.mcAxisGetPos(inst, mc.Z_AXIS) 
	local Initial_A = mc.mcAxisGetPos(inst, mc.A_AXIS)
	local Initial_Feed = mc.mcCntlGetPoundVar(inst, mc.SV_FEEDRATE)
	local Initial_Mode = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_3)
	local zSoftLimitMode = mc.mcSoftLimitGetState(inst, 2); --adp get z soft limit state
	mc.mcSoftLimitSetState(inst, 2, mc.MC_OFF); -- adp turn off z soft limit state in case its on

	--Tool Values
	local CurrentTool = mc.mcToolGetCurrent(inst) 
	local SelectedTool = mc.mcToolGetSelected(inst) --This value is changed by a T-Code call with the tool number (Ex. "T1")
	local CurrentToolPocketPos_X = mc.mcToolGetDataExDbl(inst, CurrentTool, "XToolChange") --In Machine Coordinates
	local CurrentToolPocketPos_Y = mc.mcToolGetDataExDbl(inst, CurrentTool, "YToolChange") --In Machine Coordinates
	local SelectedToolPocketPos_X = mc.mcToolGetDataExDbl(inst, SelectedTool, "XToolChange") --In Machine Coordinates
	local SelectedToolPocketPos_Y = mc.mcToolGetDataExDbl(inst, SelectedTool, "YToolChange") --In Machine Coordinates
	
	--Signals
	local sigCloseCollet = mc.mcSignalGetHandle(inst, mc.OSIG_OUTPUT32)

	if CurrentTool == SelectedTool then
		w.Log("Selected tool already equipped: " .. SelectedTool)
		return "Selected tool already equipped: " .. SelectedTool, true
	end

	local gcode = ""
	
	gcode = string.format("%s\nG90\n", gcode)
	
	gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
	
	if model ~= "Elara" and model ~= "Elara ATC" then
		gcode = string.format("%s\nG00 A0\n", gcode)
	end

	if ns.IsToolTrayEnabled() and not ns.IsToolMagazineOpen() then
		gcode = string.format("%s\nG31 C10000 F%0.4f\n", gcode, tc.ToolTrayOpenCloseFeedrate)
	end
	
	rc = mc.mcCntlGcodeExecuteWait(inst, gcode)		
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to open tool magazine")
	end
	
	if CurrentTool ~= 0 then --If holding a tool, put it back
		
		if tc.ToolBreakageCheck == 1 and tc.MeasureToolLengthDuringToolChange then
			ns.AutoSetToolHeight(true)
		end
		
		gcode = string.format("G53 G00 X%0.4f Y%0.4f\nG53 G00 Z%0.4f\n", CurrentToolPocketPos_X, CurrentToolPocketPos_Y, tc.ZToolSlowZonePosition)

		gcode = string.format("%s\nG53 G01 Z%0.4f F%0.4f\n", gcode, tc.ZToolClampPosition, tc.SlowZoneFeedrate)

		rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
		if rc ~= mc.MERROR_NOERROR then
			error("Failed to return tool")
		end
	
		mc.mcSignalSetState(sigCloseCollet, 1)
		wx.wxMilliSleep(1000)

		gcode = string.format("G53 G01 Z%0.4f F%0.4f\n", tc.ZToolClearancePosition, tc.SlowZoneFeedrate)

		rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
		if rc ~= mc.MERROR_NOERROR then
			error("Failed to return tool")
		end
	end

	gcode = string.format("G53 G00 X%0.4f Y%0.4f\n", SelectedToolPocketPos_X, SelectedToolPocketPos_Y)

	gcode = string.format("%s\nG53 G01 Z%0.4f F%0.4f\n", gcode, tc.ZToolClampPosition, tc.SlowZoneFeedrate)

	rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
	if rc ~= mc.MERROR_NOERROR then
		error("Failed move to next tool")
	end

	mc.mcSignalSetState(sigCloseCollet, 0)
	wx.wxMilliSleep(1000)
	
	mc.mcToolSetCurrent(inst, SelectedTool)
	
	gcode = string.format("G53 G00 Z%0.4f\n", tc.ZToolSlowZonePosition)

	rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to return to Z Safe Position")
	end
	
	if tc.MeasureToolLengthDuringToolChange == 1 then
		ns.AutoSetToolHeight(false)
	end
	
	gcode = string.format("G53 G00 Z%0.4f\n", tc.ZSafePosition)

	gcode = string.format("%s\nG00 X%0.4f Y%0.4f\n", gcode, Initial_X, Initial_Y)
	
	if model ~= "Elara" and model ~= "Elara ATC" then
		gcode = string.format("%s\nG00 A%0.4f\n", gcode, Initial_A)
	end
	
	if ns.IsToolTrayEnabled() then
		gcode = string.format("%s\nG31.2 C-10000 F%0.4f\n", gcode, tc.ToolTrayOpenCloseFeedrate)
	end
	
	gcode = string.format("%s\nG%2.0f\nF%4.0f", gcode, Initial_Mode, Initial_Feed)
	
	rc = mc.mcCntlGcodeExecuteWait(inst, gcode) --Restore old settings
	if tonumber(zSoftLimitMode) == 1 then mc.mcSoftLimitSetState(inst, 2, mc.MC_ON) end -- adp restore z soft limit state
	
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to restore initial settings")
	end
	
	w.Log("End -> ToolChange")
	
	return "Tool Change Complete: " .. CurrentTool .. "->" .. SelectedTool , true
end


function NS_CNC.AutoSetToolHeight(tool_breakage_check, set_tool_setter_position)
	if tool_breakage_check == nil then tool_breakage_check = false end
	if set_tool_setter_position == nil then set_tool_setter_position = false end
	
	-- ["XPosition"] = {["description"] = "X Setter Position", ["value"] = nil },
	-- ["YPosition"] = {["description"] = "Y Setter Position", ["value"] = nil },
	-- ["ZProbeStartPosition"] = {["description"] = "Z Probe Start Position", ["value"] = nil },
	-- ["ZProbeEndPosition"] = {["description"] = "Z Probe End Position", ["value"] = nil },
	-- ["ZSlowZonePosition"] = {["description"] = "Z Slow Zone Position", ["value"] = nil },
	-- ["SlowZoneFeedrate"] = {["description"] = "Slow Zone Feedrate", ["value"] = nil },
	-- ["ZFirstTouchFeedrate"] = {["description"] = "Z First Touch Feedrate", ["value"] = nil },
	-- ["ZSecondTouchFeedrate"] = {["description"] = "Z Second Touch Feedrate", ["value"] = nil },
	-- ["ZFirstTouchBackoffDistance"] = {["description"] = "Z First Touch Backoff Distance", ["value"] = nil },
	
	local inst = mc.mcGetInstance("Auto Set Tool Height") --Get the instance of Mach
	local model = ns.GetMachineModel()
	local tool_change_active = w.GetSignalState(mc.OSIG_TOOL_CHANGE)
	
	w.Log("Start -> AutoSetToolHeight")
	
	local tc = ns.ToolChangerGetSettings()
	local ts = ns.ToolSetterGetSettings()
	
	--Initial Positions and Modes
	local Initial_X = mc.mcAxisGetPos(inst, mc.X_AXIS) 
	local Initial_Y = mc.mcAxisGetPos(inst, mc.Y_AXIS)
	local Initial_Z = mc.mcAxisGetPos(inst, mc.Z_AXIS) 
	local Initial_A = mc.mcAxisGetPos(inst, mc.A_AXIS)
	local Initial_Feed = mc.mcCntlGetPoundVar(inst, mc.SV_FEEDRATE)
	local Initial_Mode = mc.mcCntlGetPoundVar(inst, mc.SV_MOD_GROUP_3)
	
	local CurrentTool = mc.mcToolGetCurrent(inst)
	
	local gcode = ""
	
	gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
	
	if model ~= "Elara" and model ~= "Elara ATC" and not tool_change_active then
		gcode = string.format("%s\nG00 A0\n", gcode)
	end
	
	if ns.IsToolTrayEnabled() and not ns.IsToolMagazineOpen() then
		gcode = string.format("%s\nG31 C10000 F%0.4f\n", gcode, tc.ToolTrayOpenCloseFeedrate)
	end

	gcode = string.format("%s\nG53 G00 X%0.4f Y%0.4f\n", gcode, ts.XPosition, ts.YPosition)

	gcode = string.format("%s\nG53 G31.1 Z%0.4f F%0.4f\n", gcode, ts.ZSlowZonePosition, ts.SlowZoneFeedrate * 3)

	gcode = string.format("%s\nG53 G31.1 Z%0.4f F%0.4f\n", gcode, ts.ZProbeStartPosition, ts.SlowZoneFeedrate)

	gcode = string.format("%s\nG53 G31.1 Z%0.4f F%0.4f\n", gcode, ts.ZProbeEndPosition, ts.ZFirstTouchFeedrate)
	
	gcode = string.format("%s\nG53 G00 Z[[#5073] + %0.4f]\n", gcode, ts.ZFirstTouchBackoffDistance)
	
	gcode = string.format("%s\nG53 G31.1 Z%0.4f F%0.4f\n", gcode, ts.ZProbeEndPosition, ts.ZSecondTouchFeedrate)
	
	gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
	
	rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to measure tool")
	end
	
	gcode = ""
	
	local probed_pos = mc.mcCntlGetPoundVar(inst, mc.SV_PROBE_MACH_POS_Z)
	
	if math.abs(probed_pos - ts.ZProbeEndPosition) < 0.5 then
		error("Failed to find tool setter during probe moves")
	end
	
	local setter_pos = mc.mcCntlGetPoundVar(inst, 500)
	local length = probed_pos - setter_pos
	local machState = mc.mcCntlGetState(inst)
	
	if set_tool_setter_position then
		gcode = string.format("%s\n#500 = #5073\n", gcode)
	else		
		if tool_breakage_check and machState < mc.MC_STATE_MRUN then
			local LastMeasuredLength = w.GetToolTableUserValue("LastMeasuredLength", CurrentTool)
			if math.abs(LastMeasuredLength - length) > tc.ToolBreakageTolerance then
				error("Tool Breakage Detected")
			end
		else
			gcode = string.format("%s\nG90 G10 L1 P#1229 Z[#5073 - #500]\n G43 H#1229\n", gcode)
		end
		
		local a,b,c = w.SetToolTableUserValue("LastMeasuredLength", length, CurrentTool)
		if b ~= true then error(c) end
		--wx.wxMessageBox(string.format("LastMeasuredLength, Tool: %s, Length: %s, return a: %s", CurrentTool, length, a))
	end
	
	gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
	
	if not tool_change_active then
		gcode = string.format("%s\nG00 X%0.4f Y%0.4f\n", gcode, Initial_X, Initial_Y)
	end
	
	if ns.IsToolTrayEnabled() and not tool_change_active then
		-- if we are not in a tool change send the tool try home
		gcode = string.format("%s\nG53 G00 Z%0.4f\n", gcode, tc.ZSafePosition)
		
		gcode = string.format("%s\nG31.2 C-10000 F%0.4f\n", gcode, tc.ToolTrayOpenCloseFeedrate)
	end	
	
	if not tool_change_active then
		if model ~= "Elara" and model ~= "Elara ATC" then
			gcode = string.format("%s\nG00 A%0.4f\n", gcode, Initial_A)
		end
		
		gcode = string.format("%s\nG%2.0f\nF%4.0f\n", gcode, Initial_Mode, Initial_Feed)
	end
	
	rc = mc.mcCntlGcodeExecuteWait(inst, gcode)
	if rc ~= mc.MERROR_NOERROR then
		error("Failed to set tool length")
	end
	
	w.Log("End -> AutoSetToolHeight")
end

function NS_CNC.SetToolSetterPosition()
	local inst = mc.mcGetInstance("Set Tool Setter Position") --Get the instance of Mach
	mc.mcCntlGcodeExecute(inst, "M901")
end

return NS_CNC