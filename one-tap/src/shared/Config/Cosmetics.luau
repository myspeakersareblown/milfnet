--[[
	Cosmetics catalog: every skin/effect, its rarity, and every crate.
	Pure data, so the shop UI and the server read the same source of truth.
	Cosmetics NEVER change stats. That's the game's promise.

	After editing, run CrateRoller.validate() (see CrateRoller.luau).

	Item fields:
	  name, kind, rarity          always
	  color, material             SniperSkin / KnifeSkin: applied to the weapon (placeholder
	                              look until real models exist; add `model = "Name"` later)
	  color | rainbow             Tracer
	  effect                      KillEffect: "Confetti" | "Lightning" | "Crown"
	  vipOnly = true              owned automatically by VIP pass holders, never in crates
	  exclusive = "StarterPack"   only from that product, never in crates
]]

local Cosmetics = {}

Cosmetics.Kinds = { "SniperSkin", "KnifeSkin", "Tracer", "KillEffect" }
Cosmetics.KindNames = {
	SniperSkin = "Sniper Skins",
	KnifeSkin = "Knife Skins",
	Tracer = "Tracers",
	KillEffect = "Kill Effects",
}

-- Lowest to highest. Rolls iterate in this order, so keep it stable.
Cosmetics.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Cosmetics.Rarities = {
	Common = { rank = 1, color = Color3.fromRGB(176, 195, 217) },
	Rare = { rank = 2, color = Color3.fromRGB(75, 105, 255) },
	Epic = { rank = 3, color = Color3.fromRGB(136, 71, 255) },
	Legendary = { rank = 4, color = Color3.fromRGB(255, 170, 40) },
	Mythic = { rank = 5, color = Color3.fromRGB(235, 75, 75) },
}

local M = Enum.Material

Cosmetics.Items = {
	-- Common
	sniper_desert = { name = "Desert Dust", kind = "SniperSkin", rarity = "Common", color = Color3.fromRGB(205, 175, 120), material = M.Sand },
	sniper_forest = { name = "Forest Camo", kind = "SniperSkin", rarity = "Common", color = Color3.fromRGB(75, 105, 60), material = M.Grass },
	knife_rust = { name = "Rust", kind = "KnifeSkin", rarity = "Common", color = Color3.fromRGB(140, 80, 50), material = M.CorrodedMetal },
	tracer_red = { name = "Red Tracer", kind = "Tracer", rarity = "Common", color = Color3.fromRGB(255, 60, 60) },
	tracer_blue = { name = "Blue Tracer", kind = "Tracer", rarity = "Common", color = Color3.fromRGB(70, 140, 255) },

	-- Rare
	sniper_arctic = { name = "Arctic", kind = "SniperSkin", rarity = "Rare", color = Color3.fromRGB(215, 235, 250), material = M.Ice },
	sniper_carbon = { name = "Carbon", kind = "SniperSkin", rarity = "Rare", color = Color3.fromRGB(35, 35, 40), material = M.Slate },
	knife_tiger = { name = "Tiger Stripe", kind = "KnifeSkin", rarity = "Rare", color = Color3.fromRGB(240, 140, 30), material = M.Fabric },
	kill_confetti = { name = "Confetti", kind = "KillEffect", rarity = "Rare", effect = "Confetti" },

	-- Epic
	sniper_neon = { name = "Neon Grid", kind = "SniperSkin", rarity = "Epic", color = Color3.fromRGB(0, 255, 200), material = M.Neon },
	knife_neon = { name = "Neon Edge", kind = "KnifeSkin", rarity = "Epic", color = Color3.fromRGB(255, 40, 200), material = M.Neon },
	tracer_rainbow = { name = "Rainbow Tracer", kind = "Tracer", rarity = "Epic", rainbow = true },

	-- Legendary
	sniper_gold = { name = "Gold Tap", kind = "SniperSkin", rarity = "Legendary", color = Color3.fromRGB(255, 200, 60), material = M.Foil },
	knife_gold = { name = "Gold Edge", kind = "KnifeSkin", rarity = "Legendary", color = Color3.fromRGB(255, 200, 60), material = M.Foil },
	kill_lightning = { name = "Lightning Strike", kind = "KillEffect", rarity = "Legendary", effect = "Lightning" },

	-- Mythic
	sniper_void = { name = "Void", kind = "SniperSkin", rarity = "Mythic", color = Color3.fromRGB(120, 40, 255), material = M.ForceField },
	knife_void = { name = "Void Edge", kind = "KnifeSkin", rarity = "Mythic", color = Color3.fromRGB(120, 40, 255), material = M.ForceField },

	-- VIP pass (owned while you have VIP, never in crates)
	sniper_vip = { name = "VIP Royale", kind = "SniperSkin", rarity = "Legendary", color = Color3.fromRGB(30, 30, 35), material = M.DiamondPlate, vipOnly = true },
	tracer_vip = { name = "VIP Gold Tracer", kind = "Tracer", rarity = "Legendary", color = Color3.fromRGB(255, 200, 60), vipOnly = true },
	kill_crown = { name = "VIP Crown", kind = "KillEffect", rarity = "Legendary", effect = "Crown", vipOnly = true },

	-- Starter Pack exclusive
	sniper_recruit = { name = "Recruit", kind = "SniperSkin", rarity = "Epic", color = Color3.fromRGB(230, 90, 60), material = M.Metal, exclusive = "StarterPack" },
}

--[[
	Crates. `odds` are relative weights per rarity (these happen to sum to 100).
	Inside a rarity every listed item is equally likely.

	currency = "Taps": earned by playing only. Taps must never be sold for Robux.
	currency = "Gems": bought with Robux, so this is a PAID RANDOM ITEM:
	  - show odds before purchase (CrateRoller.getOdds)
	  - hide it for players where PolicyService says paid random items are restricted
]]
Cosmetics.Crates = {
	StandardCrate = {
		name = "Standard Crate",
		currency = "Taps",
		price = 750,
		order = 1,
		odds = { Common = 70, Rare = 22, Epic = 7, Legendary = 1 },
		items = {
			"sniper_desert",
			"sniper_forest",
			"knife_rust",
			"tracer_red",
			"tracer_blue",
			"sniper_arctic",
			"knife_tiger",
			"tracer_rainbow",
			"kill_lightning",
		},
	},

	Season1Crate = {
		name = "Season 1 Crate",
		currency = "Gems",
		price = 100,
		order = 2,
		odds = { Common = 50, Rare = 30, Epic = 14, Legendary = 5, Mythic = 1 },
		-- Guaranteed Legendary-or-better at least once every 40 opens.
		pity = { rarity = "Legendary", within = 40 },
		items = {
			"sniper_desert",
			"sniper_forest",
			"knife_rust",
			"tracer_red",
			"tracer_blue",
			"sniper_arctic",
			"sniper_carbon",
			"knife_tiger",
			"kill_confetti",
			"sniper_neon",
			"knife_neon",
			"tracer_rainbow",
			"sniper_gold",
			"knife_gold",
			"kill_lightning",
			"sniper_void",
			"knife_void",
		},
	},
}

-- Duplicates turn into Scrap; Scrap crafts any skin you choose.
Cosmetics.ScrapValue = { Common = 5, Rare = 15, Epic = 50, Legendary = 200, Mythic = 600 }
Cosmetics.CraftCost = { Common = 25, Rare = 75, Epic = 250, Legendary = 1000, Mythic = 3000 }

-- Daily featured shop (direct buy with Gems): how many items, and price per rarity.
Cosmetics.Featured = {
	count = 4,
	prices = { Rare = 150, Epic = 400, Legendary = 1200, Mythic = 3000 },
}

-- Items that can be crafted or featured (not VIP-only / exclusive).
function Cosmetics.isObtainable(itemId: string): boolean
	local item = Cosmetics.Items[itemId]
	return item ~= nil and not item.vipOnly and item.exclusive == nil
end

return Cosmetics
