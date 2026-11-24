--[[
	SettingsClient: the settings panel (K, or the SETTINGS button under your
	profile card). Sliders and toggles come from Config/Settings.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent:WaitForChild("Ui"))
local MenuState = require(script.Parent:WaitForChild("MenuState"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local SettingsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Settings"))

local C = Ui.Colors
local gui = Ui.screenGui("SettingsUi", 11)
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local PANEL_W = 460
local ROW_H = 56

local panel = Ui.panel({
	Name = "Settings",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, 80 + #SettingsConfig.list * ROW_H),
	Visible = false,
	Active = true,
}, gui, true)

Ui.label({
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.fromOffset(200, 30),
	Font = Ui.FontHeavy,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "SETTINGS",
}, panel)

local rows = Ui.make("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 1, -68),
	BackgroundTransparency = 1,
}, panel)
Ui.list(rows, 4)

local refreshers: { () -> () } = {}

local function sliderRow(definition: any, order: number)
	local row = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, ROW_H - 4), BackgroundTransparency = 1, LayoutOrder = order }, rows)
	Ui.label({
		Size = UDim2.new(0.7, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		Text = definition.label,
	}, row)
	local valueLabel = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 16,
		TextColor3 = C.Muted,
	}, row)

	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		Active = true,
	}, row)
	Ui.corner(bar, 5)
	local fill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0 }, bar)
	Ui.corner(fill, 5)
	local knob = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
	}, bar)
	Ui.corner(knob, 10)

	local function refresh()
		local value = Settings.get(definition.key)
		local alpha = (value - definition.min) / (definition.max - definition.min)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = if definition.format then definition.format(value) else tostring(value)
	end
	table.insert(refreshers, refresh)

	local dragging = false
	local function setFromX(x: number)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		Settings.set(definition.key, definition.min + (definition.max - definition.min) * alpha)
		refresh()
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	bar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			dragging = false
		end
	end)
end

local function toggleRow(definition: any, order: number)
	local row = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, ROW_H - 4), BackgroundTransparency = 1, LayoutOrder = order }, rows)
	Ui.label({
		Size = UDim2.new(0.7, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		Text = definition.label,
	}, row)
	local button = Ui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(90, 34),
	}, function()
		Settings.set(definition.key, not Settings.get(definition.key))
	end, row)

	local function refresh()
		local on = Settings.get(definition.key) == true
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then C.Good else C.PanelLight
	end
	table.insert(refreshers, refresh)
end

for i, definition in SettingsConfig.list do
	if definition.kind == "slider" then
		sliderRow(definition, i)
	else
		toggleRow(definition, i)
	end
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end
Settings.onChanged(refreshAll)

local function setOpen(open: boolean)
	panel.Visible = open
	MenuState.set("Settings", open)
	if open then
		refreshAll()
	end
end

Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	Text = "X",
	Font = Ui.FontHeavy,
}, function()
	setOpen(false)
end, panel)

-- Small button under the profile card (top left).
Ui.button({
	Position = UDim2.fromOffset(12, 76),
	Size = UDim2.fromOffset(120, 30),
	TextSize = 14,
	Text = if touchOnly then "SETTINGS" else "SETTINGS [K]",
}, function()
	setOpen(not panel.Visible)
end, gui)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.K then
		setOpen(not panel.Visible)
	end
end)
