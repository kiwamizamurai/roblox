-- CPUの鬼と子ども（プレイヤーと同じ Kids / Oni の関数を使って動く）
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Nav = require(script.Parent.Nav)
local Kids = require(script.Parent.Kids)
local Oni = require(script.Parent.Oni)

local Cpu = {}

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
		local idle = load("rbxassetid://507766666")
		local run = load("rbxassetid://507767714")
		idle:Play()
		humanoid.Running:Connect(function(speed)
			if speed > 0.5 then
				idle:Stop()
				run:Play()
			else
				run:Stop()
				idle:Play()
			end
		end)
	end)
end

function Cpu.createModel(actor, shirt: Color3)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(245, 215, 185)
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.TorsoColor = shirt
	description.LeftLegColor = Color3.fromRGB(60, 70, 110)
	description.RightLegColor = Color3.fromRGB(60, 70, 110)

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = actor.name
	model.Parent = workspace
	local hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	hrp:SetNetworkOwner(nil)
	setupAnimations(model:WaitForChild("Humanoid") :: Humanoid)
	return model
end

local function alive(actor, model): boolean
	return actor.model == model and model.Parent ~= nil and State.actors[actor.id] == actor
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 部品が増えたり近くにプレイヤーがいると、物理の持ち主が自動で切り替わる。そうなるとサーバーの移動命令が効かない
local function keepServerOwned(actor)
	local hrp = actor.hrp
	if hrp and hrp.Parent and hrp:GetNetworkOwner() ~= nil then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end
end

-- 壁をはさんでいないか
local function canSee(a, b): boolean
	if not (a.hrp and b.hrp and a.model and b.model) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { a.model, b.model }
	local origin = a.hrp.Position + Vector3.new(0, 1.5, 0)
	local target = b.hrp.Position + Vector3.new(0, 1.5, 0)
	return workspace:Raycast(origin, target - origin, params) == nil
end

local function clampToCompound(p: Vector3): Vector3
	return Vector3.new(math.clamp(p.X, -95, 155), 3, math.clamp(p.Z, -115, 68))
end

local function nearestFreeKid(oni, maxDistance: number, sensing: boolean)
	local best, bestDistance = nil, maxDistance
	local t = os.clock()
	for _, a in State.actors do
		if a.role == "Kid" and not a.captured and not a.escaped and a.hrp and t >= a.invulUntil then
			local d = (a.hrp.Position - oni.hrp.Position).Magnitude
			if d < bestDistance and (sensing or d < 25 or canSee(oni, a)) then
				best, bestDistance = a, d
			end
		end
	end
	return best, bestDistance
end

function Cpu.startOni(actor)
	local model = actor.model
	local nav = Nav.new(actor)
	task.spawn(function()
		local patrolGoal: Vector3? = nil
		while alive(actor, model) do
			task.wait(0.15)
			keepServerOwned(actor)
			if State.phase ~= "Chase" or os.clock() < actor.stunUntil or not actor.hrp then
				continue
			end
			local sight = os.clock() < actor.senseUntil and Config.Oni.Sense.Range or Config.Cpu.OniSight
			local target, distance = nearestFreeKid(actor, sight, os.clock() < actor.senseUntil)
			if target then
				patrolGoal = nil
				Nav.moveTo(nav, target.hrp.Position)
				if distance > 12 and distance < 28 then
					Oni.skill(actor, "Dash")
				elseif distance < 10 and math.random() < 0.3 then
					Oni.skill(actor, "Slam")
				end
			else
				Oni.skill(actor, "Sense") -- 見失ったら鼻で探す
				if not patrolGoal or flatDistance(actor.hrp.Position, patrolGoal) < 6 then
					local spots = {}
					for _, c in State.world.charms do
						if not c.collected then
							table.insert(spots, c.position)
						end
					end
					patrolGoal = #spots > 0 and spots[math.random(#spots)] or Vector3.new(math.random(-80, 80), 3, math.random(-50, 50))
				end
				Nav.moveTo(nav, patrolGoal)
			end
		end
	end)
end

local function nearestBucket(pos: Vector3, maxDistance: number)
	local best, bestDistance = nil, maxDistance
	for _, b in State.world.buckets do
		local d = flatDistance(b.part.Position, pos)
		if d < bestDistance and os.clock() >= b.readyAt then
			best, bestDistance = b, d
		end
	end
	return best
end

local function nearestCharm(pos: Vector3)
	local best, bestDistance = nil, math.huge
	for _, c in State.world.charms do
		if not c.collected then
			local d = flatDistance(c.position, pos)
			if d < bestDistance then
				best, bestDistance = c, d
			end
		end
	end
	return best
end

function Cpu.startKid(actor)
	local model = actor.model
	local nav = Nav.new(actor)
	task.spawn(function()
		local busySince: number? = nil
		local fleeUntil = 0
		while alive(actor, model) do
			task.wait(0.15)
			keepServerOwned(actor)
			if actor.captured or actor.escaped or not actor.hrp then
				actor.sprinting = false
				busySince = nil
				continue
			end
			if (State.phase ~= "Chase" and State.phase ~= "Hide") or os.clock() < actor.stunUntil then
				continue
			end

			local pos = actor.hrp.Position
			local oni = State.oni
			local oniDistance = (oni and oni.hrp) and (oni.hrp.Position - pos).Magnitude or math.huge
			local oniActive = oni ~= nil and os.clock() >= oni.stunUntil

			-- 近い・見えるときに逃げ始め、しばらく逃げ続ける（境目で行ったり来たりしないように）
			if oniActive and oniDistance < 32 and (oniDistance < 12 or canSee(actor, oni)) then
				fleeUntil = os.clock() + 1.2
			end
			if State.phase == "Chase" and oniActive and oniDistance < 45 and os.clock() < fleeUntil then
				-- 鬼から逃げる。近ければ水風船を投げる
				busySince = nil
				actor.sprinting = actor.stamina > 20
				local away = Vector3.new(pos.X - oni.hrp.Position.X, 0, pos.Z - oni.hrp.Position.Z)
				local goal = clampToCompound(pos + (away.Magnitude > 0.1 and away.Unit or Vector3.xAxis) * 40)
				Nav.moveTo(nav, goal)
				if oniDistance < 24 and actor.balloons > 0 and math.random() < 0.35 then
					Kids.throw(actor, oni.hrp.Position - pos)
				end
			else
				actor.sprinting = false
				local goal, mode, target = nil, nil, nil
				if State.gateOpen then
					goal, mode = Vector3.new(0, 3, 92), "exit"
				else
					if actor.balloons == 0 then
						target = nearestBucket(pos, 70)
						if target then
							goal, mode = target.part.Position, "bucket"
						end
					end
					if not goal and oniDistance > 45 then
						for _, a in State.actors do
							if a.role == "Kid" and a.captured then
								goal, mode = State.world.jailRescuePosition, "rescue"
								break
							end
						end
					end
					if not goal then
						target = nearestCharm(pos)
						if target then
							goal, mode = target.position, "charm"
						end
					end
				end

				if goal then
					local close = flatDistance(pos, goal) < (mode == "bucket" and 5 or 4)
					if close and mode == "charm" then
						busySince = busySince or os.clock()
						actor.humanoid:MoveTo(pos)
						if os.clock() - busySince > Config.CharmHoldSeconds + 1 then
							Kids.collectCharm(actor, target)
							busySince = nil
						end
					elseif close and mode == "rescue" then
						busySince = busySince or os.clock()
						actor.humanoid:MoveTo(pos)
						if os.clock() - busySince > Config.Kid.RescueHoldSeconds + 0.5 then
							Kids.rescue(actor)
							busySince = nil
						end
					elseif close and mode == "bucket" then
						Kids.refill(actor, target)
					else
						busySince = nil
						Nav.moveTo(nav, goal)
					end
				end
			end
		end
	end)
end

return Cpu
