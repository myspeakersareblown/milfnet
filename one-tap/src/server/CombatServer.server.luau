--[[
	CombatServer: server-authoritative combat.

	Clients only CLAIM what they hit. This script re-checks every claim and is the
	only thing that ever deals damage. Never move damage math to the client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local Combat = require(Config:WaitForChild("Combat"))
local DamageRules = require(Shared:WaitForChild("DamageRules"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireShot = Remotes:WaitForChild("FireShot") :: RemoteEvent
local Reload = Remotes:WaitForChild("Reload") :: RemoteEvent
local KnifeSwing = Remotes:WaitForChild("KnifeSwing") :: RemoteEvent
local HitConfirm = Remotes:WaitForChild("HitConfirm") :: RemoteEvent
local KillFeed = Remotes:WaitForChild("KillFeed") :: RemoteEvent
local ShotFired = Remotes:WaitForChild("ShotFired") :: UnreliableRemoteEvent

local SNIPER = Weapons.Sniper
local KNIFE = Weapons.Knife
local AIM_DOT = math.cos(math.rad(Combat.maxAimDeviationDegrees))

-- Ammo / cooldowns are tracked here so a modified client can't fire faster
-- or skip reloads.
type WeaponState = {
	ammo: number,
	reloadingUntil: number,
	lastShot: number,
	lastSwing: number,
}
local states: { [Player]: WeaponState } = {}

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function resetState(player: Player)
	states[player] = {
		ammo = SNIPER.magSize,
		reloadingUntil = 0,
		lastShot = -math.huge,
		lastSwing = -math.huge,
	}
end

-- Rejects NaN / infinity / absurd values that exploiters like to send.
local function isSaneVector(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e6
		and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

-- The player's character if they're alive and currently holding `toolName`.
local function getArmedCharacter(player: Player, toolName: string): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= toolName then
		return nil
	end
	return character
end

local function isTeammate(a: Player, b: Player?): boolean
	return b ~= nil and a.Team ~= nil and a.Team == b.Team
end

-- Attacking ends your own spawn protection.
local function dropSpawnProtection(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			child:Destroy()
		end
	end
end

local function bumpStat(player: Player?, statName: string)
	if not player then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	if stat and stat:IsA("IntValue") then
		stat.Value += 1
	end
end

-- How far the claimed hit point may be from the part's position on the server.
-- What the shooter saw is slightly in the past, so moving targets get more slack.
local function hitTolerance(shooter: Player, targetCharacter: Model, hitPart: BasePart): number
	local ping = 0.1
	local ok, result = pcall(function()
		return shooter:GetNetworkPing()
	end)
	if ok and typeof(result) == "number" then
		ping = result
	end
	local lag = math.min(ping * 2 + 0.1, Combat.maxLagCompensation)

	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	local speed = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity.Magnitude else 0
	speed = math.min(speed, 60)

	return hitPart.Size.Magnitude / 2 + Combat.hitTolerance + speed * lag
end

local function charactersForLineOfSight(extra: Model): { Instance }
	local list: { Instance } = { extra }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end

-- `special` = headshot for the sniper, backstab for the knife.
local function applyDamage(attacker: Player, targetHumanoid: Humanoid, damage: number, weaponName: string, special: boolean)
	local targetCharacter = targetHumanoid.Parent
	if not targetCharacter or targetCharacter:FindFirstChildOfClass("ForceField") then
		return -- spawn protected
	end
	if targetHumanoid.Health <= 0 then
		return
	end

	targetHumanoid:TakeDamage(damage)
	local killed = targetHumanoid.Health <= 0
	HitConfirm:FireClient(attacker, weaponName, special, killed)

	if killed then
		local victim = Players:GetPlayerFromCharacter(targetCharacter)
		bumpStat(attacker, "Kills")
		bumpStat(victim, "Deaths")
		local victimName = if victim then victim.DisplayName else targetCharacter.Name
		KillFeed:FireAllClients(attacker.DisplayName, victimName, weaponName, special)
		-- TODO(M3): award Taps + XP through PlayerData here.
	end
end

--------------------------------------------------------------------------------
-- Sniper
--------------------------------------------------------------------------------

FireShot.OnServerEvent:Connect(function(player: Player, origin: any, direction: any, hitPart: any, hitPos: any)
	-- 1. Never trust argument types from the client.
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(hitPos) ~= "Vector3" then
		return
	end
	if not (isSaneVector(origin) and isSaneVector(direction) and isSaneVector(hitPos)) then
		return
	end
	if hitPart ~= nil and (typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart")) then
		return
	end

	local state = states[player]
	local character = getArmedCharacter(player, "Sniper")
	if not state or not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	-- 2. Fire rate, ammo and reload are the server's, not the client's.
	local now = os.clock()
	if now - state.lastShot < SNIPER.fireCooldown - Combat.timingGrace then
		return
	end
	if now < state.reloadingUntil or state.ammo <= 0 then
		return
	end
	state.lastShot = now
	state.ammo -= 1
	dropSpawnProtection(character)

	-- 3. The shot has to come from (roughly) the shooter's head.
	if (origin - head.Position).Magnitude > Combat.maxOriginOffset then
		return
	end
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit

	-- Everyone else sees a tracer (cosmetic, so it goes over an unreliable remote).
	local toHit = hitPos - origin
	local distance = toHit.Magnitude
	local tracerEnd = if distance <= SNIPER.range then hitPos else origin + direction * SNIPER.range
	ShotFired:FireAllClients(player, origin, tracerEnd)

	if hitPart == nil then
		return -- a miss
	end

	-- 4. They must have hit a living enemy.
	if not hitPart:IsDescendantOf(workspace) then
		return
	end
	local targetCharacter = DamageRules.getCharacterFromPart(hitPart)
	if not targetCharacter or targetCharacter == character then
		return
	end
	local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if isTeammate(player, Players:GetPlayerFromCharacter(targetCharacter)) then
		return
	end

	-- 5. Geometry: in range, on the aim line, close to where the part really is.
	if distance > SNIPER.range then
		return
	end
	if distance > 1 and direction:Dot(toHit.Unit) < AIM_DOT then
		return
	end
	if (hitPos - hitPart.Position).Magnitude > hitTolerance(player, targetCharacter, hitPart) then
		return
	end

	-- 6. No shooting through walls: nothing solid between gun and hit point.
	if distance > 1 then
		losParams.FilterDescendantsInstances = charactersForLineOfSight(targetCharacter)
		if workspace:Raycast(origin, toHit.Unit * (distance - 0.5), losParams) then
			return
		end
	end

	-- 7. Passed. The server decides the damage.
	local damage, headshot = DamageRules.sniperDamage(hitPart)
	applyDamage(player, targetHumanoid, damage, "Sniper", headshot)
end)

Reload.OnServerEvent:Connect(function(player: Player)
	local state = states[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not state or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < state.reloadingUntil or state.ammo >= SNIPER.magSize then
		return
	end
	-- Mag is refilled now, but firing stays blocked until the reload finishes.
	state.reloadingUntil = now + SNIPER.reloadTime - Combat.timingGrace
	state.ammo = SNIPER.magSize
end)

--------------------------------------------------------------------------------
-- Knife
--------------------------------------------------------------------------------

KnifeSwing.OnServerEvent:Connect(function(player: Player, target: any)
	local state = states[player]
	local character = getArmedCharacter(player, "Knife")
	if not state or not character then
		return
	end

	local now = os.clock()
	if now - state.lastSwing < KNIFE.cooldown - Combat.timingGrace then
		return
	end
	state.lastSwing = now
	dropSpawnProtection(character)

	if typeof(target) ~= "Instance" or not target:IsA("Model") or target == character then
		return -- a swing at the air
	end
	if not target:IsDescendantOf(workspace) then
		return
	end
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end
	if isTeammate(player, Players:GetPlayerFromCharacter(target)) then
		return
	end

	local myRoot = character:FindFirstChild("HumanoidRootPart")
	local theirRoot = target:FindFirstChild("HumanoidRootPart")
	if not (myRoot and myRoot:IsA("BasePart") and theirRoot and theirRoot:IsA("BasePart")) then
		return
	end

	local offset = theirRoot.Position - myRoot.Position
	if offset.Magnitude > KNIFE.range + Combat.meleeRangeTolerance then
		return
	end

	local backstab = false
	local toTarget = flat(offset)
	if toTarget then
		-- Attacker has to be (roughly) facing the target.
		local myLook = flat(myRoot.CFrame.LookVector)
		if myLook and myLook:Dot(toTarget) < KNIFE.minFacingDot then
			return
		end
		-- Backstab: the target is facing the same way we're stabbing, i.e. away from us.
		local theirLook = flat(theirRoot.CFrame.LookVector)
		backstab = theirLook ~= nil and theirLook:Dot(toTarget) > KNIFE.backstabDot
	end

	applyDamage(player, targetHumanoid, DamageRules.knifeDamage(backstab), "Knife", backstab)
end)

--------------------------------------------------------------------------------
-- Player lifecycle
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	resetState(player)
	player.CharacterAdded:Connect(function()
		resetState(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
