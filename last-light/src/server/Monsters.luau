-- 霧の怪物：夜に湧き、プレイヤーかランプへ向かう。光の中では弱る
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Monsters = {}

local cfg = Config.Monsters
local alive = {} -- [model] = { hp, speed, lastTouch, lastLamp }
local template: Model
local folder = Instance.new("Folder")
folder.Name = "Monsters"
folder.Parent = workspace

local lastAttack = {} -- [Player] = 時刻

local function fx(position: Vector3, color: Color3, size: number)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Size = Vector3.one
	ball.Position = position
	ball.Parent = workspace
	TweenService:Create(ball, TweenInfo.new(0.3), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.4)
end

local function setupAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	pcall(function()
		local function load(id: string)
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			return track
		end
		local run = load("rbxassetid://507767714")
		run:Play()
	end)
end

-- 最初に1回だけ呼ぶ（モデル生成で待つので）
function Monsters.init()
	local description = Instance.new("HumanoidDescription")
	local color = (Config.Event and Config.Event.MonsterColor) or Color3.fromRGB(35, 30, 45)
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color
	description.RightLegColor = color

	template = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	template.Name = "Fog"
	local humanoid = template:WaitForChild("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(255, 60, 60)
	outline.OutlineTransparency = 0.3
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = template

	template:ScaleTo(1.25)
	template.Parent = ServerStorage
end

local function nightSpeed(night: number): number
	return math.min(cfg.MaxSpeed, cfg.Speed + cfg.SpeedPerNight * (night - 1))
end

function Monsters.spawn(night: number)
	local model = template:Clone()
	local angle = math.random() * math.pi * 2
	local position = State.lampPosition + Vector3.new(math.cos(angle) * cfg.SpawnRadius, 4, math.sin(angle) * cfg.SpawnRadius)
	model:PivotTo(CFrame.new(position))
	model.Parent = folder

	local hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	hrp:SetNetworkOwner(nil)
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	setupAnimations(humanoid)

	local speed = nightSpeed(night)
	humanoid.WalkSpeed = speed
	alive[model] = {
		hp = cfg.Health + cfg.HealthPerNight * (night - 1),
		speed = speed,
		lastTouch = 0,
		lastLamp = 0,
	}
end

function Monsters.count(): number
	local n = 0
	for _ in alive do
		n += 1
	end
	return n
end

function Monsters.kill(model: Model, killer: Player?)
	local st = alive[model]
	if not st then
		return
	end
	alive[model] = nil
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		fx(hrp.Position, Color3.fromRGB(180, 120, 255), 10)
	end
	if killer and killer.Parent and math.random() < Config.Player.ScrapDropChance then
		killer:SetAttribute("Scrap", (killer:GetAttribute("Scrap") or 0) + 1)
	end
	model:Destroy()
end

function Monsters.damage(model: Model, amount: number, attacker: Player?)
	local st = alive[model]
	if not st then
		return
	end
	st.hp -= amount
	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.3
	flash.Parent = model
	Debris:AddItem(flash, 0.12)
	if st.hp <= 0 then
		Monsters.kill(model, attacker)
	end
end

function Monsters.clearAll(withEffect: boolean)
	for model in alive do
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if withEffect and hrp then
			fx(hrp.Position, Color3.fromRGB(255, 220, 150), 8)
		end
		alive[model] = nil
		model:Destroy()
	end
end

local function livingPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then
			table.insert(list, { player = player, hrp = hrp, humanoid = humanoid })
		end
	end
	return list
end

-- 0.2秒ごとに Match から呼ぶ
function Monsters.step(dt: number)
	local players = livingPlayers()
	local range = State.lightRange()
	local t = os.clock()

	for model, st in alive do
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not (model.Parent and hrp and humanoid) then
			alive[model] = nil
			continue
		end

		local pos = hrp.Position
		local flat = Vector3.new(pos.X - State.lampPosition.X, 0, pos.Z - State.lampPosition.Z)
		local lampDist = flat.Magnitude

		-- 近くのプレイヤーを優先して追う。いなければランプへ
		local target, best = nil, cfg.AggroRange
		for _, p in players do
			local d = (p.hrp.Position - pos).Magnitude
			if d < best then
				best, target = d, p
			end
		end
		humanoid:MoveTo(target and target.hrp.Position or State.lampPosition)

		-- 光の中では遅くなり、じわじわ削られる
		local inLight = lampDist < range
		humanoid.WalkSpeed = st.speed * (inLight and cfg.LightSlow or 1)
		if inLight then
			st.hp -= cfg.LightDps * dt
			if st.hp <= 0 then
				Monsters.kill(model, nil)
				continue
			end
		end

		if target and best < 5 and t - st.lastTouch >= cfg.TouchCooldown then
			st.lastTouch = t
			target.humanoid:TakeDamage(cfg.TouchDamage)
		end
		if lampDist < 9 and t - st.lastLamp >= cfg.LampHitCooldown then
			st.lastLamp = t
			State.addFuel(-cfg.LampHitFuel)
			fx(pos + Vector3.new(0, 3, 0), Color3.fromRGB(255, 80, 80), 6)
		end
	end
end

-- プレイヤーの攻撃（前方の扇形）
function Monsters.playerAttack(player: Player)
	local t = os.clock()
	if t - (lastAttack[player] or 0) < Config.Player.AttackCooldown then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (hrp and humanoid) or humanoid.Health <= 0 then
		return
	end
	lastAttack[player] = t

	local damage = Config.Player.AttackDamage + Config.Player.WeaponDamagePerLevel * (player:GetAttribute("WeaponLevel") or 0)
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit

	local swing = Instance.new("Part")
	swing.Material = Enum.Material.Neon
	swing.Color = Color3.fromRGB(255, 255, 200)
	swing.Transparency = 0.6
	swing.Anchored = true
	swing.CanCollide = false
	swing.CanQuery = false
	swing.CanTouch = false
	swing.Size = Vector3.new(Config.Player.AttackRange, 4, Config.Player.AttackRange * 0.6)
	swing.CFrame = CFrame.lookAt(hrp.Position + look * (Config.Player.AttackRange / 2), hrp.Position + look * Config.Player.AttackRange)
	swing.Parent = workspace
	Debris:AddItem(swing, 0.12)

	for model in alive do
		local mhrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if mhrp then
			local delta = mhrp.Position - hrp.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			local dist = flat.Magnitude
			if dist <= Config.Player.AttackRange and (dist < 3 or flat.Unit:Dot(look) > 0.2) then
				if dist > 0.01 then
					mhrp.AssemblyLinearVelocity = flat.Unit * 35 + Vector3.new(0, 15, 0)
				end
				Monsters.damage(model, damage, player)
			end
		end
	end
end

return Monsters
