--[[
	ShopServer: crates, crafting, the featured shop, Robux purchases and VIP.

	Robux purchases go through MarketplaceService.ProcessReceipt and are:
	  - idempotent: each receipt's PurchaseId is stored, so retries never double-grant
	  - only confirmed (PurchaseGranted) after the profile is actually saved
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local Products = require(Config:WaitForChild("Products"))
local CrateRoller = require(Shared:WaitForChild("CrateRoller"))
local Featured = require(Shared:WaitForChild("Featured"))

local Modules = script.Parent:WaitForChild("Modules")
local PlayerData = require(Modules:WaitForChild("PlayerData"))
local ActionRouter = require(Modules:WaitForChild("ActionRouter"))
local Progression = require(Modules:WaitForChild("Progression"))
local Ownership = require(Modules:WaitForChild("Ownership"))

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local rng = Random.new()

local problems = CrateRoller.validate()
for _, problem in problems do
	warn("[Shop] Cosmetics problem:", problem)
end

local function toast(player: Player, title: string, text: string?)
	Notify:FireClient(player, "Toast", { title = title, text = text })
end

--------------------------------------------------------------------------------
-- Per-player flags: region policy + VIP
--------------------------------------------------------------------------------

local function checkPolicy(player: Player)
	-- Some countries restrict paid random items (crates bought with Robux-bought Gems).
	-- If we can't find out, assume restricted: hiding a crate is the safe mistake.
	local restricted = true
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and typeof(info) == "table" then
		restricted = info.ArePaidRandomItemsRestricted == true
	elseif RunService:IsStudio() then
		restricted = false
	end
	player:SetAttribute("PaidRandomItemsRestricted", restricted)
end

local function checkVip(player: Player)
	if RunService:IsStudio() and Products.studioVip then
		player:SetAttribute("VIP", true)
		return
	end
	local passId = Products.GamePasses.VIP.id
	if passId == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and owns then
		player:SetAttribute("VIP", true)
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(checkPolicy, player)
	task.spawn(checkVip, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if purchased and passId == Products.GamePasses.VIP.id and passId ~= 0 then
		player:SetAttribute("VIP", true)
		toast(player, "VIP UNLOCKED!", "Your VIP cosmetics are in the Locker")
	end
end)

--------------------------------------------------------------------------------
-- Crates
--------------------------------------------------------------------------------

ActionRouter.register("OpenCrate", function(player, profile, crateId: any)
	if typeof(crateId) ~= "string" then
		return { ok = false, error = "Bad crate" }
	end
	local crate = Cosmetics.Crates[crateId]
	if not crate then
		return { ok = false, error = "Unknown crate" }
	end
	local data = profile.Data

	local ownedCount = data.Crates[crateId] or 0
	if ownedCount > 0 then
		data.Crates[crateId] = ownedCount - 1 -- free crate from a level-up / reward
	else
		if crate.currency == "Gems" and player:GetAttribute("PaidRandomItemsRestricted") ~= false then
			return { ok = false, error = "This crate isn't available in your region" }
		end
		if not Progression.spend(player, profile, crate.currency, crate.price) then
			return { ok = false, error = `Not enough {crate.currency}` }
		end
	end

	local itemId, rarity, newPity = CrateRoller.open(crateId, rng, data.Pity[crateId])
	data.Pity[crateId] = newPity

	local isNew = Ownership.give(profile, itemId)
	local scrap = 0
	if not isNew then
		scrap = Cosmetics.ScrapValue[rarity] or 0
		Progression.addCurrency(player, profile, "Scrap", scrap)
	end
	PlayerData.changed(player)

	return { ok = true, itemId = itemId, rarity = rarity, duplicate = not isNew, scrap = scrap }
end)

--------------------------------------------------------------------------------
-- Crafting (Scrap -> any obtainable item)
--------------------------------------------------------------------------------

ActionRouter.register("Craft", function(player, profile, itemId: any)
	if typeof(itemId) ~= "string" or not Cosmetics.isObtainable(itemId) then
		return { ok = false, error = "That item can't be crafted" }
	end
	if Ownership.owns(player, profile, itemId) then
		return { ok = false, error = "You already own that" }
	end
	local item = Cosmetics.Items[itemId]
	local cost = Cosmetics.CraftCost[item.rarity]
	if not cost or not Progression.spend(player, profile, "Scrap", cost) then
		return { ok = false, error = "Not enough Scrap" }
	end
	Ownership.give(profile, itemId)
	PlayerData.changed(player)
	return { ok = true }
end)

--------------------------------------------------------------------------------
-- Featured shop (direct buy with Gems, rotates daily)
--------------------------------------------------------------------------------

ActionRouter.register("GetFeatured", function(_player, _profile)
	local day = Featured.dayNumber(os.time())
	return { ok = true, items = Featured.getForDay(day), resetsAt = Featured.resetsAt(day) }
end)

ActionRouter.register("BuyFeatured", function(player, profile, itemId: any)
	if typeof(itemId) ~= "string" then
		return { ok = false, error = "Bad item" }
	end
	local today = Featured.getForDay(Featured.dayNumber(os.time()))
	if not table.find(today, itemId) then
		return { ok = false, error = "That's not in today's shop" }
	end
	if Ownership.owns(player, profile, itemId) then
		return { ok = false, error = "You already own that" }
	end
	local price = Featured.price(itemId)
	if not price or not Progression.spend(player, profile, "Gems", price) then
		return { ok = false, error = "Not enough Gems" }
	end
	Ownership.give(profile, itemId)
	PlayerData.changed(player)
	return { ok = true }
end)

--------------------------------------------------------------------------------
-- Robux developer products
--------------------------------------------------------------------------------

type Grant = (Player, any) -> string -- returns a message for the "thanks" toast
local grants: { [number]: Grant } = {}

for key, product in Products.DevProducts do
	if product.id ~= 0 then
		grants[product.id] = function(player, profile)
			local data = profile.Data
			Progression.addCurrency(player, profile, "Gems", product.gems or 0)
			local message = `+{product.gems or 0} Gems`
			if product.item and Ownership.give(profile, product.item) then
				local item = Cosmetics.Items[product.item]
				message ..= ` + {if item then item.name else product.item}`
			end
			if key == "StarterPack" then
				data.StarterPackBought = true
			end
			return message
		end
	end
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they rejoin
	end
	local profile = PlayerData.waitFor(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local grant = grants[receipt.ProductId]
	if not grant then
		warn("[Shop] No grant for product", receipt.ProductId, "(is its id in Config/Products?)")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not profile.Data.Purchases[receipt.PurchaseId] then
		local message = grant(player, profile)
		PlayerData.recordPurchase(profile, receipt.PurchaseId)
		PlayerData.changed(player)
		toast(player, "THANK YOU!", message)
	end

	-- Only confirm once it's really saved; otherwise Roblox will retry later.
	if PlayerData.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
