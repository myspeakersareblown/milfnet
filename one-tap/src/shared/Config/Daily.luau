--[[
	Daily: login streak rewards and daily challenges.

	Login: claimed automatically on your first join each UTC day. Missing a day
	resets the streak. The 7-day cycle then repeats.

	Challenges: each player gets `challengesPerDay` from the pool every day
	(different players get different ones). Rewards are paid automatically on completion.
]]

local Daily = {}

Daily.loginRewards = {
	{ taps = 100 },
	{ taps = 150 },
	{ taps = 200 },
	{ crates = { StandardCrate = 1 } },
	{ taps = 300 },
	{ gems = 10 },
	{ taps = 500, crates = { StandardCrate = 1 } },
}

Daily.challengesPerDay = 3
Daily.longShotDistance = 150 -- studs, for the "long shot" challenge

-- stat: what counts toward it (tracked by DailyServer)
--   Kills, Headshots, LongShots, KnifeKills, Backstabs, Streak5, Wins, Matches
Daily.Challenges = {
	kills_15 = { text = "Get 15 kills", stat = "Kills", goal = 15, reward = { taps = 150 } },
	kills_40 = { text = "Get 40 kills", stat = "Kills", goal = 40, reward = { taps = 350 } },
	headshots_8 = { text = "Get 8 headshot kills", stat = "Headshots", goal = 8, reward = { taps = 200 } },
	headshots_20 = { text = "Get 20 headshot kills", stat = "Headshots", goal = 20, reward = { taps = 400 } },
	longshots_3 = { text = "Get 3 headshots from 150+ studs", stat = "LongShots", goal = 3, reward = { taps = 300 } },
	knife_5 = { text = "Get 5 knife kills", stat = "KnifeKills", goal = 5, reward = { taps = 200 } },
	backstabs_3 = { text = "Get 3 backstabs", stat = "Backstabs", goal = 3, reward = { taps = 250 } },
	streak_5 = { text = "Get 5 kills without dying", stat = "Streak5", goal = 1, reward = { taps = 250 } },
	wins_1 = { text = "Win a round", stat = "Wins", goal = 1, reward = { taps = 300 } },
	matches_3 = { text = "Finish 3 rounds", stat = "Matches", goal = 3, reward = { taps = 200 } },
}

-- Today's challenges for one player (same answer on server and client).
function Daily.pickForDay(day: number, userId: number): { string }
	local pool = {}
	for id in Daily.Challenges do
		table.insert(pool, id)
	end
	table.sort(pool)
	local rng = Random.new(day * 100003 + (userId % 100000))
	local picks = {}
	for _ = 1, math.min(Daily.challengesPerDay, #pool) do
		table.insert(picks, table.remove(pool, rng:NextInteger(1, #pool)))
	end
	return picks
end

return Daily
