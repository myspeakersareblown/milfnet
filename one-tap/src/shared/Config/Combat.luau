--[[
	Match-wide combat settings + the tolerances the server uses when it
	double-checks what clients say they hit.
]]

return {
	maxHealth = 100,
	baseWalkSpeed = 16,
	respawnTime = 3,
	spawnProtection = 2, -- seconds of ForceField after spawning (removed early when you attack)

	-- Health regen: a 70 body shot only "sticks" if it's followed up quickly.
	regenEnabled = true,
	regenDelay = 6, -- seconds without taking damage before regen starts
	regenPerSecond = 15,

	-- Server-side shot validation. Loosen these if real players report
	-- "I clearly hit that"; tighten them if exploiters slip through.
	timingGrace = 0.15, -- seconds of network jitter allowed on fire rate / cooldowns
	maxOriginOffset = 6, -- studs a shot may start away from the shooter's head
	maxAimDeviationDegrees = 2, -- hit point must lie on the aim line
	hitTolerance = 3, -- studs of slack between the claimed hit point and the part
	maxLagCompensation = 0.6, -- seconds of target movement we forgive at most
	meleeRangeTolerance = 3, -- extra studs of knife reach for lag
}
