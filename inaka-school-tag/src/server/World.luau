-- 田舎の小学校をコードで生成する（校舎・体育館・校庭・校門・田んぼ・小屋）
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}

local C = {
	wall = Color3.fromRGB(236, 226, 200),
	wood = Color3.fromRGB(165, 125, 85),
	woodDark = Color3.fromRGB(110, 80, 50),
	roof = Color3.fromRGB(150, 70, 60),
	grass = Color3.fromRGB(105, 155, 80),
	sand = Color3.fromRGB(214, 190, 150),
	metal = Color3.fromRGB(150, 155, 165),
	board = Color3.fromRGB(35, 75, 55),
	fence = Color3.fromRGB(120, 130, 135),
	road = Color3.fromRGB(90, 90, 98),
	water = Color3.fromRGB(90, 160, 210),
}

local folder: Folder

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance?)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or folder
	return p
end

-- 座標の範囲で箱を作る
local function box(name: string, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, color: Color3, material: Enum.Material?, parent: Instance?)
	return part(name, Vector3.new(x2 - x1, y2 - y1, z2 - z1), CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), color, material, parent)
end

-- X方向の壁。gaps = { {中心, 幅}, ... } は出入口（高さ7）
local function wallX(x1: number, x2: number, z: number, y0: number, y1: number, gaps: { { number } }?, color: Color3, parent: Instance?)
	local g = gaps or {}
	table.sort(g, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = x1
	for _, gap in g do
		local gx1, gx2 = gap[1] - gap[2] / 2, gap[1] + gap[2] / 2
		if gx1 > cursor then
			box("Wall", cursor, y0, z - 0.5, gx1, y1, z + 0.5, color, nil, parent)
		end
		box("Lintel", gx1, y0 + 7, z - 0.5, gx2, y1, z + 0.5, color, nil, parent)
		cursor = gx2
	end
	if x2 > cursor then
		box("Wall", cursor, y0, z - 0.5, x2, y1, z + 0.5, color, nil, parent)
	end
end

local function wallZ(z1: number, z2: number, x: number, y0: number, y1: number, gaps: { { number } }?, color: Color3, parent: Instance?)
	local g = gaps or {}
	table.sort(g, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = z1
	for _, gap in g do
		local gz1, gz2 = gap[1] - gap[2] / 2, gap[1] + gap[2] / 2
		if gz1 > cursor then
			box("Wall", x - 0.5, y0, cursor, x + 0.5, y1, gz1, color, nil, parent)
		end
		box("Lintel", x - 0.5, y0 + 7, gz1, x + 0.5, y1, gz2, color, nil, parent)
		cursor = gz2
	end
	if z2 > cursor then
		box("Wall", x - 0.5, y0, cursor, x + 0.5, y1, z2, color, nil, parent)
	end
end

-- 斜めの板（スロープ・すべり台）。上面が p0→p1 を通る
local function plank(p0: Vector3, p1: Vector3, width: number, color: Color3, name: string?)
	local mid = (p0 + p1) / 2
	return part(name or "Plank", Vector3.new(width, 0.8, (p1 - p0).Magnitude), CFrame.lookAt(mid, p1) * CFrame.new(0, -0.4, 0), color)
end

local function sign(text: string, cframe: CFrame, size: Vector3, face: Enum.NormalId, bg: Color3, fg: Color3)
	local board = part("Sign", size, cframe, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = fg
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return board
end

local function ceilingLamp(x: number, y: number, z: number)
	local lamp = part("Lamp", Vector3.new(4, 0.3, 1), CFrame.new(x, y, z), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 28
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = lamp
end

local function furnishClassroom(cx: number, y0: number)
	box("Blackboard", cx - 6, y0 + 2.5, -109.6, cx + 6, y0 + 6, -109.3, C.board)
	box("TeacherDesk", cx - 2, y0, -106, cx + 2, y0 + 2.6, -104.6, C.woodDark)
	for row = 0, 3 do
		for _, col in { -1, 1 } do -- 中央は通路にする（CPUの経路探索が通れるように）
			local x, z = cx + col * 6.5, -100 + row * 3.4
			box("Desk", x - 1, y0, z - 0.7, x + 1, y0 + 2.4, z + 0.7, C.wood)
			box("Chair", x - 0.6, y0, z + 0.9, x + 0.6, y0 + 1.4, z + 1.9, C.woodDark)
		end
	end
	ceilingLamp(cx, y0 + 7.7, -98)
end

-- 校舎の1フロア分
local function buildFloor(y0: number)
	local top = y0 + 8
	local doorGaps = {}
	for i = 0, 5 do
		table.insert(doorGaps, { -50 + 20 * i, 7 })
	end
	wallX(-60, 60, -80, y0, top, { { 0, 12 } }, C.wall) -- 南の外壁（昇降口）
	wallX(-60, 60, -110, y0, top, {}, C.wall) -- 北の外壁
	wallZ(-110, -80, -60, y0, top, {}, C.wall)
	wallZ(-110, -80, 60, y0, top, {}, C.wall)
	wallX(-60, 60, -86, y0, top, doorGaps, C.wall) -- 廊下と教室の間
	for i = 1, 5 do
		wallZ(-110, -86, -60 + 20 * i, y0, top, {}, C.wall)
	end
	for i = 0, 5 do
		furnishClassroom(-50 + 20 * i, y0)
	end
	for _, x in { -40, 0, 40 } do
		ceilingLamp(x, y0 + 7.7, -83)
	end
end

local function tree(x: number, z: number, crown: Color3, scale: number)
	box("Trunk", x - 0.8 * scale, 0, z - 0.8 * scale, x + 0.8 * scale, 9 * scale, z + 0.8 * scale, Color3.fromRGB(100, 75, 55), Enum.Material.Wood)
	local a = part("Crown", Vector3.one * 14 * scale, CFrame.new(x, 11 * scale, z), crown, Enum.Material.Grass)
	a.Shape = Enum.PartType.Ball
	local b = part("Crown", Vector3.one * 10 * scale, CFrame.new(x + 3 * scale, 14 * scale, z - 2 * scale), crown, Enum.Material.Grass)
	b.Shape = Enum.PartType.Ball
	a.CanCollide = false -- 葉は通り抜けられる（幹だけ当たる）
	b.CanCollide = false
end

local function prompt(parent: BasePart, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
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
	folder = Instance.new("Folder")
	folder.Name = "School"
	folder.Parent = workspace

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
	Lighting.FogEnd = 4000

	-- 地面
	part("Ground", Vector3.new(1000, 2, 1000), CFrame.new(0, -1, 0), C.grass, Enum.Material.Grass)
	box("Yard", -98, 0, -72, 90, 0.15, 70, C.sand)
	box("Road", -8, 0, 72, 8, 0.12, 300, C.road)
	box("Path", -200, 0, -24, -100, 0.12, -16, C.sand) -- 裏門から小屋への畦道
	local waterway = box("Waterway", -146, 0.02, -120, -140, 0.2, 70, C.water, Enum.Material.Glass)
	waterway.Transparency = 0.3
	waterway.CanCollide = false

	-- 田んぼ
	for i = 0, 5 do
		local c = i % 2 == 0 and Color3.fromRGB(150, 190, 90) or Color3.fromRGB(125, 170, 80)
		box("RiceField", -280 + i * 22, 0, 20, -260 + i * 22, 0.3, 140, c, Enum.Material.Grass)
		box("RiceField", -280 + i * 22, 0, -140, -260 + i * 22, 0.3, -30, c, Enum.Material.Grass)
	end

	-- 遠くの山（見た目だけ）
	for _, m in { { -150, -420, 500 }, { 200, -450, 600 }, { -420, -150, 450 }, { 420, 100, 550 } } do
		local hill = part("Mountain", Vector3.one * m[3], CFrame.new(m[1], -m[3] * 0.35, m[2]), Color3.fromRGB(70, 120, 85), Enum.Material.Grass)
		hill.Shape = Enum.PartType.Ball
		hill.CanCollide = false
		hill.CanQuery = false
	end

	-- 校舎（1階・2階）
	box("Floor1", -60, 0, -110, 60, 0.25, -80, C.wood, Enum.Material.WoodPlanks)
	buildFloor(0)
	box("Floor2", -60, 8, -110, 60, 9, -74, C.wood, Enum.Material.WoodPlanks) -- 2階の床（外廊下つき）
	buildFloor(9)
	box("RoofSlab", -62, 17, -112, 62, 18, -72, C.roof)
	-- 2階の外廊下の手すり
	box("Rail", -60, 9, -74.3, 60, 10.2, -73.7, C.woodDark)
	-- 外階段（スロープ）
	plank(Vector3.new(-80, 0, -77), Vector3.new(-60, 9, -77), 6, C.wood, "StairWest")
	plank(Vector3.new(80, 0, -77), Vector3.new(60, 9, -77), 6, C.wood, "StairEast")
	sign("昇降口", CFrame.new(0, 7.6, -80.7), Vector3.new(8, 1.4, 0.3), Enum.NormalId.Back, C.woodDark, Color3.new(1, 1, 1))
	for i = 0, 9 do -- 下駄箱
		box("Locker", -58 + i * 2.2, 0, -85.5, -56.4 + i * 2.2, 3, -84.5, C.woodDark)
	end

	-- 体育館
	box("GymFloor", 92, 0, -22, 148, 0.25, 22, Color3.fromRGB(200, 165, 120), Enum.Material.WoodPlanks)
	wallZ(-22, 22, 92, 0, 14, { { -8, 8 }, { 8, 8 } }, Color3.fromRGB(225, 220, 205))
	wallZ(-22, 22, 148, 0, 14, {}, Color3.fromRGB(225, 220, 205))
	wallX(92, 148, -22, 0, 14, {}, Color3.fromRGB(225, 220, 205))
	wallX(92, 148, 22, 0, 14, {}, Color3.fromRGB(225, 220, 205))
	box("GymRoof", 90, 14, -24, 150, 15, 24, Color3.fromRGB(90, 110, 140))
	box("Stage", 140, 0, -6, 148, 3, 18, C.wood)
	box("StageStep", 138, 0, -6, 140, 1.5, 18, C.wood)
	for _, x in { 100, 120, 140 } do
		for _, z in { -12, 0, 12 } do
			ceilingLamp(x, 13.5, z)
		end
	end
	box("VaultBox", 106, 0, 4, 110, 1, 8, C.woodDark)
	box("VaultBox", 106, 1, 4, 110, 2, 8, C.wood)
	box("VaultBox", 106, 2, 4, 110, 3, 8, C.woodDark)
	sign("体育館", CFrame.new(91.3, 10, 0), Vector3.new(0.3, 2.4, 10), Enum.NormalId.Left, Color3.fromRGB(60, 80, 110), Color3.new(1, 1, 1))

	-- 体育館の倉庫＝ろうや（北東の角）
	wallX(134, 148, -10, 0, 8, {}, C.woodDark)
	wallZ(-22, -10, 134, 0, 8, { { -16, 5 } }, C.woodDark)
	box("JailFloor", 134, 0, -22, 148, 0.35, -10, Color3.fromRGB(80, 70, 60))
	local jailDoor = box("JailDoor", 133.7, 0, -18.5, 134.3, 7, -13.5, Color3.fromRGB(190, 70, 60), Enum.Material.Metal)
	sign("ろうや", CFrame.new(133.2, 7.6, -16), Vector3.new(0.3, 1.2, 5), Enum.NormalId.Left, Color3.fromRGB(190, 70, 60), Color3.new(1, 1, 1))
	local jailPrompt = prompt(jailDoor, "仲間を助ける", "ろうや", Config.Kid.RescueHoldSeconds, 10)

	-- 校庭の遊具
	box("Podium", -4, 0, -52, 4, 2, -46, Color3.fromRGB(215, 215, 210)) -- 朝礼台
	box("PodiumStep", -2, 0, -46, 2, 1, -44.5, Color3.fromRGB(215, 215, 210))
	for i = 0, 2 do -- 鉄棒
		local x = -50 + i * 9
		box("BarPost", x - 3.1, 0, -20.2, x - 2.9, 4 + i * 0.5, -19.8, C.metal)
		box("BarPost", x + 2.9, 0, -20.2, x + 3.1, 4 + i * 0.5, -19.8, C.metal)
		box("Bar", x - 3, 3.8 + i * 0.5, -20.15, x + 3, 4.1 + i * 0.5, -19.85, C.metal)
	end
	-- すべり台
	box("SlideTower", 48, 0, -32.5, 52, 0.5, -27.5, C.metal)
	for _, p in { { 48, -32.5 }, { 52, -32.5 }, { 48, -27.5 }, { 52, -27.5 } } do
		box("SlidePost", p[1] - 0.2, 0, p[2] - 0.2, p[1] + 0.2, 6, p[2] + 0.2, C.metal)
	end
	box("SlideDeck", 47.5, 6, -33, 52.5, 6.5, -27, C.metal)
	plank(Vector3.new(38, 0.3, -30), Vector3.new(47.5, 6.3, -30), 3, C.wood, "SlideRamp")
	plank(Vector3.new(52.5, 6.3, -30), Vector3.new(64, 0.3, -30), 3, Color3.fromRGB(190, 190, 200), "Slide")
	-- ジャングルジム
	local jx, jz = -30, 20
	for i = 0, 3 do
		for j = 0, 3 do
			box("JGPost", jx - 4.7 + i * 3, 0, jz - 4.7 + j * 3, jx - 4.3 + i * 3, 9, jz - 4.3 + j * 3, C.metal)
		end
	end
	for k = 1, 3 do
		for j = 0, 3 do
			box("JGBar", jx - 4.7, k * 3 - 0.2, jz - 4.7 + j * 3, jx + 4.7, k * 3 + 0.2, jz - 4.3 + j * 3, C.metal)
			box("JGBar", jx - 4.7 + j * 3, k * 3 - 0.2, jz - 4.7, jx - 4.3 + j * 3, k * 3 + 0.2, jz + 4.7, C.metal)
		end
	end
	-- 砂場
	box("SandBorder", -53, 0, 27, -37, 0.8, 43, C.woodDark)
	box("Sandbox", -52, 0, 28, -38, 0.9, 42, Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	-- 百葉箱
	box("HyakuyobakoLeg", 29.5, 0, -56.5, 30.5, 3, -55.5, Color3.new(1, 1, 1))
	box("Hyakuyobako", 28, 3, -58, 32, 6, -54, Color3.new(1, 1, 1))
	-- 花壇
	for i = 0, 5 do
		box("FlowerBed", -56 + i * 22, 0, -72.5, -46 + i * 22, 0.8, -70, C.woodDark)
		for k = 0, 5 do
			local c = ({ Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(250, 250, 250) })[(k + i) % 3 + 1]
			local f = part("Flower", Vector3.one * 0.9, CFrame.new(-55 + i * 22 + k * 1.7, 1.2, -71.2), c)
			f.Shape = Enum.PartType.Ball
			f.CanCollide = false
		end
	end
	-- 飼育小屋
	for _, p in { { -88, -66 }, { -72, -66 }, { -88, -54 }, { -72, -54 } } do
		box("HutPost", p[1] - 0.3, 0, p[2] - 0.3, p[1] + 0.3, 6, p[2] + 0.3, C.woodDark)
	end
	box("HutRoof", -90, 6, -68, -70, 6.6, -52, C.roof)
	box("HutBack", -88, 0, -66.3, -72, 6, -65.7, C.woodDark)

	-- 水バケツ（水風船の補充）
	World.buckets = {}
	for i, p in { { -20, -40 }, { 20, -40 }, { -60, 45 }, { 60, 45 }, { 105, 15 } } do
		local bucket = part("Bucket", Vector3.new(2.2, 3, 3), CFrame.new(p[1], 1.1, p[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 130, 200), Enum.Material.Plastic)
		bucket.Shape = Enum.PartType.Cylinder
		local pr = prompt(bucket, "水風船をつくる", "水バケツ", 0.4, 9)
		table.insert(World.buckets, { part = bucket, prompt = pr, readyAt = 0, index = i })
	end

	-- 校門・フェンス・看板
	local fenceFolder = Instance.new("Folder")
	fenceFolder.Name = "Fence"
	fenceFolder.Parent = folder
	wallX(-100, 160, -120, 0, 9, {}, C.fence, fenceFolder)
	wallX(-100, 160, 72, 0, 9, { { 0, 16 } }, C.fence, fenceFolder)
	wallZ(-120, 72, 160, 0, 9, {}, C.fence, fenceFolder)
	wallZ(-120, 72, -100, 0, 9, { { -20, 10 } }, C.fence, fenceFolder) -- 裏門
	for _, p in fenceFolder:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 0.35
			p.Material = Enum.Material.Metal
		end
	end
	box("GatePillar", -10, 0, 71, -8, 10, 73, Color3.fromRGB(190, 185, 175))
	box("GatePillar", 8, 0, 71, 10, 10, 73, Color3.fromRGB(190, 185, 175))
	sign("いなか小学校", CFrame.new(0, 10.8, 72), Vector3.new(16, 2.2, 0.4), Enum.NormalId.Front, Color3.fromRGB(110, 80, 50), Color3.new(1, 1, 1))
	local gate = box("Gate", -8, 0, 71.5, 8, 7.5, 72.5, Color3.fromRGB(60, 55, 55), Enum.Material.Metal)
	World.gate = gate
	World.gateClosedCFrame = gate.CFrame
	-- 校門の外は、校門からしか入れない（裏門から回り込んで脱出できないように、透明な壁で囲う）
	for _, b in {
		{ -60.5, 72, -59.5, 300 },
		{ 59.5, 72, 60.5, 300 },
	} do
		local wall = box("Barrier", b[1], 0, b[2], b[3], 40, b[4], Color3.new(1, 1, 1))
		wall.Transparency = 1
	end
	local endWall = box("Barrier", -60, 0, 299.5, 60, 40, 300.5, Color3.new(1, 1, 1))
	endWall.Transparency = 1

	-- 木（桜と、まわりの緑）
	local rng = Random.new(42)
	for i = 0, 11 do
		tree(-92 + i * 20, 66, Color3.fromRGB(255, 190, 210), 0.9 + rng:NextNumber() * 0.4)
	end
	for i = 0, 8 do
		tree(-95 + i * 30, -116, Color3.fromRGB(90, 150, 80), 1 + rng:NextNumber() * 0.3)
	end
	for i = 0, 6 do
		tree(156, -100 + i * 25, Color3.fromRGB(90, 150, 80), 1 + rng:NextNumber() * 0.3)
	end
	for i = 0, 9 do
		tree(-300 + rng:NextNumber() * 400, -150 + rng:NextNumber() * 20, Color3.fromRGB(80, 140, 75), 1.2)
	end

	-- 用水路の小屋（お守りの隠し場所）
	box("HutFloor", -196, 0, 4, -184, 0.3, 16, C.woodDark)
	wallZ(4, 16, -196, 0, 9, {}, C.wood)
	wallX(-196, -184, 4, 0, 9, {}, C.wood)
	wallX(-196, -184, 16, 0, 9, {}, C.wood)
	wallZ(4, 16, -184, 0, 9, { { 10, 7 } }, C.wood) -- 東向きの出入口
	box("HutRoofSmall", -198, 9, 2, -182, 9.6, 18, C.roof)
	box("HutTable", -194, 0, 8, -191, 2, 12, C.woodDark)

	-- お守り（5か所）
	World.charms = {}
	local spots = {
		{ "1年教室", Vector3.new(-30, 1.8, -98) },
		{ "職員室", Vector3.new(30, 10.8, -98) },
		{ "体育館", Vector3.new(120, 1.8, 14) },
		{ "砂場", Vector3.new(-45, 1.8, 35) },
		{ "用水路の小屋", Vector3.new(-188, 1.8, 10) },
	}
	for i, s in spots do
		local orb = part("Charm", Vector3.one * 1.8, CFrame.new(s[2]), Color3.fromRGB(255, 90, 80), Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.CanCollide = false
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 160, 120)
		glow.Range = 14
		glow.Parent = orb
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 34)
		gui.StudsOffset = Vector3.new(0, 2.4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 160
		gui.Parent = orb
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(255, 225, 130)
		text.TextStrokeTransparency = 0.3
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.Text = "お守り"
		text.Parent = gui
		local pr = prompt(orb, "お守りを集める", s[1], Config.CharmHoldSeconds, 9)
		table.insert(World.charms, { part = orb, prompt = pr, light = glow, gui = gui, collected = false, name = s[1], position = s[2] })
	end

	-- スポーン地点など
	World.jailDoor = jailDoor
	World.jailPrompt = jailPrompt
	World.jailCell = Vector3.new(141, 3, -16)
	World.jailOut = Vector3.new(129, 3.5, -16)
	World.jailRescuePosition = Vector3.new(130, 3, -16)
	World.oniSpawn = Vector3.new(0, 4, -116)
	World.waitSpot = Vector3.new(0, 4, 140)
	World.escapeMin = Vector3.new(-20, 0, 74)
	World.escapeMax = Vector3.new(20, 10, 110)
	World.kidSpawns = {}
	for i = 1, 8 do
		table.insert(World.kidSpawns, Vector3.new(-28 + (i - 1) * 8, 4, 45))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 40)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	return World
end

function World.resetCharms()
	for _, c in World.charms do
		c.collected = false
		c.part.Transparency = 0
		c.prompt.Enabled = true
		c.light.Enabled = true
		c.gui.Enabled = true
	end
end

function World.hideCharm(c)
	c.collected = true
	c.part.Transparency = 1
	c.prompt.Enabled = false
	c.light.Enabled = false
	c.gui.Enabled = false
end

function World.setGate(open: boolean)
	local gate = World.gate
	if open then
		gate.CanCollide = false
		TweenService:Create(gate, TweenInfo.new(1.2), { CFrame = World.gateClosedCFrame + Vector3.new(0, 9, 0), Transparency = 0.6 }):Play()
	else
		gate.CFrame = World.gateClosedCFrame
		gate.Transparency = 0
		gate.CanCollide = true
	end
end

return World
