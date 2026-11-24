--[[
	ActionRouter: one RemoteFunction (Remotes.PlayerAction) for every menu action
	(open crate, equip, claim daily, ...).

	Server scripts register handlers:
	  ActionRouter.register("Equip", function(player, profile, itemId)
	      ...
	      return { ok = true }
	  end)

	Clients call:  PlayerAction:InvokeServer("Equip", "sniper_gold")

	Every handler gets a loaded profile, runs inside pcall, and is rate limited.
	Handlers must validate every argument: clients can send anything.
]]

local ActionRouter = {}

type Handler = (Player, any, ...any) -> any

local handlers: { [string]: Handler } = {}
local lastCall: { [Player]: number } = {}
local MIN_INTERVAL = 0.15 -- seconds between actions per player

function ActionRouter.register(name: string, handler: Handler)
	assert(handlers[name] == nil, `Action "{name}" registered twice`)
	handlers[name] = handler
end

function ActionRouter.init(remote: RemoteFunction, PlayerData: any)
	remote.OnServerInvoke = function(player: Player, action: any, ...: any)
		if typeof(action) ~= "string" then
			return { ok = false, error = "Bad request" }
		end
		local handler = handlers[action]
		if not handler then
			return { ok = false, error = "Unknown action" }
		end

		local now = os.clock()
		if now - (lastCall[player] or 0) < MIN_INTERVAL then
			return { ok = false, error = "Slow down!" }
		end
		lastCall[player] = now

		local profile = PlayerData.get(player)
		if not profile then
			return { ok = false, error = "Still loading your data..." }
		end

		local ok, result = pcall(handler, player, profile, ...)
		if not ok then
			warn(`[ActionRouter] "{action}" failed for {player.Name}:`, result)
			return { ok = false, error = "Something went wrong" }
		end
		return result
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return ActionRouter
