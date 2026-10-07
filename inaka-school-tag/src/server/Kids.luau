-- 子ども側：スタミナ、水風船、お守り、救出、脱出
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Kids = {}

local balloonFolder = Instance.new("Folder")
balloonFolder.Name = "Balloons"
balloonFolder.Parent = workspace

function Kids.sync(actor)
	State.setAttr(actor, "Role", actor.role)
	State.setAttr(actor, "Stamina", math.floor(actor.stamina))
	State.setAttr(actor, "Balloons", actor.balloons)
	State.setAttr(actor, "Captured", actor.captured)
	State.setAttr(actor, "Escaped", actor.escaped)
end

-- ラウンド開始時
function Kids.setup(actor)
	actor.captured = false
	actor.escaped = false
	actor.stamina = Config.Kid.StaminaMax
	actor.sprinting = false
	actor.balloons = Config.Kid.StartBalloons
	actor.invulUntil = 0
	actor.stunUntil = 0
	actor.exhaustedUntil = 0
	actor.lastSprintT = 0
	actor.lastThrow = 0
	Kids.sync(actor)
end

-- 0.2秒ごと
function Kids.step(dt: number)
	local t = os.clock()
	for _, a in State.actors do
		if a.role == "Kid" and a.humanoid and a.humanoid.Parent then
			local canRun = not a.captured and not a.escaped and t >= a.stunUntil
			if a.sprinting and a.stamina > 0 and t >= a.exhaustedUntil and canRun then
				a.stamina = math.max(0, a.stamina - Config.Kid.SprintDrain * dt)
				a.lastSprintT = t
				if a.stamina <= 0 then
					a.exhaustedUntil = t + Config.Kid.ExhaustSeconds
				end
			elseif t - a.lastSprintT > Config.Kid.RegenDelay then
				a.stamina = math.min(Config.Kid.StaminaMax, a.stamina + Config.Kid.Regen * dt)
			end
			Kids.sync(a)
		end
	end
end

-- 水風船が鬼に当たった
function Kids.hitOni(oni, thrower)
	local t = os.clock()
	oni.stunUntil = t + Config.Oni.StunSeconds
	oni.slowUntil = t + Config.Oni.StunSeconds + Config.Oni.SlowSeconds
	if oni.hrp then
		State.fx(oni.hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(110, 190, 255), 12)
	end
	State.toast(thrower, "ヒット！ 鬼が止まった")
	State.toast(oni, "水風船が当たった！")
end

function Kids.throw(actor, aim)
	local t = os.clock()
	if State.phase ~= "Chase" or actor.role ~= "Kid" or actor.captured or actor.escaped or not actor.hrp then
		return
	end
	if actor.balloons <= 0 or t - actor.lastThrow < Config.Kid.ThrowCooldown or t < actor.stunUntil then
		return
	end
	if typeof(aim) ~= "Vector3" or aim.Magnitude < 0.1 then
		aim = actor.hrp.CFrame.LookVector
	end
	aim = aim.Unit
	actor.lastThrow = t
	actor.balloons -= 1
	Kids.sync(actor)

	local origin = actor.hrp.Position + Vector3.new(0, 1.5, 0) + aim * 2
	local velocity = (aim + Vector3.new(0, 0.2, 0)).Unit * Config.Kid.BalloonSpeed

	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.5
	ball.Color = Color3.fromRGB(90, 170, 255)
	ball.Material = Enum.Material.Glass
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Position = origin
	ball.Parent = balloonFolder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { actor.model, balloonFolder }

	task.spawn(function()
		local pos, vel = origin, velocity
		local start = os.clock()
		while ball.Parent and os.clock() - start < 4 do
			local dt = task.wait()
			vel += Vector3.new(0, -Config.Kid.BalloonGravity * dt, 0)
			local step = vel * dt

			-- 鬼との当たり（線分と中心点の距離）
			local oni = State.oni
			if oni and oni.hrp and oni.role == "Oni" then
				local center = oni.hrp.Position
				local seg = math.max(step:Dot(step), 1e-6)
				local along = math.clamp((center - pos):Dot(step) / seg, 0, 1)
				if (pos + step * along - center).Magnitude < 4 then
					Kids.hitOni(oni, actor)
					break
				end
			end

			if workspace:Raycast(pos, step, params) then
				State.fx(pos, Color3.fromRGB(110, 190, 255), 5)
				break
			end
			pos += step
			ball.Position = pos
		end
		ball:Destroy()
	end)
end

-- 水バケツで補充
function Kids.refill(actor, bucket): boolean
	local t = os.clock()
	if actor.role ~= "Kid" or actor.captured or actor.escaped or t < bucket.readyAt then
		return false
	end
	if actor.balloons >= Config.Kid.MaxBalloons then
		State.toast(actor, "水風船はもういっぱい")
		return false
	end
	actor.balloons = Config.Kid.MaxBalloons
	bucket.readyAt = t + Config.Kid.BucketCooldown
	Kids.sync(actor)
	State.toast(actor, "水風船をつくった！")
	return true
end

function Kids.collectCharm(actor, charm): boolean
	if charm.collected or actor.role ~= "Kid" or actor.captured or actor.escaped or State.phase ~= "Chase" then
		return false
	end
	State.world.hideCharm(charm)
	State.setCharms(State.charms + 1)
	State.toastAll(`お守りを集めた！（{charm.name}） {State.charms}/{Config.CharmsNeeded}`)
	if State.charms >= Config.CharmsNeeded then
		State.setGate(true)
		State.world.setGate(true)
		State.setBanner("校門が開いた！ 外へ逃げろ！")
		task.delay(4, function()
			if workspace:GetAttribute("Banner") == "校門が開いた！ 外へ逃げろ！" then
				State.setBanner("")
			end
		end)
	end
	return true
end

-- ろうやの仲間を1人助ける
function Kids.rescue(rescuer): boolean
	if rescuer.role ~= "Kid" or rescuer.captured or rescuer.escaped or State.phase ~= "Chase" then
		return false
	end
	for _, a in State.actors do
		if a.role == "Kid" and a.captured and a.hrp then
			a.captured = false
			a.invulUntil = os.clock() + Config.Kid.InvulnAfterRescue
			a.hrp.CFrame = CFrame.new(State.world.jailOut)
			Kids.sync(a)
			State.setCounts()
			State.toast(a, "助けてもらった！ 逃げろ！")
			State.toast(rescuer, "仲間を助けた！")
			return true
		end
	end
	State.toast(rescuer, "ろうやには誰もいない")
	return false
end

function Kids.escape(actor)
	actor.escaped = true
	actor.sprinting = false
	if actor.hrp then
		actor.hrp.CFrame = CFrame.new(State.world.waitSpot)
	end
	Kids.sync(actor)
	State.setCounts()
	State.toast(actor, "脱出成功！")
end

-- 校門が開いていて、脱出エリアに入った子どもを脱出させる
function Kids.checkEscape()
	if not State.gateOpen then
		return
	end
	local lo, hi = State.world.escapeMin, State.world.escapeMax
	for _, a in State.actors do
		if a.role == "Kid" and not a.captured and not a.escaped and a.hrp then
			local p = a.hrp.Position
			if p.X > lo.X and p.X < hi.X and p.Z > lo.Z and p.Z < hi.Z then
				Kids.escape(a)
			end
		end
	end
end

return Kids
