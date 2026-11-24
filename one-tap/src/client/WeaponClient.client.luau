--[[
	WeaponClient: input and feel for the sniper and knife.

	Everything here is prediction for responsiveness. The server re-checks every
	shot and swing (CombatServer) and is the only thing that deals damage.

	PC:      LMB fire/slash, hold RMB scope, R reload, 1/2 swap
	Mobile:  tap to fire, Scope button (toggle), Reload button
	Console: R2 fire, hold L2 scope, X reload
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Weapons = require(Config:WaitForChild("Weapons"))
local Combat = require(Config:WaitForChild("Combat"))
local DamageRules = require(Shared:WaitForChild("DamageRules"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireShot = Remotes:WaitForChild("FireShot") :: RemoteEvent
local Reload = Remotes:WaitForChild("Reload") :: RemoteEvent
local KnifeSwing = Remotes:WaitForChild("KnifeSwing") :: RemoteEvent

local SNIPER = Weapons.Sniper
local KNIFE = Weapons.Knife
local ACTION_SCOPE = "OneTapScope"
local ACTION_RELOAD = "OneTapReload"
local SCOPE_OVERLAY_AT = 0.85 -- scope progress at which the lens overlay appears

local defaultFOV = workspace.CurrentCamera.FieldOfView
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local character: Model? = nil
local humanoid: Humanoid? = nil
local equipped: Tool? = nil
local activatedConnection: RBXScriptConnection? = nil

local ammo = SNIPER.magSize
local reloading = false
local reloadToken = 0
local lastShot = -math.huge
local lastSwing = -math.huge

local scoped = false -- currently scoped (or scoping in)
local scopeHeld = false -- the player is holding (or has toggled on) scope
local scopeProgress = 0 -- 0 = hip, 1 = fully scoped

--------------------------------------------------------------------------------
-- State helpers
--------------------------------------------------------------------------------

local function holding(toolName: string): boolean
	return equipped ~= nil and equipped.Name == toolName
end

local function isAlive(): boolean
	return character ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function updateWalkSpeed()
	if not humanoid then
		return
	end
	if holding("Knife") then
		humanoid.WalkSpeed = KNIFE.walkSpeed
	elseif scoped then
		humanoid.WalkSpeed = SNIPER.scopedWalkSpeed
	else
		humanoid.WalkSpeed = Combat.baseWalkSpeed
	end
end

local function applyScopeVisuals()
	local alpha = 1 - (1 - scopeProgress) ^ 2 -- ease out
	workspace.CurrentCamera.FieldOfView = defaultFOV + (SNIPER.scopedFOV - defaultFOV) * alpha
	UserInputService.MouseDeltaSensitivity = 1 + (SNIPER.scopedSensitivity - 1) * alpha

	local inScope = scopeProgress >= SCOPE_OVERLAY_AT
	Hud.setScopeOverlay(inScope)
	Hud.setCrosshairVisible(equipped ~= nil and not inScope)
end

local function setScoped(on: boolean)
	if on then
		local boltCycling = os.clock() - lastShot < SNIPER.fireCooldown
		if not holding("Sniper") or reloading or boltCycling or not isAlive() then
			return
		end
	end
	if scoped == on then
		return
	end
	scoped = on
	if not on then
		-- Dropping the scope is instant; scoping in ramps up in RenderStepped.
		scopeProgress = 0
		applyScopeVisuals()
	end
	updateWalkSpeed()
end

RunService.RenderStepped:Connect(function(dt)
	if scoped and scopeProgress < 1 then
		scopeProgress = math.min(1, scopeProgress + dt / SNIPER.scopeInTime)
		applyScopeVisuals()
	end
end)

--------------------------------------------------------------------------------
-- Sniper
--------------------------------------------------------------------------------

local function currentSpread(): number
	-- Spread shrinks as the scope comes up: that's the quickscope window.
	local spread = SNIPER.hipSpread + (SNIPER.scopedSpread - SNIPER.hipSpread) * scopeProgress
	if humanoid then
		if humanoid.MoveDirection.Magnitude > 0.1 then
			spread += SNIPER.moveSpread
		end
		if humanoid.FloorMaterial == Enum.Material.Air then
			spread += SNIPER.airSpread
		end
	end
	return spread
end

-- A random direction inside a cone of `degrees` around where the camera aims.
local function spreadDirection(aim: CFrame, degrees: number): Vector3
	if degrees <= 0 then
		return aim.LookVector
	end
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber()) -- sqrt => even spread over the cone
	local roll = rng:NextNumber() * math.pi * 2
	return (aim.Rotation * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function reload()
	if reloading or ammo >= SNIPER.magSize or not holding("Sniper") then
		return
	end
	reloading = true
	reloadToken += 1
	local token = reloadToken
	setScoped(false)
	Reload:FireServer()
	Hud.setAmmo(ammo, SNIPER.magSize, true)

	task.delay(SNIPER.reloadTime, function()
		if token ~= reloadToken then
			return -- died / respawned mid-reload
		end
		reloading = false
		ammo = SNIPER.magSize
		Hud.setAmmo(ammo, SNIPER.magSize, false)
		if scopeHeld then
			setScoped(true)
		end
	end)
end

local function fireSniper()
	if not isAlive() then
		return
	end
	local now = os.clock()
	if reloading or ammo <= 0 or now - lastShot < SNIPER.fireCooldown then
		return
	end
	lastShot = now
	ammo -= 1
	Hud.setAmmo(ammo, SNIPER.magSize, false)

	local aim = workspace.CurrentCamera.CFrame
	local origin = aim.Position
	local direction = spreadDirection(aim, currentSpread())

	rayParams.FilterDescendantsInstances = { character :: Model }
	local result = workspace:Raycast(origin, direction * SNIPER.range, rayParams)
	local hitPart = if result then result.Instance else nil
	local hitPos = if result then result.Position else origin + direction * SNIPER.range

	FireShot:FireServer(origin, direction, hitPart, hitPos)

	-- Tracer starts a little below/right of the eye so it reads like it left the barrel.
	Effects.tracer((aim * CFrame.new(0.35, -0.45, -1.5)).Position, hitPos, Effects.tracerColorFor(player))
	Effects.recoil(SNIPER.recoilKick)

	if SNIPER.unscopeOnShot and scoped then
		setScoped(false)
		task.delay(SNIPER.fireCooldown + 0.02, function()
			if scopeHeld then
				setScoped(true) -- rescope after the bolt cycles if still holding
			end
		end)
	end

	if ammo <= 0 then
		reload()
	end
end

--------------------------------------------------------------------------------
-- Knife
--------------------------------------------------------------------------------

local function swingKnife()
	if not isAlive() then
		return
	end
	local now = os.clock()
	if now - lastSwing < KNIFE.cooldown then
		return
	end
	lastSwing = now

	local aim = workspace.CurrentCamera.CFrame
	rayParams.FilterDescendantsInstances = { character :: Model }
	local result = workspace:Spherecast(aim.Position, KNIFE.hitRadius, aim.LookVector * KNIFE.range, rayParams)

	local target = nil
	if result then
		local model = DamageRules.getCharacterFromPart(result.Instance)
		if model and model ~= character then
			target = model
		end
	end
	-- Server decides slash vs backstab and whether it was in reach at all.
	KnifeSwing:FireServer(target)
end

--------------------------------------------------------------------------------
-- Input actions (bound only while the sniper is out)
--------------------------------------------------------------------------------

local function onScopeAction(_: string, state: Enum.UserInputState, input: InputObject)
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	if state == Enum.UserInputState.Begin then
		-- Touch toggles (holding a button while aiming is awkward); mouse/gamepad hold.
		scopeHeld = if isTouch then not scopeHeld else true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if isTouch then
			return Enum.ContextActionResult.Sink
		end
		scopeHeld = false
	else
		return Enum.ContextActionResult.Sink -- ignore analog "Change" on triggers
	end
	setScoped(scopeHeld)
	return Enum.ContextActionResult.Sink
end

local function onReloadAction(_: string, state: Enum.UserInputState, _input: InputObject)
	if state == Enum.UserInputState.Begin then
		reload()
	end
	return Enum.ContextActionResult.Sink
end

--------------------------------------------------------------------------------
-- Equip / unequip
--------------------------------------------------------------------------------

local function onUnequipped(tool: Tool)
	if tool ~= equipped then
		return
	end
	if activatedConnection then
		activatedConnection:Disconnect()
		activatedConnection = nil
	end
	ContextActionService:UnbindAction(ACTION_SCOPE)
	ContextActionService:UnbindAction(ACTION_RELOAD)

	scopeHeld = false
	setScoped(false)
	equipped = nil
	scopeProgress = 0
	applyScopeVisuals()

	Hud.setAmmoVisible(false)
	UserInputService.MouseIconEnabled = true
	updateWalkSpeed()
end

local function onEquipped(tool: Tool)
	if tool.Name ~= "Sniper" and tool.Name ~= "Knife" then
		return
	end
	if equipped then
		onUnequipped(equipped) -- swap events can arrive in either order
	end
	equipped = tool

	if tool.Name == "Sniper" then
		activatedConnection = tool.Activated:Connect(fireSniper)
		ContextActionService:BindActionAtPriority(
			ACTION_SCOPE,
			onScopeAction,
			true, -- creates a touch button on mobile
			Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton2,
			Enum.KeyCode.ButtonL2
		)
		ContextActionService:SetTitle(ACTION_SCOPE, "Scope")
		ContextActionService:BindAction(ACTION_RELOAD, onReloadAction, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(ACTION_RELOAD, "Reload")

		Hud.setAmmo(ammo, SNIPER.magSize, reloading)
		Hud.setAmmoVisible(true)
		if ammo <= 0 then
			reload()
		end
	else
		activatedConnection = tool.Activated:Connect(swingKnife)
		Hud.setAmmoVisible(false)
	end

	UserInputService.MouseIconEnabled = false -- our crosshair replaces the cursor
	applyScopeVisuals()
	updateWalkSpeed()
end

--------------------------------------------------------------------------------
-- Character lifecycle
--------------------------------------------------------------------------------

local function onCharacterAdded(newCharacter: Model)
	if equipped then
		onUnequipped(equipped)
	end

	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	character = newCharacter
	humanoid = newHumanoid

	ammo = SNIPER.magSize
	reloading = false
	reloadToken += 1 -- cancels any reload from the previous life
	lastShot = -math.huge
	lastSwing = -math.huge
	scoped = false
	scopeHeld = false
	scopeProgress = 0
	applyScopeVisuals()
	Hud.setAmmo(ammo, SNIPER.magSize, false)
	Hud.setAmmoVisible(false)

	newCharacter.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			onEquipped(child)
		end
	end)
	newCharacter.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			onUnequipped(child)
		end
	end)
	newHumanoid.Died:Connect(function()
		if equipped then
			onUnequipped(equipped)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
