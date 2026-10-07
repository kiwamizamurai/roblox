-- 木材とスクラップ。触れるだけで拾え、少し待つと別の場所に出直す
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Resources = {}

local folder = Instance.new("Folder")
folder.Name = "Pickups"
folder.Parent = workspace

local generation = 0 -- リセット前の予約された再出現を無効にする

local KINDS = {
	Wood = { size = Vector3.new(3, 1, 1), color = Color3.fromRGB(139, 90, 43), material = Enum.Material.Wood },
	Scrap = { size = Vector3.new(1.6, 1.6, 1.6), color = Color3.fromRGB(150, 160, 170), material = Enum.Material.Metal },
}

local function randomSpot(): Vector3
	local angle = math.random() * math.pi * 2
	local radius = math.random(Config.Resources.MinFromLamp, Config.Resources.AreaRadius)
	return Vector3.new(math.cos(angle) * radius, 1.2, math.sin(angle) * radius)
end

local function spawnPickup(kind: string, token: number)
	local def = KINDS[kind]
	local pickup = Instance.new("Part")
	pickup.Name = kind
	pickup.Size = def.size
	pickup.Color = def.color
	pickup.Material = def.material
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CFrame = CFrame.new(randomSpot()) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	pickup.Parent = folder

	local taken = false
	pickup.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		taken = true
		player:SetAttribute(kind, (player:GetAttribute(kind) or 0) + 1)
		pickup:Destroy()
		task.delay(Config.Resources.RespawnSeconds, function()
			if token == generation then
				spawnPickup(kind, token)
			end
		end)
	end)
end

function Resources.reset()
	generation += 1
	folder:ClearAllChildren()
	for _ = 1, Config.Resources.Wood do
		spawnPickup("Wood", generation)
	end
	for _ = 1, Config.Resources.Scrap do
		spawnPickup("Scrap", generation)
	end
end

return Resources
