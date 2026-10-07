-- 入力：ダッシュ・水風船・鬼のスキル（スマホは画面ボタン）
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action")
local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled

local function role(): string
	return player:GetAttribute("Role") or "Spectator"
end

local function sprint(on: boolean)
	if role() == "Kid" then
		actionRemote:FireServer("Sprint", on)
	end
end

local function throw()
	if role() == "Kid" then
		local camera = workspace.CurrentCamera
		actionRemote:FireServer("Throw", camera and camera.CFrame.LookVector or Vector3.zero)
	end
end

local function skill(name: string)
	if role() == "Oni" then
		actionRemote:FireServer("Skill", name)
	end
end

ContextActionService:BindAction("Sprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		sprint(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprint(false)
	end
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)

ContextActionService:BindAction("Throw", function(_, state)
	if state == Enum.UserInputState.Begin then
		throw()
	end
end, false, Enum.KeyCode.F, Enum.UserInputType.MouseButton1)

ContextActionService:BindAction("OniDash", function(_, state)
	if state == Enum.UserInputState.Begin then
		skill("Dash")
	end
end, false, Enum.KeyCode.Q)
ContextActionService:BindAction("OniSense", function(_, state)
	if state == Enum.UserInputState.Begin then
		skill("Sense")
	end
end, false, Enum.KeyCode.E)
ContextActionService:BindAction("OniSlam", function(_, state)
	if state == Enum.UserInputState.Begin then
		skill("Slam")
	end
end, false, Enum.KeyCode.R)

-- スマホ用の画面ボタン（タッチ端末だけ表示。役割で出し分け）
local gui = Instance.new("ScreenGui")
gui.Name = "TouchControls"
gui.ResetOnSpawn = false
gui.Enabled = isTouch
gui.Parent = player:WaitForChild("PlayerGui")

local function touchButton(text: string, size: number, position: UDim2, roleName: string, onDown: () -> (), onUp: (() -> ())?)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Size = UDim2.fromOffset(size, size)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = false
	button.TextSize = math.floor(size * 0.22)
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

	local function updateVisible()
		button.Visible = role() == roleName
	end
	player:GetAttributeChangedSignal("Role"):Connect(updateVisible)
	updateVisible()

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

-- 移動とジャンプは標準の操作（サムスティック）。ボタンはその外側に置く
touchButton("ダッシュ", 78, UDim2.new(1, -20, 1, -110), "Kid", function()
	sprint(true)
end, function()
	sprint(false)
end)
touchButton("投げる", 78, UDim2.new(1, -110, 1, -20), "Kid", throw)

touchButton("突進", 78, UDim2.new(1, -20, 1, -110), "Oni", function()
	skill("Dash")
end)
touchButton("鼻", 70, UDim2.new(1, -110, 1, -20), "Oni", function()
	skill("Sense")
end)
touchButton("どーん", 70, UDim2.new(1, -190, 1, -20), "Oni", function()
	skill("Slam")
end)
