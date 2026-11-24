--[[
	DamageRules: the one place that decides how much a hit does.
	Only the server's result is ever applied.
]]

local Weapons = require(script.Parent:WaitForChild("Config"):WaitForChild("Weapons"))

local DamageRules = {}

-- Only the Head part counts. Accessories (hats, hair) are made unhittable on
-- spawn (see PlayerSetup), so they can't steal or fake headshots.
function DamageRules.isHeadshot(hitPart: BasePart): boolean
	return hitPart.Name == "Head"
end

-- Returns damage, isHeadshot.
function DamageRules.sniperDamage(hitPart: BasePart): (number, boolean)
	local stats = Weapons.Sniper
	if DamageRules.isHeadshot(hitPart) then
		return stats.headDamage, true
	end
	return stats.bodyDamage, false
end

function DamageRules.knifeDamage(isBackstab: boolean): number
	local stats = Weapons.Knife
	return if isBackstab then stats.backstabDamage else stats.slashDamage
end

-- Walks up from a hit part to the character Model that owns it (first ancestor
-- Model with a Humanoid). Returns nil for map geometry.
function DamageRules.getCharacterFromPart(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

return DamageRules
