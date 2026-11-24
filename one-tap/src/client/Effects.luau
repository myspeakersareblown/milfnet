--[[
	Effects: client-only visuals. Nothing here affects gameplay.
	Later: tracer color / kill effect come from the player's equipped cosmetics.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local TRACER_COLOR = Color3.fromRGB(255, 236, 170)
local TRACER_FADE = TweenInfo.new(0.25)

local Effects = {}

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
	beam.Color = color or TRACER_COLOR
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

return Effects
