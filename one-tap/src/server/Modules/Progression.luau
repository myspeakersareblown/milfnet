--[[
	Progression: the only place that hands out XP, levels and currency.
	Everything that rewards the player goes through here so level-ups,
	notifications and client sync always happen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local Progression = {}

local CURRENCIES = { Taps = true, Gems = true, Scrap = true }

function Progression.addCurrency(player: Player, profile: any, currency: string, amount: number)
	assert(CURRENCIES[currency], `Unknown currency {currency}`)
	profile.Data[currency] = math.max(0, profile.Data[currency] + math.floor(amount))
	PlayerData.changed(player)
end

-- Spends currency if the player has enough. Returns true on success.
function Progression.spend(player: Player, profile: any, currency: string, amount: number): boolean
	assert(CURRENCIES[currency], `Unknown currency {currency}`)
	if amount < 0 or profile.Data[currency] < amount then
		return false
	end
	profile.Data[currency] -= amount
	PlayerData.changed(player)
	return true
end

function Progression.addCrates(player: Player, profile: any, crateId: string, count: number)
	profile.Data.Crates[crateId] = (profile.Data.Crates[crateId] or 0) + count
	PlayerData.changed(player)
end

-- Applies a reward table { taps?, gems?, crates? }.
function Progression.grant(player: Player, profile: any, reward: Economy.Reward)
	if reward.taps then
		Progression.addCurrency(player, profile, "Taps", reward.taps)
	end
	if reward.gems then
		Progression.addCurrency(player, profile, "Gems", reward.gems)
	end
	if reward.crates then
		for crateId, count in reward.crates do
			Progression.addCrates(player, profile, crateId, count)
		end
	end
end

-- Adds XP and handles any level-ups. Returns how many levels were gained.
function Progression.addXp(player: Player, profile: any, amount: number): number
	local data = profile.Data
	if data.Level >= Economy.maxLevel then
		return 0
	end
	data.XP += math.floor(amount)

	local gained = 0
	while data.Level < Economy.maxLevel and data.XP >= Economy.xpForLevel(data.Level) do
		data.XP -= Economy.xpForLevel(data.Level)
		data.Level += 1
		gained += 1

		local reward = Economy.levelReward(data.Level)
		Progression.grant(player, profile, reward)
		Notify:FireClient(player, "LevelUp", { level = data.Level, reward = reward })
	end
	if data.Level >= Economy.maxLevel then
		data.XP = 0
	end

	PlayerData.changed(player)
	return gained
end

return Progression
