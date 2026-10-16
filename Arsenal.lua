--[[
    Arsenal Combat Assist - Xeno Fixed
    GUI carga siempre + reintento de módulos
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== SETTINGS ====================
local Settings = {
	SilentAimEnabled = true,
	AutoFireEnabled = true,
	InfiniteAmmoEnabled = true,
	AutoFireMeleeEnabled = false,
	FieldOfView = 180,
	IgnoreTeammates = true,
	RequireVisibility = true,
	RequireMouseLocked = true,
	HeadshotRatio = 0.49,
	MaximumDistance = 1500,
	MinimumWeaponRange = 20,
	CameraOriginTolerance = 2,
	ReserveAmmo = 300,
	MaximumAmmoGuard = 999,
}

local GeneralFunctions, TeamCheck, Bridge, State, General
local OriginalCast, OriginalGetHitList
local renderConnection
local modulesReady = false

-- ==================== GUI PRIMERO (siempre) ====================
pcall(function()
	if getgenv().ArsenalAssistGui then
		getgenv().ArsenalAssistGui:Destroy()
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ArsenalAssistGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Parent seguro para Xeno
local parentOk = pcall(function()
	gui.Parent = CoreGui
end)
if not parentOk then
	pcall(function()
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end)
end
getgenv().ArsenalAssistGui = gui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 270, 0, 320)
main.Position = UDim2.new(0, 20, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 60, 200)
stroke.Thickness = 1.5
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 36)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Arsenal Assist"
title.TextColor3 = Color3.fromRGB(200, 180, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 22)
statusLabel.Position = UDim2.new(0, 10, 0, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Estado: Cargando módulos..."
statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = main

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 40)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(220, 140, 160)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local function makeToggle(y, name, key, default)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -20, 0, 34)
	row.Position = UDim2.new(0, 10, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = main
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -50, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.fromRGB(220, 220, 235)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 12, 0, 12)
	indicator.Position = UDim2.new(1, -28, 0.5, -6)
	indicator.BackgroundColor3 = default and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(80, 80, 90)
	indicator.BorderSizePixel = 0
	indicator.Parent = row
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

	local state = default
	row.MouseButton1Click:Connect(function()
		state = not state
		Settings[key] = state
		indicator.BackgroundColor3 = state and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(80, 80, 90)
	end)
end

makeToggle(60, "Silent Aim", "SilentAimEnabled", true)
makeToggle(100, "Auto Fire", "AutoFireEnabled", true)
makeToggle(140, "Infinite Ammo", "InfiniteAmmoEnabled", true)
makeToggle(180, "Ignore Teammates", "IgnoreTeammates", true)
makeToggle(220, "Require Visibility", "RequireVisibility", true)
makeToggle(260, "Require Mouse Lock", "RequireMouseLocked", true)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		main.Visible = not main.Visible
	end
end)

print("[Arsenal Assist] GUI cargado")

-- ==================== MÓDULOS + COMBAT ====================
local function IsAlive()
	local nrpbs = LocalPlayer:FindFirstChild("NRPBS")
	if not nrpbs then return false end
	local health = nrpbs:FindFirstChild("Health")
	return health and health.Value > 0
end

local function HasWeaponEquipped()
	return State and State.gun ~= nil and State.equipped ~= "none"
end

local function IsMouseLocked()
	local mb = UserInputService.MouseBehavior
	return mb == Enum.MouseBehavior.LockCenter or mb == Enum.MouseBehavior.LockCurrentPosition
end

local function IsValidTarget(player)
	if player == LocalPlayer then return false end
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	if not character:FindFirstChild("Hitbox") then return false end
	if Settings.IgnoreTeammates and TeamCheck then
		local ok, isTeam = pcall(function()
			return TeamCheck.isteam(LocalPlayer, character)
		end)
		if ok and isTeam then return false end
	end
	return true
end

local function GetAimPoint(hitbox)
	return hitbox.Position + Vector3.new(0, hitbox.Size.Y * Settings.HeadshotRatio, 0)
end

local function GetAngleBetween(origin, direction, position)
	local offset = position - origin
	if offset.Magnitude < 0.001 then return 0 end
	return math.acos(math.clamp(direction.Unit:Dot(offset.Unit), -1, 1))
end

local function IsVisibleFromCamera(origin, aimPoint, character, hitList)
	if not OriginalCast then return true end
	local offset = aimPoint - origin
	local hitInstance = OriginalCast(Ray.new(origin, offset.Unit * offset.Magnitude), hitList)
	if hitInstance == nil then return true end
	return hitInstance:IsDescendantOf(character)
end

local function FindTarget(origin, direction, hitList)
	local maximumAngle = math.rad(Settings.FieldOfView) * 0.5
	local bestAngle = maximumAngle
	local bestHitbox, bestAimPoint = nil, nil

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local hitbox = character.Hitbox
			local aimPoint = GetAimPoint(hitbox)
			local distance = (aimPoint - origin).Magnitude
			if distance > 0.001 and distance <= Settings.MaximumDistance then
				local angle = GetAngleBetween(origin, direction, aimPoint)
				if angle < bestAngle then
					if not Settings.RequireVisibility or IsVisibleFromCamera(origin, aimPoint, character, hitList) then
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
		if hitbox then
			return hitbox, aimPoint, Vector3.new(0, 1, 0), hitbox.Material
		end
	end
	return OriginalCast(ray, hitList)
end

local function MaintainAmmo()
	if not Settings.InfiniteAmmoEnabled or not State or not General or not Bridge then return end
	local gun = State.gun
	if not gun then return end
	local ok, capacity = pcall(function()
		return math.min(General.getammo(gun), Settings.MaximumAmmoGuard)
	end)
	if not ok then return end

	pcall(function()
		if State.equipped == "primary" then
			if State.primarymode == "2" then
				if State.primarygrenades < 1 then State.primarygrenades = 1; Bridge.CountAmmo:Fire() end
				if State.storedgrenades < Settings.ReserveAmmo then State.storedgrenades = Settings.ReserveAmmo; Bridge.CountAmmo:Fire() end
			else
				if State.ammocount < capacity then State.ammocount = capacity; Bridge.CountAmmo:Fire() end
				if State.primarystored < Settings.ReserveAmmo then State.primarystored = Settings.ReserveAmmo; Bridge.CountAmmo:Fire() end
			end
		elseif State.equipped == "secondary" then
			if State.ammo2count < capacity then State.ammo2count = capacity; Bridge.CountAmmo:Fire() end
			if State.secondarystored < Settings.ReserveAmmo then State.secondarystored = Settings.ReserveAmmo; Bridge.CountAmmo:Fire() end
		end
	end)
end

local function ShouldAutoFire(hitList)
	if not Settings.AutoFireEnabled then return false end
	if not IsAlive() or not HasWeaponEquipped() then return false end
	if Settings.RequireMouseLocked and not IsMouseLocked() then return false end
	if State.equipped == "melee" and not Settings.AutoFireMeleeEnabled then return false end
	if State.reloading or State.equipping or State.taunting then return false end
	local hitbox = FindTarget(Camera.CFrame.Position, Camera.CFrame.LookVector, hitList)
	return hitbox ~= nil
end

local function startCombat()
	if modulesReady then return end
	if not GeneralFunctions or not State then return end

	OriginalCast = GeneralFunctions.cast
	OriginalGetHitList = GeneralFunctions.gethitlist

	local nc = newcclosure or function(f) return f end
	GeneralFunctions.cast = nc(HookedCast)

	if renderConnection then renderConnection:Disconnect() end
	renderConnection = RunService.RenderStepped:Connect(function()
		pcall(MaintainAmmo)
		local hitList = OriginalGetHitList and OriginalGetHitList() or {}
		local autoFire = ShouldAutoFire(hitList)
		local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		if State then
			State.Held1 = autoFire or holding
		end
	end)

	modulesReady = true
	statusLabel.Text = "Estado: Activo ✓"
	statusLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
	print("[Arsenal Assist] Combat activo")
end

local function tryLoadModules()
	local ok1, gf = pcall(function() return require(ReplicatedStorage.Modules.GeneralFunctions) end)
	local ok2, tc = pcall(function() return require(ReplicatedStorage.Modules.TeamCheck) end)
	local ok3, br = pcall(function() return require(ReplicatedFirst.Client.Utility.Bridge) end)
	local ok4, st = pcall(function() return require(ReplicatedFirst.Client.Utility.State) end)
	local ok5, ge = pcall(function() return require(ReplicatedFirst.Client.Utility.General) end)

	if ok1 and ok2 and ok3 and ok4 and ok5 then
		GeneralFunctions = gf
		TeamCheck = tc
		Bridge = br
		State = st
		General = ge
		return true
	end
	return false
end

-- Restore previo
pcall(function()
	if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
		getgenv().ArsenalCombatAssist.Restore()
	end
end)

local function Restore()
	pcall(function()
		if GeneralFunctions and OriginalCast then
			GeneralFunctions.cast = OriginalCast
		end
		if renderConnection then renderConnection:Disconnect() end
		if State then State.Held1 = false end
		modulesReady = false
		getgenv().ArsenalCombatAssist = nil
	end)
end

closeBtn.MouseButton1Click:Connect(function()
	Restore()
	gui:Destroy()
	getgenv().ArsenalAssistGui = nil
end)

getgenv().ArsenalCombatAssist = {
	Settings = Settings,
	Restore = Restore,
}

-- Reintentar módulos (necesitas estar EN PARTIDA)
task.spawn(function()
	for i = 1, 60 do
		if tryLoadModules() then
			startCombat()
			return
		end
		statusLabel.Text = "Estado: Esperando partida... (" .. i .. "/60)"
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		task.wait(0.5)
	end
	statusLabel.Text = "Estado: Entra a una partida y re-ejecuta"
	statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	warn("[Arsenal Assist] Módulos no encontrados. Entra a una partida (no lobby).")
end)
