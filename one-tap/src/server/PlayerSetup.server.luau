--[[
	PlayerSetup: leaderboard, health, spawn protection, and clean hitboxes.
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Combat"))

Players.RespawnTime = Combat.respawnTime

-- SpawnLocations hand out their own 10 s ForceField by default. We handle spawn
-- protection ourselves, so turn theirs off.
local function fixSpawn(instance: Instance)
	if instance:IsA("SpawnLocation") then
		instance.Duration = 0
	end
end
for _, d in workspace:GetDescendants() do
	fixSpawn(d)
end
workspace.DescendantAdded:Connect(fixSpawn)

-- Hats, hair and other accessories must not eat bullets or count as headshots.
local function makeUnhittable(instance: Instance)
	if instance:IsA("BasePart") and instance:FindFirstAncestorOfClass("Accessory") then
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
	end
end

local function onCharacterAdded(character: Model)
	for _, d in character:GetDescendants() do
		makeUnhittable(d)
	end
	character.DescendantAdded:Connect(makeUnhittable)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Combat.maxHealth
	humanoid.Health = Combat.maxHealth
	humanoid.WalkSpeed = Combat.baseWalkSpeed

	local forceField = Instance.new("ForceField")
	forceField.Parent = character
	Debris:AddItem(forceField, Combat.spawnProtection)
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, statName in { "Kills", "Deaths" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
