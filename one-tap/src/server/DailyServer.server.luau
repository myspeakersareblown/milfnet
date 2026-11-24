--[[
	DailyServer: login streak + daily challenges (see Config/Daily).

	profile.Data.Daily = {
		loginDay = number,        -- last UTC day the login reward was paid
		streak = number,
		challengeDay = number,    -- UTC day the current challenges belong to
		challenges = { id },      -- today's challenge ids
		progress = { [id] = n },
		done = { [id] = true },
	}
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Daily = require(Config:WaitForChild("Daily"))
local Economy = require(Config:WaitForChild("Economy"))
local Featured = require(Shared:WaitForChild("Featured"))

local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local Progression = require(Modules:WaitForChild("Progression"))
local Signals = require(Modules:WaitForChild("Signals"))

local MatchState = ReplicatedStorage:WaitForChild("MatchState")
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local function today(): number
	return Featured.dayNumber(os.time())
end

-- Rolls over to a new set of challenges when the UTC day changes.
local function ensureDay(player: Player, profile: any): any
	local daily = profile.Data.Daily
	local day = today()
	if daily.challengeDay ~= day then
		daily.challengeDay = day
		daily.challenges = Daily.pickForDay(day, player.UserId)
		daily.progress = {}
		daily.done = {}
		PlayerData.changed(player)
	end
	return daily
end

local function payLogin(player: Player, profile: any)
	local daily = ensureDay(player, profile)
	local day = today()
	if daily.loginDay == day then
		return
	end
	daily.streak = if daily.loginDay == day - 1 then (daily.streak or 0) + 1 else 1
	daily.loginDay = day

	local reward = Daily.loginRewards[((daily.streak - 1) % #Daily.loginRewards) + 1]
	Progression.grant(player, profile, reward)
	PlayerData.changed(player)
	Notify:FireClient(player, "Toast", {
		title = `DAY {daily.streak} LOGIN REWARD`,
		text = Economy.describeReward(reward),
		color = Color3.fromRGB(255, 205, 70),
	})
end

PlayerData.onLoaded(function(player, profile)
	ensureDay(player, profile)
	task.delay(4, function() -- give the client a moment to build its UI
		if player.Parent and PlayerData.get(player) == profile then
			payLogin(player, profile)
		end
	end)
end)

-- Catch the UTC day rolling over for people who are still playing.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.get(player)
			if profile then
				payLogin(player, profile)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Challenge progress
--------------------------------------------------------------------------------

local function addProgress(player: Player, stat: string, amount: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local daily = ensureDay(player, profile)
	for _, id in daily.challenges do
		local challenge = Daily.Challenges[id]
		if challenge and challenge.stat == stat and not daily.done[id] then
			local value = math.min(challenge.goal, (daily.progress[id] or 0) + amount)
			daily.progress[id] = value
			if value >= challenge.goal then
				daily.done[id] = true
				Progression.grant(player, profile, challenge.reward)
				Notify:FireClient(player, "Toast", {
					title = "CHALLENGE COMPLETE",
					text = `{challenge.text}   {Economy.describeReward(challenge.reward)}`,
					color = Color3.fromRGB(90, 210, 120),
				})
			end
			PlayerData.changed(player)
		end
	end
end

local killsThisLife: { [Player]: number } = {}

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		killsThisLife[player] = 0
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	killsThisLife[player] = nil
end)

Signals.Kill.Event:Connect(function(attacker: Player, victim: Player?, weaponName: string, special: boolean, distance: number?)
	if MatchState:GetAttribute("Phase") ~= "Playing" or victim == nil or victim == attacker then
		return
	end
	addProgress(attacker, "Kills", 1)
	if weaponName == "Sniper" and special then
		addProgress(attacker, "Headshots", 1)
		if distance and distance >= Daily.longShotDistance then
			addProgress(attacker, "LongShots", 1)
		end
	elseif weaponName == "Knife" then
		addProgress(attacker, "KnifeKills", 1)
		if special then
			addProgress(attacker, "Backstabs", 1)
		end
	end

	local streak = (killsThisLife[attacker] or 0) + 1
	killsThisLife[attacker] = streak
	if streak == 5 then
		addProgress(attacker, "Streak5", 1)
	end
end)

Signals.RoundEnded.Event:Connect(function(standings: { Signals.Standing }, completed: boolean)
	if not completed then
		return
	end
	for _, entry in standings do
		if entry.player and entry.player.Parent and entry.kills > 0 then
			addProgress(entry.player, "Matches", 1)
			if entry.rank == 1 then
				addProgress(entry.player, "Wins", 1)
			end
		end
	end
end)
