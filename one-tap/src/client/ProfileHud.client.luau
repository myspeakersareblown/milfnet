--[[
	ProfileHud: level badge, XP bar and currencies (top left), plus toast
	notifications (level ups, rewards, shop results).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))
local PlayerState = require(script.Parent:WaitForChild("PlayerState"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Cosmetics = require(Config:WaitForChild("Cosmetics"))

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local C = Ui.Colors
local gui = Ui.screenGui("ProfileHud", 1)

--------------------------------------------------------------------------------
-- Top-left card
--------------------------------------------------------------------------------

local card = Ui.panel({
	Name = "Profile",
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.fromOffset(230, 62),
	BackgroundTransparency = 0.15,
}, gui)

local badge = Ui.make("Frame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.fromOffset(46, 46),
	BackgroundColor3 = C.Accent,
	BorderSizePixel = 0,
}, card)
Ui.corner(badge, 23)
local levelLabel = Ui.label({
	Size = UDim2.fromScale(1, 1),
	Font = Ui.FontHeavy,
	TextSize = 20,
	Text = "1",
}, badge)

local xpBack = Ui.make("Frame", {
	Position = UDim2.fromOffset(62, 10),
	Size = UDim2.new(1, -72, 0, 8),
	BackgroundColor3 = C.PanelLight,
	BorderSizePixel = 0,
}, card)
Ui.corner(xpBack, 4)
local xpFill = Ui.make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.Good,
	BorderSizePixel = 0,
}, xpBack)
Ui.corner(xpFill, 4)

local xpLabel = Ui.label({
	Position = UDim2.fromOffset(62, 20),
	Size = UDim2.new(1, -72, 0, 14),
	Font = Ui.FontBody,
	TextSize = 12,
	TextColor3 = C.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, card)

local tapsLabel = Ui.label({
	Position = UDim2.fromOffset(62, 36),
	Size = UDim2.fromOffset(80, 20),
	TextSize = 15,
	TextColor3 = C.Taps,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "0 Taps",
}, card)
local gemsLabel = Ui.label({
	Position = UDim2.fromOffset(146, 36),
	Size = UDim2.fromOffset(76, 20),
	TextSize = 15,
	TextColor3 = C.Gems,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "0 Gems",
}, card)

PlayerState.onChanged(function(data)
	levelLabel.Text = tostring(data.Level)
	local need = Economy.xpForLevel(data.Level)
	local atMax = data.Level >= Economy.maxLevel
	local fraction = if atMax then 1 else math.clamp(data.XP / need, 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(fraction, 1) }):Play()
	xpLabel.Text = if atMax then "MAX LEVEL" else `{Ui.formatNumber(data.XP)} / {Ui.formatNumber(need)} XP`
	tapsLabel.Text = `{Ui.formatNumber(data.Taps)} Taps`
	gemsLabel.Text = `{Ui.formatNumber(data.Gems)} Gems`
end)

--------------------------------------------------------------------------------
-- Server notifications
--------------------------------------------------------------------------------

local function describeReward(reward: any): string
	local parts = {}
	if reward.taps then
		table.insert(parts, `+{reward.taps} Taps`)
	end
	if reward.gems then
		table.insert(parts, `+{reward.gems} Gems`)
	end
	if reward.crates then
		for crateId, count in reward.crates do
			local crate = Cosmetics.Crates[crateId]
			table.insert(parts, `+{count} {if crate then crate.name else crateId}`)
		end
	end
	return table.concat(parts, "   ")
end

Notify.OnClientEvent:Connect(function(kind: string, data: any)
	if typeof(data) ~= "table" then
		data = {}
	end
	if kind == "LevelUp" then
		Toasts.show(`LEVEL {data.level}!`, describeReward(data.reward or {}), C.Good)
	elseif kind == "Toast" then
		Toasts.show(data.title or "", data.text or "", data.color)
	end
end)
