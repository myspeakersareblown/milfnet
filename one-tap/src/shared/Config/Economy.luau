--[[
	Economy: what playing earns you, and the level curve.

	Rule: Taps (and anything bought with Taps) can only be EARNED by playing,
	never bought with Robux directly or indirectly. That keeps the Standard
	Crate clearly "free", and it's why VIP gives no XP/Taps boost.
]]

local Economy = {}

Economy.Rewards = {
	Kill = { taps = 10, xp = 25 },
	HeadshotBonus = { taps = 5, xp = 10 }, -- on top of Kill
	BackstabBonus = { taps = 5, xp = 10 }, -- on top of Kill
	MatchComplete = { taps = 25, xp = 50 }, -- needs at least 1 kill (no AFK farming)
	Win = { taps = 50, xp = 100 },
	Top3 = { taps = 20, xp = 40 }, -- 2nd and 3rd place
}

Economy.maxLevel = 100

-- XP needed to go from `level` to `level + 1`.
function Economy.xpForLevel(level: number): number
	return 200 + (level - 1) * 50
end

export type Reward = {
	taps: number?,
	gems: number?,
	crates: { [string]: number }?,
}

-- What you get for reaching `level`.
function Economy.levelReward(level: number): Reward
	local reward: Reward = { taps = 50 }
	if level % 5 == 0 then
		reward.crates = { StandardCrate = 1 }
	end
	if level % 10 == 0 then
		reward.gems = 25
	end
	return reward
end

-- Brand-new players start with this (only applied once, on their first join).
Economy.starting = {
	crates = { StandardCrate = 1 },
}

return Economy
