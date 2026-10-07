-- CPUファイター。プレイヤーと同じ Combat の関数だけを使って動く
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)

local Cpu = {}

local function setupAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local function load(id: string)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		return track
	end
	local ok = pcall(function()
		local idle = load("rbxassetid://507766666")
		local run = load("rbxassetid://507767714")
		local fall = load("rbxassetid://507767968")
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
		humanoid.FreeFalling:Connect(function(active)
			if active then
				fall:Play()
			else
				fall:Stop()
			end
		end)
	end)
	if not ok then
		warn("CPUのアニメーション読み込みに失敗（見た目のみ影響）")
	end
end

function Cpu.createModel(fighter)
	local description = Instance.new("HumanoidDescription")
	local palette = { Color3.fromRGB(220, 70, 70), Color3.fromRGB(70, 120, 220), Color3.fromRGB(70, 180, 90) }
	local index = tonumber(string.match(fighter.id, "%d+")) or 1
	local color = palette[(index - 1) % #palette + 1]
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color
	description.RightLegColor = color

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = fighter.name
	model.Parent = workspace
	local hrp = model:WaitForChild("HumanoidRootPart") :: BasePart
	hrp:SetNetworkOwner(nil)
	setupAnimations(model:WaitForChild("Humanoid") :: Humanoid)
	return model
end

local function sign(n: number): number
	return n >= 0 and 1 or -1
end

function Cpu.start(fighter)
	local model = fighter.model
	task.spawn(function()
		local doubleJumpUsed = false
		while fighter.model == model and model.Parent do
			task.wait(0.12)
			if not (Combat.active and fighter.alive and fighter.hrp) then
				continue
			end
			local hrp, humanoid = fighter.hrp, fighter.humanoid
			local pos = hrp.Position
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			if grounded then
				doubleJumpUsed = false
			end

			-- いちばん近い相手
			local target, best = nil, math.huge
			for _, other in Combat.fighters do
				if other ~= fighter and other.alive and other.hrp then
					local dist = (other.hrp.Position - pos).Magnitude
					if dist < best then
						best, target = dist, other
					end
				end
			end

			local offStage = (math.abs(pos.X) > Config.StageHalfWidth and pos.Y < 2) or pos.Y < -2
			if offStage then
				-- 復帰：中央へ向かい、落ち始めたら空中ジャンプ
				humanoid:Move(Vector3.new(-sign(pos.X), 0, 0), false)
				if not grounded and not doubleJumpUsed and hrp.AssemblyLinearVelocity.Y < 5 then
					doubleJumpUsed = true
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			elseif target then
				local delta = target.hrp.Position - pos
				local face = sign(delta.X)
				local distX = math.abs(delta.X)

				local move = distX > 5 and face or 0
				if math.abs(pos.X) > Config.StageHalfWidth - 3 and sign(pos.X) == move then
					move = 0 -- 端では自分から落ちない
				end
				humanoid:Move(Vector3.new(move, 0, 0), false)
				if delta.Y > 5 and grounded and distX < 12 then
					humanoid.Jump = true
				end

				if distX <= 6 and math.abs(delta.Y) < 8 then
					hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(face, 0, 0))
					local roll = math.random()
					if roll < 0.45 then
						Combat.attack(fighter, delta.Y > 4 and "Up" or (roll < 0.1 and "Down" or "Jab"))
					elseif roll < 0.6 then
						Combat.guard(fighter, true)
						task.delay(0.5, function()
							Combat.guard(fighter, false)
						end)
					end
				elseif distX > 12 and math.random() < 0.25 then
					hrp.CFrame = CFrame.lookAt(pos, pos + Vector3.new(face, 0, 0))
					Combat.special(fighter)
				end
			end
		end
	end)
end

return Cpu
