-- 鬼側：捕獲とスキル（ダッシュ・鬼の鼻・どーん）
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Kids = require(script.Parent.Kids)

local Oni = {}

local SKILLS = { "Dash", "Sense", "Slam" }

function Oni.setup(actor)
	actor.captured = false
	actor.escaped = false
	actor.stunUntil = 0
	actor.slowUntil = 0
	actor.dashUntil = 0
	actor.senseUntil = 0
	actor.cooldowns = {}
	State.setAttr(actor, "Role", "Oni")
	Oni.updateAttrs(actor)
end

function Oni.updateAttrs(actor)
	local t = os.clock()
	for _, name in SKILLS do
		State.setAttr(actor, name .. "CD", math.ceil(math.max(0, (actor.cooldowns[name] or 0) - t)))
	end
end

function Oni.capture(kid)
	kid.captured = true
	kid.sprinting = false
	local cell = State.world.jailCell + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
	if kid.hrp then
		State.fx(kid.hrp.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 120, 90), 10)
		kid.hrp.CFrame = CFrame.new(cell)
	end
	Kids.sync(kid)
	State.setCounts()
	State.toast(kid, "つかまった！ 仲間の助けを待とう")
	State.toast(State.oni, "つかまえた！")
end

-- 0.2秒ごと：触れた子どもを捕まえる
function Oni.step(dt: number)
	local oni = State.oni
	if not oni or not oni.hrp or State.phase ~= "Chase" then
		return
	end
	local t = os.clock()
	Oni.updateAttrs(oni)
	if t < oni.stunUntil then
		return
	end
	local origin = oni.hrp.Position
	for _, a in State.actors do
		if a.role == "Kid" and not a.captured and not a.escaped and a.hrp and t >= a.invulUntil then
			local d = a.hrp.Position - origin
			if Vector3.new(d.X, 0, d.Z).Magnitude <= Config.Oni.CatchRadius and math.abs(d.Y) < 6 then
				Oni.capture(a)
			end
		end
	end
end

local function highlight(model: Model, seconds: number)
	local h = Instance.new("Highlight")
	h.FillTransparency = 1
	h.OutlineColor = Color3.fromRGB(255, 170, 40)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = model
	Debris:AddItem(h, seconds)
end

-- 戻り値：発動できたか
function Oni.skill(actor, kind: string): boolean
	if State.phase ~= "Chase" or actor.role ~= "Oni" or not actor.hrp then
		return false
	end
	local def = Config.Oni[kind]
	if not def or not table.find(SKILLS, kind) then
		return false
	end
	local t = os.clock()
	if t < actor.stunUntil or t < (actor.cooldowns[kind] or 0) then
		return false
	end
	actor.cooldowns[kind] = t + def.Cooldown

	local origin = actor.hrp.Position
	if kind == "Dash" then
		actor.dashUntil = t + def.Seconds
	elseif kind == "Sense" then
		actor.senseUntil = t + def.Seconds
		for _, a in State.actors do
			if a.role == "Kid" and not a.captured and not a.escaped and a.model and a.hrp then
				if (a.hrp.Position - origin).Magnitude <= def.Range then
					highlight(a.model, def.Seconds)
					State.toast(a, "鬼に見つかった！")
				end
			end
		end
	elseif kind == "Slam" then
		State.fx(origin - Vector3.new(0, 2, 0), Color3.fromRGB(255, 200, 80), def.Radius * 2)
		for _, a in State.actors do
			if a.role == "Kid" and not a.captured and not a.escaped and a.hrp then
				if (a.hrp.Position - origin).Magnitude <= def.Radius and t >= a.invulUntil then
					a.stunUntil = t + def.StunSeconds
					State.toast(a, "どーん！ 動けない！")
				end
			end
		end
	end
	Oni.updateAttrs(actor)
	return true
end

return Oni
