--[[
	Weapon stats. Every number that changes how the weapons feel lives here.
	Server and client both read this file, but only the SERVER's copy decides damage.
	Skins never change anything in here.
]]

local Weapons = {}

Weapons.Sniper = {
	displayName = "Sniper",

	-- The whole game in two lines:
	headDamage = 100, -- 1 tap
	bodyDamage = 70, -- torso, arms, legs: needs a follow-up (2nd shot or a knife slash)

	range = 2000, -- studs (hitscan)
	magSize = 5,
	fireCooldown = 1.1, -- seconds between shots (bolt cycle)
	reloadTime = 2.4,

	-- Accuracy, in degrees of random cone around where you aim.
	hipSpread = 7, -- no-scope: possible, mostly luck
	scopedSpread = 0, -- fully scoped: perfect
	moveSpread = 2, -- added while walking
	airSpread = 9, -- added while jumping/falling

	-- Scope
	scopeInTime = 0.2, -- seconds from hip to full accuracy (the quickscope window)
	scopedFOV = 20, -- default camera FOV is 70
	scopedSensitivity = 0.35, -- mouse sensitivity multiplier while fully scoped
	scopedWalkSpeed = 9,
	unscopeOnShot = true, -- bolt-action: drop scope after each shot, rescope if still held

	recoilKick = 1.2, -- degrees the camera kicks up per shot
}

Weapons.Knife = {
	displayName = "Knife",

	slashDamage = 50, -- body shot (70) + slash (50) = kill
	backstabDamage = 100, -- the knife's own 1 tap

	range = 6, -- studs
	hitRadius = 1.25, -- thickness of the swing (spherecast radius)
	cooldown = 0.5,
	walkSpeed = 20, -- knife out = move faster

	-- Server checks
	minFacingDot = 0.3, -- attacker must roughly face the target
	backstabDot = 0.5, -- how directly behind the target you must be for a backstab
}

return Weapons
