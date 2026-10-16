-- ==================== ARGZx Silent Aim + ESP - Arsenal (Xeno) ====================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== CONFIGURACIÓN ====================
getgenv().ARGZxSettings = {
    -- Silent Aim
    SilentAim = true,
    TeamCheck = true,
    FOV = 220,
    HitPart = "Head",
    
    -- ESP
    ESP = true,
    BoxESP = true,
    NameESP = true,
    DistanceESP = true,
    HealthESP = true,
    TracerESP = false,
    
    -- Colores
    EnemyColor = Color3.fromRGB(255, 50, 50),
    TeamColor = Color3.fromRGB(50, 255, 100),
    
    -- Keybinds
    ToggleSilent = Enum.KeyCode.V,
    ToggleESP = Enum.KeyCode.B
}

local Settings = getgenv().ARGZxSettings
local ESPObjects = {}

-- ==================== FUNCIONES ÚTILES ====================
local function IsAlive(player)
    local char = player.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    return humanoid and humanoid.Health > 0 and head
end

local function IsEnemy(player)
    if not Settings.TeamCheck then return true end
    if LocalPlayer.Team and player.Team then
        return LocalPlayer.Team ~= player.Team
    end
    return true
end

local function GetClosestPlayer()
    local closest, shortest = nil, Settings.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) and IsEnemy(player) then
            local head = player.Character:FindFirstChild(Settings.HitPart)
            if head then
                local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

-- ==================== SILENT AIM ====================
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if Settings.SilentAim and tostring(method) == "FindPartOnRayWithIgnoreList" and not checkcaller() then
        local target = GetClosestPlayer()
        if target and target.Character and target.Character:FindFirstChild(Settings.HitPart) then
            local origin = args[1].Origin
            local direction = (target.Character[Settings.HitPart].Position - origin).Unit * 1000
            args[1] = Ray.new(origin, direction)
            return oldNamecall(self, unpack(args))
        end
    end
    return oldNamecall(self, ...)
end)

setreadonly(mt, true)

-- ==================== ESP ====================
local function CreateESP(player)
    if ESPObjects[player] then return end

    local drawings = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        HealthBar = Drawing.new("Square"),
        HealthBarBG = Drawing.new("Square"),
        Tracer = Drawing.new("Line")
    }

    -- Box
    drawings.Box.Thickness = 1
    drawings.Box.Filled = false
    drawings.Box.Visible = false

    -- Name
    drawings.Name.Size = 14
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Visible = false

    -- Distance
    drawings.Distance.Size = 12
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.Visible = false

    -- Health Bar
    drawings.HealthBarBG.Filled = true
    drawings.HealthBarBG.Thickness = 0
    drawings.HealthBarBG.Visible = false
    drawings.HealthBar.Filled = true
    drawings.HealthBar.Thickness = 0
    drawings.HealthBar.Visible = false

    -- Tracer
    drawings.Tracer.Thickness = 1
    drawings.Tracer.Visible = false

    ESPObjects[player] = drawings
end

local function RemoveESP(player)
    if ESPObjects[player] then
        for _, v in pairs(ESPObjects[player]) do
            pcall(function() v:Remove() end)
        end
        ESPObjects[player] = nil
    end
end

local function UpdateESP()
    for player, drawings in pairs(ESPObjects) do
        if not player or not player.Parent then
            RemoveESP(player)
            continue
        end

        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if Settings.ESP and IsAlive(player) and head and root then
            local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
            local color = IsEnemy(player) and Settings.EnemyColor or Settings.TeamColor

            if onScreen then
                local size = char:GetExtentsSize()
                local scale = (Camera.CFrame.Position - root.Position).Magnitude
                local w = math.clamp(2000 / scale, 8, 40)
                local h = math.clamp(3000 / scale, 16, 70)

                -- Box
                if Settings.BoxESP then
                    drawings.Box.Size = Vector2.new(w, h)
                    drawings.Box.Position = Vector2.new(pos.X - w/2, pos.Y - h/2)
                    drawings.Box.Color = color
                    drawings.Box.Visible = true
                else
                    drawings.Box.Visible = false
                end

                -- Name
                if Settings.NameESP then
                    drawings.Name.Text = player.Name
                    drawings.Name.Position = Vector2.new(pos.X, pos.Y - h/2 - 16)
                    drawings.Name.Color = color
                    drawings.Name.Visible = true
                else
                    drawings.Name.Visible = false
                end

                -- Distance
                if Settings.DistanceESP then
                    local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                    drawings.Distance.Text = dist .. "m"
                    drawings.Distance.Position = Vector2.new(pos.X, pos.Y + h/2 + 2)
                    drawings.Distance.Color = Color3.fromRGB(200, 200, 200)
                    drawings.Distance.Visible = true
                else
                    drawings.Distance.Visible = false
                end

                -- Health Bar
                if Settings.HealthESP and humanoid then
                    local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                    local barH = h * healthPercent
                    drawings.HealthBarBG.Size = Vector2.new(3, h)
                    drawings.HealthBarBG.Position = Vector2.new(pos.X - w/2 - 6, pos.Y - h/2)
                    drawings.HealthBarBG.Color = Color3.fromRGB(30, 30, 30)
                    drawings.HealthBarBG.Visible = true

                    drawings.HealthBar.Size = Vector2.new(3, barH)
                    drawings.HealthBar.Position = Vector2.new(pos.X - w/2 - 6, pos.Y - h/2 + (h - barH))
                    drawings.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                    drawings.HealthBar.Visible = true
                else
                    drawings.HealthBar.Visible = false
                    drawings.HealthBarBG.Visible = false
                end

                -- Tracer
                if Settings.TracerESP then
                    drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(pos.X, pos.Y)
                    drawings.Tracer.Color = color
                    drawings.Tracer.Visible = true
                else
                    drawings.Tracer.Visible = false
                end
            else
                for _, v in pairs(drawings) do
                    v.Visible = false
                end
            end
        else
            for _, v in pairs(drawings) do
                v.Visible = false
            end
        end
    end
end

-- Crear ESP para jugadores existentes y nuevos
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end)

Players.PlayerRemoving:Connect(RemoveESP)

-- Actualizar ESP cada frame
RunService.RenderStepped:Connect(UpdateESP)

-- ==================== KEYBINDS ====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Settings.ToggleSilent then
        Settings.SilentAim = not Settings.SilentAim
        print("[ARGZx] Silent Aim:", Settings.SilentAim and "✅ ON" or "❌ OFF")
    end

    if input.KeyCode == Settings.ToggleESP then
        Settings.ESP = not Settings.ESP
        print("[ARGZx] ESP:", Settings.ESP and "✅ ON" or "❌ OFF")
    end
end)

print("========================================")
print("[ARGZx] Silent Aim + ESP Arsenal")
print("Compatible con: Xeno Executor")
print("Teclas:")
print("  V → Activar/Desactivar Silent Aim")
print("  B → Activar/Desactivar ESP")
print("========================================")
