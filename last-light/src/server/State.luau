-- ゲーム全体の状態（ランプの燃料・夜数・フェーズ）と、サーバー⇔クライアントの通信
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local State = {}
State.fuel = Config.Lamp.StartFuel
State.phase = "Lobby" -- Lobby / Countdown / Day / Night / Result
State.night = 1
State.lampPosition = Vector3.zero
State.spawnCFrame = CFrame.new(0, 3.5, 16)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

State.attackRemote = Instance.new("RemoteEvent")
State.attackRemote.Name = "Attack"
State.attackRemote.Parent = remotes

State.toastRemote = Instance.new("RemoteEvent")
State.toastRemote.Name = "Toast"
State.toastRemote.Parent = remotes

workspace:SetAttribute("MaxFuel", Config.Lamp.MaxFuel)

function State.setFuel(value: number)
	State.fuel = math.clamp(value, 0, Config.Lamp.MaxFuel)
	workspace:SetAttribute("Fuel", math.floor(State.fuel))
end

function State.addFuel(delta: number)
	State.setFuel(State.fuel + delta)
end

function State.setPhase(phase: string)
	State.phase = phase
	workspace:SetAttribute("Phase", phase)
end

function State.setNight(night: number)
	State.night = night
	workspace:SetAttribute("Night", night)
end

function State.setBanner(text: string)
	workspace:SetAttribute("Banner", text)
end

-- いまの光の半径。燃料が減るほど小さくなる
function State.lightRange(): number
	local lamp = Config.Lamp
	return lamp.LightRangeMin + (lamp.LightRangeMax - lamp.LightRangeMin) * (State.fuel / lamp.MaxFuel)
end

function State.toast(player: Player, text: string)
	State.toastRemote:FireClient(player, text)
end

State.setFuel(State.fuel)
State.setPhase(State.phase)
State.setNight(State.night)

return State
