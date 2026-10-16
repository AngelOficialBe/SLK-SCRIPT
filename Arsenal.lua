-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Variables / Toggles
local Settings = {
    SilentAim = true,
    FOV = 150,
    InfiniteAmmo = true
}

-- Silent Aim (Hooks / Visual Target Matching)
local function GetClosestPlayer()
    local Closest = nil
    local MaxDistance = Settings.FOV

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") and v.Character:FindFirstChild("Humanoid") then
            if v.Character.Humanoid.Health > 0 then
                local ScreenPos, OnScreen = Camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
                if OnScreen then
                    local MousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local TargetPos = Vector2.new(ScreenPos.X, ScreenPos.Y)
                    local Distance = (MousePos - TargetPos).Magnitude

                    if Distance < MaxDistance then
                        MaxDistance = Distance
                        Closest = v
                    end
                end
            end
        end
    end
    return Closest
end

-- Hooking Namecall (Metatable Hook)
local gmt = getrawmetatable(game)
local oldNamecall = gmt.__namecall
setreadonly(gmt, false)

gmt.__namecall = newcclosure(function(self, ...)
    local Args = {...}
    local Method = getnamecallmethod()

    -- Interceptación para Silent Aim (Raycast / FireServer)
    if Settings.SilentAim and tostring(Method) == "FindPartOnWithIgnoreList" or tostring(Method) == "Raycast" then
        local Target = GetClosestPlayer()
        if Target and Target.Character and Target.Character:FindFirstChild("Head") then
            -- Modifica la dirección o el origen hacia la cabeza del objetivo
            Args[2] = Ray.new(Camera.CFrame.Position, (Target.Character.Head.Position - Camera.CFrame.Position).Unit * 1000)
            return oldNamecall(self, unpack(Args))
        end
    end

    return oldNamecall(self, ...)
end)

setreadonly(gmt, true)

-- Infinite Ammo / Modificación de atributos locales del arma
task.spawn(function()
    while task.wait(0.5) do
        if Settings.InfiniteAmmo then
            pcall(function()
                -- En la mayoría de frameworks de armas, la munición está guardada en la tabla del módulo o un IntValue
                local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if Tool then
                    if Tool:FindFirstChild("Ammo") then
                        Tool.Ammo.Value = 999
                    end
                    if Tool:FindFirstChild("StoredAmmo") then
                        Tool.StoredAmmo.Value = 999
                    end
                end
            end)
        end
    end
end)
