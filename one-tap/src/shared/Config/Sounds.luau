--[[
	Sounds. Paste asset IDs ("rbxassetid://123...") from the Creator Store
	(Toolbox > Audio) or your own uploads. Empty id = that sound is skipped.

	The few rbxasset://sounds/... entries are classic sounds that ship with Roblox,
	used as placeholders so something plays out of the box. Swap them for better ones.
]]

return {
	-- Weapons
	SniperShot = { id = "", volume = 0.9 }, -- the most important sound in the game: pick a punchy one
	SniperBolt = { id = "", volume = 0.5 },
	ScopeIn = { id = "", volume = 0.4 },
	Reload = { id = "", volume = 0.6 },
	KnifeSwing = { id = "rbxasset://sounds/swordslash.wav", volume = 0.5 },

	-- Feedback
	Hitmarker = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6 },
	HeadshotDing = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
	Kill = { id = "", volume = 0.7 },

	-- Menus
	UiClick = { id = "rbxasset://sounds/button.wav", volume = 0.4 },
	CrateTick = { id = "rbxasset://sounds/clickfast.wav", volume = 0.25 },
	CrateReveal = { id = "", volume = 0.8 },
	LevelUp = { id = "", volume = 0.7 },
}
