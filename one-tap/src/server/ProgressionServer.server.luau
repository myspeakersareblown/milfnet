--[[
	ProgressionServer: pays out Taps + XP for kills and round results,
	and keeps lifetime stats. Only real rounds count (no warmup, no test dummies).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))
local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Progression = require(Modules:WaitForChild("Progression"))
local Signals = require(Modules:WaitForChild("Signals"))

local MatchState = ReplicatedStorage:WaitForChild("MatchState")
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local R = Economy.Rewards

-- What each player earned this round, for the results screen.
local roundEarnings: { [Player]: { taps: number, xp: number } } = {}

local function pay(player: Player, profile: any, reward: { taps: number, xp: number })
	Progression.addCurrency(player, profile, "Taps", reward.taps)
	Progression.addXp(player, profile, reward.xp)
	local earned = roundEarnings[player] or { taps = 0, xp = 0 }
	earned.taps += reward.taps
	earned.xp += reward.xp
	roundEarnings[player] = earned
end

Signals.Kill.Event:Connect(function(attacker: Player, victim: Player?, weaponName: string, special: boolean)
	if MatchState:GetAttribute("Phase") ~= "Playing" or victim == nil or victim == attacker then
		return
	end

	local victimProfile = PlayerData.get(victim)
	if victimProfile then
		victimProfile.Data.Stats.Deaths += 1
	end

	local profile = PlayerData.get(attacker)
	if not profile then
		return
	end
	local stats = profile.Data.Stats
	stats.Kills += 1
	pay(attacker, profile, R.Kill)

	if special and weaponName == "Sniper" then
		stats.Headshots += 1
		pay(attacker, profile, R.HeadshotBonus)
	elseif special and weaponName == "Knife" then
		stats.Backstabs += 1
		pay(attacker, profile, R.BackstabBonus)
	end
end)

Signals.RoundStarted.Event:Connect(function()
	table.clear(roundEarnings)
end)

Signals.RoundEnded.Event:Connect(function(standings: { Signals.Standing }, completed: boolean)
	for _, entry in standings do
		local player = entry.player
		local profile = player and player.Parent and PlayerData.get(player)
		if profile then
			if completed and entry.kills > 0 then
				profile.Data.Stats.Matches += 1
				pay(player, profile, R.MatchComplete)
				if entry.rank == 1 then
					profile.Data.Stats.Wins += 1
					pay(player, profile, R.Win)
				elseif entry.rank <= 3 then
					pay(player, profile, R.Top3)
				end
			end
			local earned = roundEarnings[player] or { taps = 0, xp = 0 }
			Notify:FireClient(player, "RoundRewards", earned)
		end
	end
	table.clear(roundEarnings)
end)

Players.PlayerRemoving:Connect(function(player)
	roundEarnings[player] = nil
end)
