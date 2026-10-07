local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local toastRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Toast")

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name: string, size: UDim2, position: UDim2, font: Enum.Font, anchor: Vector2?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.AnchorPoint = anchor or Vector2.zero
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextScaled = true
	l.Font = font
	l.Parent = gui
	return l
end

local top = Vector2.new(0.5, 0)
local timerLabel = label("Timer", UDim2.fromOffset(360, 34), UDim2.new(0.5, 0, 0, 6), Enum.Font.GothamBlack, top)
local goalLabel = label("Goal", UDim2.fromOffset(560, 24), UDim2.new(0.5, 0, 0, 42), Enum.Font.GothamBold, top)
local statLabel = label("Stats", UDim2.fromOffset(560, 22), UDim2.new(0.5, 0, 0, 68), Enum.Font.Gotham, top)
local banner = label("Banner", UDim2.fromOffset(760, 90), UDim2.new(0.5, 0, 0.3, 0), Enum.Font.GothamBlack, Vector2.new(0.5, 0.5))
banner.TextStrokeTransparency = 0
local status = label("Status", UDim2.fromOffset(700, 44), UDim2.new(0.5, 0, 0.42, 0), Enum.Font.GothamBold, Vector2.new(0.5, 0.5))
status.TextColor3 = Color3.fromRGB(255, 230, 140)
local toast = label("Toast", UDim2.fromOffset(560, 28), UDim2.new(0.5, 0, 1, -110), Enum.Font.GothamBold, Vector2.new(0.5, 0))
toast.Text = ""
local wins = label("Wins", UDim2.fromOffset(200, 22), UDim2.new(1, -12, 0, 6), Enum.Font.GothamBold, Vector2.new(1, 0))
wins.TextXAlignment = Enum.TextXAlignment.Right

-- 左下：子どもはスタミナと水風船、鬼はスキルのクールダウン
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(280, 86)
panel.Position = UDim2.new(0, 12, 1, isTouch and -190 or -100)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local panelText = Instance.new("TextLabel")
panelText.Size = UDim2.new(1, -16, 0, 40)
panelText.Position = UDim2.fromOffset(8, 6)
panelText.BackgroundTransparency = 1
panelText.TextColor3 = Color3.new(1, 1, 1)
panelText.TextXAlignment = Enum.TextXAlignment.Left
panelText.TextYAlignment = Enum.TextYAlignment.Top
panelText.TextSize = 16
panelText.Font = Enum.Font.GothamBold
panelText.Parent = panel

local staminaBack = Instance.new("Frame")
staminaBack.Size = UDim2.new(1, -16, 0, 12)
staminaBack.Position = UDim2.new(0, 8, 1, -22)
staminaBack.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
staminaBack.BorderSizePixel = 0
staminaBack.Parent = panel
local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.fromScale(1, 1)
staminaFill.BackgroundColor3 = Color3.fromRGB(90, 210, 120)
staminaFill.BorderSizePixel = 0
staminaFill.Parent = staminaBack

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function refresh()
	local phase = workspace:GetAttribute("Phase") or "Lobby"
	local role = attr("Role", "Spectator")
	local left = workspace:GetAttribute("TimeLeft") or 0
	local charms = workspace:GetAttribute("Charms") or 0
	local gate = workspace:GetAttribute("GateOpen") or false

	if phase == "Chase" then
		timerLabel.Text = `チャイムまで {math.floor(left / 60)}:{string.format("%02d", left % 60)}`
	elseif phase == "Hide" then
		timerLabel.Text = "隠れろ！"
	else
		timerLabel.Text = ({ Lobby = "待機中", Prep = "準備中", Result = "結果" })[phase] or ""
	end

	if role == "Oni" then
		goalLabel.Text = "あなたは【鬼】子どもを全員つかまえろ！"
		goalLabel.TextColor3 = Color3.fromRGB(255, 120, 110)
	elseif role == "Kid" then
		goalLabel.Text = gate and "校門が開いた！ 外へ走れ！" or `あなたは【子ども】お守りを{Config.CharmsNeeded}個集めて校門から脱出！`
		goalLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	else
		goalLabel.Text = phase == "Lobby" and "プレイヤー待ち..." or "次の鬼ごっこから参加します"
		goalLabel.TextColor3 = Color3.new(1, 1, 1)
	end

	statLabel.Text = phase == "Chase" and `お守り {charms}/{Config.CharmsNeeded}　校門 {gate and "開" or "閉"}　のこり {workspace:GetAttribute("FreeKids") or 0}人　ろうや {workspace:GetAttribute("CapturedKids") or 0}　脱出 {workspace:GetAttribute("EscapedKids") or 0}` or ""
	banner.Text = workspace:GetAttribute("Banner") or ""
	wins.Text = `勝利 {attr("Wins", 0)}`

	-- 状態メッセージ
	if attr("Captured", false) and role == "Kid" then
		status.Text = "つかまった… 仲間が助けに来るのを待とう"
	elseif attr("Escaped", false) then
		status.Text = "脱出成功！ みんなを応援しよう"
	else
		status.Text = ""
	end

	panel.Visible = (role == "Kid" or role == "Oni") and (phase == "Hide" or phase == "Chase")
	if role == "Oni" then
		local function cd(name: string, key: string, text: string): string
			local remain = attr(name, 0)
			return `{key} {text} {remain > 0 and remain .. "s" or "OK"}`
		end
		panelText.Text = cd("DashCD", "Q", "ダッシュ") .. "\n" .. cd("SenseCD", "E", "鬼の鼻") .. "　" .. cd("SlamCD", "R", "どーん")
		staminaBack.Visible = false
	else
		panelText.Text = `水風船 ×{attr("Balloons", 0)}　（Shift ダッシュ / F 投げる）`
		staminaBack.Visible = true
		staminaFill.Size = UDim2.fromScale(math.clamp(attr("Stamina", 100) / Config.Kid.StaminaMax, 0, 1), 1)
	end
end

for _, name in { "Phase", "TimeLeft", "Charms", "GateOpen", "Banner", "FreeKids", "CapturedKids", "EscapedKids" } do
	workspace:GetAttributeChangedSignal(name):Connect(refresh)
end
for _, name in { "Role", "Stamina", "Balloons", "Captured", "Escaped", "DashCD", "SenseCD", "SlamCD", "Wins" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

local toastId = 0
toastRemote.OnClientEvent:Connect(function(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	task.delay(3, function()
		if id == toastId then
			toast.Text = ""
		end
	end)
end)

-- 操作の説明（デスクトップのみ）
if not isTouch then
	local help = Instance.new("TextLabel")
	help.Size = UDim2.fromOffset(330, 92)
	help.Position = UDim2.fromOffset(12, 12)
	help.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	help.BackgroundTransparency = 0.4
	help.TextColor3 = Color3.new(1, 1, 1)
	help.TextXAlignment = Enum.TextXAlignment.Left
	help.TextYAlignment = Enum.TextYAlignment.Top
	help.TextSize = 14
	help.Font = Enum.Font.Gotham
	help.Text = "WASD 移動 / Space ジャンプ\n子ども：Shift ダッシュ / F 水風船 / E長押し お守り・救出\n鬼：Q ダッシュ / E 鬼の鼻 / R どーん（触れると捕獲）"
	help.Parent = gui
end
