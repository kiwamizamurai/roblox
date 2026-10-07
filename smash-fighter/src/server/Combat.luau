-- 攻撃・ダメージ・吹っ飛び・ガード・回避。プレイヤーもCPUも同じ関数を使う
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Combat = {}
Combat.fighters = {} -- [id] = fighter
Combat.byPlayer = {} -- [Player] = fighter
Combat.active = false -- 試合中だけ攻撃できる
Combat.onDeath = nil -- Humanoidが死んだときにMatchが差し込む

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = "Action"
actionRemote.Parent = remotes

local pushRemote = Instance.new("RemoteEvent")
pushRemote.Name = "Push"
pushRemote.Parent = remotes

-- HUDが読む状態置き場（Damage / Stocks / Shield / Alive）
local fightersFolder = Instance.new("Folder")
fightersFolder.Name = "Fighters"
fightersFolder.Parent = ReplicatedStorage

local function now(): number
	return os.clock()
end

function Combat.register(id: string, displayName: string, player: Player?, isCpu: boolean)
	local state = Instance.new("Folder")
	state.Name = id
	state:SetAttribute("DisplayName", displayName)
	state:SetAttribute("IsCpu", isCpu)
	state:SetAttribute("Damage", 0)
	state:SetAttribute("Stocks", Config.Stocks)
	state:SetAttribute("Shield", Config.Shield.Max)
	state:SetAttribute("Alive", false)
	state.Parent = fightersFolder

	local fighter = {
		id = id,
		name = displayName,
		player = player,
		isCpu = isCpu,
		state = state,
		alive = false,
		facing = 1,
		shield = Config.Shield.Max,
		cooldowns = {},
		guarding = false,
		stunUntil = 0,
		dodgeUntil = 0,
		dodgeReadyAt = 0,
		invincibleUntil = 0,
	}
	Combat.fighters[id] = fighter
	if player then
		Combat.byPlayer[player] = fighter
	end
	return fighter
end

function Combat.fx(position: Vector3, color: Color3, size: number)
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

local function flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.Parent = model
	Debris:AddItem(highlight, 0.15)
end

local function setShield(fighter, value: number)
	fighter.shield = math.clamp(value, 0, Config.Shield.Max)
	fighter.state:SetAttribute("Shield", math.floor(fighter.shield))
end

function Combat.reset(fighter)
	fighter.state:SetAttribute("Damage", 0)
	setShield(fighter, Config.Shield.Max)
	fighter.cooldowns = {}
	fighter.stunUntil = 0
	fighter.dodgeUntil = 0
	fighter.dodgeReadyAt = 0
	fighter.invincibleUntil = 0
end

local function updateFacing(fighter)
	if not fighter.hrp then
		return
	end
	local look = fighter.hrp.CFrame.LookVector
	if math.abs(look.X) > 0.3 then
		fighter.facing = look.X > 0 and 1 or -1
	end
end

local function canAct(fighter): boolean
	return Combat.active and fighter.alive and fighter.hrp ~= nil and now() >= fighter.stunUntil and now() >= fighter.dodgeUntil
end

-- サーバーが物理を持つモデル（CPU）用の吹っ飛ばし
local function upright(hrp: BasePart, vx: number)
	local face = vx >= 0 and 1 or -1
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(face, 0, 0))
end

local function applyPush(model: Model, velocity: Vector3, stun: number)
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
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
				upright(hrp, velocity.X)
			end
		end)
	end
end

function Combat.push(fighter, velocity: Vector3, stun: number)
	fighter.stunUntil = now() + stun
	if fighter.guarding then
		Combat.guard(fighter, false)
	end
	if fighter.player then
		-- プレイヤーの物理はクライアントが持つので、本人に適用してもらう
		pushRemote:FireClient(fighter.player, velocity, stun)
	elseif fighter.model then
		applyPush(fighter.model, velocity, stun)
	end
end

function Combat.guard(fighter, on: boolean)
	if on then
		if not canAct(fighter) or fighter.guarding or fighter.shield < 5 then
			return
		end
		fighter.guarding = true
		fighter.humanoid.WalkSpeed = 0
		fighter.humanoid.JumpHeight = 0
		fighter.humanoid.JumpPower = 0

		local bubble = Instance.new("Part")
		bubble.Name = "Shield"
		bubble.Shape = Enum.PartType.Ball
		bubble.Material = Enum.Material.ForceField
		bubble.Color = Color3.fromRGB(80, 170, 255)
		bubble.Size = Vector3.one * 8
		bubble.Transparency = 0.3
		bubble.CanCollide = false
		bubble.CanQuery = false
		bubble.CanTouch = false
		bubble.Massless = true
		bubble.Position = fighter.hrp.Position
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = fighter.hrp
		weld.Part1 = bubble
		weld.Parent = bubble
		bubble.Parent = fighter.model
		fighter.bubble = bubble
	elseif fighter.guarding then
		fighter.guarding = false
		if fighter.bubble then
			fighter.bubble:Destroy()
			fighter.bubble = nil
		end
		if fighter.humanoid and fighter.humanoid.Parent then
			fighter.humanoid.WalkSpeed = fighter.baseWalkSpeed
			fighter.humanoid.JumpHeight = fighter.baseJumpHeight
			fighter.humanoid.JumpPower = fighter.baseJumpPower
		end
	end
end

-- 当たったか（ガードで防いだ場合もtrue）。無敵で素通りしたらfalse
function Combat.hit(attacker, victim, move, face: number): boolean
	local t = now()
	if t < victim.invincibleUntil or t < victim.dodgeUntil or not victim.alive then
		return false
	end

	if victim.guarding then
		setShield(victim, victim.shield - move.Damage * 2)
		Combat.fx(victim.hrp.Position, Color3.fromRGB(80, 170, 255), 7)
		if victim.shield <= 0 then
			Combat.guard(victim, false)
			Combat.push(victim, Vector3.new(0, 40, 0), Config.Shield.BreakStun) -- シールドブレイク
		end
		return true
	end

	local damage = victim.state:GetAttribute("Damage") + move.Damage
	victim.state:SetAttribute("Damage", damage)
	local direction = Vector3.new(move.Dir.X * face, move.Dir.Y, 0).Unit
	Combat.push(victim, direction * (move.Base + damage * move.Scale), Config.StunSeconds)
	flash(victim.model)
	Combat.fx(victim.hrp.Position, Color3.new(1, 1, 1), 9)
	return true
end

function Combat.attack(fighter, kind: string)
	local move = Config.Moves[kind]
	if not move or not canAct(fighter) or fighter.guarding then
		return
	end
	local t = now()
	if t < (fighter.cooldowns[kind] or 0) then
		return
	end
	fighter.cooldowns[kind] = t + move.Cooldown

	updateFacing(fighter)
	local face = fighter.facing
	local origin = fighter.hrp.Position

	-- 見た目の判定箱
	local swing = Instance.new("Part")
	swing.Material = Enum.Material.Neon
	swing.Color = Color3.fromRGB(255, 255, 200)
	swing.Transparency = 0.6
	swing.Anchored = true
	swing.CanCollide = false
	swing.CanQuery = false
	swing.CanTouch = false
	swing.Size = Vector3.new(move.Half.X * 2, move.Half.Y * 2, 1.5)
	swing.Position = origin + Vector3.new(face * move.Center.X, move.Center.Y, 0)
	swing.Parent = workspace
	Debris:AddItem(swing, 0.12)

	for _, other in Combat.fighters do
		if other ~= fighter and other.alive and other.hrp then
			local d = other.hrp.Position - origin
			-- +1/+2 は相手の体の幅/高さの半分
			if math.abs(d.X * face - move.Center.X) <= move.Half.X + 1 and math.abs(d.Y - move.Center.Y) <= move.Half.Y + 2 then
				Combat.hit(fighter, other, move, face)
			end
		end
	end
end

function Combat.special(fighter)
	local sp = Config.Special
	if not canAct(fighter) or fighter.guarding or now() < (fighter.cooldowns.Special or 0) then
		return
	end
	fighter.cooldowns.Special = now() + sp.Cooldown
	updateFacing(fighter)
	local face = fighter.facing

	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 140, 30)
	ball.Size = Vector3.one * sp.Radius * 2
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Position = fighter.hrp.Position + Vector3.new(face * 3, 0.5, 0)
	ball.Parent = workspace

	task.spawn(function()
		local start = now()
		local last = start
		while ball.Parent and Combat.active and now() - start < sp.Lifetime do
			task.wait()
			local t = now()
			local dt = t - last
			last = t
			ball.Position += Vector3.new(face * sp.Speed * dt, 0, 0)
			local hitSomeone = false
			for _, other in Combat.fighters do
				if other ~= fighter and other.alive and other.hrp then
					local d = other.hrp.Position - ball.Position
					if Vector2.new(d.X, d.Y).Magnitude <= sp.Radius + 2 and Combat.hit(fighter, other, sp, face) then
						hitSomeone = true
						break
					end
				end
			end
			if hitSomeone then
				break
			end
		end
		ball:Destroy()
	end)
end

function Combat.dodge(fighter, direction: number)
	local t = now()
	if not (Combat.active and fighter.alive and fighter.hrp) or t < fighter.stunUntil or t < fighter.dodgeReadyAt then
		return
	end
	Combat.guard(fighter, false)
	fighter.dodgeUntil = t + Config.Dodge.Seconds
	fighter.dodgeReadyAt = t + Config.Dodge.Cooldown
	Combat.push(fighter, Vector3.new((direction >= 0 and 1 or -1) * Config.Dodge.Speed, 0, 0), 0)
	-- 無敵の間は半透明
	local parts = {}
	for _, part in fighter.model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			parts[part] = part.Transparency
			part.Transparency = 0.6
		end
	end
	task.delay(Config.Dodge.Seconds, function()
		for part, original in parts do
			if part.Parent then
				part.Transparency = original
			end
		end
	end)
end

function Combat.makeInvincible(fighter, seconds: number)
	fighter.invincibleUntil = now() + seconds
	local ff = Instance.new("ForceField")
	ff.Parent = fighter.model
	Debris:AddItem(ff, seconds)
end

-- キャラクターができたら呼ぶ（プレイヤー・CPU共通）
function Combat.setupCharacter(fighter, model: Model, invincibleSeconds: number)
	local hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = model:WaitForChild("Humanoid") :: Humanoid
	fighter.model = model
	fighter.hrp = hrp
	fighter.humanoid = humanoid
	fighter.baseWalkSpeed = humanoid.WalkSpeed
	fighter.baseJumpHeight = humanoid.JumpHeight
	fighter.baseJumpPower = humanoid.JumpPower
	fighter.guarding = false
	model:SetAttribute("FighterId", fighter.id)

	-- 2D：Z方向の速度を0に保つ（ズレは step() で戻す）
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local zlock = Instance.new("LinearVelocity")
	zlock.Attachment0 = attachment
	zlock.RelativeTo = Enum.ActuatorRelativeTo.World
	zlock.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	zlock.LineDirection = Vector3.zAxis
	zlock.LineVelocity = 0
	zlock.MaxForce = 1e6
	zlock.Parent = hrp
	fighter.zlock = zlock

	humanoid.Died:Connect(function()
		if Combat.onDeath then
			Combat.onDeath(fighter, model)
		end
	end)

	fighter.alive = true
	fighter.state:SetAttribute("Alive", true)
	if invincibleSeconds > 0 then
		Combat.makeInvincible(fighter, invincibleSeconds)
	end
end

function Combat.removeCharacter(fighter)
	Combat.guard(fighter, false)
	fighter.alive = false
	fighter.state:SetAttribute("Alive", false)
	local model = fighter.model
	fighter.model = nil
	fighter.hrp = nil
	fighter.humanoid = nil
	fighter.zlock = nil
	if model then
		model:Destroy()
	end
end

function Combat.unregister(fighter)
	Combat.removeCharacter(fighter)
	Combat.fighters[fighter.id] = nil
	if fighter.player then
		Combat.byPlayer[fighter.player] = nil
	end
	fighter.state:Destroy()
end

-- 毎フレーム的な更新（Matchから0.1秒ごとに呼ぶ）
function Combat.step(dt: number)
	for _, fighter in Combat.fighters do
		if fighter.alive and fighter.hrp and fighter.hrp.Parent then
			updateFacing(fighter)
			if fighter.zlock then
				fighter.zlock.LineVelocity = math.clamp(-fighter.hrp.Position.Z * 5, -20, 20)
			end
			if fighter.guarding then
				setShield(fighter, fighter.shield - Config.Shield.DrainPerSecond * dt)
				if fighter.bubble then
					fighter.bubble.Size = Vector3.one * (3 + 5 * fighter.shield / Config.Shield.Max)
				end
				if fighter.shield <= 0 then
					Combat.guard(fighter, false)
					Combat.push(fighter, Vector3.new(0, 40, 0), Config.Shield.BreakStun)
				end
			else
				setShield(fighter, fighter.shield + Config.Shield.RegenPerSecond * dt)
			end
		end
	end
end

-- クライアントからの操作
actionRemote.OnServerEvent:Connect(function(player: Player, kind: any, arg: any)
	local fighter = Combat.byPlayer[player]
	if not fighter or typeof(kind) ~= "string" then
		return
	end
	if kind == "Jab" or kind == "Up" or kind == "Down" then
		Combat.attack(fighter, kind)
	elseif kind == "Special" then
		Combat.special(fighter)
	elseif kind == "GuardOn" then
		Combat.guard(fighter, true)
	elseif kind == "GuardOff" then
		Combat.guard(fighter, false)
	elseif kind == "Dodge" then
		Combat.dodge(fighter, typeof(arg) == "number" and arg or fighter.facing)
	end
end)

return Combat
