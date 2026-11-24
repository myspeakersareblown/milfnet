--[[
	MatchClient: round status bar, map vote, and the results screen.
	Reads ReplicatedStorage.MatchState attributes (set by MatchServer).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent:WaitForChild("Ui"))

local player = Players.LocalPlayer
local MatchState = ReplicatedStorage:WaitForChild("MatchState")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MapVote = Remotes:WaitForChild("MapVote") :: RemoteEvent
local MatchResults = Remotes:WaitForChild("MatchResults") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local C = Ui.Colors
local gui = Ui.screenGui("MatchUi", 2)

--------------------------------------------------------------------------------
-- Status bar (top center)
--------------------------------------------------------------------------------

local bar = Ui.panel({
	Name = "Status",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(380, 54),
	BackgroundTransparency = 0.15,
}, gui)
local title = Ui.label({
	Size = UDim2.new(1, -16, 0, 26),
	Position = UDim2.fromOffset(8, 4),
	Font = Ui.FontHeavy,
	TextSize = 20,
	Text = "",
}, bar)
local subtitle = Ui.label({
	Size = UDim2.new(1, -16, 0, 18),
	Position = UDim2.fromOffset(8, 30),
	Font = Ui.FontBody,
	TextSize = 14,
	TextColor3 = C.Muted,
	Text = "",
}, bar)

local function timeLeft(): number
	local endsAt = MatchState:GetAttribute("PhaseEndsAt")
	if typeof(endsAt) ~= "number" or endsAt == 0 then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function updateStatus()
	local phase = MatchState:GetAttribute("Phase") or "Waiting"
	local mode = MatchState:GetAttribute("Mode") or "FFA"
	local map = MatchState:GetAttribute("Map") or ""

	if phase == "Waiting" then
		local needed = MatchState:GetAttribute("PlayersNeeded") or 0
		title.Text = "WARMUP"
		subtitle.Text = `Waiting for {needed} more player{if needed == 1 then "" else "s"} · {map}`
	elseif phase == "Intermission" then
		title.Text = `NEXT ROUND IN {Ui.formatTime(timeLeft())}`
		subtitle.Text = if touchOnly then "Tap a map to vote" else "Press V to vote for a map"
	elseif phase == "Playing" then
		local leaderName = MatchState:GetAttribute("LeaderName") or ""
		local leaderKills = MatchState:GetAttribute("LeaderKills") or 0
		local target = MatchState:GetAttribute("KillTarget") or 0
		title.Text = `{mode} · {Ui.formatTime(timeLeft())}`
		subtitle.Text = if leaderName ~= ""
			then `First to {target} · Leader: {leaderName} ({leaderKills}) · {map}`
			else `First to {target} · {map}`
	else
		title.Text = "ROUND OVER"
		subtitle.Text = `Next round in {Ui.formatTime(timeLeft())}`
	end
end

--------------------------------------------------------------------------------
-- Map vote (right side, during intermission)
--------------------------------------------------------------------------------

local votePanel = Ui.panel({
	Name = "MapVote",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(230, 60),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, gui)
Ui.padding(votePanel, 10)
Ui.list(votePanel, 8)
Ui.label({
	Size = UDim2.new(1, 0, 0, 22),
	Font = Ui.FontHeavy,
	TextSize = 18,
	Text = "VOTE FOR A MAP",
	LayoutOrder = 0,
}, votePanel)

-- PC: the mouse is locked in first person. V shows this Modal button, which frees it.
local mouseUnlock = Ui.make("TextButton", {
	Size = UDim2.fromScale(0, 0),
	BackgroundTransparency = 1,
	Text = "",
	Modal = true,
	Visible = false,
}, votePanel)

local myVote: string? = nil
local voteButtons: { TextButton } = {}

local function renderVote(options: { { id: string, name: string } }, counts: { [string]: number })
	for _, button in voteButtons do
		button:Destroy()
	end
	table.clear(voteButtons)

	if #options == 0 then
		votePanel.Visible = false
		mouseUnlock.Visible = false
		myVote = nil
		return
	end

	for i, option in options do
		local chosen = option.id == myVote
		local button = Ui.button({
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = i,
			BackgroundColor3 = if chosen then C.Accent else C.PanelLight,
			Text = `{option.name}   ({counts[option.id] or 0})`,
		}, function()
			myVote = option.id
			MapVote:FireServer(option.id)
			mouseUnlock.Visible = false -- give the mouse back to the camera
		end, votePanel)
		table.insert(voteButtons, button)
	end
	votePanel.Visible = true
end

MapVote.OnClientEvent:Connect(renderVote)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.V then
		return
	end
	if votePanel.Visible then
		mouseUnlock.Visible = not mouseUnlock.Visible
	end
end)

--------------------------------------------------------------------------------
-- Results screen
--------------------------------------------------------------------------------

local results = Ui.panel({
	Name = "Results",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 120),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, gui)
Ui.padding(results, 16)
Ui.list(results, 6)

local resultsTitle = Ui.label({
	Size = UDim2.new(1, 0, 0, 40),
	Font = Ui.FontHeavy,
	TextSize = 32,
	TextColor3 = C.Accent,
	LayoutOrder = 1,
}, results)
local resultsSubtitle = Ui.label({
	Size = UDim2.new(1, 0, 0, 20),
	Font = Ui.FontBody,
	TextSize = 15,
	TextColor3 = C.Muted,
	LayoutOrder = 2,
}, results)
local rows = Ui.make("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 3,
}, results)
Ui.list(rows, 2)
local rewardsLine = Ui.label({
	Size = UDim2.new(1, 0, 0, 24),
	Font = Ui.Font,
	TextSize = 17,
	TextColor3 = C.Taps,
	Text = "",
	LayoutOrder = 4,
}, results)

type ResultRow = { name: string, kills: number, deaths: number, rank: number }

MatchResults.OnClientEvent:Connect(function(data: { map: string, completed: boolean, winner: string?, standings: { ResultRow } })
	for _, child in rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	resultsTitle.Text = if data.winner then `{data.winner} WINS` else "ROUND OVER"
	resultsSubtitle.Text = if data.completed then data.map else `{data.map} · ended early`
	rewardsLine.Text = ""

	for i, row in data.standings do
		local isMe = row.name == player.DisplayName
		local line = Ui.make("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = if isMe then C.PanelLight else C.Panel,
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, rows)
		Ui.corner(line, 6)
		Ui.label({
			Size = UDim2.new(0.12, 0, 1, 0),
			Text = `#{row.rank}`,
			TextColor3 = if row.rank == 1 then C.Taps else C.Muted,
		}, line)
		Ui.label({
			Position = UDim2.fromScale(0.12, 0),
			Size = UDim2.new(0.58, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = row.name,
		}, line)
		Ui.label({
			Position = UDim2.fromScale(0.7, 0),
			Size = UDim2.new(0.3, 0, 1, 0),
			Text = `{row.kills} K  /  {row.deaths} D`,
			TextColor3 = C.Muted,
		}, line)
	end
	results.Visible = true
end)

-- Progression sends what you earned this round.
Notify.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "RoundRewards" and typeof(data) == "table" then
		rewardsLine.Text = `+{data.taps or 0} Taps   +{data.xp or 0} XP`
	end
end)

MatchState:GetAttributeChangedSignal("Phase"):Connect(function()
	if MatchState:GetAttribute("Phase") ~= "Results" then
		results.Visible = false
	end
	updateStatus()
end)

while true do
	updateStatus()
	task.wait(0.2)
end
