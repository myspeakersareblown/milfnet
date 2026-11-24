--[[
	PlayerData: saves and loads player profiles with DataStoreService.

	Session locking: a profile can only be open in ONE server at a time. This is
	what stops item duplication when players hop between servers. If another
	server takes over a profile, this server stops saving it and kicks the player.

	Studio: if DataStores aren't available (place not published, or
	"Enable Studio Access to API Services" is off in Game Settings > Security),
	profiles still work but run OFFLINE and nothing is saved.

	Usage from other server scripts:
	  local profile = PlayerData.get(player)   -- nil while loading
	  profile.Data.Taps += 10
	  PlayerData.changed(player)               -- syncs to the client, marks for autosave
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))
local ProfileSync = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProfileSync") :: RemoteEvent

local PlayerData = {}

local STORE_NAME = "OneTap_PlayerData_v1" -- change the suffix only to wipe everyone's data
local SESSION_ID = HttpService:GenerateGUID(false)
local LOCK_STALE_SECONDS = 300 -- a lock older than this belongs to a crashed server
local LOAD_ATTEMPTS = 6
local MAX_PURCHASE_HISTORY = 50

PlayerData.TEMPLATE = {
	Taps = 0,
	Gems = 0,
	Scrap = 0,
	XP = 0,
	Level = 1,
	Inventory = {}, -- [itemId] = true
	Equipped = {}, -- [kind] = itemId   (kind = "SniperSkin" | "KnifeSkin" | "Tracer" | "KillEffect")
	Crates = {}, -- [crateId] = unopened crates owned (free ones from levels etc.)
	Pity = {}, -- [crateId] = opens since the last pity-rarity drop
	Stats = { Kills = 0, Deaths = 0, Headshots = 0, Backstabs = 0, Wins = 0, Matches = 0 },
	StarterPackBought = false,
	Purchases = {}, -- [receipt PurchaseId] = os.time()   (server only)
	Daily = {}, -- login streak + challenges (DailyServer)
	Settings = {}, -- client settings (sensitivity etc.)
}

export type Profile = {
	player: Player,
	Data: any,
	offline: boolean, -- DataStores unavailable: never saved
	released: boolean,
	lostLock: boolean,
	saving: boolean,
	syncQueued: boolean,
}

local profiles: { [Player]: Profile } = {}
local leaving: { [Player]: boolean } = {} -- left while their profile was still loading
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function isGone(player: Player): boolean
	return leaving[player] == true or player.Parent == nil
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds any keys from the template that older saves don't have yet.
local function reconcile(data: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local storeCache: DataStore? = nil
local function getStore(): DataStore?
	if storeCache then
		return storeCache
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		storeCache = result
		return result
	end
	warn("[PlayerData] DataStores unavailable:", result)
	return nil
end

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function isStudioAccessError(err: any): boolean
	local message = tostring(err)
	return RunService:IsStudio()
		and (
			message:find("StudioAccessToApisNotAllowed") ~= nil
			or message:find("publish") ~= nil
			or message:find("API") ~= nil
		)
end

local function newProfile(player: Player, data: any, offline: boolean): Profile
	return {
		player = player,
		Data = data,
		offline = offline,
		released = false,
		lostLock = false,
		saving = false,
		syncQueued = false,
	}
end

local function freshData(): any
	local data = deepCopy(PlayerData.TEMPLATE)
	for crateId, count in Economy.starting.crates do
		data.Crates[crateId] = count
	end
	return data
end

local function finishLoad(player: Player, profile: Profile)
	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	PlayerData.changed(player)
end

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------

-- Writes the profile. With `release`, also gives up the session lock.
local function write(profile: Profile, release: boolean): boolean
	if profile.offline then
		return true
	end
	if profile.lostLock then
		return false
	end
	while profile.saving do
		task.wait()
	end
	profile.saving = true

	local store = getStore()
	local ownsLock = true
	local ok, err = false, "no data store"
	if store then
		ok, err = pcall(function()
			store:UpdateAsync(keyFor(profile.player), function(stored)
				stored = stored or {}
				local lock = stored.Lock
				if not lock or lock.Session ~= SESSION_ID then
					ownsLock = false
					return nil -- another server owns this profile now: don't overwrite it
				end
				stored.Data = profile.Data
				stored.Lock = if release then nil else { Session = SESSION_ID, Time = os.time() }
				return stored
			end)
		end)
	end
	profile.saving = false

	if not ok then
		warn(`[PlayerData] Save failed for {profile.player.Name}:`, err)
		return false
	end
	if not ownsLock then
		profile.lostLock = true
		warn(`[PlayerData] {profile.player.Name}'s profile was taken over by another server`)
		if profile.player.Parent then
			profile.player:Kick("Your data was opened in another server. Please rejoin.")
		end
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PlayerData.load(player: Player): Profile?
	local store = getStore()
	if not store then
		finishLoad(player, newProfile(player, freshData(), true))
		return profiles[player]
	end

	local key = keyFor(player)
	for attempt = 1, LOAD_ATTEMPTS do
		local outcome, loaded = "error", nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(stored)
				stored = stored or {}
				local lock = stored.Lock
				local lockedElsewhere = lock ~= nil
					and lock.Session ~= SESSION_ID
					and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS
				-- On the last attempt we take the lock anyway: the old server can no
				-- longer save over us (its writes check the lock), so nothing dupes.
				if lockedElsewhere and attempt < LOAD_ATTEMPTS then
					outcome = "locked"
					return nil
				end
				outcome = "loaded"
				loaded = stored.Data
				stored.Lock = { Session = SESSION_ID, Time = os.time() }
				return stored
			end)
		end)

		if not ok and isStudioAccessError(err) then
			warn("[PlayerData] Studio has no DataStore access, so data is OFFLINE and won't save.", err)
			finishLoad(player, newProfile(player, freshData(), true))
			return profiles[player]
		end

		if ok and outcome == "loaded" then
			local data = loaded
			if type(data) ~= "table" then
				data = freshData()
			else
				reconcile(data, PlayerData.TEMPLATE)
			end
			local profile = newProfile(player, data, false)

			if isGone(player) then
				write(profile, true) -- they left while we were loading: let go of the lock
				leaving[player] = nil
				return nil
			end
			finishLoad(player, profile)
			return profile
		end

		if not ok then
			warn(`[PlayerData] Load attempt {attempt} failed for {player.Name}:`, err)
		end
		if isGone(player) then
			leaving[player] = nil
			return nil
		end
		task.wait(2)
	end

	player:Kick("We couldn't load your data. Please rejoin in a minute.")
	return nil
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

-- Yields until the player's profile is loaded (or they leave / timeout).
function PlayerData.waitFor(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- callback(player, profile) runs for every profile that loads (and ones already loaded).
function PlayerData.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

-- Call after changing profile.Data. Pushes a fresh copy to the client (once per frame).
function PlayerData.changed(player: Player)
	local profile = profiles[player]
	if not profile or profile.syncQueued then
		return
	end
	profile.syncQueued = true
	task.defer(function()
		profile.syncQueued = false
		if not player.Parent then
			return
		end
		local data = profile.Data
		player:SetAttribute("Level", data.Level)
		player:SetAttribute("Taps", data.Taps)
		player:SetAttribute("Gems", data.Gems)
		local leaderstats = player:FindFirstChild("leaderstats")
		local level = leaderstats and leaderstats:FindFirstChild("Level")
		if level and level:IsA("IntValue") then
			level.Value = data.Level
		end
		ProfileSync:FireClient(player, PlayerData.snapshot(profile))
	end)
end

-- What the client is allowed to see.
function PlayerData.snapshot(profile: Profile): any
	local snapshot = table.clone(profile.Data)
	snapshot.Purchases = nil
	return snapshot
end

-- Remembers a receipt so the same purchase is never granted twice.
function PlayerData.recordPurchase(profile: Profile, purchaseId: string)
	local purchases = profile.Data.Purchases
	purchases[purchaseId] = os.time()

	local ids = {}
	for id in purchases do
		table.insert(ids, id)
	end
	if #ids > MAX_PURCHASE_HISTORY then
		table.sort(ids, function(a, b)
			return purchases[a] < purchases[b]
		end)
		for i = 1, #ids - MAX_PURCHASE_HISTORY do
			purchases[ids[i]] = nil
		end
	end
end

-- Saves right now. Returns true only if it really reached the DataStore
-- (or the profile is offline). Use before confirming a Robux purchase.
function PlayerData.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return write(profile, false)
end

function PlayerData.release(player: Player)
	local profile = profiles[player]
	if not profile then
		-- Still loading: PlayerData.load sees this and releases the lock itself.
		leaving[player] = true
		task.delay(120, function()
			leaving[player] = nil
		end)
		return
	end
	if profile.released then
		return
	end
	profile.released = true
	write(profile, true)
	profiles[player] = nil
end

function PlayerData.autosaveAll()
	for _, profile in profiles do
		if not profile.released then
			task.spawn(write, profile, false)
			task.wait(0.5) -- spread requests out to stay under DataStore limits
		end
	end
end

-- For game:BindToClose: release every profile in parallel and wait for them.
function PlayerData.releaseAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			PlayerData.release(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return PlayerData
