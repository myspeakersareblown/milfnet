--[[
	Hud: all on-screen UI, built in code so it works before any art exists.
	Swap pieces for designed UI (scope reticle image, fonts, icons) in milestone M2.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local RED = Color3.fromRGB(255, 70, 70)
local CENTER = UDim2.fromScale(0.5, 0.5)
local MIDDLE = Vector2.new(0.5, 0.5)

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local gui = make("ScreenGui", {
	Name = "OneTapHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- so the screen center matches the camera center
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

--------------------------------------------------------------------------------
-- Scope overlay: round lens, black outside, thin crosshair
--------------------------------------------------------------------------------

local scopeOverlay = make("Frame", {
	Name = "Scope",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)

local lens = make("Frame", {
	Name = "Lens",
	AnchorPoint = MIDDLE,
	Position = CENTER,
	Size = UDim2.fromScale(0.92, 0.92),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
}, scopeOverlay)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, lens)
-- A huge stroke around a round see-through frame blacks out everything outside the lens.
make("UIStroke", { Thickness = 2000, Color = BLACK }, lens)

make("Frame", {
	AnchorPoint = MIDDLE,
	Position = CENTER,
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = BLACK,
	BorderSizePixel = 0,
}, lens)
make("Frame", {
	AnchorPoint = MIDDLE,
	Position = CENTER,
	Size = UDim2.new(0, 2, 1, 0),
	BackgroundColor3 = BLACK,
	BorderSizePixel = 0,
}, lens)

--------------------------------------------------------------------------------
-- Hip crosshair (a dot)
--------------------------------------------------------------------------------

local crosshair = make("Frame", {
	Name = "Crosshair",
	AnchorPoint = MIDDLE,
	Position = CENTER,
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, crosshair)
make("UIStroke", { Thickness = 1, Color = BLACK, Transparency = 0.3 }, crosshair)

--------------------------------------------------------------------------------
-- Hitmarker
--------------------------------------------------------------------------------

local hitmarker = make("Frame", {
	Name = "Hitmarker",
	AnchorPoint = MIDDLE,
	Position = CENTER,
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 5,
}, gui)
local hitmarkerBars = {}
for _, rotation in { 45, -45 } do
	table.insert(
		hitmarkerBars,
		make("Frame", {
			AnchorPoint = MIDDLE,
			Position = CENTER,
			Size = UDim2.new(1, 0, 0, 3),
			Rotation = rotation,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, hitmarker)
	)
end

--------------------------------------------------------------------------------
-- Ammo
--------------------------------------------------------------------------------

local ammoLabel = make("TextLabel", {
	Name = "Ammo",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(260, 44),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 32,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = "",
	Visible = false,
}, gui)

--------------------------------------------------------------------------------
-- Kill feed (top right)
--------------------------------------------------------------------------------

local feed = make("Frame", {
	Name = "KillFeed",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 60),
	Size = UDim2.fromOffset(380, 160),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
}, feed)
local feedCount = 0
local FEED_MAX = 5

--------------------------------------------------------------------------------
-- Big banner ("1 TAP", "BACKSTAB")
--------------------------------------------------------------------------------

local banner = make("TextLabel", {
	Name = "Banner",
	AnchorPoint = MIDDLE,
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(700, 100),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextSize = 72,
	TextColor3 = RED,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Text = "",
}, gui)
local bannerTween: Tween? = nil

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

local Hud = {}

function Hud.setScopeOverlay(visible: boolean)
	scopeOverlay.Visible = visible
end

function Hud.setCrosshairVisible(visible: boolean)
	crosshair.Visible = visible
end

function Hud.setAmmoVisible(visible: boolean)
	ammoLabel.Visible = visible
end

function Hud.setAmmo(current: number, max: number, reloading: boolean)
	ammoLabel.Text = if reloading then "RELOADING" else `{current} / {max}`
end

local hitToken = 0
function Hud.hitmarker(special: boolean, killed: boolean)
	local color = if special then RED else WHITE
	for _, bar in hitmarkerBars do
		bar.BackgroundColor3 = color
	end
	local size = if killed then 36 else 24
	hitmarker.Size = UDim2.fromOffset(size, size)
	hitmarker.Visible = true

	hitToken += 1
	local token = hitToken
	task.delay(if killed then 0.3 else 0.15, function()
		if token == hitToken then
			hitmarker.Visible = false
		end
	end)
end

function Hud.killFeed(killerName: string, victimName: string, weaponName: string, special: boolean, killerColor: Color3?)
	local tag = ""
	if special then
		tag = if weaponName == "Sniper" then "  HEADSHOT" else "  BACKSTAB"
	end

	feedCount += 1
	local line = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.45,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = killerColor or (if killerName == player.DisplayName then Color3.fromRGB(255, 220, 90) else WHITE),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = `{killerName}  [{weaponName}]  {victimName}{tag}`,
		LayoutOrder = feedCount,
	}, feed)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, line)

	-- Keep only the newest FEED_MAX lines.
	local lines = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #lines - FEED_MAX do
		lines[i]:Destroy()
	end

	task.delay(6, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

function Hud.banner(text: string)
	if bannerTween then
		bannerTween:Cancel()
	end
	banner.Text = text
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.3
	banner.TextSize = 88

	local tween = TweenService:Create(
		banner,
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1, TextSize = 64 }
	)
	bannerTween = tween
	tween:Play()
end

return Hud
