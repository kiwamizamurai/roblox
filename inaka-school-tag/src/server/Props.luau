-- Toolbox素材の読み込み。スクリプトは必ず取り除き、失敗しても何もせずに続ける（Partsの簡易版が残る）
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Props = {}

local function sanitize(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

-- Config.Props = { { id = 123456, name = "木", cframe = CFrame.new(...) }, ... }
function Props.placeAll()
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = workspace
	for _, def in Config.Props do
		task.spawn(function()
			local ok, container = pcall(function()
				return InsertService:LoadAsset(def.id)
			end)
			if not ok or not container then
				warn("[Props] 読み込めませんでした（見た目のみ影響）:", def.name or def.id)
				return
			end
			sanitize(container)
			for _, child in container:GetChildren() do
				child.Parent = folder
				if child:IsA("Model") then
					child:PivotTo(def.cframe)
				elseif child:IsA("BasePart") then
					child.CFrame = def.cframe
				end
			end
			container:Destroy()
		end)
	end
end

return Props
