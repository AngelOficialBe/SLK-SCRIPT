-- ==================== ARGZx Arsenal Silent Aim + ESP ====================
-- Basado en el open source de ScriptBlox (GeneralFunctions.cast)
-- Todo se activa automaticamente al ejecutar
-- Optimizado para Xeno

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== CARGAR MODULOS DEL JUEGO ====================
local GeneralFunctions, TeamCheck, Bridge, State, General

local success, err = pcall(function()
	GeneralFunctions = require(ReplicatedStorage.Modules.GeneralFunctions)
	TeamCheck = require(ReplicatedStorage.Modules.TeamCheck)
	Bridge = require(ReplicatedFirst.Client.Utility.Bridge)
	State = require(ReplicatedFirst.Client.Utility.State)
	General = require(ReplicatedFirst.Client.Utility.General)
end)

if not success then
	warn("[ARGZx] Error cargando modulos de Arsenal:", err)
	warn("[ARGZx] Asegurate de estar DENTRO de una partida de Arsenal.")
	return
end

local OriginalCast = GeneralFunctions.cast
local OriginalGetHitList = GeneralFunctions.gethitlist

-- ==================== SETTINGS ====================
local Settings = {
	-- Silent Aim
	SilentAimEnabled = true,
	FieldOfView = 220,              -- FOV amplio
	IgnoreTeammates = true,
	RequireVisibility = false,      -- false = apunta aunque haya pared (mas fuerte)
	HeadshotRatio = 0.62,           -- Mas alto = mas cerca de la cabeza real
	MaximumDistance = 2000,
	MinimumWeaponRange = 15,
	CameraOriginTolerance = 3,

	-- Extra
	AutoFireEnabled = false,        -- false = solo cuando TU disparas
	InfiniteAmmoEnabled = true,
	RequireMouseLocked = false,

	-- ESP
	ESPEnabled = true,
	MaxESPDistance = 900,
	EnemyColor = Color3.fromRGB(255, 45, 45),
	AllyColor = Color3.fromRGB(50, 255, 100),
}

print("[ARGZx] Modulos cargados. Inicializando Silent Aim + ESP...")

-- Limpiar hooks anteriores
if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
	pcall(function() getgenv().ArsenalCombatAssist.Restore() end)
end

-- ==================== SILENT AIM (metodo correcto de Arsenal) ====================
local function IsAlive()
	local ok, result = pcall(function()
		return LocalPlayer.NRPBS.Health.Value > 0
	end)
	return ok and result
end

local function IsValidTarget(player)
	if player == LocalPlayer then return false end
	local character = player.Character
	if not character then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if not character:FindFirstChild("Hitbox") then return false end

	if Settings.IgnoreTeammates then
		local ok, isTeam = pcall(function()
			return TeamCheck.isteam(LocalPlayer, character)
		end)
		if ok and isTeam then return false end
	end

	return true
end

local function GetAimPoint(hitbox)
	-- Apunta a la parte superior del hitbox (cabeza)
	local verticalOffset = hitbox.Size.Y * Settings.HeadshotRatio
	return hitbox.Position + Vector3.new(0, verticalOffset, 0)
end

local function GetAngleBetween(origin, direction, position)
	local offset = position - origin
	if offset.Magnitude < 0.001 then return 0 end
	local dot = direction.Unit:Dot(offset.Unit)
	return math.acos(math.clamp(dot, -1, 1))
end

local function IsVisibleFromCamera(origin, aimPoint, character, hitList)
	local offset = aimPoint - origin
	local hitInstance = OriginalCast(Ray.new(origin, offset.Unit * offset.Magnitude), hitList)
	if hitInstance == nil then return true end
	return hitInstance:IsDescendantOf(character)
end

local function FindTarget(origin, direction, hitList)
	local maximumAngle = math.rad(Settings.FieldOfView) * 0.5
	local bestAngle = maximumAngle
	local bestHitbox = nil
	local bestAimPoint = nil

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local hitbox = character.Hitbox
			local aimPoint = GetAimPoint(hitbox)
			local distance = (aimPoint - origin).Magnitude

			if distance > 0.001 and distance <= Settings.MaximumDistance then
				local angle = GetAngleBetween(origin, direction, aimPoint)

				if angle < bestAngle then
					local visible = true
					if Settings.RequireVisibility then
						visible = IsVisibleFromCamera(origin, aimPoint, character, hitList)
					end
					if visible then
						bestAngle = angle
						bestHitbox = hitbox
						bestAimPoint = aimPoint
					end
				end
			end
		end
	end

	return bestHitbox, bestAimPoint
end

local function IsWeaponRay(ray)
	local originOffset = (ray.Origin - Camera.CFrame.Position).Magnitude
	return originOffset <= Settings.CameraOriginTolerance and ray.Direction.Magnitude >= Settings.MinimumWeaponRange
end

local function HookedCast(ray, hitList)
	if Settings.SilentAimEnabled and IsWeaponRay(ray) then
		local hitbox, aimPoint = FindTarget(ray.Origin, ray.Direction, hitList)
		if hitbox and aimPoint then
			-- Fuerza el tiro exactamente al punto de la cabeza
			return hitbox, aimPoint, Vector3.new(0, 1, 0), hitbox.Material
		end
	end
	return OriginalCast(ray, hitList)
end

-- Aplicar el hook
GeneralFunctions.cast = newcclosure(HookedCast)

-- ==================== INFINITE AMMO ====================
local function MaintainAmmo()
	if not Settings.InfiniteAmmoEnabled then return end
	local gun = State.gun
	if not gun then return end

	local capacity = math.min(General.getammo(gun), 999)

	if State.equipped == "primary" then
		if State.primarymode == "2" then
			if State.primarygrenades < 1 then
				State.primarygrenades = 1
				Bridge.CountAmmo:Fire()
			end
			if State.storedgrenades < 300 then
				State.storedgrenades = 300
				Bridge.CountAmmo:Fire()
			end
		else
			if State.ammocount < capacity then
				State.ammocount = capacity
				Bridge.CountAmmo:Fire()
			end
			if State.primarystored < 300 then
				State.primarystored = 300
				Bridge.CountAmmo:Fire()
			end
		end
	elseif State.equipped == "secondary" then
		if State.ammo2count < capacity then
			State.ammo2count = capacity
			Bridge.CountAmmo:Fire()
		end
		if State.secondarystored < 300 then
			State.secondarystored = 300
			Bridge.CountAmmo:Fire()
		end
	end
end

-- ==================== ESP ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ARGZx_ESP"
pcall(function() ESPFolder.Parent = CoreGui end)

local highlights = {}
local billboards = {}

local function clearESP(plr)
	if highlights[plr] then
		pcall(function() highlights[plr]:Destroy() end)
		highlights[plr] = nil
	end
	if billboards[plr] then
		pcall(function() billboards[plr]:Destroy() end)
		billboards[plr] = nil
	end
end

local function createESP(plr)
	if plr == LocalPlayer then return end
	clearESP(plr)

	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0.15
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = ESPFolder
	highlights[plr] = hl

	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 220, 0, 55)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Parent = ESPFolder

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Parent = bb

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.new(0, 0, 0.45, 0)
	infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 12
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Parent = bb

	billboards[plr] = bb
end

local function updateESP()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LocalPlayer then continue end

		if not highlights[plr] then
			createESP(plr)
		end

		local hl = highlights[plr]
		local bb = billboards[plr]
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local head = char and char:FindFirstChild("Head")
		local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Hitbox"))

		if Settings.ESPEnabled and char and hum and hum.Health > 0 and head and root then
			local dist = (Camera.CFrame.Position - root.Position).Magnitude
			if dist > Settings.MaxESPDistance then
				if hl then hl.Enabled = false end
				if bb then bb.Enabled = false end
				continue
			end

			local enemy = true
			pcall(function()
				if TeamCheck.isteam(LocalPlayer, char) then
					enemy = false
				end
			end)

			local color = enemy and Settings.EnemyColor or Settings.AllyColor

			if hl then
				hl.Adornee = char
				hl.FillColor = color
				hl.OutlineColor = color
				hl.Enabled = true
			end

			if bb then
				bb.Adornee = head
				bb.Enabled = true
				local nameL = bb:FindFirstChild("Name")
				local infoL = bb:FindFirstChild("Info")
				if nameL then
					nameL.Text = plr.DisplayName or plr.Name
					nameL.TextColor3 = color
				end
				if infoL then
					infoL.Text = string.format("%dm  |  %d HP", math.floor(dist), math.floor(hum.Health))
					infoL.TextColor3 = Color3.fromRGB(230, 230, 230)
				end
			end
		else
			if hl then hl.Enabled = false end
			if bb then bb.Enabled = false end
		end
	end
end

for _, plr in ipairs(Players:GetPlayers()) do
	createESP(plr)
end

Players.PlayerAdded:Connect(function(plr)
	task.wait(1.5)
	createESP(plr)
end)

Players.PlayerRemoving:Connect(clearESP)

-- ==================== LOOP PRINCIPAL ====================
local renderConnection = RunService.RenderStepped:Connect(function()
	MaintainAmmo()
	updateESP()
end)

-- Guardar para poder restaurar
getgenv().ArsenalCombatAssist = {
	Settings = Settings,
	Restore = function()
		GeneralFunctions.cast = OriginalCast
		if renderConnection then renderConnection:Disconnect() end
		for plr in pairs(highlights) do clearESP(plr) end
		pcall(function() ESPFolder:Destroy() end)
		getgenv().ArsenalCombatAssist = nil
		print("[ARGZx] Silent Aim + ESP desactivado.")
	end
}

print("================================================")
print("[ARGZx] Arsenal Silent Aim + ESP CARGADO")
print("Silent Aim : ACTIVADO (tiros a la cabeza)")
print("ESP        : ACTIVADO")
print("Municion   : INFINITA")
print("================================================")
