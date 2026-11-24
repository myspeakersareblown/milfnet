--[[
	Cosmetics catalog: every skin/effect, its rarity, and every crate.
	Pure data, so the shop UI and the server read the same source of truth.
	Cosmetics NEVER change stats. That's the game's promise.

	After editing, run CrateRoller.validate() (see CrateRoller.luau).
]]

local Cosmetics = {}

-- Lowest to highest. Rolls iterate in this order, so keep it stable.
Cosmetics.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Cosmetics.Rarities = {
	Common = { rank = 1, color = Color3.fromRGB(176, 195, 217) },
	Rare = { rank = 2, color = Color3.fromRGB(75, 105, 255) },
	Epic = { rank = 3, color = Color3.fromRGB(136, 71, 255) },
	Legendary = { rank = 4, color = Color3.fromRGB(255, 170, 40) },
	Mythic = { rank = 5, color = Color3.fromRGB(235, 75, 75) },
}

-- kind: "SniperSkin" | "KnifeSkin" | "Tracer" | "KillEffect"
-- Placeholder names; the actual models/textures get hooked up in milestone M3.
Cosmetics.Items = {
	-- Common
	sniper_desert = { name = "Desert Dust", kind = "SniperSkin", rarity = "Common" },
	sniper_forest = { name = "Forest Camo", kind = "SniperSkin", rarity = "Common" },
	knife_rust = { name = "Rust", kind = "KnifeSkin", rarity = "Common" },
	tracer_red = { name = "Red Tracer", kind = "Tracer", rarity = "Common" },
	tracer_blue = { name = "Blue Tracer", kind = "Tracer", rarity = "Common" },

	-- Rare
	sniper_arctic = { name = "Arctic", kind = "SniperSkin", rarity = "Rare" },
	sniper_carbon = { name = "Carbon", kind = "SniperSkin", rarity = "Rare" },
	knife_tiger = { name = "Tiger Stripe", kind = "KnifeSkin", rarity = "Rare" },
	kill_confetti = { name = "Confetti", kind = "KillEffect", rarity = "Rare" },

	-- Epic
	sniper_neon = { name = "Neon Grid", kind = "SniperSkin", rarity = "Epic" },
	knife_neon = { name = "Neon Edge", kind = "KnifeSkin", rarity = "Epic" },
	tracer_rainbow = { name = "Rainbow Tracer", kind = "Tracer", rarity = "Epic" },

	-- Legendary
	sniper_gold = { name = "Gold Tap", kind = "SniperSkin", rarity = "Legendary" },
	knife_gold = { name = "Gold Edge", kind = "KnifeSkin", rarity = "Legendary" },
	kill_lightning = { name = "Lightning Strike", kind = "KillEffect", rarity = "Legendary" },

	-- Mythic
	sniper_void = { name = "Void", kind = "SniperSkin", rarity = "Mythic" },
	knife_void = { name = "Void Edge", kind = "KnifeSkin", rarity = "Mythic" },
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

return Cosmetics
