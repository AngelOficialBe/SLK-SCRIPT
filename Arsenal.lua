-- Arsenal Silent Aim + Auto Fire + Inf Ammo (Xeno)
-- Ejecuta DENTRO de una partida (no en el lobby)

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Esperar módulos (obligatorio estar en partida)
local GeneralFunctions, TeamCheck, Bridge, State, General

local function waitModules()
	local t = 0
	while t < 30 do
		local ok = pcall(function()
			GeneralFunctions = require(ReplicatedStorage.Modules.GeneralFunctions)
			TeamCheck = require(ReplicatedStorage.Modules.TeamCheck)
			Bridge = require(ReplicatedFirst.Client.Utility.Bridge)
			State = require(ReplicatedFirst.Client.Utility.State)
			General = require(ReplicatedFirst.Client.Utility.General)
		end)
		if ok and GeneralFunctions and State then
			return true
		end
		task.wait(0.5)
		t = t + 0.5
	end
	return false
end

if not waitModules() then
	warn("[Arsenal] Entra a una PARTIDA primero, luego ejecuta el script.")
	return
end

local OriginalCast = GeneralFunctions.cast
local OriginalGetHitList = GeneralFunctions.gethitlist

local Settings = {
	SilentAimEnabled = true,
	AutoFireEnabled = true,
	InfiniteAmmoEnabled = true,
	AutoFireMeleeEnabled = false,
	FieldOfView = 180,
	IgnoreTeammates = true,
	RequireVisibility = true,
	RequireMouseLocked = false, -- false = más fácil de usar
	HeadshotRatio = 0.49,
	MaximumDistance = 1500,
	MinimumWeaponRange = 20,
	CameraOriginTolerance = 2,
	ReserveAmmo = 300,
	MaximumAmmoGuard = 999,
}

-- Limpiar script anterior
pcall(function()
	if getgenv().ArsenalCombatAssist and getgenv().ArsenalCombatAssist.Restore then
		getgenv().ArsenalCombatAssist.Restore()
	end
end)

local function IsAlive()
	local ok, result = pcall(function()
		return LocalPlayer.NRPBS.Health.Value > 0
	end)
	return ok and result
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
		local ok, team = pcall(function()
			return TeamCheck.isteam(LocalPlayer, character)
		end)
		if ok and team then return false end
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
	local offset = aimPoint - origin
	local hitInstance = OriginalCast(Ray.new(origin, offset.Unit * offset.Magnitude), hitList)
	if hitInstance == nil then return true end
	return hitInstance:IsDescendantOf(character)
end

local function FindTarget(origin, direction, hitList)
	local maxAngle = math.rad(Settings.FieldOfView) * 0.5
	local bestAngle = maxAngle
	local bestHitbox, bestAimPoint = nil, nil

	for _, player in ipairs(Players:GetPlayers()) do
		if IsValidTarget(player) then
			local character = player.Character
			local hitbox = character.Hitbox
			local aimPoint = GetAimPoint(hitbox)
			local dist = (aimPoint - origin).Magnitude
			if dist > 0.001 and dist <= Settings.MaximumDistance then
				local angle = GetAngleBetween(origin, direction, aimPoint)
				if angle < bestAngle then
					if (not Settings.RequireVisibility) or IsVisibleFromCamera(origin, aimPoint, character, hitList) then
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

-- Hook
if newcclosure then
	GeneralFunctions.cast = newcclosure(HookedCast)
else
	GeneralFunctions.cast = HookedCast
end

local renderConnection = RunService.RenderStepped:Connect(function()
	pcall(MaintainAmmo)
	local hitList = OriginalGetHitList()
	local autoFire = ShouldAutoFire(hitList)
	local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	State.Held1 = autoFire or holding
end)

-- ==================== GUI ====================
pcall(function()
	if getgenv().ArsenalGUI then getgenv().ArsenalGUI:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ArsenalGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
getgenv().ArsenalGUI = gui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 250)
frame.Position = UDim2.new(0, 15, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "Arsenal Assist"
title.TextColor3 = Color3.fromRGB(180, 160, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = frame

local function addToggle(y, text, key)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 32)
	btn.Position = UDim2.new(0, 8, 0, y)
	btn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
	btn.Text = text .. ": ON"
	btn.TextColor3 = Color3.fromRGB(100, 255, 140)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	btn.MouseButton1Click:Connect(function()
		Settings[key] = not Settings[key]
		if Settings[key] then
			btn.Text = text .. ": ON"
			btn.TextColor3 = Color3.fromRGB(100, 255, 140)
		else
			btn.Text = text .. ": OFF"
			btn.TextColor3 = Color3.fromRGB(255, 100, 100)
		end
	end)
end

addToggle(40, "Silent Aim", "SilentAimEnabled")
addToggle(78, "Auto Fire", "AutoFireEnabled")
addToggle(116, "Inf Ammo", "InfiniteAmmoEnabled")
addToggle(154, "Team Check", "IgnoreTeammates")
addToggle(192, "Wall Check", "RequireVisibility")

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 26, 0, 26)
close.Position = UDim2.new(1, -30, 0, 3)
close.BackgroundColor3 = Color3.fromRGB(50, 30, 35)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 150, 150)
close.Font = Enum.Font.GothamBold
close.TextSize = 12
close.Parent = frame
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)

local function Restore()
	pcall(function()
		GeneralFunctions.cast = OriginalCast
		renderConnection:Disconnect()
		State.Held1 = false
	end)
	getgenv().ArsenalCombatAssist = nil
end

close.MouseButton1Click:Connect(function()
	Restore()
	gui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.RightControl then
		frame.Visible = not frame.Visible
	end
end)

getgenv().ArsenalCombatAssist = {
	Settings = Settings,
	Restore = Restore,
}

print("[Arsenal Assist] OK - Silent Aim activo")
