--[[
	Featured: the daily direct-buy shop. The same items for everyone each UTC day,
	picked deterministically from the day number, so no storage is needed.
]]

local Cosmetics = require(script.Parent:WaitForChild("Config"):WaitForChild("Cosmetics"))

local Featured = {}

local DAY = 86400

function Featured.dayNumber(unixTime: number): number
	return math.floor(unixTime / DAY)
end

-- Unix time when the given day's shop ends.
function Featured.resetsAt(day: number): number
	return (day + 1) * DAY
end

function Featured.price(itemId: string): number?
	local item = Cosmetics.Items[itemId]
	return item and Cosmetics.Featured.prices[item.rarity]
end

function Featured.getForDay(day: number): { string }
	local pool = {}
	for itemId in Cosmetics.Items do
		if Cosmetics.isObtainable(itemId) and Featured.price(itemId) then
			table.insert(pool, itemId)
		end
	end
	table.sort(pool) -- table iteration order isn't stable; sorting makes the pick deterministic

	local rng = Random.new(day * 7919 + 17)
	local picks = {}
	for _ = 1, math.min(Cosmetics.Featured.count, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(picks, table.remove(pool, index))
	end
	return picks
end

return Featured
