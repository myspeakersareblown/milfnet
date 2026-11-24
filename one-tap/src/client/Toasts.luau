--[[
	Toasts: small stacked pop-up messages under the round status bar.
	  Toasts.show("LEVEL 5!", "+50 Taps", Color3)
]]

local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent:WaitForChild("Ui"))

local C = Ui.Colors
local gui = Ui.screenGui("Toasts", 5)

local holder = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(360, 300),
	BackgroundTransparency = 1,
}, gui)
Ui.list(holder, 6)

local Toasts = {}
local order = 0
local MAX_VISIBLE = 4

function Toasts.show(title: string, text: string?, color: Color3?)
	order += 1
	local toast = Ui.panel({
		Size = UDim2.new(1, 0, 0, if text and text ~= "" then 54 else 34),
		LayoutOrder = order,
		BackgroundTransparency = 0.1,
	}, holder)
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color or C.Accent
		stroke.Thickness = 2
	end
	local titleLabel = Ui.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Ui.FontHeavy,
		TextSize = 19,
		TextColor3 = color or C.Text,
		Text = title,
	}, toast)
	local textLabel = Ui.label({
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Ui.FontBody,
		TextSize = 14,
		TextColor3 = C.Muted,
		Text = text or "",
	}, toast)

	-- Drop the oldest if too many are stacked.
	local toasts = {}
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - MAX_VISIBLE do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if not toast.Parent then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(titleLabel, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(textLabel, fade, { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

return Toasts
