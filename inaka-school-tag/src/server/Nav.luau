-- CPU用の道案内（PathfindingService）。壁や階段をよけて目的地へ向かう
local PathfindingService = game:GetService("PathfindingService")

local Nav = {}

function Nav.new(actor)
	return { actor = actor, waypoints = {}, index = 1, goal = nil, lastCompute = 0 }
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Nav.moveTo(nav, goal: Vector3)
	local actor = nav.actor
	local hrp, humanoid = actor.hrp, actor.humanoid
	if not hrp or not humanoid or not humanoid.Parent then
		return
	end

	local t = os.clock()
	if not nav.goal or (nav.goal - goal).Magnitude > 8 or t - nav.lastCompute > 2.5 then
		nav.goal = goal
		nav.lastCompute = t
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = false })
		local ok = pcall(function()
			-- 足元から探す（体の中心だと、2階や屋根など上の面に取り違えることがある）
			path:ComputeAsync(hrp.Position - Vector3.new(0, humanoid.HipHeight + hrp.Size.Y / 2, 0), goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			nav.waypoints = path:GetWaypoints()
			nav.index = 2
		else
			nav.waypoints = {}
			nav.index = 1
		end
	end

	local waypoint = nav.waypoints[nav.index]
	if waypoint and (flat(waypoint.Position) - flat(hrp.Position)).Magnitude < 3.5 then
		nav.index += 1
		waypoint = nav.waypoints[nav.index]
	end
	if waypoint then
		humanoid:MoveTo(waypoint.Position)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
	else
		humanoid:MoveTo(goal)
	end
end

return Nav
