-- ==================== ARGZx Arsenal - HARD LOCK Silent Aim + ESP ====================
-- Circulo grande de FOV
-- Si el enemigo esta dentro del circulo → TODOS los tiros van BLOQUEADOS a la cabeza
-- Compatible con Xeno

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== MODULOS ====================
local GeneralFunctions, TeamCheck, Bridge, State, General

local okLoad, loadErr = pcall(function()
	GeneralFunctions = require(ReplicatedStorage.Modules.GeneralFunctions)
	TeamCheck = require(ReplicatedStorage.Modules.TeamCheck)
	Bridge = require(ReplicatedFirst.Client.Utility.Bridge)
	State = require(ReplicatedFirst.Client.Utility.State)
	General = require(ReplicatedFirst.Client.Utility.General)
end)

if not okLoad then
	warn("[ARGZx] Error: entra a una PARTIDA de Arsenal antes de ejecutar.")
	warn(loadErr)
	return
end

local OriginalCast = GeneralFunctions.cast
local OriginalGetHitList = GeneralFunctions.gethitlist

-- ==================== CONFIG (AGRESIVO) ====================
local Settings = {
	SilentAimEnabled = true,
	FieldOfView = 350,              -- CIRCULO GRANDE
	IgnoreTeammates = true,
	RequireVisibility = false,      -- Atraviesa paredes
	HeadshotRatio = 0.72,           -- Muy arriba del hitbox = cabeza
	MaximumDistance = 2500,
	MinimumWeaponRange = 10,
	CameraOriginTolerance = 4,

	InfiniteAmmo = true,
	ESPEnabled = true,
	MaxESPDistance = 1000,

	-- Colores
	FOVColor = Color3.fromRGB(255, 50, 50),
	EnemyColor = Color3.fromRGB(255, 40, 40),
	AllyColor = Color3.fromRGB(40, 255, 90),
}

-- Limpiar versiones anteriores
if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
	pcall(function() getgenv().ArsenalCombatAssist.Restore() end)
end

print("[ARGZx] Cargando HARD LOCK Silent Aim...")

-- ==================== FOV CIRCLE (visible) ====================
local FOVCircle = nil
pcall(function()
	FOVCircle = Drawing.new("Circle")
	FOVCircle.Thickness = 2
	FOVCircle.NumSides = 80
	FOVCircle.Radius = Settings.FieldOfView
	FOVCircle.Filled = false
	FOVCircle.Color = Settings.FOVColor
	FOVCircle.Transparency = 0.7
	FOVCircle.Visible = true
end)

-- ==================== SILENT AIM HARD LOCK ====================
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

local function GetHeadPosition(hitbox, character)
	-- Prioridad 1: Head real del personaje
	local head = character:FindFirstChild("Head")
	if head then
		return head.Position + Vector3.new(0, 0.15, 0) -- un poco mas arriba del centro de la cabeza
	end
	-- Prioridad 2: parte superior del Hitbox
	local verticalOffset = hitbox.Size.Y * Settings.HeadshotRatio
	return hitbox.Position + Vector3.new(0, verticalOffset, 0)
end

local function GetAngleBetween(origin, direction, position)
	local offset = position - origin
	if offset.Magnitude < 0.001 then return 0 end
	local dot = direction.Unit:Dot(offset.Unit)
	return math.acos(math.clamp(dot, -1, 1))
end

local function FindTarget(origin, direction)
	local maximumAngle = math.rad(Settings.FieldOfView) * 0.5
	local bestAngle = maximumAngle
	local bestHitbox = nil
	local bestAimPoint = nil
	local bestCharacter = nil

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local hitbox = character.Hitbox
			local aimPoint = GetHeadPosition(hitbox, character)
			local distance = (aimPoint - origin).Magnitude

			if distance > 0.5 and distance <= Settings.MaximumDistance then
				local angle = GetAngleBetween(origin, direction, aimPoint)

				if angle < bestAngle then
					bestAngle = angle
					bestHitbox = hitbox
					bestAimPoint = aimPoint
					bestCharacter = character
				end
			end
		end
	end

	return bestHitbox, bestAimPoint, bestCharacter
end

local function IsWeaponRay(ray)
	local originOffset = (ray.Origin - Camera.CFrame.Position).Magnitude
	return originOffset <= Settings.CameraOriginTolerance and ray.Direction.Magnitude >= Settings.MinimumWeaponRange
end

-- HOOK PRINCIPAL - HARD LOCK
local function HookedCast(ray, hitList)
	if Settings.SilentAimEnabled and IsWeaponRay(ray) then
		local hitbox, aimPoint, character = FindTarget(ray.Origin, ray.Direction)

		if hitbox and aimPoint then
			-- TOTALMENTE BLOQUEADO a la cabeza
			-- Devuelve siempre el hitbox + el punto exacto de la cabeza
			return hitbox, aimPoint, Vector3.new(0, 1, 0), hitbox.Material
		end
	end

	return OriginalCast(ray, hitList)
end

GeneralFunctions.cast = newcclosure(HookedCast)

-- ==================== INFINITE AMMO ====================
local function MaintainAmmo()
	if not Settings.InfiniteAmmo then return end
	local gun = State.gun
	if not gun then return end

	local capacity = math.min(General.getammo(gun), 999)

	pcall(function()
		if State.equipped == "primary" then
			if State.primarymode == "2" then
				if State.primarygrenades < 1 then State.primarygrenades = 1; Bridge.CountAmmo:Fire() end
				if State.storedgrenades < 300 then State.storedgrenades = 300; Bridge.CountAmmo:Fire() end
			else
				if State.ammocount < capacity then State.ammocount = capacity; Bridge.CountAmmo:Fire() end
				if State.primarystored < 300 then State.primarystored = 300; Bridge.CountAmmo:Fire() end
			end
		elseif State.equipped == "secondary" then
			if State.ammo2count < capacity then State.ammo2count = capacity; Bridge.CountAmmo:Fire() end
			if State.secondarystored < 300 then State.secondarystored = 300; Bridge.CountAmmo:Fire() end
		end
	end)
end

-- ==================== ESP ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ARGZx_ESP"
pcall(function() ESPFolder.Parent = CoreGui end)

local highlights = {}
local billboards = {}

local function clearESP(plr)
	if highlights[plr] then pcall(function() highlights[plr]:Destroy() end); highlights[plr] = nil end
	if billboards[plr] then pcall(function() billboards[plr]:Destroy() end); billboards[plr] = nil end
end

local function createESP(plr)
	if plr == LocalPlayer then return end
	clearESP(plr)

	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = ESPFolder
	highlights[plr] = hl

	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 220, 0, 50)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.Parent = ESPFolder

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextStrokeTransparency = 0.25
	nameLabel.Parent = bb

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.new(0, 0, 0.48, 0)
	infoLabel.Size = UDim2.new(1, 0, 0.45, 0)
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 12
	infoLabel.TextStrokeTransparency = 0.35
	infoLabel.Parent = bb

	billboards[plr] = bb
end

local function updateESP()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr == LocalPlayer then continue end
		if not highlights[plr] then createESP(plr) end

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
				if TeamCheck.isteam(LocalPlayer, char) then enemy = false end
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

for _, plr in ipairs(Players:GetPlayers()) do createESP(plr) end
Players.PlayerAdded:Connect(function(plr) task.wait(1.2); createESP(plr) end)
Players.PlayerRemoving:Connect(clearESP)

-- ==================== RENDER LOOP ====================
local conn = RunService.RenderStepped:Connect(function()
	-- Actualizar circulo FOV
	if FOVCircle then
		local mousePos = UserInputService:GetMouseLocation()
		FOVCircle.Position = mousePos
		FOVCircle.Radius = Settings.FieldOfView
		FOVCircle.Visible = Settings.SilentAimEnabled
	end

	MaintainAmmo()
	updateESP()
end)

-- ==================== RESTORE ====================
getgenv().ArsenalCombatAssist = {
	Settings = Settings,
	Restore = function()
		GeneralFunctions.cast = OriginalCast
		if conn then conn:Disconnect() end
		if FOVCircle then pcall(function() FOVCircle:Remove() end) end
		for plr in pairs(highlights) do clearESP(plr) end
		pcall(function() ESPFolder:Destroy() end)
		getgenv().ArsenalCombatAssist = nil
		print("[ARGZx] Desactivado.")
	end
}

print("====================================================")
print("[ARGZx] HARD LOCK Silent Aim + ESP CARGADO")
print("Circulo FOV : GRANDE (350)")
print("Silent Aim  : BLOQUEADO A LA CABEZA")
print("ESP         : ACTIVADO")
print("Municion    : INFINITA")
print("====================================================")
