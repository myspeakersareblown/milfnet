--[[
	DataServer: loads profiles on join, autosaves, releases on leave/shutdown,
	and answers the "GetProfile" action.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local ActionRouter = require(Modules:WaitForChild("ActionRouter"))

local PlayerAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayerAction") :: RemoteFunction

local AUTOSAVE_INTERVAL = 60

ActionRouter.init(PlayerAction, PlayerData)

ActionRouter.register("GetProfile", function(_player, profile)
	return { ok = true, profile = PlayerData.snapshot(profile) }
end)

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(PlayerData.load, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

game:BindToClose(function()
	PlayerData.releaseAll()
end)

while true do
	task.wait(AUTOSAVE_INTERVAL)
	PlayerData.autosaveAll()
end
