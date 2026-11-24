--[[
	Replaces Roblox's default "Health" script (a Script named "Health" in
	StarterCharacterScripts overrides the built-in one, which slowly heals all the time).

	Our rule: no regen until you've gone `regenDelay` seconds without taking damage.
	That gives a 70 body shot a short window to be finished off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Combat"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

if not Combat.regenEnabled then
	return
end

local lastDamaged = 0
local lastHealth = humanoid.Health

humanoid.HealthChanged:Connect(function(health)
	if health < lastHealth then
		lastDamaged = os.clock()
	end
	lastHealth = health
end)

while humanoid.Health > 0 and humanoid.Parent do
	local dt = task.wait(0.1)
	if humanoid.Health < humanoid.MaxHealth and os.clock() - lastDamaged >= Combat.regenDelay then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Combat.regenPerSecond * dt)
	end
end
