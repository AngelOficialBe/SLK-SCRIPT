-- ==================== ARGZx Arsenal HARD LOCK v3 ====================
-- Mas estable para Xeno
-- Todo se activa solo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

print("[ARGZx] Iniciando...")

-- Esperar a que el jugador este listo
if not LocalPlayer.Character then
	LocalPlayer.CharacterAdded:Wait()
end
task.wait(1)

-- ==================== SETTINGS ====================
local Settings = {
	SilentAim = true,
	FOV = 320,
	TeamCheck = true,
	HeadOffset = 0.8,          -- altura de la cabeza
	MaxDistance = 2000,
	InfiniteAmmo = true,
	ESP = true,
	ShowFOV = true,
	EnemyColor = Color3.fromRGB(255, 40, 40),
	AllyColor = Color3.fromRGB(40, 255, 90),
	FOVColor = Color3.fromRGB(255, 60, 60),
}

-- ==================== LIMPIAR VERSION ANTERIOR ====================
if getgenv().ARGZxArsenal then
	pcall(function()
		if getgenv().ARGZxArsenal.Cleanup then
			getgenv().ARGZxArsenal.Cleanup()
		end
	end)
end

-- ==================== FOV CIRCLE ====================
local FOVCircle = nil
local hasDrawing = false

pcall(function()
	FOVCircle = Drawing.new("Circle")
	FOVCircle.Thickness = 2
	FOVCircle.NumSides = 70
	FOVCircle.Radius = Settings.FOV
	FOVCircle.Filled = false
	FOVCircle.Color = Settings.FOVColor
	FOVCircle.Transparency = 0.65
	FOVCircle.Visible = true
	hasDrawing = true
	print("[ARGZx] FOV Circle creado")
end)

if not hasDrawing then
	print("[ARGZx] Drawing no disponible, FOV invisible (normal en algunos executors)")
end

-- ==================== HELPERS ====================
local function isAlive(plr)
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function isEnemy(plr)
	if not Settings.TeamCheck then return true end
	if LocalPlayer.Team and plr.Team then
		return LocalPlayer.Team ~= plr.Team
	end
	return true
end

local function getHeadPos(char)
	local head = char:FindFirstChild("Head")
	if head then
		return head.Position + Vector3.new(0, 0.2, 0)
	end
	local hitbox = char:FindFirstChild("Hitbox")
	if hitbox then
		return hitbox.Position + Vector3.new(0, hitbox.Size.Y * Settings.HeadOffset, 0)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position + Vector3.new(0, 2.5, 0)
	end
	return nil
end

local function getClosestInFOV()
	local closest = nil
	local closestAngle = math.rad(Settings.FOV / 2)
	local origin = Camera.CFrame.Position
	local look = Camera.CFrame.LookVector

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and isAlive(plr) and isEnemy(plr) then
			local char = plr.Character
			local headPos = getHeadPos(char)
			if headPos then
				local dist = (headPos - origin).Magnitude
				if dist < Settings.MaxDistance and dist > 1 then
					local dir = (headPos - origin).Unit
					local angle = math.acos(math.clamp(look:Dot(dir), -1, 1))
					if angle < closestAngle then
						closestAngle = angle
						closest = {player = plr, char = char, pos = headPos}
					end
				end
			end
		end
	end
	return closest
end

-- ==================== SILENT AIM - METODO 1 (GeneralFunctions) ====================
local hookedGameMethod = false
local OriginalCast = nil
local GeneralFunctions = nil
local TeamCheckModule = nil
local State = nil
local Bridge = nil
local General = nil

local function tryHookGameMethod()
	local success = pcall(function()
		GeneralFunctions = require(ReplicatedStorage:WaitForChild("Modules", 3):WaitForChild("GeneralFunctions", 3))
		TeamCheckModule = require(ReplicatedStorage.Modules.TeamCheck)
		State = require(ReplicatedFirst.Client.Utility.State)
		Bridge = require(ReplicatedFirst.Client.Utility.Bridge)
		General = require(ReplicatedFirst.Client.Utility.General)

		OriginalCast = GeneralFunctions.cast

		GeneralFunctions.cast = newcclosure(function(ray, hitList)
			if Settings.SilentAim then
				local target = getClosestInFOV()
				if target then
					local hitbox = target.char:FindFirstChild("Hitbox") or target.char:FindFirstChild("Head")
					if hitbox then
						return hitbox, target.pos, Vector3.new(0, 1, 0), hitbox.Material
					end
				end
			end
			return OriginalCast(ray, hitList)
		end)

		hookedGameMethod = true
		print("[ARGZx] Silent Aim: Metodo de juego (GeneralFunctions) ACTIVADO")
	end)

	if not success then
		print("[ARGZx] Metodo de juego no disponible, usando metodo alternativo...")
	end
	return success
end

-- ==================== SILENT AIM - METODO 2 (hookmetamethod backup) ====================
local function tryHookMetaMethod()
	local success = pcall(function()
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			local args = {...}

			if Settings.SilentAim and not checkcaller() then
				if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast" then
					local target = getClosestInFOV()
					if target then
						local origin = Camera.CFrame.Position
						if typeof(args[1]) == "Ray" then
							origin = args[1].Origin
						elseif typeof(args[1]) == "Vector3" then
							origin = args[1]
						end
						local dir = (target.pos - origin).Unit * 2000

						if method == "Raycast" then
							if typeof(args[1]) == "Vector3" then
								return old(self, origin, dir, args[3])
							end
						else
							args[1] = Ray.new(origin, dir)
							return old(self, unpack(args))
						end
					end
				end
			end
			return old(self, ...)
		end))
		print("[ARGZx] Silent Aim: Metodo alternativo (hookmetamethod) ACTIVADO")
	end)
	return success
end

-- Intentar ambos metodos
if not tryHookGameMethod() then
	tryHookMetaMethod()
end

-- ==================== INFINITE AMMO ====================
local function maintainAmmo()
	if not Settings.InfiniteAmmo then return end
	if not State or not Bridge or not General then return end

	pcall(function()
		local gun = State.gun
		if not gun then return end
		local capacity = math.min(General.getammo(gun), 999)

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

-- ==================== ESP (Highlight + Billboard - mas compatible) ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ARGZxESP"
pcall(function()
	ESPFolder.Parent = CoreGui
end)

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
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = ESPFolder
	highlights[plr] = hl

	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 200, 0, 50)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Parent = ESPFolder

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 14
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.Parent = bb

	local infoLbl = Instance.new("TextLabel")
	infoLbl.Name = "Info"
	infoLbl.BackgroundTransparency = 1
	infoLbl.Position = UDim2.new(0, 0, 0.5, 0)
	infoLbl.Size = UDim2.new(1, 0, 0.45, 0)
	infoLbl.Font = Enum.Font.Gotham
	infoLbl.TextSize = 12
	infoLbl.TextStrokeTransparency = 0.3
	infoLbl.Parent = bb

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
		local root = char and char:FindFirstChild("HumanoidRootPart")

		if Settings.ESP and isAlive(plr) and head and root then
			local dist = (Camera.CFrame.Position - root.Position).Magnitude
			if dist > 1200 then
				if hl then hl.Enabled = false end
				if bb then bb.Enabled = false end
				continue
			end

			local color = isEnemy(plr) and Settings.EnemyColor or Settings.AllyColor

			if hl then
				hl.Adornee = char
				hl.FillColor = color
				hl.OutlineColor = color
				hl.Enabled = true
			end

			if bb then
				bb.Adornee = head
				bb.Enabled = true
				local n = bb:FindFirstChild("Name")
				local i = bb:FindFirstChild("Info")
				if n then
					n.Text = plr.DisplayName or plr.Name
					n.TextColor3 = color
				end
				if i then
					i.Text = math.floor(dist) .. "m | " .. math.floor(hum.Health) .. " HP"
					i.TextColor3 = Color3.fromRGB(240, 240, 240)
				end
			end
		else
			if hl then hl.Enabled = false end
			if bb then bb.Enabled = false end
		end
	end
end

for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(createESP, plr)
end

Players.PlayerAdded:Connect(function(plr)
	task.wait(1)
	createESP(plr)
end)

Players.PlayerRemoving:Connect(clearESP)

print("[ARGZx] ESP creado")

-- ==================== LOOP ====================
local connection = RunService.RenderStepped:Connect(function()
	-- FOV
	if FOVCircle and hasDrawing then
		FOVCircle.Position = UserInputService:GetMouseLocation()
		FOVCircle.Radius = Settings.FOV
		FOVCircle.Visible = Settings.ShowFOV and Settings.SilentAim
	end

	maintainAmmo()
	updateESP()
end)

-- ==================== CLEANUP ====================
getgenv().ARGZxArsenal = {
	Settings = Settings,
	Cleanup = function()
		Settings.SilentAim = false
		Settings.ESP = false
		if connection then connection:Disconnect() end
		if FOVCircle then pcall(function() FOVCircle:Remove() end) end
		if OriginalCast and GeneralFunctions then
			pcall(function() GeneralFunctions.cast = OriginalCast end)
		end
		for plr in pairs(highlights) do clearESP(plr) end
		pcall(function() ESPFolder:Destroy() end)
		getgenv().ARGZxArsenal = nil
	end
}

print("===========================================")
print("[ARGZx] SCRIPT CARGADO")
print("Silent Aim : " .. (Settings.SilentAim and "ON" or "OFF"))
print("ESP        : " .. (Settings.ESP and "ON" or "OFF"))
print("FOV        : " .. tostring(Settings.FOV))
print("===========================================")
print("Si no ves el ESP, asegurate de estar DENTRO de una partida.")
