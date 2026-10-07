-- ゲーム全体の状態・登場人物(actor)・通信
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local State = {}
State.phase = "Lobby" -- Lobby / Prep / Hide / Chase / Result
State.actors = {} -- [id] = actor
State.byPlayer = {} -- [Player] = actor
State.oni = nil
State.charms = 0
State.gateOpen = false
State.world = nil -- Match が World を入れる

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

State.actionRemote = Instance.new("RemoteEvent")
State.actionRemote.Name = "Action"
State.actionRemote.Parent = remotes

State.toastRemote = Instance.new("RemoteEvent")
State.toastRemote.Name = "Toast"
State.toastRemote.Parent = remotes

workspace:SetAttribute("CharmsNeeded", Config.CharmsNeeded)

function State.setPhase(phase: string)
	State.phase = phase
	workspace:SetAttribute("Phase", phase)
end

function State.setBanner(text: string)
	workspace:SetAttribute("Banner", text)
end

function State.setTime(seconds: number)
	workspace:SetAttribute("TimeLeft", math.max(0, math.ceil(seconds)))
end

function State.setCharms(n: number)
	State.charms = n
	workspace:SetAttribute("Charms", n)
end

function State.setGate(open: boolean)
	State.gateOpen = open
	workspace:SetAttribute("GateOpen", open)
end

function State.newActor(id: string, name: string, player: Player?, isCpu: boolean)
	local actor = {
		id = id,
		name = name,
		player = player,
		isCpu = isCpu,
		role = "Spectator", -- Oni / Kid / Spectator
		captured = false,
		escaped = false,
		stamina = Config.Kid.StaminaMax,
		sprinting = false,
		balloons = 0,
		invulUntil = 0,
		stunUntil = 0,
		slowUntil = 0,
		dashUntil = 0,
		exhaustedUntil = 0,
		lastSprintT = 0,
		lastThrow = 0,
		senseUntil = 0,
		cooldowns = {},
	}
	State.actors[id] = actor
	if player then
		State.byPlayer[player] = actor
	end
	return actor
end

function State.removeActor(actor)
	State.actors[actor.id] = nil
	if actor.player then
		State.byPlayer[actor.player] = nil
	end
	if actor.isCpu and actor.model then
		actor.model:Destroy()
	end
	actor.model, actor.hrp, actor.humanoid = nil, nil, nil
end

function State.holder(actor)
	return actor.player or actor.model
end

function State.setAttr(actor, key: string, value: any)
	local holder = State.holder(actor)
	if holder then
		holder:SetAttribute(key, value)
	end
end

function State.toast(actor, text: string)
	if actor.player then
		State.toastRemote:FireClient(actor.player, text)
	end
end

function State.toastAll(text: string, role: string?)
	for _, actor in State.actors do
		if not role or actor.role == role then
			State.toast(actor, text)
		end
	end
end

-- 人数の集計（HUD用）
function State.setCounts()
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
	workspace:SetAttribute("TotalKids", total)
	workspace:SetAttribute("CapturedKids", captured)
	workspace:SetAttribute("EscapedKids", escaped)
	workspace:SetAttribute("FreeKids", total - captured - escaped)
end

-- 状態から歩く速さを決める
function State.applySpeed(actor)
	local humanoid = actor.humanoid
	if not humanoid or not humanoid.Parent then
		return
	end
	local t = os.clock()
	local speed
	if actor.role == "Oni" then
		speed = Config.Oni.WalkSpeed
		if t < actor.dashUntil then
			speed = Config.Oni.Dash.Speed
		end
		if t < actor.slowUntil then
			speed *= Config.Oni.SlowMultiplier
		end
		if State.phase == "Hide" or State.phase == "Prep" then
			speed = 0
		end
	else
		speed = Config.Kid.WalkSpeed
		if actor.sprinting and actor.stamina > 0 and t >= actor.exhaustedUntil and not actor.captured and not actor.escaped then
			speed = Config.Kid.SprintSpeed
		end
	end
	if t < actor.stunUntil then
		speed = 0
	end
	humanoid.WalkSpeed = speed
end

function State.fx(position: Vector3, color: Color3, size: number)
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
	TweenService:Create(ball, TweenInfo.new(0.35), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.45)
end

return State
