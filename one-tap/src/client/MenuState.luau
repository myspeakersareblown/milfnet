--[[
	MenuState: tracks whether any menu (shop, map vote, settings...) is open, so
	weapons stop firing and the mouse cursor shows while you click around.

	  MenuState.set("Shop", true)
	  MenuState.anyOpen()
	  MenuState.onChanged(function() ... end)
]]

local MenuState = {}

local open: { [string]: boolean } = {}
local listeners: { () -> () } = {}

function MenuState.set(name: string, isOpen: boolean)
	if (open[name] == true) == isOpen then
		return
	end
	open[name] = if isOpen then true else nil
	for _, listener in listeners do
		task.spawn(listener)
	end
end

function MenuState.anyOpen(): boolean
	return next(open) ~= nil
end

function MenuState.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

return MenuState
