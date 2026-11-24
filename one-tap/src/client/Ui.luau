--[[
	Ui: tiny helpers so every menu is built the same way, with one shared look.
	Restyle the whole game by editing Ui.Colors / Ui.Font.
]]

local Players = game:GetService("Players")

local Ui = {}

Ui.Colors = {
	Background = Color3.fromRGB(14, 16, 21),
	Panel = Color3.fromRGB(26, 29, 37),
	PanelLight = Color3.fromRGB(38, 42, 53),
	Stroke = Color3.fromRGB(58, 63, 78),
	Text = Color3.fromRGB(240, 242, 247),
	Muted = Color3.fromRGB(160, 166, 182),
	Accent = Color3.fromRGB(255, 70, 70), -- the "1 TAP" red
	Good = Color3.fromRGB(90, 210, 120),
	Taps = Color3.fromRGB(255, 205, 70),
	Gems = Color3.fromRGB(90, 200, 255),
	Scrap = Color3.fromRGB(190, 160, 130),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
}

Ui.Font = Enum.Font.GothamBold
Ui.FontHeavy = Enum.Font.GothamBlack
Ui.FontBody = Enum.Font.GothamMedium

function Ui.make(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Ui.corner(parent: Instance, radius: number?)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function Ui.stroke(parent: Instance, color: Color3?, thickness: number?)
	return Ui.make("UIStroke", {
		Color = color or Ui.Colors.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Ui.padding(parent: Instance, px: number)
	return Ui.make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	}, parent)
end

function Ui.list(parent: Instance, padding: number?, horizontal: boolean?)
	return Ui.make("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 6),
	}, parent)
end

function Ui.screenGui(name: string, displayOrder: number?, ignoreInset: boolean?): ScreenGui
	return Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = ignoreInset == true,
		DisplayOrder = displayOrder or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

function Ui.label(props: { [string]: any }, parent: Instance?): TextLabel
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextSize = 18,
		TextColor3 = Ui.Colors.Text,
		TextWrapped = true,
	}, nil)
	for key, value in props do
		(label :: any)[key] = value
	end
	if parent then
		label.Parent = parent
	end
	return label
end

function Ui.button(props: { [string]: any }, onClick: (() -> ())?, parent: Instance?): TextButton
	local button = Ui.make("TextButton", {
		BackgroundColor3 = Ui.Colors.PanelLight,
		AutoButtonColor = true,
		Font = Ui.Font,
		TextSize = 18,
		TextColor3 = Ui.Colors.Text,
		Text = "",
	}, nil)
	for key, value in props do
		(button :: any)[key] = value
	end
	Ui.corner(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	if parent then
		button.Parent = parent
	end
	return button
end

-- A rounded panel. Set `modal = true` on panels with buttons: a visible Modal
-- button frees the mouse while the camera is locked in first person.
function Ui.panel(props: { [string]: any }, parent: Instance?, modal: boolean?): Frame
	local frame = Ui.make("Frame", {
		BackgroundColor3 = Ui.Colors.Panel,
		BorderSizePixel = 0,
	}, nil)
	for key, value in props do
		(frame :: any)[key] = value
	end
	Ui.corner(frame, 12)
	Ui.stroke(frame)
	if modal then
		Ui.make("TextButton", {
			Name = "MouseUnlock",
			Size = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			Text = "",
			Modal = true,
		}, frame)
	end
	if parent then
		frame.Parent = parent
	end
	return frame
end

function Ui.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Ui.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

return Ui
