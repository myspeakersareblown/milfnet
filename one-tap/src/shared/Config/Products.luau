--[[
	Robux products.

	SETUP: publish the game, then on the Creator Dashboard open your experience >
	Monetization, create each Game Pass / Developer Product, and paste its ID here.
	Anything left at id = 0 shows in the shop as "not set up yet" and can't be bought.

	`robux` is only a fallback for display: the real price shown comes from Roblox
	(MarketplaceService:GetProductInfo), so set prices on the dashboard.
]]

return {
	GamePasses = {
		VIP = {
			id = 0,
			name = "VIP",
			robux = 399,
			perks = {
				"VIP Royale sniper skin",
				"VIP Gold tracer",
				"VIP Crown kill effect",
				"[VIP] chat tag + gold name in the kill feed",
			},
		},
	},

	DevProducts = {
		StarterPack = {
			id = 0,
			name = "Starter Pack",
			robux = 99,
			gems = 500,
			item = "sniper_recruit", -- exclusive Epic skin
			oneTime = true,
			order = 0,
		},
		Gems100 = { id = 0, name = "100 Gems", robux = 49, gems = 100, order = 1 },
		Gems500 = { id = 0, name = "500 Gems", robux = 199, gems = 500, order = 2 },
		Gems1200 = { id = 0, name = "1,200 Gems", robux = 449, gems = 1200, order = 3, tag = "MOST POPULAR" },
		Gems2600 = { id = 0, name = "2,600 Gems", robux = 899, gems = 2600, order = 4, tag = "BEST VALUE" },
	},

	-- Studio only: pretend you own VIP so you can test VIP cosmetics.
	studioVip = false,
}
