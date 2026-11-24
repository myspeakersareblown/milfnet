--[[
	MatchServer: the round loop.

	  Waiting      -> not enough players; free-for-all warmup on the current map
	  Intermission -> countdown + map vote (warmup continues)
	  Playing      -> FFA: first to Match.killTarget, or most kills when time runs out
	  Results      -> scores shown, damage off, rewards handed out (Signals.RoundEnded)

	Clients read the state from attributes on ReplicatedStorage.MatchState:
	  Phase, PhaseEndsAt (workspace:GetServerTimeNow() time), Map, Mode,
	  KillTarget, LeaderName, LeaderKills, PlayersNeeded
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local MatchConfig = require(Config:WaitForChild("Match"))

local Modules = script.Parent:WaitForChild("Modules")
local Signals = require(Modules:WaitForChild("Signals"))
local MapBuilder = require(Modules:WaitForChild("MapBuilder"))

local MatchState = ReplicatedStorage:WaitForChild("MatchState") :: Configuration
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MapVote = Remotes:WaitForChild("MapVote") :: RemoteEvent
local MatchResults = Remotes:WaitForChild("MatchResults") :: RemoteEvent

local rng = Random.new()

--------------------------------------------------------------------------------
-- Maps
--------------------------------------------------------------------------------

local mapsFolder = ServerStorage:FindFirstChild("Maps")
local function countMaps(folder: Instance?): number
	if not folder then
		return 0
	end
	local n = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			n += 1
		end
	end
	return n
end
if countMaps(mapsFolder) == 0 then
	if mapsFolder then
		mapsFolder:Destroy()
	end
	mapsFolder = MapBuilder.buildDefaults(ServerStorage)
	print("[1 Tap] No maps in ServerStorage.Maps, so using the generated greybox maps.")
end

local currentMap: Model? = nil
local currentMapName = ""

local function mapNames(): { string }
	local names = {}
	for _, child in (mapsFolder :: Folder):GetChildren() do
		if child:IsA("Model") then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

local function displayName(mapName: string): string
	local template = (mapsFolder :: Folder):FindFirstChild(mapName)
	local name = template and template:GetAttribute("DisplayName")
	return if typeof(name) == "string" then name else mapName
end

local function loadMap(mapName: string)
	local template = (mapsFolder :: Folder):FindFirstChild(mapName)
	if not template then
		warn(`[1 Tap] Map "{mapName}" not found`)
		return
	end
	if currentMap then
		currentMap:Destroy()
	end
	local map = template:Clone()
	map.Name = "Map"
	map:SetAttribute("MapName", mapName)
	map.Parent = workspace
	currentMap = map
	currentMapName = mapName
	MatchState:SetAttribute("Map", displayName(mapName))
end

--------------------------------------------------------------------------------
-- Spawning: put players as far from enemies as possible
--------------------------------------------------------------------------------

local function spawnPoints(): { BasePart }
	local points = {}
	local folder = currentMap and currentMap:FindFirstChild("Spawns")
	if folder then
		for _, child in folder:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(points, child)
			end
		end
	end
	return points
end

local function enemyPositions(player: Player): { Vector3 }
	local positions = {}
	for _, other in Players:GetPlayers() do
		local isTeammate = player.Team ~= nil and other.Team == player.Team
		if other ~= player and not isTeammate and other.Character then
			local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
			local root = other.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(positions, root.Position)
			end
		end
	end
	return positions
end

-- Spawns handed out in the last few seconds count as "occupied", so a whole
-- lobby respawning at round start gets spread across the map.
local recentSpawns: { { position: Vector3, at: number } } = {}
local RECENT_SPAWN_SECONDS = 3

local function pickSpawn(player: Player): CFrame?
	local points = spawnPoints()
	if #points == 0 then
		return nil
	end
	local enemies = enemyPositions(player)

	local now = os.clock()
	for i = #recentSpawns, 1, -1 do
		if now - recentSpawns[i].at > RECENT_SPAWN_SECONDS then
			table.remove(recentSpawns, i)
		else
			table.insert(enemies, recentSpawns[i].position)
		end
	end

	for i = #points, 2, -1 do -- shuffle so ties break randomly
		local j = rng:NextInteger(1, i)
		points[i], points[j] = points[j], points[i]
	end

	local scored = {}
	for _, point in points do
		local nearest = math.huge
		for _, position in enemies do
			nearest = math.min(nearest, (position - point.Position).Magnitude)
		end
		table.insert(scored, { point = point, score = nearest })
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)

	-- Random pick among the 3 safest so spawns aren't predictable.
	local choice = scored[rng:NextInteger(1, math.min(3, #scored))].point
	table.insert(recentSpawns, { position = choice.Position, at = now })
	return choice.CFrame + Vector3.new(0, 3, 0)
end

local function placeCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- let Roblox finish its own spawn positioning first
	if character.Parent == nil then
		return
	end
	local cframe = pickSpawn(player)
	if cframe then
		character:PivotTo(cframe)
	end
end

--------------------------------------------------------------------------------
-- Phases & scoring
--------------------------------------------------------------------------------

local phase = "Waiting"
local roundDecided = false

local function setPhase(name: string, duration: number?)
	phase = name
	MatchState:SetAttribute("Phase", name)
	MatchState:SetAttribute("PhaseEndsAt", if duration then workspace:GetServerTimeNow() + duration else 0)
end

local function stat(player: Player, statName: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(statName)
	return if value and value:IsA("IntValue") then value else nil
end

local function standings(): { Signals.Standing }
	local list: { Signals.Standing } = {}
	for _, player in Players:GetPlayers() do
		local kills = stat(player, "Kills")
		local deaths = stat(player, "Deaths")
		table.insert(list, {
			player = player,
			name = player.DisplayName,
			kills = if kills then kills.Value else 0,
			deaths = if deaths then deaths.Value else 0,
			rank = 0,
		})
	end
	table.sort(list, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.deaths < b.deaths
	end)
	for i, entry in list do
		entry.rank = i
	end
	return list
end

local function updateLeader()
	local top = standings()[1]
	MatchState:SetAttribute("LeaderName", if top and top.kills > 0 then top.name else "")
	MatchState:SetAttribute("LeaderKills", if top then top.kills else 0)
end

local function resetScores()
	for _, player in Players:GetPlayers() do
		for _, statName in { "Kills", "Deaths" } do
			local value = stat(player, statName)
			if value then
				value.Value = 0
			end
		end
	end
	updateLeader()
end

Signals.Kill.Event:Connect(function(attacker: Player, victim: Player?, _weaponName: string, _special: boolean)
	if phase == "Results" then
		return
	end
	local kills = attacker.Parent and stat(attacker, "Kills")
	if kills then
		kills.Value += 1
	end
	local deaths = victim and stat(victim, "Deaths")
	if deaths then
		deaths.Value += 1
	end

	updateLeader()
	if phase == "Playing" and kills and kills.Value >= MatchConfig.killTarget then
		roundDecided = true
	end
end)

local function enoughPlayers(): boolean
	local count = #Players:GetPlayers()
	MatchState:SetAttribute("PlayersNeeded", math.max(0, MatchConfig.minPlayers - count))
	return count >= MatchConfig.minPlayers
end

--------------------------------------------------------------------------------
-- Map vote
--------------------------------------------------------------------------------

type VoteOption = { id: string, name: string }
local voteOptions: { VoteOption } = {}
local votes: { [Player]: string } = {}

local function tallies(): { [string]: number }
	local counts = {}
	for _, option in voteOptions do
		counts[option.id] = 0
	end
	for _, choice in votes do
		if counts[choice] then
			counts[choice] += 1
		end
	end
	return counts
end

local function sendVote(target: Player?)
	if target then
		MapVote:FireClient(target, voteOptions, tallies())
	else
		MapVote:FireAllClients(voteOptions, tallies())
	end
end

local function startVote()
	local names = mapNames()
	-- Don't offer the map we just played if there are enough others.
	if #names > MatchConfig.voteOptions then
		local index = table.find(names, currentMapName)
		if index then
			table.remove(names, index)
		end
	end
	for i = #names, 2, -1 do -- shuffle
		local j = rng:NextInteger(1, i)
		names[i], names[j] = names[j], names[i]
	end

	table.clear(voteOptions)
	table.clear(votes)
	for i = 1, math.min(MatchConfig.voteOptions, #names) do
		table.insert(voteOptions, { id = names[i], name = displayName(names[i]) })
	end
	sendVote()
end

local function finishVote(): string
	local counts = tallies()
	local best, bestCount = {}, -1
	for _, option in voteOptions do
		local count = counts[option.id]
		if count > bestCount then
			best, bestCount = { option.id }, count
		elseif count == bestCount then
			table.insert(best, option.id)
		end
	end
	table.clear(voteOptions)
	table.clear(votes)
	sendVote() -- empty list = vote closed
	if #best == 0 then
		return currentMapName
	end
	return best[rng:NextInteger(1, #best)]
end

MapVote.OnServerEvent:Connect(function(player: Player, choice: any)
	if phase ~= "Intermission" or typeof(choice) ~= "string" then
		return
	end
	for _, option in voteOptions do
		if option.id == choice then
			votes[player] = choice
			sendVote()
			return
		end
	end
end)

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
	if phase == "Intermission" then
		sendVote(player)
	end
	enoughPlayers()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	votes[player] = nil
	task.defer(function()
		enoughPlayers()
		updateLeader()
		if phase == "Intermission" then
			sendVote()
		end
	end)
end)

--------------------------------------------------------------------------------
-- Round loop
--------------------------------------------------------------------------------

MatchState:SetAttribute("Mode", MatchConfig.mode)
MatchState:SetAttribute("KillTarget", MatchConfig.killTarget)
loadMap(mapNames()[1])
setPhase("Waiting")
enoughPlayers()

local function respawnEveryone()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

while true do
	if not enoughPlayers() then
		setPhase("Waiting")
		repeat
			task.wait(1)
		until enoughPlayers()
	end

	-- Intermission + vote
	setPhase("Intermission", MatchConfig.intermissionLength)
	startVote()
	task.wait(MatchConfig.intermissionLength)
	local chosen = finishVote()
	if not enoughPlayers() then
		continue
	end

	-- Round
	loadMap(chosen)
	resetScores()
	roundDecided = false
	setPhase("Playing", MatchConfig.roundLength)
	respawnEveryone()
	Signals.RoundStarted:Fire(chosen)

	local endsAt = os.clock() + MatchConfig.roundLength
	local completed = true
	while os.clock() < endsAt and not roundDecided do
		if not enoughPlayers() then
			completed = false
			break
		end
		task.wait(0.25)
	end

	-- Results
	local final = standings()
	setPhase("Results", MatchConfig.resultsLength)

	local payload = {}
	for i = 1, math.min(8, #final) do
		local entry = final[i]
		table.insert(payload, { name = entry.name, kills = entry.kills, deaths = entry.deaths, rank = entry.rank })
	end
	local winner = final[1]
	MatchResults:FireAllClients({
		map = displayName(chosen),
		completed = completed,
		winner = if winner and winner.kills > 0 then winner.name else nil,
		standings = payload,
	})
	Signals.RoundEnded:Fire(final, completed)

	task.wait(MatchConfig.resultsLength)
end
