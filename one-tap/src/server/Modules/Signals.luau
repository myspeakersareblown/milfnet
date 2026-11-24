--[[
	Signals: server-only events that let systems talk without requiring each other.

	  Kill          (attacker: Player, victim: Player?, weaponName: string, special: boolean)
	                Fired by CombatServer. `special` = headshot (Sniper) / backstab (Knife).
	                victim is nil for test dummies.
	  RoundStarted  (mapName: string)
	  RoundEnded    (standings: { Standing }, completed: boolean)
	                completed = false when the round was cut short (players left).
]]

export type Standing = {
	player: Player,
	name: string,
	kills: number,
	deaths: number,
	rank: number,
}

local function signal(name: string): BindableEvent
	local event = Instance.new("BindableEvent")
	event.Name = name
	return event
end

return {
	Kill = signal("Kill"),
	RoundStarted = signal("RoundStarted"),
	RoundEnded = signal("RoundEnded"),
}
