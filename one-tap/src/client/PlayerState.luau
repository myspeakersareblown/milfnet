--[[
	PlayerState: the client's copy of your profile (Taps, Gems, inventory, ...).
	The server pushes a fresh copy over Remotes.ProfileSync whenever it changes.
	This is display-only: the server's copy is the real one.

	  PlayerState.onChanged(function(data) ... end)   -- runs now (if loaded) and on every change
	  PlayerState.action("Equip", "sniper_gold")       -- calls Remotes.PlayerAction safely
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileSync = Remotes:WaitForChild("ProfileSync") :: RemoteEvent
local PlayerAction = Remotes:WaitForChild("PlayerAction") :: RemoteFunction

local PlayerState = {}
PlayerState.data = nil :: any

local listeners: { (any) -> () } = {}

local function set(data: any)
	PlayerState.data = data
	for _, listener in listeners do
		task.spawn(listener, data)
	end
end

function PlayerState.onChanged(listener: (any) -> ())
	table.insert(listeners, listener)
	if PlayerState.data then
		task.spawn(listener, PlayerState.data)
	end
end

-- Returns the server's reply table, e.g. { ok = true, ... } or { ok = false, error = "..." }.
function PlayerState.action(name: string, ...: any): any
	local args = table.pack(...)
	local ok, result = pcall(function()
		return PlayerAction:InvokeServer(name, table.unpack(args, 1, args.n))
	end)
	if not ok or typeof(result) ~= "table" then
		return { ok = false, error = "Couldn't reach the server" }
	end
	return result
end

ProfileSync.OnClientEvent:Connect(set)

-- In case the first sync arrived before this script was listening.
task.spawn(function()
	for _ = 1, 30 do
		if PlayerState.data then
			return
		end
		local reply = PlayerState.action("GetProfile")
		if reply.ok and reply.profile then
			if not PlayerState.data then
				set(reply.profile)
			end
			return
		end
		task.wait(1)
	end
end)

return PlayerState
