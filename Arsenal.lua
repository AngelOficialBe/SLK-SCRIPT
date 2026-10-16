-- ==================== ARGZx Silent Aim + ESP - Arsenal ====================
-- Optimizado para Xeno Executor
-- Se activa TODO automaticamente al ejecutar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ==================== CONFIG ====================
local Config = {
    -- Silent Aim
    SilentAim = true,
    FOV = 300,                  -- FOV grande para que sea mas facil
    TeamCheck = true,
    HitPart = "Head",
    Prediction = 0.12,          -- Prediccion de movimiento

    -- ESP
    ESP = true,
    Box = true,
    Name = true,
    Distance = true,
    Health = true,
    Tracer = true,
    MaxDistance = 800,

    -- Colores
    EnemyColor = Color3.fromRGB(255, 40, 40),
    AllyColor = Color3.fromRGB(40, 255, 100),
    TracerColor = Color3.fromRGB(255, 80, 80),
}

print("[ARGZx] Cargando Silent Aim + ESP para Arsenal...")

-- ==================== UTILS ====================
local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")
    return hum and hum.Health > 0 and head ~= nil
end

local function isEnemy(plr)
    if not Config.TeamCheck then return true end
    if LocalPlayer.Team and plr.Team then
        return LocalPlayer.Team ~= plr.Team
    end
    return true
end

local function getClosest()
    local closest, shortest = nil, Config.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and isEnemy(plr) then
            local head = plr.Character:FindFirstChild(Config.HitPart) or plr.Character:FindFirstChild("Head")
            if head then
                local screen, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - mousePos).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function getPredictedPos(part, root)
    if not root then return part.Position end
    local velocity = root.AssemblyLinearVelocity or Vector3.zero
    return part.Position + (velocity * Config.Prediction)
end

-- ==================== SILENT AIM (metodo mas compatible) ====================
local function applySilentAim()
    -- Metodo 1: Hook namecall (mas comun)
    local success1 = pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local old = mt.__namecall

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if Config.SilentAim and not checkcaller() then
                if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast" then
                    local target = getClosest()
                    if target and target.Character then
                        local head = target.Character:FindFirstChild(Config.HitPart) or target.Character:FindFirstChild("Head")
                        local root = target.Character:FindFirstChild("HumanoidRootPart")
                        if head then
                            local origin
                            if typeof(args[1]) == "Ray" then
                                origin = args[1].Origin
                            elseif typeof(args[1]) == "Vector3" then
                                origin = args[1]
                            else
                                origin = Camera.CFrame.Position
                            end

                            local targetPos = getPredictedPos(head, root)
                            local direction = (targetPos - origin).Unit * 1500

                            if method == "Raycast" then
                                -- Para Raycast moderno
                                if typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                                    args[2] = direction
                                    return old(self, unpack(args))
                                end
                            else
                                args[1] = Ray.new(origin, direction)
                                return old(self, unpack(args))
                            end
                        end
                    end
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)

    -- Metodo 2: hookmetamethod (backup)
    if not success1 then
        pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if Config.SilentAim and not checkcaller() then
                    if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" then
                        local target = getClosest()
                        if target and target.Character then
                            local head = target.Character:FindFirstChild("Head")
                            local root = target.Character:FindFirstChild("HumanoidRootPart")
                            if head then
                                local origin = args[1].Origin
                                local targetPos = getPredictedPos(head, root)
                                args[1] = Ray.new(origin, (targetPos - origin).Unit * 1500)
                                return old(self, unpack(args))
                            end
                        end
                    end
                end
                return old(self, ...)
            end))
        end)
    end

    -- Metodo 3: Mouse.Hit spoof (ayuda extra en algunos casos)
    pcall(function()
        local mt = getrawmetatable(Mouse)
        setreadonly(mt, false)
        local oldIndex = mt.__index

        mt.__index = newcclosure(function(self, key)
            if Config.SilentAim and (key == "Hit" or key == "Target") then
                local target = getClosest()
                if target and target.Character and target.Character:FindFirstChild("Head") then
                    local head = target.Character.Head
                    if key == "Hit" then
                        return CFrame.new(head.Position)
                    elseif key == "Target" then
                        return head
                    end
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(mt, true)
    end)
end

applySilentAim()

-- ==================== ESP (Drawing + Highlight fallback) ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ARGZxESP"
ESPFolder.Parent = game:GetService("CoreGui")

local drawings = {} -- Drawing objects
local highlights = {} -- Highlight objects
local billboards = {} -- Name tags

local hasDrawing = pcall(function()
    local t = Drawing.new("Circle")
    t:Remove()
end)

local function clearPlayerESP(plr)
    if drawings[plr] then
        for _, obj in pairs(drawings[plr]) do
            pcall(function() obj:Remove() end)
        end
        drawings[plr] = nil
    end
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
    clearPlayerESP(plr)

    -- Highlight (siempre funciona)
    local hl = Instance.new("Highlight")
    hl.Name = "ARGZxHL"
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = ESPFolder
    highlights[plr] = hl

    -- BillboardGui para nombre + distancia + vida
    local bb = Instance.new("BillboardGui")
    bb.Name = "ARGZxBB"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.Parent = bb

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "Info"
    infoLabel.BackgroundTransparency = 1
    infoLabel.Position = UDim2.new(0, 0, 0.4, 0)
    infoLabel.Size = UDim2.new(1, 0, 0.35, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 11
    infoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    infoLabel.TextStrokeTransparency = 0.5
    infoLabel.Parent = bb

    billboards[plr] = bb

    -- Drawing objects (si el executor lo soporta)
    if hasDrawing then
        drawings[plr] = {
            box = Drawing.new("Square"),
            tracer = Drawing.new("Line"),
        }
        drawings[plr].box.Thickness = 1
        drawings[plr].box.Filled = false
        drawings[plr].box.Visible = false

        drawings[plr].tracer.Thickness = 1.2
        drawings[plr].tracer.Visible = false
    end
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

        if Config.ESP and isAlive(plr) and head and root then
            local dist = (Camera.CFrame.Position - root.Position).Magnitude
            if dist > Config.MaxDistance then
                if hl then hl.Enabled = false end
                if bb then bb.Enabled = false end
                if drawings[plr] then
                    drawings[plr].box.Visible = false
                    drawings[plr].tracer.Visible = false
                end
                continue
            end

            local enemy = isEnemy(plr)
            local color = enemy and Config.EnemyColor or Config.AllyColor

            -- Highlight
            if hl then
                hl.Adornee = char
                hl.FillColor = color
                hl.OutlineColor = color
                hl.Enabled = true
            end

            -- Billboard
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
                    local hp = hum and math.floor(hum.Health) or 0
                    local maxhp = hum and math.floor(hum.MaxHealth) or 100
                    infoL.Text = string.format("%dm | %d/%d HP", math.floor(dist), hp, maxhp)
                end
            end

            -- Drawing Box + Tracer
            if hasDrawing and drawings[plr] then
                local screen, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen and Config.Box then
                    local scale = math.clamp(2500 / dist, 6, 55)
                    local w, h = scale * 0.7, scale * 1.35
                    drawings[plr].box.Size = Vector2.new(w, h)
                    drawings[plr].box.Position = Vector2.new(screen.X - w/2, screen.Y - h/2)
                    drawings[plr].box.Color = color
                    drawings[plr].box.Visible = true
                else
                    drawings[plr].box.Visible = false
                end

                if onScreen and Config.Tracer then
                    drawings[plr].tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    drawings[plr].tracer.To = Vector2.new(screen.X, screen.Y)
                    drawings[plr].tracer.Color = Config.TracerColor
                    drawings[plr].tracer.Visible = true
                else
                    drawings[plr].tracer.Visible = false
                end
            end
        else
            if hl then hl.Enabled = false end
            if bb then bb.Enabled = false end
            if drawings[plr] then
                drawings[plr].box.Visible = false
                drawings[plr].tracer.Visible = false
            end
        end
    end
end

-- Crear ESP para todos
for _, plr in ipairs(Players:GetPlayers()) do
    createESP(plr)
end

Players.PlayerAdded:Connect(function(plr)
    task.wait(1)
    createESP(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
    clearPlayerESP(plr)
end)

RunService.RenderStepped:Connect(updateESP)

-- ==================== FIN ====================
print("==============================================")
print("[ARGZx] Silent Aim + ESP cargado correctamente")
print("Executor: Xeno")
print("Silent Aim: ACTIVADO (todos los tiros a la cabeza)")
print("ESP: ACTIVADO (Highlight + Nombre + Distancia + Vida)")
print("==============================================")
