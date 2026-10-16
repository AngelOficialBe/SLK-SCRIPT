--[[
    Arsenal Combat Assist - Xeno Compatible
    Features: Silent Aim, Auto Fire, Infinite Ammo
    Based on open-source ScriptBlox version
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Wait for Arsenal modules
local GeneralFunctions, TeamCheck, Bridge, State, General

local function loadModules()
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

local loaded = false
for i = 1, 50 do
	if loadModules() then
		loaded = true
		break
	end
	task.wait(0.2)
end

if not loaded then
	warn("[Arsenal] No se pudieron cargar los módulos. Entra a una partida e intenta de nuevo.")
	return
end

local OriginalCast = GeneralFunctions.cast
local OriginalGetHitList = GeneralFunctions.gethitlist

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

-- Restore previous if exists
if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
	pcall(getgenv().ArsenalCombatAssist.Restore)
end

-- ==================== HELPERS ====================
local function IsAlive()
	local nrpbs = LocalPlayer:FindFirstChild("NRPBS")
	if not nrpbs then return false end
	local health = nrpbs:FindFirstChild("Health")
	return health and health.Value > 0
end

local function HasWeaponEquipped()
	return State.gun ~= nil and State.equipped ~= "none"
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

	if Settings.IgnoreTeammates then
		local ok, isTeam = pcall(function()
			return TeamCheck.isteam(LocalPlayer, character)
		end)
		if ok and isTeam then return false end
	end

	return true
end

local function GetAimPoint(hitbox)
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
	if not Settings.InfiniteAmmoEnabled then return end
	local gun = State.gun
	if not gun then return end

	local capacity = math.min(General.getammo(gun), Settings.MaximumAmmoGuard)

	if State.equipped == "primary" then
		if State.primarymode == "2" then
			if State.primarygrenades < 1 then
				State.primarygrenades = 1
				Bridge.CountAmmo:Fire()
			end
			if State.storedgrenades < Settings.ReserveAmmo then
				State.storedgrenades = Settings.ReserveAmmo
				Bridge.CountAmmo:Fire()
			end
		else
			if State.ammocount < capacity then
				State.ammocount = capacity
				Bridge.CountAmmo:Fire()
			end
			if State.primarystored < Settings.ReserveAmmo then
				State.primarystored = Settings.ReserveAmmo
				Bridge.CountAmmo:Fire()
			end
		end
	elseif State.equipped == "secondary" then
		if State.ammo2count < capacity then
			State.ammo2count = capacity
			Bridge.CountAmmo:Fire()
		end
		if State.secondarystored < Settings.ReserveAmmo then
			State.secondarystored = Settings.ReserveAmmo
			Bridge.CountAmmo:Fire()
		end
	end
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

-- Hook cast (Xeno compatible)
local nc = newcclosure or function(f) return f end
GeneralFunctions.cast = nc(HookedCast)

local renderConnection = RunService.RenderStepped:Connect(function()
	pcall(MaintainAmmo)

	local hitList = OriginalGetHitList()
	local autoFire = ShouldAutoFire(hitList)
	local playerHolding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

	if autoFire or playerHolding then
		State.Held1 = true
	else
		State.Held1 = false
	end
end)

-- ==================== SIMPLE GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "ArsenalAssistGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 280)
main.Position = UDim2.new(0, 20, 0.5, -140)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 50, 180)
stroke.Thickness = 1.5
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Text = "Arsenal Assist"
title.TextColor3 = Color3.fromRGB(200, 180, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = main

local function makeToggle(y, name, key, default)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -20, 0, 36)
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

makeToggle(44, "Silent Aim", "SilentAimEnabled", true)
makeToggle(86, "Auto Fire", "AutoFireEnabled", true)
makeToggle(128, "Infinite Ammo", "InfiniteAmmoEnabled", true)
makeToggle(170, "Ignore Teammates", "IgnoreTeammates", true)
makeToggle(212, "Require Visibility", "RequireVisibility", true)

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

closeBtn.MouseButton1Click:Connect(function()
	if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
		getgenv().ArsenalCombatAssist.Restore()
	end
	gui:Destroy()
end)

-- RightControl to toggle GUI
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		main.Visible = not main.Visible
	end
end)

getgenv().ArsenalCombatAssist = {
	Settings = Settings,
	FindTarget = FindTarget,
	IsWeaponRay = IsWeaponRay,
	MaintainAmmo = MaintainAmmo,
	ShouldAutoFire = ShouldAutoFire,
	OriginalCast = OriginalCast,
	Restore = function()
		GeneralFunctions.cast = OriginalCast
		if renderConnection then renderConnection:Disconnect() end
		State.Held1 = false
		getgenv().ArsenalCombatAssist = nil
	end,
}

print("[Arsenal Assist] Cargado | RightCtrl = mostrar/ocultar GUI")
