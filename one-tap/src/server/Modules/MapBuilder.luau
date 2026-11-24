--[[
	MapBuilder: generates simple greybox maps so the game is playable before any
	real maps exist.

	USING YOUR OWN MAPS (recommended once you build them):
	  Put Models in ServerStorage > Maps. Each map Model needs:
	    - a Folder named "Spawns" with invisible Parts where players can spawn
	      (point their front face toward the action)
	    - optional attribute DisplayName (string) for the vote screen
	  If ServerStorage.Maps has at least one Model, these generated maps are skipped.

	Generated maps are built high in the sky (ORIGIN) so they never overlap the
	Baseplate or anything else already in your place.
]]

local MapBuilder = {}

local ORIGIN = Vector3.new(0, 200, 0)

type Palette = {
	floor: Color3,
	wall: Color3,
	cover: Color3,
	accent: Color3,
}

local PALETTES: { [string]: Palette } = {
	Yard = {
		floor = Color3.fromRGB(96, 101, 112),
		wall = Color3.fromRGB(62, 66, 77),
		cover = Color3.fromRGB(196, 142, 84),
		accent = Color3.fromRGB(226, 92, 70),
	},
	Alley = {
		floor = Color3.fromRGB(84, 80, 92),
		wall = Color3.fromRGB(122, 96, 88),
		cover = Color3.fromRGB(70, 120, 150),
		accent = Color3.fromRGB(240, 196, 80),
	},
	Towers = {
		floor = Color3.fromRGB(110, 122, 98),
		wall = Color3.fromRGB(78, 86, 72),
		cover = Color3.fromRGB(170, 170, 160),
		accent = Color3.fromRGB(90, 170, 230),
	},
}

local function block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A block whose BOTTOM sits at floor level (y is height above the floor).
local function onFloor(parent: Instance, size: Vector3, x: number, z: number, color: Color3, y: number?, rotation: number?): Part
	local cf = CFrame.new(ORIGIN + Vector3.new(x, (y or 0) + size.Y / 2, z)) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	return block(parent, size, cf, color)
end

local function spawnMarker(spawns: Instance, x: number, z: number, lookX: number?, lookZ: number?, y: number?)
	local position = ORIGIN + Vector3.new(x, (y or 0) + 0.5, z)
	local target = ORIGIN + Vector3.new(lookX or 0, (y or 0) + 0.5, lookZ or 0)
	local marker = Instance.new("Part")
	marker.Name = "Spawn"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(4, 1, 4)
	marker.CFrame = CFrame.lookAt(position, target)
	marker.Parent = spawns
end

local function newMap(name: string, displayName: string): (Model, Folder, Folder)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("DisplayName", displayName)
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = model
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	return model, geometry, spawns
end

-- Floor + four tall walls. width = X size, length = Z size.
local function arena(geometry: Instance, width: number, length: number, wallHeight: number, palette: Palette)
	block(
		geometry,
		Vector3.new(width + 8, 2, length + 8),
		CFrame.new(ORIGIN - Vector3.new(0, 1, 0)),
		palette.floor,
		Enum.Material.Concrete
	)
	local hw, hl = width / 2, length / 2
	onFloor(geometry, Vector3.new(4, wallHeight, length + 8), -hw - 2, 0, palette.wall)
	onFloor(geometry, Vector3.new(4, wallHeight, length + 8), hw + 2, 0, palette.wall)
	onFloor(geometry, Vector3.new(width, wallHeight, 4), 0, -hl - 2, palette.wall)
	onFloor(geometry, Vector3.new(width, wallHeight, 4), 0, hl + 2, palette.wall)
end

-- Stairs climbing `height` studs, starting at (x, z) and rising toward +Z (rotated by `rotation`).
local function stairs(geometry: Instance, x: number, z: number, height: number, width: number, rotation: number, color: Color3)
	local stepHeight, stepDepth = 2, 3
	local steps = math.ceil(height / stepHeight)
	local basis = CFrame.new(ORIGIN + Vector3.new(x, 0, z)) * CFrame.Angles(0, math.rad(rotation), 0)
	for i = 1, steps do
		local h = i * stepHeight
		local size = Vector3.new(width, h, stepDepth)
		block(geometry, size, basis * CFrame.new(0, h / 2, (i - 1) * stepDepth + stepDepth / 2), color)
	end
end

--------------------------------------------------------------------------------
-- Map 1: Yard. Open square full of crates: lots of mid-range peeks.
--------------------------------------------------------------------------------

local function buildYard(): Model
	local palette = PALETTES.Yard
	local model, geometry, spawns = newMap("Yard", "Yard")
	local size = 220
	arena(geometry, size, size, 40, palette)

	local rng = Random.new(11)
	local shapes = {
		Vector3.new(8, 8, 8),
		Vector3.new(12, 6, 4),
		Vector3.new(4, 10, 16),
		Vector3.new(16, 5, 8),
	}
	local placed = 0
	while placed < 42 do
		local shape = shapes[rng:NextInteger(1, #shapes)]
		local x = rng:NextNumber(-80, 80)
		local z = rng:NextNumber(-80, 80)
		-- Keep crates off the spawn ring and out of the corner perches/stairs.
		local nearPerch = math.abs(x) > 50 and math.abs(z) > 50
		if x * x + z * z < 82 * 82 and not nearPerch then
			placed += 1
			local rot = rng:NextInteger(0, 3) * 45
			local crate = onFloor(geometry, shape, x, z, palette.cover, 0, rot)
			crate.Material = Enum.Material.WoodPlanks
			if rng:NextNumber() < 0.25 then
				local stacked = onFloor(geometry, Vector3.new(6, 6, 6), x, z, palette.cover, shape.Y, rot + 20)
				stacked.Material = Enum.Material.WoodPlanks
			end
		end
	end

	-- Four sniper perches in the corners, reached by stairs from the -Z side.
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local cx, cz = corner[1] * 70, corner[2] * 70
		onFloor(geometry, Vector3.new(18, 2, 18), cx, cz, palette.accent, 14) -- deck, top at 16
		for _, leg in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			onFloor(geometry, Vector3.new(2, 14, 2), cx + leg[1] * 8, cz + leg[2] * 8, palette.wall)
		end
		onFloor(geometry, Vector3.new(18, 3, 1), cx, cz + 8.5, palette.accent, 16) -- parapet
		stairs(geometry, cx, cz - 9 - 24, 16, 6, 0, palette.wall) -- 8 steps x 3 = 24 long
	end

	for i = 1, 12 do
		local angle = i / 12 * math.pi * 2
		spawnMarker(spawns, math.cos(angle) * 98, math.sin(angle) * 98)
	end
	return model
end

--------------------------------------------------------------------------------
-- Map 2: Alley. Three long lanes (sniper heaven) with doorways between them
-- (knife flanks).
--------------------------------------------------------------------------------

local function buildAlley(): Model
	local palette = PALETTES.Alley
	local model, geometry, spawns = newMap("Alley", "Alley")
	local width, length = 120, 260
	arena(geometry, width, length, 36, palette)

	-- Two long dividing walls with doorway gaps. They stay below the bridge (y 16).
	for _, wallX in { -20, 20 } do
		local z = -length / 2
		local segment = 34
		local gap = 10
		while z < length / 2 do
			local segLength = math.min(segment, length / 2 - z)
			local wall = onFloor(geometry, Vector3.new(4, 14, segLength), wallX, z + segLength / 2, palette.wall)
			wall.Material = Enum.Material.Brick
			z += segLength + gap
		end
	end

	-- Low cover staggered down each lane.
	local rng = Random.new(23)
	for _, laneX in { -40, 0, 40 } do
		for z = -100, 100, 25 do
			if math.abs(z) > 8 then -- leave the bridge landing clear
				local offset = rng:NextNumber(-5, 5)
				onFloor(geometry, Vector3.new(10, 4, 3), laneX + offset, z + rng:NextNumber(-4, 4), palette.cover)
			end
		end
	end

	-- A bridge across the middle (top at 18) for high-ground shots.
	onFloor(geometry, Vector3.new(width, 2, 10), 0, 0, palette.accent, 16)
	stairs(geometry, -55, -32, 18, 6, 0, palette.wall) -- 9 steps x 3 = 27 long, ends at z -5
	stairs(geometry, 55, 32, 18, 6, 180, palette.wall)

	for _, endZ in { -1, 1 } do
		for _, x in { -48, -30, -8, 8, 30, 48 } do
			spawnMarker(spawns, x, endZ * 118, x, 0)
		end
	end
	return model
end

--------------------------------------------------------------------------------
-- Map 3: Towers. Four towers around a walled plaza: high ground vs. flanks.
--------------------------------------------------------------------------------

local function buildTowers(): Model
	local palette = PALETTES.Towers
	local model, geometry, spawns = newMap("Towers", "Towers")
	local size = 200
	arena(geometry, size, size, 44, palette)

	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local cx, cz = corner[1] * 50, corner[2] * 50
		onFloor(geometry, Vector3.new(20, 18, 20), cx, cz, palette.wall).Material = Enum.Material.Slate
		-- Parapet on the tower roof, open on the side facing the stairs.
		onFloor(geometry, Vector3.new(20, 3, 1), cx, cz - corner[2] * 9.5, palette.accent, 18)
		onFloor(geometry, Vector3.new(1, 3, 20), cx - corner[1] * 9.5, cz, palette.accent, 18)
		-- Stairs up the outer (wall-facing) side: 9 steps x 3 = 27 long, ending at the tower.
		stairs(geometry, cx, cz + corner[2] * 37, 18, 6, if corner[2] > 0 then 180 else 0, palette.cover)
	end

	-- Central plaza: a cross of walls with gaps + some boxes.
	onFloor(geometry, Vector3.new(40, 8, 3), -26, 0, palette.cover)
	onFloor(geometry, Vector3.new(40, 8, 3), 26, 0, palette.cover)
	onFloor(geometry, Vector3.new(3, 8, 40), 0, -26, palette.cover)
	onFloor(geometry, Vector3.new(3, 8, 40), 0, 26, palette.cover)
	local rng = Random.new(37)
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-78, 78), rng:NextNumber(-78, 78)
		local inPlaza = math.abs(x) < 30 and math.abs(z) < 30
		local nearTower = math.abs(x) > 30 and math.abs(x) < 70 and math.abs(z) > 30 and math.abs(z) < 95
		local onSpawnRing = x * x + z * z > 76 * 76
		if not (inPlaza or nearTower or onSpawnRing) then
			onFloor(geometry, Vector3.new(7, 7, 7), x, z, palette.cover, 0, rng:NextInteger(0, 3) * 30)
		end
	end

	for i = 1, 12 do
		local angle = (i + 0.5) / 12 * math.pi * 2
		spawnMarker(spawns, math.cos(angle) * 88, math.sin(angle) * 88)
	end
	return model
end

--------------------------------------------------------------------------------

-- Builds every default map into a new Folder (normally ServerStorage.Maps).
function MapBuilder.buildDefaults(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Maps"
	for _, build in { buildYard, buildAlley, buildTowers } do
		build().Parent = folder
	end
	folder.Parent = parent
	return folder
end

return MapBuilder
