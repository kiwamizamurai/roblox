local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action")
local pushRemote = remotes:WaitForChild("Push")
local fightersFolder = ReplicatedStorage:WaitForChild("Fighters")

local player = Players.LocalPlayer
local myId = "P" .. player.UserId

---------------------------------------------------------------- HUD
local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.Size = UDim2.fromOffset(600, 120)
banner.Position = UDim2.new(0.5, -300, 0.25, 0)
banner.BackgroundTransparency = 1
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextStrokeTransparency = 0
banner.TextScaled = true
banner.Font = Enum.Font.GothamBlack
banner.Parent = gui

local function refreshBanner()
	local state = workspace:GetAttribute("MatchState")
	local text = workspace:GetAttribute("Banner") or ""
	if state == "Waiting" then
		text = "プレイヤー待ち..."
	end
	banner.Text = text
end
workspace:GetAttributeChangedSignal("Banner"):Connect(refreshBanner)
workspace:GetAttributeChangedSignal("MatchState"):Connect(refreshBanner)
refreshBanner()

local cardRow = Instance.new("Frame")
local isTouch = UserInputService.TouchEnabled

cardRow.Size = UDim2.fromOffset(700, 110)
if isTouch then
	-- スマホは操作ボタンと被らないよう、上に出す
	cardRow.AnchorPoint = Vector2.new(0.5, 0)
	cardRow.Position = UDim2.new(0.5, 0, 0, 6)
else
	cardRow.AnchorPoint = Vector2.new(0.5, 1)
	cardRow.Position = UDim2.new(0.5, 0, 1, -15)
end
-- 画面が狭いときは縮めて、4人ぶんでもはみ出さないようにする
local cardScale = Instance.new("UIScale", cardRow)
local camera = workspace.CurrentCamera
local function updateCardScale()
	cardScale.Scale = math.min(isTouch and 0.6 or 1, camera.ViewportSize.X / 720)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCardScale)
updateCardScale()
cardRow.BackgroundTransparency = 1
cardRow.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 12)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = cardRow

local function makeLabel(parent: Instance, size: UDim2, position: UDim2, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = font
	label.Parent = parent
	return label
end

local function makeCard(state: Folder)
	local card = Instance.new("Frame")
	card.Name = state.Name
	card.Size = UDim2.fromOffset(160, 105)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	card.BackgroundTransparency = 0.25
	card.Parent = cardRow
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = state.Name == myId and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(90, 90, 100)
	stroke.Thickness = 2

	local nameLabel = makeLabel(card, UDim2.new(1, -10, 0, 20), UDim2.fromOffset(5, 4), Enum.Font.GothamBold)
	local damageLabel = makeLabel(card, UDim2.new(1, -10, 0, 46), UDim2.fromOffset(5, 24), Enum.Font.GothamBlack)
	local stocksLabel = makeLabel(card, UDim2.new(1, -10, 0, 16), UDim2.fromOffset(5, 72), Enum.Font.GothamBold)
	stocksLabel.TextColor3 = Color3.fromRGB(255, 80, 80)

	local shieldBack = Instance.new("Frame")
	shieldBack.Size = UDim2.new(1, -16, 0, 6)
	shieldBack.Position = UDim2.new(0, 8, 1, -12)
	shieldBack.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	shieldBack.BorderSizePixel = 0
	shieldBack.Parent = card
	local shieldFill = Instance.new("Frame")
	shieldFill.Size = UDim2.fromScale(1, 1)
	shieldFill.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
	shieldFill.BorderSizePixel = 0
	shieldFill.Parent = shieldBack

	local function refresh()
		local damage = state:GetAttribute("Damage") or 0
		nameLabel.Text = state:GetAttribute("DisplayName") or state.Name
		damageLabel.Text = `{damage}%`
		-- ダメージが増えるほど白→赤に
		damageLabel.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 40, 40), math.clamp(damage / 150, 0, 1))
		stocksLabel.Text = string.rep("●", math.max(state:GetAttribute("Stocks") or 0, 0))
		shieldFill.Size = UDim2.fromScale(math.clamp((state:GetAttribute("Shield") or 0) / Config.Shield.Max, 0, 1), 1)
		card.BackgroundTransparency = state:GetAttribute("Alive") and 0.25 or 0.6
	end
	for _, attribute in { "Damage", "Stocks", "Shield", "Alive", "DisplayName" } do
		state:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()
end

fightersFolder.ChildAdded:Connect(makeCard)
fightersFolder.ChildRemoved:Connect(function(state)
	local card = cardRow:FindFirstChild(state.Name)
	if card then
		card:Destroy()
	end
end)
for _, state in fightersFolder:GetChildren() do
	makeCard(state)
end

local help = Instance.new("TextLabel")
help.Size = UDim2.fromOffset(330, 88)
help.Position = UDim2.fromOffset(12, 12)
help.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
help.BackgroundTransparency = 0.4
help.TextColor3 = Color3.new(1, 1, 1)
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextYAlignment = Enum.TextYAlignment.Top
help.TextSize = 16
help.Font = Enum.Font.Gotham
help.Text = "A/D: 移動  Space: ジャンプ(空中も可)\nF/クリック: 攻撃（W+F: 上 / S+F: 下）\nR: 飛び道具  Q: ガード（長押し）\nE または Q+A/D: 回避"
help.Visible = not isTouch
help.Parent = gui

---------------------------------------------------------------- 2D移動（デフォルト操作は切って、A/Dだけで動かす）
task.spawn(function()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if playerModule then
		require(playerModule):GetControls():Disable()
	end
end)

local function getCharacter(): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function isDown(a: Enum.KeyCode, b: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(b)
end

local touchLeft, touchRight = false, false

local function horizontalInput(): number
	local x = (touchRight and 1 or 0) - (touchLeft and 1 or 0)
	if isDown(Enum.KeyCode.A, Enum.KeyCode.Left) then
		x -= 1
	end
	if isDown(Enum.KeyCode.D, Enum.KeyCode.Right) then
		x += 1
	end
	return math.clamp(x, -1, 1)
end

RunService.RenderStepped:Connect(function()
	local _, humanoid = getCharacter()
	if humanoid then
		humanoid:Move(Vector3.new(horizontalInput(), 0, 0), false)
	end
end)

-- ジャンプと空中ジャンプ
local jumpsUsed = 0
local function jump()
	local _, humanoid = getCharacter()
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif jumpsUsed < Config.ExtraJumps then
		jumpsUsed += 1
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local function onCharacterAdded(character: Model)
	jumpsUsed = 0
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			jumpsUsed = 0
		end
	end)
end
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

---------------------------------------------------------------- 技の入力
local guardHeld = false

local function facingSign(): number
	local hrp = getCharacter()
	if hrp and math.abs(hrp.CFrame.LookVector.X) > 0.3 then
		return hrp.CFrame.LookVector.X > 0 and 1 or -1
	end
	return 1
end

local function dodgeDirection(): number
	local x = horizontalInput()
	return x ~= 0 and x or facingSign()
end

ContextActionService:BindAction("Attack", function(_, state)
	if state == Enum.UserInputState.Begin then
		local kind = "Jab"
		if isDown(Enum.KeyCode.W, Enum.KeyCode.Up) then
			kind = "Up"
		elseif isDown(Enum.KeyCode.S, Enum.KeyCode.Down) then
			kind = "Down"
		end
		actionRemote:FireServer(kind)
	end
end, false, Enum.KeyCode.F, Enum.UserInputType.MouseButton1)

ContextActionService:BindAction("Special", function(_, state)
	if state == Enum.UserInputState.Begin then
		actionRemote:FireServer("Special")
	end
end, false, Enum.KeyCode.R)

ContextActionService:BindAction("Guard", function(_, state)
	if state == Enum.UserInputState.Begin then
		guardHeld = true
		actionRemote:FireServer("GuardOn")
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		guardHeld = false
		actionRemote:FireServer("GuardOff")
	end
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("Dodge", function(_, state)
	if state == Enum.UserInputState.Begin then
		actionRemote:FireServer("Dodge", dodgeDirection())
	end
end, false, Enum.KeyCode.E)

-- スマホ用の画面ボタン（タッチ端末だけ表示）
local touchGui = Instance.new("Frame")
touchGui.Name = "TouchControls"
touchGui.Size = UDim2.fromScale(1, 1)
touchGui.BackgroundTransparency = 1
touchGui.Visible = isTouch
touchGui.Parent = gui

local function touchButton(text: string, size: number, anchor: Vector2, position: UDim2, onDown: () -> (), onUp: (() -> ())?)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Size = UDim2.fromOffset(size, size)
	button.AnchorPoint = anchor
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = false
	button.TextSize = utf8.len(text) == 1 and math.floor(size * 0.45) or math.floor(size * 0.22)
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = touchGui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

	local pressed = false
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) and not pressed then
			pressed = true
			button.BackgroundTransparency = 0.1
			onDown()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) and pressed then
			pressed = false
			button.BackgroundTransparency = 0.35
			if onUp then
				onUp()
			end
		end
	end)
end

local bottomLeft, bottomRight = Vector2.new(0, 1), Vector2.new(1, 1)
touchButton("◀", 84, bottomLeft, UDim2.new(0, 20, 1, -20), function()
	touchLeft = true
	if guardHeld then
		actionRemote:FireServer("Dodge", -1)
	end
end, function()
	touchLeft = false
end)
touchButton("▶", 84, bottomLeft, UDim2.new(0, 120, 1, -20), function()
	touchRight = true
	if guardHeld then
		actionRemote:FireServer("Dodge", 1)
	end
end, function()
	touchRight = false
end)
touchButton("攻撃", 84, bottomRight, UDim2.new(1, -20, 1, -20), function()
	actionRemote:FireServer("Jab")
end)
touchButton("ジャンプ", 84, bottomRight, UDim2.new(1, -20, 1, -114), jump)
touchButton("必殺", 84, bottomRight, UDim2.new(1, -114, 1, -20), function()
	actionRemote:FireServer("Special")
end)
touchButton("ガード", 84, bottomRight, UDim2.new(1, -114, 1, -114), function()
	guardHeld = true
	actionRemote:FireServer("GuardOn")
end, function()
	guardHeld = false
	actionRemote:FireServer("GuardOff")
end)
touchButton("回避", 70, bottomRight, UDim2.new(1, -208, 1, -20), function()
	actionRemote:FireServer("Dodge", dodgeDirection())
end)
touchButton("上攻撃", 60, bottomRight, UDim2.new(1, -208, 1, -100), function()
	actionRemote:FireServer("Up")
end)
touchButton("下攻撃", 60, bottomRight, UDim2.new(1, -208, 1, -170), function()
	actionRemote:FireServer("Down")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		jump()
	elseif guardHeld then
		-- ガード中に左右 = 回避
		if input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			actionRemote:FireServer("Dodge", -1)
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			actionRemote:FireServer("Dodge", 1)
		end
	end
end)

-- 吹っ飛ばされる／回避で動く（物理はクライアントが持つので、ここで速度を与える）
pushRemote.OnClientEvent:Connect(function(velocity: Vector3, stun: number)
	local hrp, humanoid = getCharacter()
	if not (hrp and humanoid) then
		return
	end
	if stun > 0 then
		humanoid.PlatformStand = true
	end
	hrp.AssemblyLinearVelocity = velocity
	if stun > 0 then
		task.delay(stun, function()
			if humanoid.Parent and hrp.Parent then
				humanoid.PlatformStand = false
				-- 立ち上がらせて、飛ばされた向きに向ける
				local face = velocity.X >= 0 and 1 or -1
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(face, 0, 0))
			end
		end)
	end
end)
