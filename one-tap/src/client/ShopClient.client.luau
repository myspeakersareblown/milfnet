--[[
	ShopClient: the Shop + Locker window.

	  B = Shop, L = Locker, J = Daily (or the buttons on the left of the screen)

	Tabs: Crates (open, odds, opening reel) · Featured (daily direct buy) ·
	      Gems (Robux packs, Starter Pack, VIP) · Locker (equip + craft with Scrap) ·
	      Daily (login streak + challenges)

	Everything here only REQUESTS actions; the server decides (ShopServer).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local MenuState = require(script.Parent:WaitForChild("MenuState"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local Sounds = require(script.Parent:WaitForChild("Sounds"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cosmetics = require(Config:WaitForChild("Cosmetics"))
local Products = require(Config:WaitForChild("Products"))
local Daily = require(Config:WaitForChild("Daily"))
local Economy = require(Config:WaitForChild("Economy"))
local CrateRoller = require(Shared:WaitForChild("CrateRoller"))
local Featured = require(Shared:WaitForChild("Featured"))

local player = Players.LocalPlayer
local C = Ui.Colors
local rng = Random.new()

local WINDOW_W, WINDOW_H = 760, 480
local CONTENT_W = WINDOW_W - 32

local gui = Ui.screenGui("ShopUi", 10)
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local isOpen = false
local currentTab = "Crates"
local lockerKind = "SniperSkin"
local busy = false -- a crate is being opened: don't re-render underneath the reel
local featuredCache: { items: { string }, resetsAt: number }? = nil
local robuxPrices: { [number]: number } = {}

local function data(): any
	return PlayerState.data
end

local function owns(itemId: string): boolean
	local item = Cosmetics.Items[itemId]
	local d = data()
	if not item or not d then
		return false
	end
	if item.vipOnly then
		return player:GetAttribute("VIP") == true
	end
	return d.Inventory[itemId] == true
end

local function rarityColor(rarity: string): Color3
	local info = Cosmetics.Rarities[rarity]
	return if info then info.color else C.Muted
end

local function currencyColor(currency: string): Color3
	return if currency == "Gems" then C.Gems elseif currency == "Scrap" then C.Scrap else C.Taps
end

local function failToast(reply: any)
	Toasts.show("Couldn't do that", reply.error or "Try again", C.Accent)
end

--------------------------------------------------------------------------------
-- Window chrome
--------------------------------------------------------------------------------

local side = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
	Size = UDim2.fromOffset(120, 150),
	BackgroundTransparency = 1,
}, gui)
Ui.list(side, 8)

local window = Ui.panel({
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
	Visible = false,
	Active = true, -- clicks on the window don't fall through to the game
}, gui, true)
local windowScale = Ui.make("UIScale", {}, window)

local function fitToScreen()
	local viewport = workspace.CurrentCamera.ViewportSize
	windowScale.Scale = math.min(1, (viewport.X - 24) / WINDOW_W, (viewport.Y - 24) / WINDOW_H)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
fitToScreen()

local titleLabel = Ui.label({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.fromOffset(200, 32),
	Font = Ui.FontHeavy,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "SHOP",
}, window)

local balance = Ui.label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 14),
	Size = UDim2.fromOffset(420, 24),
	TextXAlignment = Enum.TextXAlignment.Right,
	RichText = true,
	TextSize = 17,
	Text = "",
}, window)

local tabsRow = Ui.make("Frame", {
	Position = UDim2.fromOffset(16, 50),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
}, window)
Ui.list(tabsRow, 8, true)

local content = Ui.make("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(16, 98),
	Size = UDim2.new(1, -32, 1, -112),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, window)

-- Overlay for odds lists and the crate opening reel.
local overlay = Ui.make("Frame", {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
	Active = true,
}, window)
Ui.corner(overlay, 12)

local render: () -> () -- defined below
local open: (string) -> ()
local close: () -> ()
local openCrate: (string) -> ()

local function hex(color: Color3): string
	local function byte(v: number): number
		return math.clamp(math.floor(v * 255 + 0.5), 0, 255)
	end
	return string.format("#%02X%02X%02X", byte(color.R), byte(color.G), byte(color.B))
end

local function updateBalance()
	local d = data()
	if not d then
		return
	end
	balance.Text = string.format(
		'<font color="%s">%s Taps</font>    <font color="%s">%s Gems</font>    <font color="%s">%s Scrap</font>',
		hex(C.Taps),
		Ui.formatNumber(d.Taps),
		hex(C.Gems),
		Ui.formatNumber(d.Gems),
		hex(C.Scrap),
		Ui.formatNumber(d.Scrap)
	)
end

Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	Text = "X",
	Font = Ui.FontHeavy,
}, function()
	close()
end, window)

local TABS = { "Crates", "Featured", "Gems", "Locker", "Daily" }
local tabButtons: { [string]: TextButton } = {}
for i, tab in TABS do
	tabButtons[tab] = Ui.button({
		Size = UDim2.fromOffset(120, 36),
		LayoutOrder = i,
		Text = string.upper(tab),
	}, function()
		if not busy then
			currentTab = tab
			render()
		end
	end, tabsRow)
end

--------------------------------------------------------------------------------
-- Building blocks
--------------------------------------------------------------------------------

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

local function scroller(parent: Instance, cellSize: Vector2?): ScrollingFrame
	local frame = Ui.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	if cellSize then
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, frame)
	else
		Ui.list(frame, 6)
	end
	return frame
end

-- Little colored square that previews an item.
local function swatch(parent: Instance, item: any, size: UDim2, position: UDim2?)
	local frame = Ui.make("Frame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundColor3 = item.color or C.PanelLight,
		BorderSizePixel = 0,
	}, parent)
	Ui.corner(frame, 8)
	if item.rainbow then
		frame.BackgroundColor3 = C.White
		Ui.make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 255)),
			}),
		}, frame)
	elseif item.effect then
		Ui.label({
			Size = UDim2.fromScale(1, 1),
			Font = Ui.FontHeavy,
			TextSize = 14,
			Text = string.upper(item.effect),
			TextColor3 = rarityColor(item.rarity),
		}, frame)
	end
	if item.material == Enum.Material.Neon or item.material == Enum.Material.ForceField then
		Ui.stroke(frame, item.color, 2)
	end
	return frame
end

-- Card for one cosmetic with an optional action button.
local function itemCard(
	parent: Instance,
	itemId: string,
	order: number,
	actionText: string?,
	actionColor: Color3?,
	onAction: (() -> ())?
): Frame
	local item = Cosmetics.Items[itemId]
	local card = Ui.make("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
	}, parent)
	Ui.corner(card, 10)
	Ui.stroke(card, rarityColor(item.rarity), 2)

	swatch(card, item, UDim2.new(1, -20, 0, 56), UDim2.fromOffset(10, 10))
	Ui.label({
		Position = UDim2.fromOffset(8, 70),
		Size = UDim2.new(1, -16, 0, 20),
		TextSize = 15,
		Text = item.name,
	}, card)
	Ui.label({
		Position = UDim2.fromOffset(8, 90),
		Size = UDim2.new(1, -16, 0, 16),
		Font = Ui.FontBody,
		TextSize = 12,
		TextColor3 = rarityColor(item.rarity),
		Text = string.upper(item.rarity),
	}, card)
	if actionText then
		local button = Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 30),
			TextSize = 14,
			Text = actionText,
			BackgroundColor3 = actionColor or C.Panel,
		}, onAction, card)
		if not onAction then
			button.AutoButtonColor = false
		end
	end
	return card
end

--------------------------------------------------------------------------------
-- Overlay: odds list
--------------------------------------------------------------------------------

local function hideOverlay()
	overlay.Visible = false
	clear(overlay)
end

local function showOdds(crateId: string)
	clear(overlay)
	local crate = Cosmetics.Crates[crateId]
	Ui.label({
		Position = UDim2.fromOffset(20, 14),
		Size = UDim2.new(1, -40, 0, 30),
		Font = Ui.FontHeavy,
		TextSize = 24,
		Text = `{crate.name} · Odds`,
		ZIndex = 21,
	}, overlay)
	local note = "Chance per open. Duplicates turn into Scrap."
	if crate.pity then
		note ..= ` {crate.pity.rarity} or better is guaranteed at least once every {crate.pity.within} opens.`
	end
	Ui.label({
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -40, 0, 34),
		Font = Ui.FontBody,
		TextSize = 14,
		TextColor3 = C.Muted,
		Text = note,
		ZIndex = 21,
	}, overlay)

	local holder = Ui.make("Frame", {
		Position = UDim2.fromOffset(20, 86),
		Size = UDim2.new(1, -40, 1, -146),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, overlay)
	local list = scroller(holder)
	for i, line in CrateRoller.getOdds(crateId) do
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 28),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 21,
		}, list)
		Ui.corner(row, 6)
		Ui.label({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 15,
			Text = line.name,
			ZIndex = 22,
		}, row)
		Ui.label({
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.25, 0, 1, 0),
			TextSize = 14,
			TextColor3 = rarityColor(line.rarity),
			Text = line.rarity,
			ZIndex = 22,
		}, row)
		Ui.label({
			Position = UDim2.fromScale(0.75, 0),
			Size = UDim2.new(0.25, -10, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 15,
			Text = string.format("%.2f%%", line.percent),
			ZIndex = 22,
		}, row)
	end

	Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 38),
		Text = "BACK",
		ZIndex = 21,
	}, hideOverlay, overlay)
	overlay.Visible = true
end

--------------------------------------------------------------------------------
-- Overlay: crate opening reel
--------------------------------------------------------------------------------

local REEL_TILES = 46
local REEL_WINNER = 40
local TILE_W = 120
local REEL_W = CONTENT_W - 40

local function randomItemFrom(crateId: string): string
	local lines = CrateRoller.getOdds(crateId)
	local roll = rng:NextNumber() * 100
	for _, line in lines do
		roll -= line.percent
		if roll <= 0 then
			return line.itemId
		end
	end
	return lines[#lines].itemId
end

local function reelTile(parent: Instance, itemId: string, order: number)
	local item = Cosmetics.Items[itemId]
	local slot = Ui.make("Frame", {
		Size = UDim2.new(0, TILE_W, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		ZIndex = 22,
	}, parent)
	local tile = Ui.make("Frame", {
		Position = UDim2.fromOffset(4, 6),
		Size = UDim2.new(1, -8, 1, -12),
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, slot)
	Ui.corner(tile, 8)
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = rarityColor(item.rarity),
		BorderSizePixel = 0,
		ZIndex = 23,
	}, tile)
	local preview = swatch(tile, item, UDim2.new(1, -16, 0, 50), UDim2.fromOffset(8, 10))
	preview.ZIndex = 23
	for _, child in preview:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 24
		end
	end
	Ui.label({
		Position = UDim2.fromOffset(4, 66),
		Size = UDim2.new(1, -8, 0, 40),
		TextSize = 13,
		Text = item.name,
		ZIndex = 23,
	}, tile)
end

local function showResult(crateId: string, reply: any)
	clear(overlay)
	local item = Cosmetics.Items[reply.itemId]
	Ui.label({
		Position = UDim2.fromOffset(20, 30),
		Size = UDim2.new(1, -40, 0, 30),
		Font = Ui.FontHeavy,
		TextSize = 28,
		TextColor3 = if reply.duplicate then C.Muted else C.Good,
		Text = if reply.duplicate then "DUPLICATE" else "NEW!",
		ZIndex = 21,
	}, overlay)
	local card = itemCard(overlay, reply.itemId, 0)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 80)
	card.Size = UDim2.fromOffset(200, 150)
	for _, child in card:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 22
		end
	end
	card.ZIndex = 21
	Ui.label({
		Position = UDim2.fromOffset(20, 246),
		Size = UDim2.new(1, -40, 0, 24),
		TextSize = 17,
		TextColor3 = if reply.duplicate then C.Scrap else rarityColor(item.rarity),
		Text = if reply.duplicate
			then `You already had this: +{reply.scrap} Scrap`
			else `{item.rarity} {Cosmetics.KindNames[item.kind] or item.kind}`,
		ZIndex = 21,
	}, overlay)

	local buttons = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(500, 44),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, overlay)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buttons)

	local function done()
		busy = false
		hideOverlay()
		render()
	end
	if not reply.duplicate then
		Ui.button({
			Size = UDim2.fromOffset(150, 44),
			LayoutOrder = 1,
			BackgroundColor3 = C.Good,
			Text = "EQUIP",
			ZIndex = 22,
		}, function()
			local equipReply = PlayerState.action("Equip", reply.itemId)
			if not equipReply.ok then
				failToast(equipReply)
			end
			done()
		end, buttons)
	end
	Ui.button({
		Size = UDim2.fromOffset(150, 44),
		LayoutOrder = 2,
		BackgroundColor3 = C.Accent,
		Text = "OPEN ANOTHER",
		ZIndex = 22,
	}, function()
		busy = false
		hideOverlay()
		render()
		openCrate(crateId) -- the server checks the balance again
	end, buttons)
	Ui.button({
		Size = UDim2.fromOffset(150, 44),
		LayoutOrder = 3,
		Text = "OK",
		ZIndex = 22,
	}, done, buttons)
end

local function playReel(crateId: string, reply: any)
	clear(overlay)
	local crate = Cosmetics.Crates[crateId]
	Ui.label({
		Position = UDim2.fromOffset(20, 30),
		Size = UDim2.new(1, -40, 0, 30),
		Font = Ui.FontHeavy,
		TextSize = 24,
		Text = `Opening {crate.name}...`,
		ZIndex = 21,
	}, overlay)

	local viewport = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(REEL_W, 150),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 21,
	}, overlay)
	Ui.corner(viewport, 10)
	local strip = Ui.make("Frame", {
		Size = UDim2.new(0, TILE_W * REEL_TILES, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, viewport)
	Ui.list(strip, 0, true)
	for i = 1, REEL_TILES do
		reelTile(strip, if i == REEL_WINNER then reply.itemId else randomItemFrom(crateId), i)
	end
	Ui.make("Frame", { -- center marker
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, viewport)

	-- Land the winner under the marker, a bit off-center so it feels less rigged.
	local winnerCenter = (REEL_WINNER - 0.5) * TILE_W + rng:NextNumber(-0.35, 0.35) * TILE_W
	local finalX = REEL_W / 2 - winnerCenter
	local tween = TweenService:Create(
		strip,
		TweenInfo.new(4.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(finalX, 0) }
	)

	-- Tick sound each time a tile passes the marker.
	local lastTile = -1
	local ticker = RunService.RenderStepped:Connect(function()
		local passed = math.floor((REEL_W / 2 - strip.Position.X.Offset) / TILE_W)
		if passed ~= lastTile then
			lastTile = passed
			Sounds.play("CrateTick", 1 + rng:NextNumber() * 0.1)
		end
	end)

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		ticker:Disconnect()
		tween:Cancel()
		Sounds.play("CrateReveal")
		showResult(crateId, reply)
	end
	Ui.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(140, 38),
		Text = "SKIP",
		ZIndex = 21,
	}, finish, overlay)

	overlay.Visible = true
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			task.wait(0.4)
			finish()
		end
	end)
	tween:Play()
end

openCrate = function(crateId: string)
	if busy then
		return
	end
	busy = true
	local reply = PlayerState.action("OpenCrate", crateId)
	if not reply.ok then
		busy = false
		failToast(reply)
		return
	end
	playReel(crateId, reply)
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

local function renderCrates()
	local d = data()
	local list = scroller(content, Vector2.new(230, 330))
	local crateIds = {}
	for crateId in Cosmetics.Crates do
		table.insert(crateIds, crateId)
	end
	table.sort(crateIds, function(a, b)
		return (Cosmetics.Crates[a].order or 0) < (Cosmetics.Crates[b].order or 0)
	end)

	for i, crateId in crateIds do
		local crate = Cosmetics.Crates[crateId]
		local ownedCount = d.Crates[crateId] or 0
		local restricted = crate.currency == "Gems" and player:GetAttribute("PaidRandomItemsRestricted") ~= false

		local card = Ui.make("Frame", { LayoutOrder = i, BackgroundColor3 = C.PanelLight, BorderSizePixel = 0 }, list)
		Ui.corner(card, 10)
		Ui.padding(card, 12)
		Ui.list(card, 4)

		Ui.label({ Size = UDim2.new(1, 0, 0, 26), Font = Ui.FontHeavy, TextSize = 20, Text = crate.name, LayoutOrder = 1 }, card)
		Ui.label({
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 16,
			TextColor3 = currencyColor(crate.currency),
			Text = `{Ui.formatNumber(crate.price)} {crate.currency}`,
			LayoutOrder = 2,
		}, card)

		-- Odds per rarity, right on the card.
		local total = 0
		for _, weight in crate.odds do
			total += weight
		end
		for r, rarity in Cosmetics.RarityOrder do
			local weight = crate.odds[rarity]
			if weight then
				Ui.label({
					Size = UDim2.new(1, 0, 0, 16),
					Font = Ui.FontBody,
					TextSize = 13,
					TextColor3 = rarityColor(rarity),
					Text = string.format("%s  %.1f%%", rarity, weight / total * 100),
					LayoutOrder = 10 + r,
				}, card)
			end
		end

		if crate.pity then
			local left = crate.pity.within - (d.Pity[crateId] or 0)
			Ui.label({
				Size = UDim2.new(1, 0, 0, 30),
				Font = Ui.FontBody,
				TextSize = 12,
				TextColor3 = C.Muted,
				Text = `{crate.pity.rarity}+ guaranteed within {left} opens`,
				LayoutOrder = 20,
			}, card)
		end

		local openText = if ownedCount > 0 then `OPEN FREE ({ownedCount})` else "OPEN"
		if restricted and ownedCount == 0 then
			Ui.label({
				Size = UDim2.new(1, 0, 0, 36),
				Font = Ui.FontBody,
				TextSize = 13,
				TextColor3 = C.Muted,
				Text = "Not available in your region",
				LayoutOrder = 30,
			}, card)
		else
			Ui.button({
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundColor3 = if ownedCount > 0 then C.Good else C.Accent,
				Font = Ui.FontHeavy,
				Text = openText,
				LayoutOrder = 30,
			}, function()
				openCrate(crateId)
			end, card)
		end
		Ui.button({
			Size = UDim2.new(1, 0, 0, 30),
			TextSize = 14,
			Text = "SEE ALL ODDS",
			LayoutOrder = 31,
		}, function()
			showOdds(crateId)
		end, card)
	end
end

-- One countdown label at a time (featured shop / daily challenges both reset at UTC midnight).
local countdownLabel: TextLabel? = nil
local countdownEndsAt = 0
local countdownPrefix = ""

local function renderFeatured()
	local now = workspace:GetServerTimeNow()
	if not featuredCache or now >= featuredCache.resetsAt then
		Ui.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading today's shop...", TextColor3 = C.Muted }, content)
		task.spawn(function()
			local reply = PlayerState.action("GetFeatured")
			if reply.ok then
				featuredCache = { items = reply.items, resetsAt = reply.resetsAt }
				if isOpen and currentTab == "Featured" and not busy then
					render()
				end
			else
				failToast(reply)
			end
		end)
		return
	end

	countdownLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Muted,
		TextSize = 15,
		Text = "",
	}, content)
	countdownEndsAt = featuredCache.resetsAt
	countdownPrefix = "New items in"
	local holder = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
	}, content)
	local grid = scroller(holder, Vector2.new(170, 170))
	for i, itemId in featuredCache.items do
		local item = Cosmetics.Items[itemId]
		local price = Cosmetics.Featured.prices[item.rarity] or 0
		if owns(itemId) then
			itemCard(grid, itemId, i, "OWNED")
		else
			itemCard(grid, itemId, i, `{Ui.formatNumber(price)} Gems`, C.Gems, function()
				local reply = PlayerState.action("BuyFeatured", itemId)
				if reply.ok then
					Toasts.show("PURCHASED", item.name, C.Good)
				else
					failToast(reply)
				end
			end)
		end
	end
end

local function fetchRobuxPrice(id: number, infoType: Enum.InfoType, label: TextLabel, fallback: number)
	label.Text = `R$ {fallback}`
	if id == 0 then
		return
	end
	if robuxPrices[id] then
		label.Text = `R$ {robuxPrices[id]}`
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and info and info.PriceInRobux then
			robuxPrices[id] = info.PriceInRobux
			if label.Parent then
				label.Text = `R$ {info.PriceInRobux}`
			end
		end
	end)
end

local function promptProduct(id: number)
	if id == 0 then
		Toasts.show("Not set up yet", "Add this product's ID in Config/Products", C.Muted)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function renderGems()
	local d = data()
	local list = scroller(content)

	local function card(order: number, height: number, accent: Color3): Frame
		local frame = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, height),
			BackgroundColor3 = C.PanelLight,
			BorderSizePixel = 0,
			LayoutOrder = order,
		}, list)
		Ui.corner(frame, 10)
		Ui.stroke(frame, accent, 2)
		return frame
	end

	local function buyButton(parent: Instance, id: number, infoType: Enum.InfoType, fallback: number, onClick: () -> ())
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(130, 40),
			BackgroundColor3 = C.Good,
			Font = Ui.FontHeavy,
		}, onClick, parent)
		fetchRobuxPrice(id, infoType, button :: any, fallback)
	end

	-- Starter Pack: best value, one per account.
	local starter = Products.DevProducts.StarterPack
	if not d.StarterPackBought then
		local item = Cosmetics.Items[starter.item]
		local frame = card(0, 84, C.Taps)
		Ui.label({
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -180, 0, 26),
			Font = Ui.FontHeavy,
			TextSize = 22,
			TextColor3 = C.Taps,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "STARTER PACK · ONE TIME ONLY",
		}, frame)
		Ui.label({
			Position = UDim2.fromOffset(16, 40),
			Size = UDim2.new(1, -180, 0, 34),
			Font = Ui.FontBody,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `{starter.gems} Gems + exclusive {item.name} {item.rarity} sniper skin`,
		}, frame)
		buyButton(frame, starter.id, Enum.InfoType.Product, starter.robux, function()
			promptProduct(starter.id)
		end)
	end

	-- Gem packs
	local packs = {}
	for key, product in Products.DevProducts do
		if key ~= "StarterPack" then
			table.insert(packs, product)
		end
	end
	table.sort(packs, function(a, b)
		return a.order < b.order
	end)
	for i, product in packs do
		local frame = card(i, 60, C.Gems)
		Ui.label({
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Font = Ui.FontHeavy,
			TextSize = 20,
			TextColor3 = C.Gems,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = product.name,
		}, frame)
		if product.tag then
			Ui.label({
				Position = UDim2.new(0.45, 0, 0, 0),
				Size = UDim2.new(0.25, 0, 1, 0),
				TextSize = 13,
				TextColor3 = C.Taps,
				Text = product.tag,
			}, frame)
		end
		buyButton(frame, product.id, Enum.InfoType.Product, product.robux, function()
			promptProduct(product.id)
		end)
	end

	-- VIP pass
	local vip = Products.GamePasses.VIP
	local frame = card(100, 40 + #vip.perks * 20, Color3.fromRGB(255, 200, 60))
	Ui.label({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -180, 0, 26),
		Font = Ui.FontHeavy,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 200, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "VIP PASS",
	}, frame)
	for i, perk in vip.perks do
		Ui.label({
			Position = UDim2.fromOffset(16, 16 + i * 20),
			Size = UDim2.new(1, -180, 0, 20),
			Font = Ui.FontBody,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `• {perk}`,
		}, frame)
	end
	if player:GetAttribute("VIP") then
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(130, 40),
			Font = Ui.FontHeavy,
			TextColor3 = C.Good,
			Text = "OWNED",
		}, frame)
	else
		buyButton(frame, vip.id, Enum.InfoType.GamePass, vip.robux, function()
			if vip.id == 0 then
				Toasts.show("Not set up yet", "Add the VIP pass ID in Config/Products", C.Muted)
			else
				MarketplaceService:PromptGamePassPurchase(player, vip.id)
			end
		end)
	end
end

local function renderLocker()
	local d = data()

	local filters = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, content)
	Ui.list(filters, 6, true)
	for i, kind in Cosmetics.Kinds do
		Ui.button({
			Size = UDim2.fromOffset(140, 32),
			LayoutOrder = i,
			TextSize = 14,
			BackgroundColor3 = if kind == lockerKind then C.Accent else C.PanelLight,
			Text = string.upper(Cosmetics.KindNames[kind]),
		}, function()
			lockerKind = kind
			render()
		end, filters)
	end

	local holder = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
	}, content)
	local grid = scroller(holder, Vector2.new(170, 150))

	local ids = {}
	for itemId, item in Cosmetics.Items do
		if item.kind == lockerKind then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids, function(a, b)
		local ia, ib = Cosmetics.Items[a], Cosmetics.Items[b]
		local oa, ob = owns(a), owns(b)
		if oa ~= ob then
			return oa -- owned first
		end
		if ia.rarity ~= ib.rarity then
			return Cosmetics.Rarities[ia.rarity].rank > Cosmetics.Rarities[ib.rarity].rank
		end
		return ia.name < ib.name
	end)

	for i, itemId in ids do
		local item = Cosmetics.Items[itemId]
		if owns(itemId) then
			local equipped = d.Equipped[item.kind] == itemId
			itemCard(grid, itemId, i, if equipped then "EQUIPPED" else "EQUIP", if equipped then C.Good else C.Panel, function()
				local reply = if equipped
					then PlayerState.action("Unequip", item.kind)
					else PlayerState.action("Equip", itemId)
				if not reply.ok then
					failToast(reply)
				end
			end)
		elseif item.vipOnly then
			itemCard(grid, itemId, i, "VIP ONLY", C.Panel, function()
				currentTab = "Gems"
				render()
			end)
		elseif item.exclusive then
			itemCard(grid, itemId, i, "STARTER PACK", C.Panel, function()
				currentTab = "Gems"
				render()
			end)
		else
			local cost = Cosmetics.CraftCost[item.rarity] or 0
			itemCard(grid, itemId, i, `CRAFT · {Ui.formatNumber(cost)} Scrap`, C.Panel, function()
				local reply = PlayerState.action("Craft", itemId)
				if reply.ok then
					Toasts.show("CRAFTED", item.name, C.Good)
				else
					failToast(reply)
				end
			end)
		end
	end
end

local function renderDaily()
	local d = data()
	local daily = d.Daily or {}
	local list = scroller(content)

	-- Login streak: a 7-day strip, days already collected this cycle in green.
	local streak = daily.streak or 0
	Ui.label({
		Size = UDim2.new(1, -10, 0, 26),
		Font = Ui.FontHeavy,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `LOGIN STREAK: {streak} DAY{if streak == 1 then "" else "S"}`,
		LayoutOrder = 1,
	}, list)
	local strip = Ui.make("Frame", { Size = UDim2.new(1, -10, 0, 86), BackgroundTransparency = 1, LayoutOrder = 2 }, list)
	Ui.list(strip, 8, true)
	local cycleDay = if streak > 0 then ((streak - 1) % #Daily.loginRewards) + 1 else 0
	for i, reward in Daily.loginRewards do
		local collected = i <= cycleDay
		local box = Ui.make("Frame", {
			Size = UDim2.fromOffset(92, 86),
			BackgroundColor3 = if collected then C.Good else C.PanelLight,
			BackgroundTransparency = if collected then 0.4 else 0,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, strip)
		Ui.corner(box, 8)
		if i == cycleDay then
			Ui.stroke(box, C.Good, 2)
		end
		Ui.label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Text = `DAY {i}` }, box)
		Ui.label({
			Position = UDim2.fromOffset(4, 26),
			Size = UDim2.new(1, -8, 1, -30),
			Font = Ui.FontBody,
			TextSize = 12,
			TextColor3 = C.Taps,
			Text = Economy.describeReward(reward),
		}, box)
	end

	Ui.label({
		Size = UDim2.new(1, -10, 0, 30),
		Font = Ui.FontHeavy,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "TODAY'S CHALLENGES",
		LayoutOrder = 3,
	}, list)

	local progressById = daily.progress or {}
	local doneById = daily.done or {}
	for i, id in daily.challenges or {} do
		local challenge = Daily.Challenges[id]
		if challenge then
			local progress = progressById[id] or 0
			local done = doneById[id] == true
			local row = Ui.make("Frame", {
				Size = UDim2.new(1, -10, 0, 58),
				BackgroundColor3 = C.PanelLight,
				BorderSizePixel = 0,
				LayoutOrder = 10 + i,
			}, list)
			Ui.corner(row, 8)
			if done then
				Ui.stroke(row, C.Good, 2)
			end
			Ui.label({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(0.6, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = 16,
				Text = challenge.text,
			}, row)
			Ui.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 6),
				Size = UDim2.new(0.4, -12, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 14,
				TextColor3 = C.Taps,
				Text = Economy.describeReward(challenge.reward),
			}, row)
			local barBack = Ui.make("Frame", {
				Position = UDim2.fromOffset(12, 36),
				Size = UDim2.new(1, -110, 0, 10),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
			}, row)
			Ui.corner(barBack, 5)
			local fill = Ui.make("Frame", {
				Size = UDim2.fromScale(math.clamp(progress / challenge.goal, 0, 1), 1),
				BackgroundColor3 = C.Good,
				BorderSizePixel = 0,
			}, barBack)
			Ui.corner(fill, 5)
			Ui.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 30),
				Size = UDim2.fromOffset(86, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 14,
				TextColor3 = if done then C.Good else C.Muted,
				Text = if done then "DONE" else `{progress} / {challenge.goal}`,
			}, row)
		end
	end

	countdownLabel = Ui.label({
		Size = UDim2.new(1, -10, 0, 24),
		Font = Ui.FontBody,
		TextSize = 14,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		LayoutOrder = 100,
	}, list)
	countdownEndsAt = Featured.resetsAt(Featured.dayNumber(workspace:GetServerTimeNow()))
	countdownPrefix = "New challenges in"
end

local RENDERERS = {
	Crates = renderCrates,
	Featured = renderFeatured,
	Gems = renderGems,
	Locker = renderLocker,
	Daily = renderDaily,
}


render = function()
	if not isOpen or busy then
		return
	end
	updateBalance()
	titleLabel.Text = if currentTab == "Locker" then "LOCKER" elseif currentTab == "Daily" then "DAILY" else "SHOP"
	for tab, button in tabButtons do
		button.BackgroundColor3 = if tab == currentTab then C.Accent else C.PanelLight
	end
	countdownLabel = nil
	clear(content)
	if not data() then
		Ui.label({ Size = UDim2.new(1, 0, 0, 30), Text = "Loading your profile...", TextColor3 = C.Muted }, content)
		return
	end
	RENDERERS[currentTab]()
end

open = function(tab: string)
	currentTab = tab
	isOpen = true
	window.Visible = true
	MenuState.set("Shop", true)
	render()
end

close = function()
	if busy then
		return
	end
	isOpen = false
	window.Visible = false
	hideOverlay()
	MenuState.set("Shop", false)
end

local function toggle(tab: string)
	if isOpen and currentTab == tab then
		close()
	else
		open(tab)
	end
end

--------------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------------

Ui.button({
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C.Accent,
	Font = Ui.FontHeavy,
	Text = if touchOnly then "SHOP" else "SHOP [B]",
	LayoutOrder = 1,
}, function()
	toggle("Crates")
end, side)
Ui.button({
	Size = UDim2.new(1, 0, 0, 44),
	Font = Ui.FontHeavy,
	Text = if touchOnly then "LOCKER" else "LOCKER [L]",
	LayoutOrder = 2,
}, function()
	toggle("Locker")
end, side)
Ui.button({
	Size = UDim2.new(1, 0, 0, 44),
	Font = Ui.FontHeavy,
	Text = if touchOnly then "DAILY" else "DAILY [J]",
	LayoutOrder = 3,
}, function()
	toggle("Daily")
end, side)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggle("Crates")
	elseif input.KeyCode == Enum.KeyCode.L then
		toggle("Locker")
	elseif input.KeyCode == Enum.KeyCode.J then
		toggle("Daily")
	end
end)

PlayerState.onChanged(function()
	if isOpen then
		updateBalance()
		render()
	end
end)
player:GetAttributeChangedSignal("VIP"):Connect(render)
player:GetAttributeChangedSignal("PaidRandomItemsRestricted"):Connect(render)

-- Countdown (featured shop / daily challenges)
task.spawn(function()
	while true do
		task.wait(1)
		if countdownLabel and countdownLabel.Parent then
			local left = math.max(0, countdownEndsAt - workspace:GetServerTimeNow())
			local hours = math.floor(left / 3600)
			countdownLabel.Text = `{countdownPrefix} {hours}h {Ui.formatTime(left % 3600)}`
			if left <= 0 then
				featuredCache = nil
				task.wait(2) -- let the server roll over first
				render()
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- VIP chat tag (new TextChatService chat only)
--------------------------------------------------------------------------------

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local sender = Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") then
			properties.PrefixText = `<font color="#FFC83C">[VIP]</font> {message.PrefixText}`
		end
	end
	return properties
end
