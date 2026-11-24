--[[
	Ownership: who owns which cosmetic. VIP-only items are owned while the
	player has the VIP pass (player attribute "VIP", set by ShopServer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cosmetics"))

local Ownership = {}

function Ownership.owns(player: Player, profile: any, itemId: string): boolean
	local item = Cosmetics.Items[itemId]
	if not item then
		return false
	end
	if item.vipOnly then
		return player:GetAttribute("VIP") == true
	end
	return profile.Data.Inventory[itemId] == true
end

-- Gives an item. Returns false if they already had it (a duplicate).
function Ownership.give(profile: any, itemId: string): boolean
	if profile.Data.Inventory[itemId] then
		return false
	end
	profile.Data.Inventory[itemId] = true
	return true
end

return Ownership
