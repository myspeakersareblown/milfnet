--[[
	SettingsServer: stores validated player settings in their profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Settings"))
local ActionRouter = require(script.Parent:WaitForChild("Modules"):WaitForChild("ActionRouter"))

ActionRouter.register("SaveSettings", function(_player, profile, changes: any)
	if typeof(changes) ~= "table" then
		return { ok = false, error = "Bad settings" }
	end
	local saved = 0
	for key, value in changes do
		if typeof(key) == "string" then
			local clean = SettingsConfig.sanitize(key, value)
			if clean ~= nil then
				profile.Data.Settings[key] = clean
				saved += 1
			end
		end
		if saved > 20 then
			break
		end
	end
	-- No client sync needed: the client already has these values. Autosave stores them.
	return { ok = true }
end)
