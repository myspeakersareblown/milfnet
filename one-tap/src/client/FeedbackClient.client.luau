--[[
	FeedbackClient: reacts to what the server confirmed. Hitmarkers, banners,
	kill feed, and other players' tracers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(script.Parent:WaitForChild("Hud"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HitConfirm = Remotes:WaitForChild("HitConfirm") :: RemoteEvent
local KillFeed = Remotes:WaitForChild("KillFeed") :: RemoteEvent
local ShotFired = Remotes:WaitForChild("ShotFired") :: UnreliableRemoteEvent

local player = Players.LocalPlayer
local streak = 0 -- kills this life

player.CharacterAdded:Connect(function()
	streak = 0
end)

HitConfirm.OnClientEvent:Connect(function(weaponName: string, special: boolean, killed: boolean)
	Hud.hitmarker(special, killed)
	-- TODO(M2): headshot "ding" + kill sound here.
	if not killed then
		return
	end

	streak += 1
	if weaponName == "Sniper" and special then
		Hud.banner(if streak >= 2 then `1 TAP x{streak}` else "1 TAP")
	elseif weaponName == "Knife" and special then
		Hud.banner("BACKSTAB")
	end
end)

local VIP_COLOR = Color3.fromRGB(255, 200, 60)

KillFeed.OnClientEvent:Connect(
	function(killerName: string, victimName: string, weaponName: string, special: boolean, killer: Player?, position: Vector3?)
		local killerColor = if killer and killer:GetAttribute("VIP") then VIP_COLOR else nil
		Hud.killFeed(killerName, victimName, weaponName, special, killerColor)
		if typeof(position) == "Vector3" then
			Effects.killEffectFor(killer, position)
		end
	end
)

ShotFired.OnClientEvent:Connect(function(shooter: Player, origin: Vector3, finish: Vector3)
	if shooter == player then
		return -- we already drew our own tracer instantly
	end
	if typeof(origin) == "Vector3" and typeof(finish) == "Vector3" then
		Effects.tracer(origin, finish, Effects.tracerColorFor(shooter))
	end
end)
