--[[
	Round settings (FFA for now; Duels/TDM come later).
]]

return {
	mode = "FFA",

	minPlayers = 2, -- set to 1 to test rounds alone in Studio
	killTarget = 30, -- first to this many kills wins
	roundLength = 360, -- seconds; most kills when time runs out wins

	intermissionLength = 15, -- map vote happens here
	resultsLength = 8, -- results screen, no damage

	voteOptions = 3, -- maps offered per vote
}
