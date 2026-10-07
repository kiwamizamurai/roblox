-- ステージ生成と試合進行（待機 → カウントダウン → 対戦 → 結果 → 再戦）
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)
local Cpu = require(script.Parent.Cpu)

Players.CharacterAutoLoads = false -- スポーンは試合側で管理する

-- 既定の床とスポーンを消して、落ちられるステージを作る
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local function makePlatform(name: string, size: Vector3, position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace
	return part
end

makePlatform("MainStage", Vector3.new(60, 4, 24), Vector3.new(0, -2, 0), Color3.fromRGB(90, 140, 90))
makePlatform("PlatformL", Vector3.new(14, 1, 10), Vector3.new(-20, 9, 0), Color3.fromRGB(120, 120, 140))
makePlatform("PlatformR", Vector3.new(14, 1, 10), Vector3.new(20, 9, 0), Color3.fromRGB(120, 120, 140))

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Anchored = true
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.Position = Vector3.new(0, 0.5, 0)
spawnLocation.Transparency = 1
spawnLocation.CanCollide = false
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Parent = workspace

local roundToken = 0

local function setBanner(text: string)
	workspace:SetAttribute("Banner", text)
end

local function spawnFighter(fighter, cframe: CFrame, invincibleSeconds: number)
	if fighter.player then
		fighter.player:LoadCharacter()
		local character = fighter.player.Character
		if not character then
			return
		end
		character:WaitForChild("HumanoidRootPart")
		character:PivotTo(cframe)
		Combat.setupCharacter(fighter, character, invincibleSeconds)
	else
		local model = Cpu.createModel(fighter)
		model:PivotTo(cframe)
		Combat.setupCharacter(fighter, model, invincibleSeconds)
		Cpu.start(fighter)
	end
end

local function spawnCFrame(index: number, total: number): CFrame
	local spacing = total > 1 and math.min(16, 50 / (total - 1)) or 0
	local x = (index - (total + 1) / 2) * spacing
	return CFrame.lookAt(Vector3.new(x, 3.5, 0), Vector3.new(0, 3.5, 0))
end

local function koFighter(fighter)
	if not fighter.alive then
		return
	end
	local position = fighter.hrp and fighter.hrp.Position or Vector3.zero
	local blast = Config.Blast
	Combat.fx(
		Vector3.new(math.clamp(position.X, -blast.X, blast.X), math.clamp(position.Y, blast.MinY, blast.MaxY), 0),
		Color3.fromRGB(255, 80, 80),
		30
	)
	Combat.removeCharacter(fighter)

	local stocks = fighter.state:GetAttribute("Stocks") - 1
	fighter.state:SetAttribute("Stocks", stocks)
	fighter.state:SetAttribute("Damage", 0)

	local token = roundToken
	if stocks > 0 then
		task.delay(Config.RespawnDelay, function()
			if token ~= roundToken or not Combat.active or Combat.fighters[fighter.id] ~= fighter then
				return
			end
			-- 復活台
			local height = Config.RespawnHeight
			local platform = makePlatform("RespawnPlatform", Vector3.new(8, 1, 8), Vector3.new(0, height - 3.5, 0), Color3.fromRGB(255, 220, 120))
			Debris:AddItem(platform, 4)
			Combat.reset(fighter)
			spawnFighter(fighter, CFrame.lookAt(Vector3.new(0, height, 0), Vector3.new(1, height, 0)), Config.RespawnInvincible)
		end)
	end
end

Combat.onDeath = function(fighter, model)
	if fighter.model == model then
		koFighter(fighter)
	end
end

local function isOutOfBounds(position: Vector3): boolean
	local blast = Config.Blast
	return position.Y < blast.MinY or position.Y > blast.MaxY or math.abs(position.X) > blast.X
end

local function runRound()
	roundToken += 1
	local token = roundToken
	Combat.active = false
	workspace:SetAttribute("MatchState", "Countdown")

	-- CPUは人間が1人のときだけ参加する
	for _, fighter in Combat.fighters do
		if fighter.isCpu then
			Combat.unregister(fighter)
		end
	end
	if #Players:GetPlayers() == 1 then
		for i = 1, Config.CpuCount do
			Combat.register("CPU" .. i, i == 1 and "CPU" or ("CPU" .. i), nil, true)
		end
	end

	local list = {}
	for _, fighter in Combat.fighters do
		table.insert(list, fighter)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)

	for index, fighter in list do
		fighter.state:SetAttribute("Stocks", Config.Stocks)
		Combat.reset(fighter)
		spawnFighter(fighter, spawnCFrame(index, #list), 0)
	end

	for n = Config.CountdownSeconds, 1, -1 do
		setBanner(tostring(n))
		task.wait(1)
	end
	setBanner("GO!")
	workspace:SetAttribute("MatchState", "Fighting")
	Combat.active = true
	task.delay(1, function()
		if workspace:GetAttribute("Banner") == "GO!" then
			setBanner("")
		end
	end)

	local winner
	while true do
		local dt = task.wait(0.1)
		Combat.step(dt)
		for _, fighter in Combat.fighters do
			if fighter.alive and fighter.hrp and isOutOfBounds(fighter.hrp.Position) then
				koFighter(fighter)
			end
		end

		local remaining, last = 0, nil
		for _, fighter in Combat.fighters do
			if fighter.state:GetAttribute("Stocks") > 0 then
				remaining += 1
				last = fighter
			end
		end
		if remaining <= 1 or #Players:GetPlayers() == 0 then
			winner = remaining == 1 and last or nil
			break
		end
	end

	Combat.active = false
	workspace:SetAttribute("MatchState", "Result")
	setBanner(winner and ("勝者: " .. winner.name) or "引き分け")
	task.wait(Config.ResultSeconds)

	if token == roundToken then
		for _, fighter in Combat.fighters do
			Combat.removeCharacter(fighter)
		end
	end
end

local function onPlayerAdded(player: Player)
	if #Players:GetPlayers() > Config.MaxPlayers then
		player:Kick(`満員です（最大{Config.MaxPlayers}人）`)
		return
	end
	local fighter = Combat.register("P" .. player.UserId, player.Name, player, false)
	-- 試合の途中で入った人は、次の試合から参加する（観戦）
	fighter.state:SetAttribute("Stocks", 0)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do -- Studioでは先に参加済みのことがある
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	local fighter = Combat.byPlayer[player]
	if fighter then
		Combat.unregister(fighter)
	end
end)

while true do
	if #Players:GetPlayers() == 0 then
		workspace:SetAttribute("MatchState", "Waiting")
		task.wait(1)
	else
		local ok, err = pcall(runRound)
		if not ok then
			warn("試合進行でエラー:", err)
			task.wait(2)
		end
	end
end
