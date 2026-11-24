--[[
	Player settings (saved in their profile). The server validates against these
	definitions, so only listed keys and in-range values are ever stored.
]]

export type Definition = {
	key: string,
	label: string,
	kind: "slider" | "toggle",
	default: any,
	min: number?,
	max: number?,
	step: number?,
	format: ((number) -> string)?,
}

local list: { Definition } = {
	{
		key = "ScopedSensitivity",
		label = "Scoped mouse sensitivity",
		kind = "slider",
		min = 0.1,
		max = 1,
		step = 0.05,
		default = 0.35,
		format = function(v)
			return string.format("%.2fx", v)
		end,
	},
	{
		key = "FieldOfView",
		label = "Field of view",
		kind = "slider",
		min = 60,
		max = 90,
		step = 1,
		default = 70,
		format = function(v)
			return tostring(math.floor(v + 0.5))
		end,
	},
	{
		key = "SfxVolume",
		label = "Sound effects volume",
		kind = "slider",
		min = 0,
		max = 1,
		step = 0.05,
		default = 0.8,
		format = function(v)
			return `{math.floor(v * 100 + 0.5)}%`
		end,
	},
	{ key = "KillEffects", label = "Show kill effects", kind = "toggle", default = true },
	{ key = "OtherTracers", label = "Show other players' tracers", kind = "toggle", default = true },
}

local byKey: { [string]: Definition } = {}
for _, definition in list do
	byKey[definition.key] = definition
end

-- Returns the cleaned value, or nil if it's not allowed.
local function sanitize(key: string, value: any): any
	local definition = byKey[key]
	if not definition then
		return nil
	end
	if definition.kind == "toggle" then
		return if typeof(value) == "boolean" then value else nil
	end
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local min, max, step = definition.min :: number, definition.max :: number, definition.step :: number
	local snapped = math.floor((value - min) / step + 0.5) * step + min
	return math.clamp(snapped, min, max)
end

return {
	list = list,
	byKey = byKey,
	sanitize = sanitize,
}
