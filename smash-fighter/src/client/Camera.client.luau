-- 全ファイターが映る横視点カメラ
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local camera = workspace.CurrentCamera

local centerX, centerY, distance = 0, 8, 80

RunService:BindToRenderStep("FightCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60

	local blast = Config.Blast
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, model in workspace:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("FighterId") then
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then
				local x = math.clamp(hrp.Position.X, -blast.X, blast.X)
				local y = math.clamp(hrp.Position.Y, blast.MinY, blast.MaxY)
				minX, maxX = math.min(minX, x), math.max(maxX, x)
				minY, maxY = math.min(minY, y), math.max(maxY, y)
			end
		end
	end

	local targetX, targetY, targetDistance = 0, 8, 80
	if minX <= maxX then
		targetX = (minX + maxX) / 2
		targetY = math.clamp((minY + maxY) / 2, 4, 25) -- ステージが画面から外れないように
		-- 画面の縦横比に合わせて、全員が入る距離を求める（スマホの縦横比でも切れないように）
		local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
		local halfV = math.tan(math.rad(camera.FieldOfView) / 2)
		local needH = (maxX - minX + 40) / (2 * halfV * aspect)
		local needV = (maxY - minY + 30) / (2 * halfV)
		targetDistance = math.clamp(math.max(needH, needV, 55), 55, 160)
	end

	local alpha = 1 - math.exp(-6 * dt)
	centerX += (targetX - centerX) * alpha
	centerY += (targetY - centerY) * alpha
	distance += (targetDistance - distance) * alpha

	camera.CFrame = CFrame.lookAt(Vector3.new(centerX, centerY + 6, distance), Vector3.new(centerX, centerY, 0))
end)
