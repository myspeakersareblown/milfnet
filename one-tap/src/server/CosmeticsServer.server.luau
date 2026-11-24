--[[
	CosmeticsServer: equipping, and making equipped cosmetics visible.

	Equipped cosmetics are mirrored to Player attributes (SniperSkin, KnifeSkin,
	Tracer, KillEffect) so every client can draw other players' tracers and kill
	effects in the right style. Weapon skins are applied to the tools here on the
	server, so everyone sees them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Cosmetics"))
local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local ActionRouter = require(Modules:WaitForChild("ActionRouter"))
local Ownership = require(Modules:WaitForChild("Ownership"))

local SKIN_KIND_FOR_TOOL = {
	Sniper = "SniperSkin",
	Knife = "KnifeSkin",
}

--------------------------------------------------------------------------------
-- Weapon skins
--------------------------------------------------------------------------------

-- Remember each tool's original look the first time, so unequipping a skin restores it.
local function rememberDefault(part: BasePart)
	if part:GetAttribute("DefaultColor") == nil then
		part:SetAttribute("DefaultColor", part.Color)
		part:SetAttribute("DefaultMaterial", part.Material.Name)
	end
end

local function applySkinToTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") then
		return
	end
	local kind = SKIN_KIND_FOR_TOOL[tool.Name]
	if not kind then
		return
	end
	local itemId = player:GetAttribute(kind)
	local item = if typeof(itemId) == "string" then Cosmetics.Items[itemId] else nil

	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			rememberDefault(part)
			if item and item.color then
				part.Color = item.color
				part.Material = item.material or Enum.Material.SmoothPlastic
			else
				part.Color = part:GetAttribute("DefaultColor")
				local materialName = part:GetAttribute("DefaultMaterial")
				local ok, material = pcall(function()
					return (Enum.Material :: any)[materialName]
				end)
				part.Material = if ok and material then material else Enum.Material.SmoothPlastic
			end
		end
	end
end

local function applySkins(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				applySkinToTool(player, child)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Attributes
--------------------------------------------------------------------------------

local function syncAttributes(player: Player, profile: any)
	for _, kind in Cosmetics.Kinds do
		local itemId = profile.Data.Equipped[kind]
		-- Drop anything they no longer own (e.g. VIP-only item after losing VIP).
		if itemId and not Ownership.owns(player, profile, itemId) then
			itemId = nil
			profile.Data.Equipped[kind] = nil
		end
		player:SetAttribute(kind, itemId or "")
	end
	applySkins(player)
end

PlayerData.onLoaded(function(player, profile)
	syncAttributes(player, profile)
end)

-- VIP can be granted mid-session (ShopServer sets the attribute).
local function watchVip(player: Player)
	player:GetAttributeChangedSignal("VIP"):Connect(function()
		local profile = PlayerData.get(player)
		if profile then
			syncAttributes(player, profile)
			PlayerData.changed(player)
		end
	end)
end

--------------------------------------------------------------------------------
-- Tools appear on every respawn: skin them as they show up
--------------------------------------------------------------------------------

local backpackConnections: { [Player]: RBXScriptConnection } = {}

local function onCharacterAdded(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		applySkinToTool(player, child)
	end)
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		if backpackConnections[player] then
			backpackConnections[player]:Disconnect()
		end
		backpackConnections[player] = backpack.ChildAdded:Connect(function(child)
			applySkinToTool(player, child)
		end)
	end
	applySkins(player)
end

Players.PlayerRemoving:Connect(function(player)
	if backpackConnections[player] then
		backpackConnections[player]:Disconnect()
		backpackConnections[player] = nil
	end
end)

local function onPlayerAdded(player: Player)
	watchVip(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

ActionRouter.register("Equip", function(player, profile, itemId: any)
	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Bad item" }
	end
	local item = Cosmetics.Items[itemId]
	if not item then
		return { ok = false, error = "Unknown item" }
	end
	if not Ownership.owns(player, profile, itemId) then
		return { ok = false, error = "You don't own that" }
	end
	profile.Data.Equipped[item.kind] = itemId
	syncAttributes(player, profile)
	PlayerData.changed(player)
	return { ok = true }
end)

ActionRouter.register("Unequip", function(player, profile, kind: any)
	if typeof(kind) ~= "string" or not table.find(Cosmetics.Kinds, kind) then
		return { ok = false, error = "Bad slot" }
	end
	profile.Data.Equipped[kind] = nil
	syncAttributes(player, profile)
	PlayerData.changed(player)
	return { ok = true }
end)
