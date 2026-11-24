--[[
	Settings (client): current values with defaults, loaded once from your saved
	profile, saved back to the server a moment after you stop changing them.

	  Settings.get("FieldOfView")
	  Settings.set("FieldOfView", 80)
	  Settings.onChanged(function(key, value) ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Settings"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))

local Settings = {}

local values: { [string]: any } = {}
local listeners: { (string, any) -> () } = {}
local pending: { [string]: any } = {}
local saveToken = 0
local SAVE_DELAY = 1

local function notify(key: string, value: any)
	for _, listener in listeners do
		task.spawn(listener, key, value)
	end
end

function Settings.get(key: string): any
	local value = values[key]
	if value == nil then
		local definition = SettingsConfig.byKey[key]
		return if definition then definition.default else nil
	end
	return value
end

function Settings.set(key: string, value: any)
	local clean = SettingsConfig.sanitize(key, value)
	if clean == nil or values[key] == clean then
		return
	end
	values[key] = clean
	notify(key, clean)

	pending[key] = clean
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token ~= saveToken then
			return -- still changing; the latest call will save
		end
		local changes = pending
		pending = {}
		PlayerState.action("SaveSettings", changes)
	end)
end

function Settings.onChanged(listener: (string, any) -> ())
	table.insert(listeners, listener)
end

-- Load saved values the first time the profile arrives.
local loaded = false
PlayerState.onChanged(function(data)
	if loaded or typeof(data.Settings) ~= "table" then
		return
	end
	loaded = true
	for key, value in data.Settings do
		local clean = SettingsConfig.sanitize(key, value)
		if clean ~= nil and values[key] == nil then
			values[key] = clean
			notify(key, clean)
		end
	end
end)

return Settings
