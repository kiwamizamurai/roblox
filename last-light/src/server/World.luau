-- 島・灯台・燃料箱・作業台を作る
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local World = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = workspace
	return p
end

local function prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.25
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

function World.build()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- 島（円柱。上面が y=0）と、まわりの海
	local island = part("Island", Vector3.new(2, 280, 280), CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 120, 70), Enum.Material.Grass)
	island.Shape = Enum.PartType.Cylinder
	part("Sea", Vector3.new(900, 2, 900), CFrame.new(0, -8, 0), Color3.fromRGB(20, 60, 110), Enum.Material.SmoothPlastic)

	-- 灯台
	local white, red = Color3.fromRGB(235, 235, 235), Color3.fromRGB(190, 50, 50)
	part("Tower", Vector3.new(7, 24, 7), CFrame.new(0, 12, 0), white)
	for _, y in { 6, 14, 22 } do
		part("Stripe", Vector3.new(7.2, 3, 7.2), CFrame.new(0, y, 0), red)
	end
	part("Gallery", Vector3.new(11, 1, 11), CFrame.new(0, 24.5, 0), Color3.fromRGB(60, 60, 70))
	part("Roof", Vector3.new(9, 2, 9), CFrame.new(0, 31, 0), red)

	local core = part("LampCore", Vector3.one * 5, CFrame.new(0, 27.5, 0), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = Color3.fromRGB(255, 210, 130)
	light.Range = 60
	light.Brightness = 4
	light.Parent = core

	-- 光の届く範囲を示す円盤
	local ring = part("LightRing", Vector3.new(0.2, 110, 110), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 230, 150), Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.88
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false

	-- 燃料箱：木材をランプの燃料にする
	local fuelBox = part("FuelBox", Vector3.new(4, 3, 3), CFrame.new(0, 1.5, -6), Color3.fromRGB(120, 80, 40), Enum.Material.Wood)
	local fuelPrompt = prompt(fuelBox, "燃料を入れる", "ランプ（木材）")
	fuelPrompt.Triggered:Connect(function(player: Player)
		local wood = player:GetAttribute("Wood") or 0
		if wood <= 0 then
			State.toast(player, "木材がありません")
			return
		end
		local needed = math.ceil((Config.Lamp.MaxFuel - State.fuel) / Config.Lamp.FuelPerWood)
		local used = math.min(wood, needed)
		if used <= 0 then
			State.toast(player, "燃料は満タンです")
			return
		end
		State.addFuel(used * Config.Lamp.FuelPerWood)
		player:SetAttribute("Wood", wood - used)
		State.toast(player, `木材 {used} 個 → 燃料 +{used * Config.Lamp.FuelPerWood}`)
	end)

	-- 作業台：スクラップで武器を強化
	local bench = part("Workbench", Vector3.new(5, 3, 3), CFrame.new(10, 1.5, 6), Color3.fromRGB(110, 115, 125), Enum.Material.Metal)
	local benchPrompt = prompt(bench, "武器を強化する", "作業台（スクラップ）")
	benchPrompt.Triggered:Connect(function(player: Player)
		local level = player:GetAttribute("WeaponLevel") or 0
		if level >= Config.Player.WeaponMaxLevel then
			State.toast(player, "武器は最大レベルです")
			return
		end
		local cost = Config.Player.WeaponCost * (level + 1)
		local scrap = player:GetAttribute("Scrap") or 0
		if scrap < cost then
			State.toast(player, `スクラップが足りません（{scrap}/{cost}）`)
			return
		end
		player:SetAttribute("Scrap", scrap - cost)
		player:SetAttribute("WeaponLevel", level + 1)
		State.toast(player, `武器が Lv{level + 1} になった`)
	end)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 16)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	World.ring = ring
	World.light = light
	return World
end

-- 燃料に合わせて光の見た目を更新する
function World.updateLamp()
	local range = State.lightRange()
	World.ring.Size = Vector3.new(0.2, range * 2, range * 2)
	World.light.Range = math.min(60, 20 + range * 0.7)
	World.light.Brightness = 1 + 4 * (State.fuel / Config.Lamp.MaxFuel)
end

return World
