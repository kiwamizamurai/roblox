-- 試合進行：カウントダウン → (昼 → 夜) × 30 → 勝利 or 敗北 → 再戦
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local World = require(script.Parent.World)
local Resources = require(script.Parent.Resources)
local Monsters = require(script.Parent.Monsters)
local Save = require(script.Parent.Save)

Players.RespawnTime = 4
World.build()
Monsters.init()

State.attackRemote.OnServerEvent:Connect(function(player: Player)
	if State.phase == "Day" or State.phase == "Night" then
		Monsters.playerAttack(player)
	end
end)

local function setupPlayer(player: Player)
	player:SetAttribute("Wood", 0)
	player:SetAttribute("Scrap", 0)
	player:SetAttribute("WeaponLevel", 0)
	player:SetAttribute("BestNight", 0)
	task.spawn(function()
		player:SetAttribute("BestNight", Save.getBest(player))
	end)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do -- Studioでは先に参加済みのことがある
	setupPlayer(player)
end

-- 昼と夜の見た目
local function lightingTo(clockStart: number, clockEnd: number, outdoor: Color3, fogEnd: number, fogColor: Color3, seconds: number)
	Lighting.ClockTime = clockStart
	TweenService:Create(Lighting, TweenInfo.new(math.max(seconds, 0.1), Enum.EasingStyle.Linear), {
		ClockTime = clockEnd,
		OutdoorAmbient = outdoor,
		FogEnd = fogEnd,
		FogColor = fogColor,
	}):Play()
end

local function rescueFallers()
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and hrp.Position.Y < -6 then
			hrp.CFrame = State.spawnCFrame
		end
	end
end

local function nightMonsterCount(night: number): number
	local m = Config.Monsters
	local extra = math.max(#Players:GetPlayers() - 1, 0)
	return math.min(m.MaxAlive, math.floor(m.BaseCount + m.PerNight * (night - 1) + m.PerExtraPlayer * extra))
end

-- 戻り値: 生き延びたら true、ランプが消えたら false
local function runPhase(phase: string, seconds: number): boolean
	State.setPhase(phase)
	local scale = workspace:GetAttribute("TimeScale") or 1 -- テスト用の時間短縮
	local total = seconds / scale
	if phase == "Night" then
		lightingTo(18, 23.9, Color3.fromRGB(25, 25, 50), 220, Color3.fromRGB(10, 10, 25), total)
	else
		lightingTo(6, 17, Color3.fromRGB(110, 110, 110), 1500, Color3.fromRGB(190, 200, 210), total)
	end

	local count = phase == "Night" and nightMonsterCount(State.night) or 0
	local interval = count > 0 and (total * 0.7 / count) or math.huge
	local spawned, elapsed = 0, 0

	while elapsed < total do
		local dt = task.wait(0.2)
		elapsed += dt
		workspace:SetAttribute("TimeLeft", math.max(0, math.ceil(total - elapsed)))

		State.addFuel(-(phase == "Night" and Config.Lamp.DrainNight or Config.Lamp.DrainDay) * dt)
		World.updateLamp()
		rescueFallers()

		if phase == "Night" then
			while spawned < count and elapsed >= spawned * interval do
				Monsters.spawn(State.night)
				spawned += 1
			end
			Monsters.step(dt)
		end
		if State.fuel <= 0 then
			return false
		end
	end
	return true
end

local function runGame()
	State.setPhase("Countdown")
	Monsters.clearAll(false)
	Resources.reset()
	State.setNight(1)
	State.setFuel(Config.Lamp.StartFuel)
	World.updateLamp()
	Lighting.ClockTime = 12
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Wood", 0)
		player:SetAttribute("Scrap", 0)
		player:SetAttribute("WeaponLevel", 0)
		task.spawn(function()
			player:LoadCharacter()
		end)
	end

	State.setBanner(`Last Light：{Config.Nights}夜、ランプを守れ`)
	task.wait(Config.CountdownSeconds)
	State.setBanner("")

	local survived = 0
	for night = 1, Config.Nights do
		State.setNight(night)
		if not runPhase("Day", Config.DaySeconds) then
			break
		end
		State.setBanner(`{night}夜目：霧が来る`)
		task.delay(3, function()
			State.setBanner("")
		end)
		if not runPhase("Night", Config.NightSeconds) then
			break
		end
		Monsters.clearAll(true)
		survived = night
		if table.find(Config.Milestones, night) and night < Config.Nights then
			State.setBanner(`{night}夜を生き延びた！`)
			task.delay(4, function()
				State.setBanner("")
			end)
		end
	end

	Monsters.clearAll(true)
	State.setPhase("Result")
	local won = survived >= Config.Nights
	State.setBanner(won and `救助船が到着！ {Config.Nights}夜を生き延びた！` or `ランプが消えた…  {survived}夜まで生存`)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if survived > (player:GetAttribute("BestNight") or 0) then
				player:SetAttribute("BestNight", survived)
			end
			Save.setBest(player, survived)
		end)
	end
	task.wait(Config.ResultSeconds)
	State.setBanner("")
end

while true do
	if #Players:GetPlayers() == 0 then
		State.setPhase("Lobby")
		task.wait(1)
	else
		local ok, err = pcall(runGame)
		if not ok then
			warn("試合進行でエラー:", err)
			task.wait(2)
		end
	end
end
