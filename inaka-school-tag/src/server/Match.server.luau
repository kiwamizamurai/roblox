-- 試合進行：役割決定 → 隠れ時間 → 追いかけ → 結果 → 再戦
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local World = require(script.Parent.World)
local Kids = require(script.Parent.Kids)
local Oni = require(script.Parent.Oni)
local Cpu = require(script.Parent.Cpu)
local Save = require(script.Parent.Save)
local Props = require(script.Parent.Props)

World.build()
State.world = World
Props.placeAll()

-- クライアントからの操作
State.actionRemote.OnServerEvent:Connect(function(player: Player, kind: any, arg: any)
	local actor = State.byPlayer[player]
	if not actor then
		return
	end
	if kind == "Sprint" then
		actor.sprinting = arg == true
	elseif kind == "Throw" then
		Kids.throw(actor, arg)
	elseif kind == "Skill" and typeof(arg) == "string" then
		Oni.skill(actor, arg)
	end
end)

for _, charm in World.charms do
	charm.prompt.Triggered:Connect(function(player: Player)
		local actor = State.byPlayer[player]
		if actor then
			Kids.collectCharm(actor, charm)
		end
	end)
end
for _, bucket in World.buckets do
	bucket.prompt.Triggered:Connect(function(player: Player)
		local actor = State.byPlayer[player]
		if actor then
			Kids.refill(actor, bucket)
		end
	end)
end
World.jailPrompt.Triggered:Connect(function(player: Player)
	local actor = State.byPlayer[player]
	if actor then
		Kids.rescue(actor)
	end
end)

-- プレイヤーの出入り
local function onPlayerAdded(player: Player)
	if #Players:GetPlayers() > Config.MaxPlayers then
		player:Kick(`満員です（最大{Config.MaxPlayers}人）`)
		return
	end
	State.newActor("P" .. player.UserId, player.Name, player, false)
	player:SetAttribute("Role", "Spectator")
	player:SetAttribute("Wins", 0)
	task.spawn(function()
		player:SetAttribute("Wins", Save.getWins(player))
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do -- Studioでは先に参加済みのことがある
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(function(player)
	local actor = State.byPlayer[player]
	if actor then
		State.removeActor(actor)
	end
end)

-- 鬼の見た目（角・赤い体・大きさ）
local function styleOni(model: Model)
	pcall(function()
		model:ScaleTo(Config.Oni.Scale)
	end)
	local red = Color3.fromRGB(205, 60, 55)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = red
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		for _, side in { -1, 1 } do
			local horn = Instance.new("Part")
			horn.Name = "Horn"
			horn.Shape = Enum.PartType.Cylinder
			horn.Size = Vector3.new(1.5, 0.5, 0.5) * Config.Oni.Scale
			horn.Color = Color3.fromRGB(245, 240, 210)
			horn.CanCollide = false
			horn.Massless = true
			horn.CFrame = head.CFrame * CFrame.new(side * 0.6 * Config.Oni.Scale, 0.8 * Config.Oni.Scale, 0) * CFrame.Angles(0, 0, math.rad(90) - side * math.rad(20))
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = horn
			weld.Parent = horn
			horn.Parent = model
		end
	end
end

local function attach(actor, model: Model)
	actor.model = model
	actor.hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	actor.humanoid = model:WaitForChild("Humanoid") :: Humanoid
	model:SetAttribute("ActorId", actor.id)
end

local function spawnActor(actor, position: Vector3)
	if actor.player then
		actor.player:LoadCharacter()
		local character = actor.player.Character
		if not character then
			return
		end
		character:WaitForChild("HumanoidRootPart")
		character:PivotTo(CFrame.new(position))
		attach(actor, character)
	else
		local shirt = actor.role == "Oni" and Color3.fromRGB(205, 60, 55)
			or Color3.fromHSV(math.random(), 0.5, 0.9)
		local model = Cpu.createModel(actor, shirt)
		model:PivotTo(CFrame.new(position))
		attach(actor, model)
	end
	if actor.role == "Oni" then
		styleOni(actor.model)
	end
	if actor.isCpu then
		actor.hrp:SetNetworkOwner(nil) -- 部品を足したあとに、サーバーの持ち物にする
	end
end

local function enforceBounds()
	for _, a in State.actors do
		if a.hrp and a.hrp.Parent then
			local p = a.hrp.Position
			if p.Y < -15 or math.abs(p.X) > Config.Bounds or math.abs(p.Z) > Config.Bounds then
				a.hrp.CFrame = CFrame.new(0, 4, 40)
			end
		end
	end
end

local function tick(dt: number)
	for _, a in State.actors do
		State.applySpeed(a)
	end
	Kids.step(dt)
	Oni.step(dt)
	Kids.checkEscape()
	enforceBounds()
	State.setCounts()
end

-- 勝敗。決まらなければ nil
local function evaluate(timeLeft: number): string?
	local total, captured, escaped = 0, 0, 0
	for _, a in State.actors do
		if a.role == "Kid" then
			total += 1
			if a.escaped then
				escaped += 1
			elseif a.captured then
				captured += 1
			end
		end
	end
	if total == 0 or not State.oni or State.actors[State.oni.id] ~= State.oni then
		return "Draw"
	end
	if escaped * 2 >= total then
		return "Kids"
	end
	if captured + escaped >= total or timeLeft <= 0 then
		return "Oni"
	end
	return nil
end

local roundIndex = 0

local function runRound()
	roundIndex += 1
	State.setPhase("Prep")
	State.setBanner("")
	State.oni = nil
	State.setCharms(0)
	State.setGate(false)
	World.setGate(false)
	World.resetCharms()
	Lighting.ClockTime = 14

	-- 前回のCPUを片づける
	local old = {}
	for _, a in State.actors do
		if a.isCpu then
			table.insert(old, a)
		end
	end
	for _, a in old do
		State.removeActor(a)
	end

	-- 役割を決める。人間が1人なら鬼はCPU
	local humans = {}
	for _, a in State.actors do
		if a.player then
			table.insert(humans, a)
		end
	end
	table.sort(humans, function(a, b)
		return a.id < b.id
	end)

	local oni
	if #humans == 1 then
		oni = State.newActor("CPU_ONI", Config.Cpu.OniName, nil, true)
	else
		oni = humans[(roundIndex - 1) % #humans + 1]
	end
	oni.role = "Oni"

	local kids = {}
	for _, h in humans do
		if h ~= oni then
			h.role = "Kid"
			table.insert(kids, h)
		end
	end
	for i = 1, math.max(0, Config.MinKids - #kids) do
		local k = State.newActor("CPU_KID" .. i, Config.Cpu.KidNames[i] or ("コドモ" .. i), nil, true)
		k.role = "Kid"
		table.insert(kids, k)
	end
	State.oni = oni

	spawnActor(oni, World.oniSpawn)
	Oni.setup(oni)
	for i, k in kids do
		spawnActor(k, World.kidSpawns[(i - 1) % #World.kidSpawns + 1])
		Kids.setup(k)
	end
	State.setCounts()

	-- 隠れ時間
	State.setPhase("Hide")
	if oni.isCpu then
		Cpu.startOni(oni)
	end
	for _, k in kids do
		if k.isCpu then
			Cpu.startKid(k)
		end
	end
	local scale = workspace:GetAttribute("TimeScale") or 1
	local hideTotal = Config.HideSeconds / scale
	local hidden = 0
	while hidden < hideTotal do
		local dt = task.wait(0.2)
		hidden += dt
		State.setBanner(`鬼が動くまで {math.max(0, math.ceil(hideTotal - hidden))}`)
		tick(dt)
	end
	State.setBanner("鬼ごっこスタート！")
	task.delay(2, function()
		if workspace:GetAttribute("Banner") == "鬼ごっこスタート！" then
			State.setBanner("")
		end
	end)

	-- 追いかけ
	State.setPhase("Chase")
	local total = Config.RoundSeconds / scale
	local elapsed = 0
	local winner
	while true do
		local dt = task.wait(0.2)
		elapsed += dt
		State.setTime(total - elapsed)
		tick(dt)
		winner = evaluate(total - elapsed)
		if winner or #Players:GetPlayers() == 0 then
			winner = winner or "Draw"
			break
		end
	end

	-- 結果
	State.setPhase("Result")
	local escaped = workspace:GetAttribute("EscapedKids") or 0
	if winner == "Kids" then
		State.setBanner(`子どもの勝ち！ {escaped}人が脱出`)
	elseif winner == "Oni" then
		State.setBanner("鬼の勝ち！")
	else
		State.setBanner("引き分け")
	end
	for _, a in State.actors do
		if a.player and ((winner == "Kids" and a.role == "Kid" and a.escaped) or (winner == "Oni" and a.role == "Oni")) then
			task.spawn(function()
				a.player:SetAttribute("Wins", (a.player:GetAttribute("Wins") or 0) + 1)
				Save.addWin(a.player)
			end)
		end
	end
	task.wait(Config.ResultSeconds)

	-- 後片づけ
	State.setBanner("")
	State.oni = nil
	for _, a in State.actors do
		a.role = "Spectator"
		a.sprinting = false
		if a.player then
			a.player:SetAttribute("Role", "Spectator")
		end
	end
end

while true do
	if #Players:GetPlayers() == 0 then
		State.setPhase("Lobby")
		task.wait(1)
	else
		local ok, err = pcall(runRound)
		if not ok then
			warn("試合進行でエラー:", err)
			task.wait(2)
		end
	end
end
