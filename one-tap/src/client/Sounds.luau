--[[
	Sounds: plays the sounds listed in Config/Sounds (empty ids are skipped).
	  Sounds.play("HeadshotDing")             -- 2D, just for you
	  Sounds.playAt("SniperShot", position)   -- 3D, in the world
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local Sounds = {}

local folder = Instance.new("Folder")
folder.Name = "OneTapSounds"
folder.Parent = SoundService

local templates: { [string]: Sound } = {}

local function template(name: string): Sound?
	local definition = SoundConfig[name]
	if not definition or definition.id == "" then
		return nil
	end
	local sound = templates[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = definition.id
		sound.Volume = definition.volume or 0.5
		sound.Parent = folder
		templates[name] = sound
	end
	return sound
end

function Sounds.play(name: string, pitch: number?)
	local base = template(name)
	if not base then
		return
	end
	local sound = base:Clone()
	sound.Volume = base.Volume * Settings.get("SfxVolume")
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, 6)
end

function Sounds.playAt(name: string, position: Vector3, maxDistance: number?)
	local base = template(name)
	if not base then
		return
	end
	local emitter = Instance.new("Part")
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Position = position
	emitter.Parent = workspace

	local sound = base:Clone()
	sound.Volume = base.Volume * Settings.get("SfxVolume")
	sound.RollOffMaxDistance = maxDistance or 600
	sound.Parent = emitter
	sound:Play()
	Debris:AddItem(emitter, 6)
end

return Sounds
