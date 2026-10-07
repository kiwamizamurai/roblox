local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local attackRemote = remotes:WaitForChild("Attack")
local toastRemote = remotes:WaitForChild("Toast")

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

-- 上：夜数・フェーズ・残り時間
local title = label("Title", UDim2.fromOffset(360, 36), UDim2.new(0.5, 0, 0, 8), Enum.Font.GothamBlack, Vector2.new(0.5, 0))

-- 上：燃料バー
local fuelBack = Instance.new("Frame")
fuelBack.Name = "FuelBar"
fuelBack.Size = UDim2.fromOffset(300, 18)
fuelBack.Position = UDim2.new(0.5, 0, 0, 50)
fuelBack.AnchorPoint = Vector2.new(0.5, 0)
fuelBack.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
fuelBack.BorderSizePixel = 0
fuelBack.Parent = gui
Instance.new("UICorner", fuelBack).CornerRadius = UDim.new(0, 6)
local fuelFill = Instance.new("Frame")
fuelFill.Size = UDim2.fromScale(1, 1)
fuelFill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
fuelFill.BorderSizePixel = 0
fuelFill.Parent = fuelBack
Instance.new("UICorner", fuelFill).CornerRadius = UDim.new(0, 6)
local fuelText = label("FuelText", UDim2.fromOffset(300, 16), UDim2.new(0.5, 0, 0, 70), Enum.Font.GothamBold, Vector2.new(0.5, 0))

-- 中央：バナー
local banner = label("Banner", UDim2.fromOffset(700, 90), UDim2.new(0.5, 0, 0.3, 0), Enum.Font.GothamBlack, Vector2.new(0.5, 0.5))
banner.TextStrokeTransparency = 0

-- 下：所持品
local inventory = label("Inventory", UDim2.fromOffset(300, 28), UDim2.new(0, 12, 1, -48), Enum.Font.GothamBold)
inventory.TextXAlignment = Enum.TextXAlignment.Left
if isTouch then
	inventory.Position = UDim2.new(0, 12, 1, -150)
end

-- 右上：ベスト
local best = label("Best", UDim2.fromOffset(200, 22), UDim2.new(1, -12, 0, 8), Enum.Font.GothamBold, Vector2.new(1, 0))
best.TextXAlignment = Enum.TextXAlignment.Right

-- 下：メッセージ
local toast = label("Toast", UDim2.fromOffset(500, 28), UDim2.new(0.5, 0, 1, -90), Enum.Font.GothamBold, Vector2.new(0.5, 0))
toast.Text = ""

local function refresh()
	local phase = workspace:GetAttribute("Phase") or "Lobby"
	local night = workspace:GetAttribute("Night") or 1
	local left = workspace:GetAttribute("TimeLeft") or 0
	local phaseText = ({ Day = "昼", Night = "夜", Countdown = "準備", Result = "結果", Lobby = "待機" })[phase] or phase
	title.Text = `{night} / {Config.Nights} 夜　{phaseText}　{(phase == "Day" or phase == "Night") and left .. "s" or ""}`
	title.TextColor3 = phase == "Night" and Color3.fromRGB(180, 160, 255) or Color3.new(1, 1, 1)

	local fuel = workspace:GetAttribute("Fuel") or 0
	local maxFuel = workspace:GetAttribute("MaxFuel") or Config.Lamp.MaxFuel
	fuelFill.Size = UDim2.fromScale(math.clamp(fuel / maxFuel, 0, 1), 1)
	fuelFill.BackgroundColor3 = fuel / maxFuel < 0.25 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(255, 200, 80)
	fuelText.Text = `ランプ燃料 {fuel}/{maxFuel}`

	banner.Text = phase == "Lobby" and "プレイヤー待ち..." or (workspace:GetAttribute("Banner") or "")

	inventory.Text = `木材 {player:GetAttribute("Wood") or 0}　スクラップ {player:GetAttribute("Scrap") or 0}　武器Lv {player:GetAttribute("WeaponLevel") or 0}`
	best.Text = `ベスト {player:GetAttribute("BestNight") or 0} 夜`
end
for _, attribute in { "Phase", "Night", "TimeLeft", "Fuel", "MaxFuel", "Banner" } do
	workspace:GetAttributeChangedSignal(attribute):Connect(refresh)
end
for _, attribute in { "Wood", "Scrap", "WeaponLevel", "BestNight" } do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

local toastId = 0
toastRemote.OnClientEvent:Connect(function(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	task.delay(2.5, function()
		if id == toastId then
			toast.Text = ""
		end
	end)
end)

-- 操作の説明（デスクトップのみ）
if not isTouch then
	local help = Instance.new("TextLabel")
	help.Size = UDim2.fromOffset(380, 88)
	help.Position = UDim2.fromOffset(12, 12)
	help.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	help.BackgroundTransparency = 0.4
	help.TextColor3 = Color3.new(1, 1, 1)
	help.TextXAlignment = Enum.TextXAlignment.Left
	help.TextYAlignment = Enum.TextYAlignment.Top
	help.TextSize = 15
	help.Font = Enum.Font.Gotham
	help.Text = "WASD 移動 / Space ジャンプ / F・クリック 攻撃\n昼：木材とスクラップを拾う　木箱でランプに燃料\n夜：霧の怪物は光の中で弱る。ランプを消すな\n作業台：スクラップで武器を強化"
	help.Parent = gui
end

-- 攻撃
ContextActionService:BindAction("Attack", function(_, state)
	if state == Enum.UserInputState.Begin then
		attackRemote:FireServer()
	end
end, false, Enum.KeyCode.F, Enum.UserInputType.MouseButton1)

if isTouch then
	local button = Instance.new("TextButton")
	button.Name = "攻撃"
	button.Text = "攻撃"
	button.Size = UDim2.fromOffset(84, 84)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -150, 1, -30)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 20
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackRemote:FireServer()
		end
	end)
end
