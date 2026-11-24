--[[
	Effects: client-only visuals. Nothing here affects gameplay.
	Tracer colors and kill effects come from the shooter's equipped cosmetics
	(Player attributes "Tracer" / "KillEffect", set by CosmeticsServer).
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cosmetics"))

local DEFAULT_TRACER = Color3.fromRGB(255, 236, 170)
local TRACER_FADE = TweenInfo.new(0.25)

local Effects = {}

local function equippedItem(player: Player?, kind: string): any
	if not player then
		return nil
	end
	local itemId = player:GetAttribute(kind)
	if typeof(itemId) ~= "string" or itemId == "" then
		return nil
	end
	return Cosmetics.Items[itemId]
end

-- The color this player's tracers should be (rainbow picks a random hue per shot).
function Effects.tracerColorFor(player: Player?): Color3
	local item = equippedItem(player, "Tracer")
	if item and item.rainbow then
		return Color3.fromHSV(math.random(), 0.85, 1)
	end
	return if item and item.color then item.color else DEFAULT_TRACER
end

function Effects.tracer(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end

	local beam = Instance.new("Part")
	beam.Name = "Tracer"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false -- bullets must never hit tracers
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color or DEFAULT_TRACER
	beam.Size = Vector3.new(0.06, 0.06, length)
	beam.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	beam.Parent = workspace

	TweenService:Create(beam, TRACER_FADE, { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.3)
end

-- Kicks the camera up by `degrees`.
function Effects.recoil(degrees: number)
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(math.rad(degrees), 0, 0)
end

--------------------------------------------------------------------------------
-- Kill effects
--------------------------------------------------------------------------------

local function anchorPoint(position: Vector3, lifetime: number): Part
	local point = Instance.new("Part")
	point.Name = "KillEffect"
	point.Anchored = true
	point.CanCollide = false
	point.CanQuery = false
	point.CanTouch = false
	point.Transparency = 1
	point.Size = Vector3.new(1, 1, 1)
	point.Position = position
	point.Parent = workspace
	Debris:AddItem(point, lifetime)
	return point
end

local function burst(position: Vector3, colors: ColorSequence, count: number, speed: number, lifetime: number)
	local point = anchorPoint(position, lifetime + 0.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = colors
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -workspace.Gravity * 0.15, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.Size = NumberSequence.new(0.35)
	emitter.LightEmission = 0.3
	emitter.Parent = point
	emitter:Emit(count)
end

local function confetti(position: Vector3)
	burst(
		position + Vector3.new(0, 1, 0),
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
		}),
		70,
		25,
		1.6
	)
end

local function crown(position: Vector3)
	burst(position + Vector3.new(0, 3, 0), ColorSequence.new(Color3.fromRGB(255, 205, 60)), 45, 12, 1.4)
end

-- A jagged neon bolt from the sky plus a flash of light.
local function lightning(position: Vector3)
	local top = position + Vector3.new(0, 60, 0)
	local segments = 8
	local previous = top
	local parts = {}
	for i = 1, segments do
		local t = i / segments
		local jitter = if i == segments then Vector3.zero else Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		local nextPoint = top:Lerp(position, t) + jitter
		local length = (nextPoint - previous).Magnitude
		local bolt = Instance.new("Part")
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.CastShadow = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(170, 210, 255)
		bolt.Size = Vector3.new(0.4, 0.4, length)
		bolt.CFrame = CFrame.lookAt(previous:Lerp(nextPoint, 0.5), nextPoint)
		bolt.Parent = workspace
		table.insert(parts, bolt)
		previous = nextPoint
	end

	local flash = anchorPoint(position + Vector3.new(0, 2, 0), 0.6)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 210, 255)
	light.Range = 30
	light.Brightness = 8
	light.Parent = flash
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()

	for _, bolt in parts do
		TweenService:Create(bolt, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		Debris:AddItem(bolt, 0.45)
	end
end

local KILL_EFFECTS: { [string]: (Vector3) -> () } = {
	Confetti = confetti,
	Lightning = lightning,
	Crown = crown,
}

-- Plays the killer's equipped kill effect (if any) where the victim died.
function Effects.killEffectFor(killer: Player?, position: Vector3)
	local item = equippedItem(killer, "KillEffect")
	local play = item and KILL_EFFECTS[item.effect]
	if play then
		play(position)
	end
end

-- For previews in the locker.
function Effects.playKillEffect(effectName: string, position: Vector3)
	local play = KILL_EFFECTS[effectName]
	if play then
		play(position)
	end
end

return Effects
