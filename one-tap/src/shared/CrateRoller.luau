--[[
	CrateRoller: weighted crate rolls with a pity timer, plus exact odds for the UI.

	It lives in Shared so the shop UI can show odds, but ONLY the server may call
	`open`. A roll made on a client means nothing.

	Quick check from the Studio command bar after editing Cosmetics:
	  print(require(game.ReplicatedStorage.Shared.CrateRoller).validate())
]]

local Cosmetics = require(script.Parent:WaitForChild("Config"):WaitForChild("Cosmetics"))

local CrateRoller = {}

export type OddsLine = {
	itemId: string,
	name: string,
	rarity: string,
	percent: number,
}

local function rank(rarity: string): number
	return Cosmetics.Rarities[rarity].rank
end

local function getCrate(crateId: string)
	local crate = Cosmetics.Crates[crateId]
	assert(crate, `Unknown crate "{crateId}"`)
	return crate
end

-- rarity -> { itemId } for one crate's pool (unknown ids are skipped; validate() reports them)
local function itemsByRarity(crate): { [string]: { string } }
	local buckets = {}
	for _, itemId in crate.items do
		local item = Cosmetics.Items[itemId]
		if item then
			buckets[item.rarity] = buckets[item.rarity] or {}
			table.insert(buckets[item.rarity], itemId)
		end
	end
	return buckets
end

-- Weighted rarity pick. Rarities ranked below `minRank` are removed (used by pity).
local function rollRarity(crate, rng: Random, minRank: number): string
	local total = 0
	for _, rarity in Cosmetics.RarityOrder do
		local weight = crate.odds[rarity]
		if weight and weight > 0 and rank(rarity) >= minRank then
			total += weight
		end
	end

	local roll = rng:NextNumber() * total
	local last = nil
	for _, rarity in Cosmetics.RarityOrder do
		local weight = crate.odds[rarity]
		if weight and weight > 0 and rank(rarity) >= minRank then
			last = rarity
			if roll < weight then
				return rarity
			end
			roll -= weight
		end
	end
	assert(last, "Crate has no rollable rarities")
	return last -- only reached through float rounding
end

--[[
	SERVER ONLY. Opens one crate.
	pityCount = crates of this type opened since the last pity-rarity-or-better drop
	(store it per player, per crate).
	Returns: itemId, rarity, newPityCount
]]
function CrateRoller.open(crateId: string, rng: Random, pityCount: number?): (string, string, number)
	local crate = getCrate(crateId)
	local count = pityCount or 0

	local minRank = 0
	if crate.pity and count + 1 >= crate.pity.within then
		minRank = rank(crate.pity.rarity) -- pity kicks in: this open is guaranteed
	end

	local rarity = rollRarity(crate, rng, minRank)
	local bucket = itemsByRarity(crate)[rarity]
	assert(bucket and #bucket > 0, `Crate "{crateId}" has {rarity} odds but no {rarity} items`)
	local itemId = bucket[rng:NextInteger(1, #bucket)]

	local newCount = count + 1
	if crate.pity and rank(rarity) >= rank(crate.pity.rarity) then
		newCount = 0
	end
	return itemId, rarity, newCount
end

-- Exact per-item odds in percent, rarest first. Show this BEFORE every purchase.
function CrateRoller.getOdds(crateId: string): { OddsLine }
	local crate = getCrate(crateId)
	local buckets = itemsByRarity(crate)

	local total = 0
	for rarity, weight in crate.odds do
		if buckets[rarity] then
			total += weight
		end
	end

	local lines: { OddsLine } = {}
	for rarity, ids in buckets do
		local weight = crate.odds[rarity] or 0
		for _, itemId in ids do
			table.insert(lines, {
				itemId = itemId,
				name = Cosmetics.Items[itemId].name,
				rarity = rarity,
				percent = if total > 0 then weight / total * 100 / #ids else 0,
			})
		end
	end

	table.sort(lines, function(a, b)
		if a.rarity ~= b.rarity then
			return rank(a.rarity) > rank(b.rarity)
		end
		return a.name < b.name
	end)
	return lines
end

-- Returns a list of problems in the catalog (empty = all good).
function CrateRoller.validate(): { string }
	local problems = {}
	for crateId, crate in Cosmetics.Crates do
		for _, itemId in crate.items do
			if not Cosmetics.Items[itemId] then
				table.insert(problems, `{crateId}: unknown item "{itemId}"`)
			elseif not Cosmetics.isObtainable(itemId) then
				table.insert(problems, `{crateId}: "{itemId}" is VIP-only/exclusive and can't be in a crate`)
			end
		end

		local buckets = itemsByRarity(crate)
		for rarity, weight in crate.odds do
			if not Cosmetics.Rarities[rarity] then
				table.insert(problems, `{crateId}: unknown rarity "{rarity}"`)
			elseif weight > 0 and not buckets[rarity] then
				table.insert(problems, `{crateId}: has {rarity} odds but no {rarity} items`)
			end
		end
		for rarity in buckets do
			if not crate.odds[rarity] then
				table.insert(problems, `{crateId}: {rarity} items can never drop (no odds)`)
			end
		end

		if crate.pity then
			local pityRarity = Cosmetics.Rarities[crate.pity.rarity]
			if not pityRarity then
				table.insert(problems, `{crateId}: pity rarity "{crate.pity.rarity}" is unknown`)
			else
				local reachable = false
				for rarity in buckets do
					if rank(rarity) >= pityRarity.rank and (crate.odds[rarity] or 0) > 0 then
						reachable = true
					end
				end
				if not reachable then
					table.insert(problems, `{crateId}: pity can't be satisfied (no {crate.pity.rarity}+ items)`)
				end
			end
		end
	end
	return problems
end

return CrateRoller
