-- 勝利数を DataStore に保存する。使えない環境（Studioの設定など）でも、ゲームは止めない
local DataStoreService = game:GetService("DataStoreService")

local Save = {}

local store
local ok = pcall(function()
	store = DataStoreService:GetDataStore("InakaTag_v1")
end)
if not ok then
	store = nil
end

local warned = false
local function warnOnce(message: any)
	if not warned then
		warned = true
		warn("[Save] 保存を使えません（ゲームは続行）:", message)
	end
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

function Save.getWins(player: Player): number
	if not store then
		return 0
	end
	local success, value = pcall(function()
		return store:GetAsync(key(player))
	end)
	if not success then
		warnOnce(value)
		return 0
	end
	return tonumber(value) or 0
end

function Save.addWin(player: Player)
	if not store then
		return
	end
	local success, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			return (tonumber(old) or 0) + 1
		end)
	end)
	if not success then
		warnOnce(err)
	end
end

return Save
