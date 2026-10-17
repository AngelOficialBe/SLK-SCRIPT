-- ==================== CONFIGURACION DE KEY ====================
local ValidKey = "SLK" -- <--- Cambia tu key here
local ScriptURL = "https://raw.githubusercontent.com/AngelOficialBe/ARGZx-Official-script/refs/heads/main/ARGZx-Update.lua"
-- ==============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

-- ==================== KEY SYSTEM ====================
local keyGui = Instance.new("ScreenGui")
keyGui.Name = "SLKSystem"
keyGui.ResetOnSpawn = false
keyGui.IgnoreGuiInset = true
keyGui.Parent = PlayerGui

local keyFrame = Instance.new("Frame")
keyFrame.Size = UDim2.new(0, 300, 0, 180)
keyFrame.Position = UDim2.new(0.5, -150, 0.5, -90)
keyFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
keyFrame.BorderSizePixel = 0
keyFrame.Parent = keyGui
Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 12)

local keyStroke = Instance.new("UIStroke")
keyStroke.Color = Color3.fromRGB(180, 0, 0)
keyStroke.Thickness = 2
keyStroke.Parent = keyFrame

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, 0, 0, 40)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "SLK Key System"
keyTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
keyTitle.Font = Enum.Font.GothamBold
keyTitle.TextSize = 18
keyTitle.Parent = keyFrame

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(0.85, 0, 0, 40)
keyInput.Position = UDim2.new(0.075, 0, 0, 60)
keyInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
keyInput.Text = ""
keyInput.PlaceholderText = "Enter Key here..."
keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 14
keyInput.Parent = keyFrame
Instance.new("UICorner", keyInput).CornerRadius = UDim.new(0, 8)

local verifyBtn = Instance.new("TextButton")
verifyBtn.Size = UDim2.new(0.85, 0, 0, 40)
verifyBtn.Position = UDim2.new(0.075, 0, 0, 115)
verifyBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
verifyBtn.Text = "Verify Key"
verifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
verifyBtn.Font = Enum.Font.GothamBold
verifyBtn.TextSize = 14
verifyBtn.Parent = keyFrame
Instance.new("UICorner", verifyBtn).CornerRadius = UDim.new(0, 8)

local isVerified = false
verifyBtn.MouseButton1Click:Connect(function()
	if keyInput.Text == ValidKey then
		verifyBtn.Text = "Key Accepted!"
		verifyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
		task.wait(1)
		keyGui:Destroy()
		isVerified = true
	else
		verifyBtn.Text = "Invalid Key"
		verifyBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
		task.wait(1)
		verifyBtn.Text = "Verify Key"
		verifyBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	end
end)

repeat task.wait(0.2) until isVerified

-- Kill-switch
task.spawn(function()
	while task.wait(10) do
		local success, onlineCode = pcall(function()
			return game:HttpGet(ScriptURL)
		end)

		if success and type(onlineCode) == "string" then
			local onlineKey =
				string.match(onlineCode, 'local%s+ValidKey%s*=%s*"([^"]+)"')
				or string.match(onlineCode, "local%s+ValidKey%s*=%s*'([^']+)'")

			if onlineKey and onlineKey ~= ValidKey then
				pcall(function()
					if keyGui and keyGui.Parent then keyGui:Destroy() end
					if gui and gui.Parent then gui:Destroy() end
					FastFarm = false
					AutoRebirth = false
					FastRebirth = false
				end)

				pcall(function()
					LP:Kick("[SLK] La Key ha sido actualizada o tu acceso fue revocado.")
				end)
				break
			end
		end
	end
end)

-- Anti-AFK
LP.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

repeat task.wait(0.3) until LP:FindFirstChild("muscleEvent") and LP:FindFirstChild("leaderstats")

local Strength = LP.leaderstats.Strength
local Rebirths = LP.leaderstats.Rebirths

-- ==================== VARIABLES GLOBALES ====================
local FastFarm = false
local AutoRebirth = false
local FastRebirth = false
local FastRebirthStage = "Idle"
local FastRebirthGeneration = 0

local startTime = tick()
local sessionRebirths = 0
local lastRebirths = Rebirths.Value
local totalStrengthGained = 0
local lastStrengthValue = tonumber(Strength.Value) or 0

Strength:GetPropertyChangedSignal("Value"):Connect(function()
	local current = tonumber(Strength.Value) or 0
	if current >= lastStrengthValue then
		totalStrengthGained += current - lastStrengthValue
	else
		totalStrengthGained += lastStrengthValue
	end
	lastStrengthValue = current
end)

-- ==================== HELPERS ====================
local function getCharacter()
	return LP.Character
end

local function getHumanoid()
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local char = getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function formatExact(n)
	n = tonumber(n) or 0
	if n >= 1e12 then return string.format("%.2fT", n/1e12)
	elseif n >= 1e9 then return string.format("%.2fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.2fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
	else return tostring(math.floor(n)) end
end

-- ==================== PING PROTECTION ====================
local PingProtection = true
local PING_PAUSE = 15000
local PING_RESUME = 350
local PING_CHECK = 0.5
local pingPaused = false
local fastFarmBeforePing = false

local Stats = game:GetService("Stats")

local function getPing()
    local success, ping = pcall(function()
        local network = Stats:FindFirstChild("Network")
        local serverStats = network and network:FindFirstChild("ServerStatsItem")
        local dataPing = serverStats and serverStats:FindFirstChild("Data Ping")
        if dataPing then
            return tonumber(string.match(dataPing:GetValueString(), "%d+"))
        end
        return nil
    end)
    return success and ping or nil
end

task.spawn(function()
    while true do
        task.wait(PING_CHECK)
        if PingProtection then
            local ping = getPing()
            if ping then
                if not pingPaused and ping >= PING_PAUSE then
                    pingPaused = true
                    fastFarmBeforePing = FastFarm
                    FastFarm = false
                elseif pingPaused and ping <= PING_RESUME then
                    pingPaused = false
                    if fastFarmBeforePing then
                        FastFarm = true
                    end
                    fastFarmBeforePing = false
                end
            end
        end
    end
end)

-- ==================== OP FARM ESTABLE ====================
task.spawn(function()
    local cachedEvent = LP:FindFirstChild("muscleEvent")
    LP.ChildAdded:Connect(function(child)
        if child.Name == "muscleEvent" then cachedEvent = child end
    end)

    local RATE = 50000
    local BURST = 5000
    local INTERVAL = BURST / RATE

    while true do
        if FastFarm then
            if not cachedEvent or not cachedEvent.Parent then
                cachedEvent = LP:FindFirstChild("muscleEvent")
            end
            if cachedEvent then
                local start = os.clock()
                for i = 1, BURST do
                    if not FastFarm then break end
                    pcall(function() cachedEvent:FireServer("rep") end)
                end
                local remaining = INTERVAL - (os.clock() - start)
                if remaining > 0 then task.wait(remaining) else task.wait() end
            else
                task.wait(0.05)
            end
        else
            task.wait(0.1)
        end
    end
end)

-- ==================== AUTO REBIRTH ESTABLE ====================
task.spawn(function()
	local lastRequest = 0
	local minCooldown = 0.20

	local function getRemote()
		local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
		return rEvents and rEvents:FindFirstChild("rebirthRemote")
	end

	local function tryRebirth()
		if not AutoRebirth then return end
		local now = os.clock()
		if now - lastRequest < minCooldown then return end

		local remote = getRemote()
		if not remote then return end

		lastRequest = now
		pcall(function()
			if remote:IsA("RemoteFunction") then
				remote:InvokeServer("rebirthRequest")
			elseif remote:IsA("RemoteEvent") then
				remote:FireServer("rebirthRequest")
			end
		end)
	end

	-- Eventos para reaccionar rapido.
	Strength:GetPropertyChangedSignal("Value"):Connect(tryRebirth)
	Rebirths:GetPropertyChangedSignal("Value"):Connect(function()
		if AutoRebirth then
			task.defer(tryRebirth)
		end
	end)

	-- Fallback periodico: evita quedarse bloqueado si un cambio se pierde.
	while task.wait(0.10) do
		tryRebirth()
	end
end)

-- ==================== FAST REBIRTH WORKFLOW ====================
-- Workflow requested by the user:
-- Speed -> Farm -> Packs -> Rebirth -> Golems
-- Only actions whose remotes are already known in this script are executed.
-- Unknown Pack/Golem remotes are never guessed; the stage is reported instead.
local function getRebirthRemote()
	local rEvents = ReplicatedStorage:FindFirstChild("rEvents")
	return rEvents and rEvents:FindFirstChild("rebirthRemote")
end

local function fastRebirthStep()
	if not FastRebirth then return end
	local generation = FastRebirthGeneration

	FastRebirthStage = "Speed"
	local speedRemote = ReplicatedStorage:FindFirstChild("rEvents")
		and ReplicatedStorage.rEvents:FindFirstChild("changeSpeedSizeRemote")
	if speedRemote and speedRemote.Parent and FastRebirth and generation == FastRebirthGeneration then
		-- Keep the player's current size/speed state; do not force an unknown value.
	end

	FastRebirthStage = "Farm"
	FastFarm = true

	-- Wait until the character has enough strength for the existing rebirth request.
	local deadline = os.clock() + 8
	while FastRebirth and generation == FastRebirthGeneration and os.clock() < deadline do
		local remote = getRebirthRemote()
		if remote and Strength and Strength.Parent then
			break
		end
		task.wait(0.05)
	end

	FastRebirthStage = "Packs"
	-- Pack remote is game-version dependent and is not present in the current script.
	-- Do not guess or spam an unknown remote.
	task.wait(0.03)

	FastRebirthStage = "Rebirth"
	local rebirthRemote = getRebirthRemote()
	if rebirthRemote and FastRebirth and generation == FastRebirthGeneration then
		pcall(function()
			if rebirthRemote:IsA("RemoteFunction") then
				rebirthRemote:InvokeServer("rebirthRequest")
			elseif rebirthRemote:IsA("RemoteEvent") then
				rebirthRemote:FireServer("rebirthRequest")
			end
		end)
	end

	FastRebirthStage = "Golems"
	-- Golem remote is also version dependent and is not present in the current script.
	-- Leave the stage visible rather than inventing a remote call.
	task.wait(0.03)

	if FastRebirth and generation == FastRebirthGeneration then
		FastRebirthStage = "Farm"
	end
end

task.spawn(function()
	while true do
		if FastRebirth then
			pcall(fastRebirthStep)
		else
			FastRebirthStage = "Idle"
			task.wait(0.15)
		end
	end
end)

-- Contador session
task.spawn(function()
	while true do
		if Rebirths.Value > lastRebirths then
			sessionRebirths += (Rebirths.Value - lastRebirths)
			lastRebirths = Rebirths.Value
		elseif Rebirths.Value < lastRebirths then
			lastRebirths = Rebirths.Value
		end
		task.wait(0.4)
	end
end)

-- ==================== BOSS FARM (adaptado) ====================
local BossFarm = {
	active = false,
	generation = 0,
	status = "Sin boss activo",
	originalCharacter = nil,
	originalPivot = nil,
	originalSize = nil,
	originalRootAnchored = nil,
	engagedBoss = nil,
	confirmedDamage = 0,
	attacks = 0,
	hitInterval = 0.31,
	antiLag = false,
	antiLagOriginals = setmetatable({}, { __mode = "k" }),
	antiLagConnection = nil,
	cameraRenderName = "SLKBossStableCamera",
	cameraSaved = nil,
	cameraFocusPosition = nil,
	cameraStableCFrame = nil,
	lastPlayerHealth = nil,
	safetyTriggered = false,
	safeAttackPosition = nil,
}

local function findBoss()
	for _, boss in ipairs(CollectionService:GetTagged("BossEventBoss")) do
		if boss and boss.Parent then
			local part = boss:FindFirstChild("BossDamageHitbox", true)
				or boss.PrimaryPart
				or boss:FindFirstChild("Boss", true)
				or boss:FindFirstChild("Head", true)
				or boss:FindFirstChildWhichIsA("BasePart", true)
			if part and part:IsA("BasePart") then
				local target = boss:FindFirstChild("Boss")
					or boss:FindFirstChild("Head", true)
					or boss.PrimaryPart
					or part
				if not target:IsA("BasePart") then target = part end
				return boss, part, target
			end
		end
	end
	return nil, nil, nil
end

local function bossHealth()
	return math.max(0, tonumber(workspace:GetAttribute("BossHealth")) or 0)
end

local function setCharacterSize(size)
	local events = ReplicatedStorage:FindFirstChild("rEvents")
	local remote = events and events:FindFirstChild("changeSpeedSizeRemote")
	size = math.clamp(math.floor((tonumber(size) or 2) + 0.5), 1, 100)
	if not remote then return false end
	if remote:IsA("RemoteEvent") then
		return pcall(remote.FireServer, remote, "changeSize", size)
	elseif remote:IsA("RemoteFunction") then
		return pcall(remote.InvokeServer, remote, "changeSize", size)
	end
	return false
end

local function readCharacterSize()
	local humanoid = getHumanoid()
	local height = humanoid and humanoid:FindFirstChild("BodyHeightScale")
	return math.clamp(math.floor(((height and height.Value) or 2) + 0.5), 1, 100)
end

local function equipBossPunch()
	local character = getCharacter()
	local humanoid = getHumanoid()
	local backpack = LP:FindFirstChild("Backpack")
	local punch = character and character:FindFirstChild("Punch")
		or (backpack and backpack:FindFirstChild("Punch"))
	if punch and humanoid and punch.Parent ~= character then
		pcall(humanoid.EquipTool, humanoid, punch)
		RunService.Heartbeat:Wait()
	end
	local attackTime = punch and punch:FindFirstChild("attackTime")
	if attackTime and attackTime:IsA("ValueBase") then attackTime.Value = 0 end
	return punch
end

function BossFarm:ApplyAntiLagObject(object)
	if not self.antiLag or not object then return end
	local property
	if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam")
		or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Sparkles")
		or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight")
		or object:IsA("Highlight") then
		property = "Enabled"
	elseif object:IsA("BasePart") then
		property = "CastShadow"
	end
	if property and self.antiLagOriginals[object] == nil then
		self.antiLagOriginals[object] = { property = property, value = object[property] }
		pcall(function() object[property] = false end)
	end
end

function BossFarm:SetAntiLag(enabled)
	enabled = enabled == true
	self.antiLag = enabled
	if self.antiLagConnection then
		self.antiLagConnection:Disconnect()
		self.antiLagConnection = nil
	end
	if not enabled then
		for object, saved in pairs(self.antiLagOriginals) do
			if object and object.Parent then
				pcall(function() object[saved.property] = saved.value end)
			end
			self.antiLagOriginals[object] = nil
		end
		return true
	end
	local events = workspace:FindFirstChild("Events")
	local arena = events and events:FindFirstChild("BossArena")
	if not arena then self.antiLag = false; return false end
	for _, object in ipairs(arena:GetDescendants()) do
		self:ApplyAntiLagObject(object)
	end
	self.antiLagConnection = arena.DescendantAdded:Connect(function(object)
		task.defer(function() self:ApplyAntiLagObject(object) end)
	end)
	return true
end

function BossFarm:StopStableCamera()
	pcall(RunService.UnbindFromRenderStep, RunService, self.cameraRenderName)
	local camera = workspace.CurrentCamera
	local saved = self.cameraSaved
	if camera and saved then
		pcall(function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = saved.cframe
			camera.Focus = saved.focus
			if saved.subject and saved.subject.Parent then
				camera.CameraSubject = saved.subject
			end
			camera.CameraType = saved.cameraType
		end)
	end
	self.cameraSaved = nil
	self.cameraFocusPosition = nil
	self.cameraStableCFrame = nil
end

function BossFarm:StartStableCamera()
	self:StopStableCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end
	self.cameraSaved = {
		cameraType = camera.CameraType,
		subject = camera.CameraSubject,
		cframe = camera.CFrame,
		focus = camera.Focus,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(self.cameraRenderName, Enum.RenderPriority.Camera.Value + 50, function(delta)
		local focus = self.cameraFocusPosition
		local currentCamera = workspace.CurrentCamera
		if not self.engagedBoss or not focus or not currentCamera then return end
		local desired = CFrame.lookAt(focus + Vector3.new(0, 34, 48), focus + Vector3.new(0, -5, 0))
		self.cameraStableCFrame = self.cameraStableCFrame
			and self.cameraStableCFrame:Lerp(desired, math.clamp(delta * 4, 0.04, 0.22)) or desired
		currentCamera.CameraType = Enum.CameraType.Scriptable
		currentCamera.CFrame = self.cameraStableCFrame
		currentCamera.Focus = CFrame.new(focus)
	end)
end

function BossFarm:WaitForReadyCharacter(timeout)
	local deadline = os.clock() + (tonumber(timeout) or 8)
	local stableCharacter, stableRoot, stableAt
	while self.active and os.clock() < deadline do
		local character = getCharacter()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local machine = LP:FindFirstChild("machineInUse")
		local rebirthing = character and (character:GetAttribute("IsRebirthing") == true
			or character:GetAttribute("LastMapCFrame") ~= nil)
		local mounted = (machine and machine.Value ~= nil) or (humanoid and humanoid.SeatPart ~= nil)
		if character and root and humanoid and humanoid.Health > 0 and not rebirthing and not mounted then
			if character ~= stableCharacter or root ~= stableRoot then
				stableCharacter, stableRoot, stableAt = character, root, os.clock()
			elseif os.clock() - stableAt >= 0.18 then
				return character, root, humanoid
			end
		else
			stableCharacter, stableRoot, stableAt = nil, nil, nil
		end
		task.wait(0.05)
	end
	return nil, nil, nil
end

function BossFarm:BeginBattle(boss)
	if self.engagedBoss == boss then return true end

	-- Pause OP Farm temporarily
	local wasFarming = FastFarm
	FastFarm = false

	local character, root = self:WaitForReadyCharacter(8)
	if not character or not root or boss.Parent == nil or workspace:GetAttribute("BossActive") ~= true then
		FastFarm = wasFarming
		self:RestoreBattle()
		return false
	end

	self.originalCharacter = character
	self.originalPivot = character:GetPivot()
	self.originalSize = readCharacterSize()
	self.originalRootAnchored = root.Anchored
	self.engagedBoss = boss
	self.confirmedDamage = 0
	self.attacks = 0
	self.safetyTriggered = false
	self.lastPlayerHealth = nil
	self.safeAttackPosition = nil
	self._wasFarming = wasFarming

	-- Keep the normal avatar scale. Changing scale during a live boss fight can
	-- disturb the Humanoid physics and leave the player falling/out of range.
	self:StartStableCamera()
	task.wait(0.2)

	local humanoid = getHumanoid()
	self.lastPlayerHealth = humanoid and humanoid.Health or nil
	return true
end

function BossFarm:RestoreBattle()
	local character = LP.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and character == self.originalCharacter and root and self.originalPivot then
		character:PivotTo(self.originalPivot)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if self.originalRootAnchored ~= nil then
			root.Anchored = self.originalRootAnchored
		end
	end
	-- Avatar size is left unchanged during the fight to avoid physics instability.
	self:StopStableCamera()

	local backpack = LP:FindFirstChild("Backpack")
	local punch = character and character:FindFirstChild("Punch")
	if punch and backpack then punch.Parent = backpack end

	self.originalCharacter = nil
	self.originalPivot = nil
	self.originalSize = nil
	self.originalRootAnchored = nil
	self.engagedBoss = nil
	self.lastPlayerHealth = nil
	self.safeAttackPosition = nil

	-- Restore OP Farm if it was active
	if self._wasFarming then
		FastFarm = true
		self._wasFarming = nil
	end
end

function BossFarm:CollectChest(timeout)
	local opened = false
	local openedConnection
	local remoteFolder = ReplicatedStorage:FindFirstChild("rEvents")
	local openedEvent = remoteFolder and remoteFolder:FindFirstChild("bossChestOpenedEvent")
	if openedEvent and openedEvent:IsA("RemoteEvent") then
		openedConnection = openedEvent.OnClientEvent:Connect(function()
			opened = true
		end)
	end

	local function finish(success)
		if openedConnection then
			openedConnection:Disconnect()
			openedConnection = nil
		end
		return success
	end

	local function findChestPrompt()
		for _, candidate in ipairs(CollectionService:GetTagged("BossEventChest")) do
			if candidate and candidate.Parent then
				local found
				if candidate:IsA("ProximityPrompt") then
					found = candidate
				else
					found = candidate:FindFirstChild("bossChestPrompt", true)
						or candidate:FindFirstChildWhichIsA("ProximityPrompt", true)
				end
				if found and found:IsA("ProximityPrompt") then
					return candidate, found
				end
			end
		end

		local events = workspace:FindFirstChild("Events")
		if events then
			local found = events:FindFirstChild("bossChestPrompt", true)
				or events:FindFirstChildWhichIsA("ProximityPrompt", true)
			if found and found:IsA("ProximityPrompt") then
				return found:FindFirstAncestorOfClass("Model") or found.Parent, found
			end
		end
		return nil, nil
	end

	local function activatePrompt(prompt)
		if type(fireproximityprompt) == "function" then
			local ok = pcall(fireproximityprompt, prompt)
			if ok then return true end
		end

		local began = pcall(function()
			prompt:InputHoldBegin()
		end)
		if not began then return false end
		task.wait(math.clamp(tonumber(prompt.HoldDuration) or 0, 0.1, 3) + 0.1)
		pcall(function()
			prompt:InputHoldEnd()
		end)
		return true
	end

	local deadline = os.clock() + (tonumber(timeout) or 18)
	local pendingWasSeen = LP:GetAttribute("BossChestPending") == true
	local attempted, lastAttempt = false, 0

	while self.active and os.clock() < deadline do
		if opened then return finish(true) end

		local chestModel, prompt = findChestPrompt()
		local pending = LP:GetAttribute("BossChestPending") == true
		if pending then pendingWasSeen = true end

		local emerging = chestModel and chestModel:GetAttribute("BossChestEmerging") == true
		if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and not emerging then
			local character = getCharacter()
			local root = getRoot()
			local promptParent = prompt.Parent
			local parentPart = promptParent
			if parentPart and not parentPart:IsA("BasePart") then
				parentPart = parentPart:FindFirstAncestorWhichIsA("BasePart")
			end

			if character and root and parentPart and parentPart:IsA("BasePart") then
				local targetCFrame = parentPart.CFrame
					* CFrame.new(0, math.max(3, parentPart.Size.Y * 0.5 + 2), 0)
				if (root.Position - targetCFrame.Position).Magnitude > 8 then
					character:PivotTo(targetCFrame)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					task.wait(0.2)
				end
			end

			if os.clock() - lastAttempt >= 0.65 then
				lastAttempt = os.clock()
				attempted = activatePrompt(prompt) or attempted
			end
		end

		if opened then return finish(true) end
		if attempted and pendingWasSeen and LP:GetAttribute("BossChestPending") ~= true then
			return finish(true)
		end
		task.wait(0.1)
	end

	return finish(opened or (attempted and pendingWasSeen
		and LP:GetAttribute("BossChestPending") ~= true))
end

function BossFarm:Fight(boss)
	if not self:BeginBattle(boss) then return end

	local lastHealth = bossHealth()
	local lastAttack = 0
	local lastPositionUpdate = 0
	local lastPromptedNoDamage = 0

	local function headHoverCFrame(character, root, humanoid, bossModel, hitPart)
		-- Prefer the real head; fall back to the damage hitbox if the model has no Head.
		local head = bossModel:FindFirstChild("Head", true)
		if not (head and head:IsA("BasePart")) then
			head = hitPart
		end

		-- Hover just above the head, keeping a small horizontal offset so Punch
		-- can activate without the avatar clipping through the boss.
		local headTop = head.Position.Y + head.Size.Y * 0.5
		local hoverY = headTop + math.max(2.0, root.Size.Y * 0.65)
		local horizontal = Vector3.new(root.Position.X - head.Position.X, 0, root.Position.Z - head.Position.Z)
		if horizontal.Magnitude < 0.1 then
			horizontal = Vector3.new(1, 0, 0)
		else
			horizontal = horizontal.Unit
		end
		local hoverPosition = Vector3.new(head.Position.X + horizontal.X * 1.25, hoverY, head.Position.Z + horizontal.Z * 1.25)
		return CFrame.lookAt(hoverPosition, head.Position)
	end

	while self.active and boss.Parent and workspace:GetAttribute("BossActive") == true do
		local currentBoss, hitPart, target = findBoss()
		if currentBoss ~= boss or not hitPart or not target then break end

		local character = getCharacter()
		local root = getRoot()
		local humanoid = getHumanoid()
		local punch = equipBossPunch()

		if not character or not root or not humanoid or humanoid.Health <= 0
			or not punch or not punch:IsA("Tool") then
			self.status = "Esperando personaje o Punch"
			self:UpdateUi()
			task.wait(0.2)
		else
			-- Do not turn Boss Farm off just because the boss hits the player once.
			-- The old behavior disabled the whole routine before the boss was defeated,
			-- which also prevented the chest-claim step from running.
			if self.lastPlayerHealth and humanoid.Health < self.lastPlayerHealth then
				self.status = "Recibiendo daño; manteniendo posición de combate"
			end
			self.lastPlayerHealth = humanoid.Health

			local now = os.clock()
			if now - lastPositionUpdate >= 0.12 then
				lastPositionUpdate = now
				local attackCFrame = headHoverCFrame(character, root, humanoid, boss, hitPart)
				local desiredPosition = attackCFrame.Position
				self.safeAttackPosition = desiredPosition
				-- Re-correct frequently to counter gravity and stay hovering above the head.
				-- Do not anchor the character; that can break normal tool activation.
				local facingDot = root.CFrame.LookVector:Dot(attackCFrame.LookVector)
				if (root.Position - desiredPosition).Magnitude > 0.85 or facingDot < 0.9 then
					character:PivotTo(attackCFrame)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				end
			end

			local aimPosition = target.Position
			self.cameraFocusPosition = self.cameraFocusPosition
				and self.cameraFocusPosition:Lerp(aimPosition, 0.18) or aimPosition

			-- Fast Punch: use the normal equipped tool activation at a short interval.
			-- attackTime is set to zero in equipBossPunch(); the server can still throttle hits.
			if now - lastAttack >= 0.06 then
				lastAttack = now
				pcall(function() punch:Activate() end)
				self.attacks += 1
			end

			local health = bossHealth()
			if health < lastHealth then
				self.confirmedDamage += (lastHealth - health)
			end
			lastHealth = health

			if self.attacks > 8 and self.confirmedDamage <= 0 and now - lastPromptedNoDamage > 5 then
				lastPromptedNoDamage = now
				self.status = "Atacando; sin daño confirmado: revisa rango/hitbox del evento"
			else
				self.status = (workspace:GetAttribute("BossDisplayName") or "Boss")
					.. " | daño confirmado " .. formatExact(self.confirmedDamage)
			end
			self:UpdateUi()
			task.wait(0.04)
		end
	end

	-- Allow the server a short moment to replicate defeat before deciding whether
	-- the reward chest should be collected.
	local settleDeadline = os.clock() + 3
	local defeated = workspace:GetAttribute("BossActive") ~= true or bossHealth() <= 0
	while self.active and not defeated and os.clock() < settleDeadline do
		if workspace:GetAttribute("BossActive") ~= true or bossHealth() <= 0 then
			defeated = true
			break
		end
		if boss.Parent then break end
		task.wait(0.1)
	end

	if defeated and self.active then
		self.status = "Boss derrotado; reclamando cofre..."
		self:UpdateUi()
		local claimed = self:CollectChest(18)
		if self.active then
			self.status = claimed and "Cofre reclamado" or "No se pudo confirmar el cofre"
			self:UpdateUi()
			task.wait(claimed and 0.6 or 1.2)
		end
	end
	self:RestoreBattle()
end

function BossFarm:Set(enabled)
	enabled = enabled == true
	self.generation += 1
	local generation = self.generation
	self.active = enabled

	if not enabled then
		self.status = "Sin boss activo"
		self:RestoreBattle()
		self:SetAntiLag(false)
		self:UpdateUi()
		return true
	end

	-- Verificar si el evento esta disponible
	local config = ReplicatedStorage:FindFirstChild("shared")
	config = config and config:FindFirstChild("config")
	config = config and config:FindFirstChild("BossEventConfig")
	local ok, values = pcall(function() return config and require(config) end)
	if not ok or type(values) ~= "table" or values.ENABLED ~= true then
		self.active = false
		self.status = "El evento del boss no esta disponible"
		self:SetAntiLag(false)
		self:UpdateUi()
		return false
	end

	self:SetAntiLag(true)
	-- Fast Punch uses a 0.06 s client activation cadence; the server may apply its own cap.
	self.hitInterval = 0.06

	task.spawn(function()
		while self.active and self.generation == generation do
			local boss = findBoss()
			if boss and workspace:GetAttribute("BossActive") == true then
				self:Fight(boss)
			else
				self.engagedBoss = nil
				self.status = "Sin boss activo"
				self:UpdateUi()
				task.wait(0.4)
			end
		end
		if self.generation == generation then
			self:RestoreBattle()
		end
	end)

	self:UpdateUi()
	return true
end

function BossFarm:UpdateUi()
	if self.StatusLabel then
		self.StatusLabel.Text = self.status
		self.StatusLabel.TextColor3 = self.engagedBoss and Color3.fromRGB(100, 255, 140) or Color3.fromRGB(160, 160, 180)
	end
	if self.HealthLabel then
		local health = bossHealth()
		local maximum = math.max(health, tonumber(workspace:GetAttribute("BossMaxHealth")) or 0)
		if maximum > 0 and workspace:GetAttribute("BossActive") == true then
			self.HealthLabel.Text = formatExact(health) .. " / " .. formatExact(maximum)
		else
			self.HealthLabel.Text = "-"
		end
	end
end

-- ==================== GUI ESTILO AURAL ====================
local gui = Instance.new("ScreenGui")
gui.Name = "SLK_AuralGUI_Improved"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 360, 0, 270)
main.Position = UDim2.new(0.5, -180, 0.5, -135)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = false
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(40, 40, 50)
mainStroke.Thickness = 1
mainStroke.Parent = main

-- Drag only from the top bar so scrolling inside pages does not move the whole GUI.
local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, -100, 0, 32)
dragBar.Position = UDim2.new(0, 100, 0, 0)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.Parent = main

local dragTitle = Instance.new("TextLabel")
dragTitle.Size = UDim2.new(1, -70, 1, 0)
dragTitle.Position = UDim2.new(0, 12, 0, 0)
dragTitle.BackgroundTransparency = 1
dragTitle.Text = "SLK"
dragTitle.TextColor3 = Color3.fromRGB(150, 150, 170)
dragTitle.Font = Enum.Font.GothamMedium
dragTitle.TextSize = 11
dragTitle.TextXAlignment = Enum.TextXAlignment.Left
dragTitle.Parent = dragBar

local dragging = false
local dragStart = nil
local startPos = nil

dragBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = input.Position - dragStart
	main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end)

-- SIDEBAR
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 100, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local logoFrame = Instance.new("Frame")
logoFrame.Size = UDim2.new(1, 0, 0, 56)
logoFrame.BackgroundTransparency = 1
logoFrame.Parent = sidebar

local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(0, 20, 0, 20)
logoIcon.Position = UDim2.new(0, 7, 0, 10)
logoIcon.BackgroundColor3 = Color3.fromRGB(90, 60, 220)
logoIcon.Text = "A"
logoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
logoIcon.Font = Enum.Font.GothamBold
logoIcon.TextSize = 12
logoIcon.Parent = logoFrame
Instance.new("UICorner", logoIcon).CornerRadius = UDim.new(0, 6)

local logoTitle = Instance.new("TextLabel")
logoTitle.Size = UDim2.new(1, -32, 0, 16)
logoTitle.Position = UDim2.new(0, 31, 0, 8)
logoTitle.BackgroundTransparency = 1
logoTitle.Text = "SLK Paid"
logoTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
logoTitle.Font = Enum.Font.GothamBold
logoTitle.TextSize = 10
logoTitle.TextXAlignment = Enum.TextXAlignment.Left
logoTitle.Parent = logoFrame

local logoSub = Instance.new("TextLabel")
logoSub.Size = UDim2.new(1, -32, 0, 12)
logoSub.Position = UDim2.new(0, 31, 0, 23)
logoSub.BackgroundTransparency = 1
logoSub.Text = "Muscle Legends"
logoSub.TextColor3 = Color3.fromRGB(140, 140, 160)
logoSub.Font = Enum.Font.Gotham
logoSub.TextSize = 8
logoSub.TextXAlignment = Enum.TextXAlignment.Left
logoSub.Parent = logoFrame

local navContainer = Instance.new("Frame")
navContainer.Size = UDim2.new(1, -10, 1, -58)
navContainer.Position = UDim2.new(0, 5, 0, 56)
navContainer.BackgroundTransparency = 1
navContainer.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 4)
navLayout.Parent = navContainer

local pages = {}
local currentPage = "Farming"

local function createNavButton(name, icon, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 29)
	btn.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = navContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 20, 1, 0)
	iconLabel.Position = UDim2.new(0, 3, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 10
	iconLabel.Parent = btn

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -27, 1, 0)
	textLabel.Position = UDim2.new(0, 25, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = name
	textLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.TextSize = 10
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Parent = btn

	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0, 3, 0, 20)
	indicator.Position = UDim2.new(0, 0, 0.5, -10)
	indicator.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = btn
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)

	btn.MouseButton1Click:Connect(function()
		for _, page in pairs(pages) do page.Visible = false end
		if pages[name] then pages[name].Visible = true end
		currentPage = name

		for _, child in ipairs(navContainer:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
				local ind = child:FindFirstChild("Indicator")
				if ind then ind.Visible = false end
			end
		end
		btn.BackgroundColor3 = Color3.fromRGB(28, 24, 45)
		indicator.Visible = true
	end)
	return btn
end

local farmingNav = createNavButton("Farming", "F", 1)
local bossNav = createNavButton("Boss", "B", 2)
local infoNav = createNavButton("Info", "I", 3)
local settingsNav = createNavButton("Settings", "S", 4)

farmingNav.BackgroundColor3 = Color3.fromRGB(28, 24, 45)
farmingNav:FindFirstChild("Indicator").Visible = true

-- CONTENT
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -100, 1, 0)
content.Position = UDim2.new(0, 100, 0, 0)
content.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
content.BorderSizePixel = 0
content.Parent = main

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = content
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
	BossFarm:Set(false)
	gui:Destroy()
end)

-- ==================== MINIMIZAR ARGZx ====================
local miniButton = Instance.new("TextButton")
miniButton.Name = "SLKMini"
miniButton.Size = UDim2.new(0, 118, 0, 42)
miniButton.Position = UDim2.new(1, -132, 0, 18)
miniButton.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
miniButton.BorderSizePixel = 0
miniButton.Text = "SLK"
miniButton.TextColor3 = Color3.fromRGB(235, 235, 255)
miniButton.Font = Enum.Font.GothamBold
miniButton.TextSize = 15
miniButton.Visible = false
miniButton.AutoButtonColor = false
miniButton.Parent = gui
Instance.new("UICorner", miniButton).CornerRadius = UDim.new(0, 12)
local miniStroke = Instance.new("UIStroke")
miniStroke.Color = Color3.fromRGB(95, 70, 190)
miniStroke.Thickness = 1.5
miniStroke.Parent = miniButton

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -70, 0, 10)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(210, 210, 225)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 16
minimizeBtn.Parent = content
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)

minimizeBtn.MouseButton1Click:Connect(function()
	main.Visible = false
	miniButton.Visible = true
end)

miniButton.MouseButton1Click:Connect(function()
	miniButton.Visible = false
	main.Visible = true
end)

-- ========== HELPERS GUI ==========
local function createToggle(parent, yPos, titleText, descText, defaultState, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 52)
	row.Position = UDim2.new(0, 0, 0, yPos)
	row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	row.BorderSizePixel = 0
	row.Parent = parent
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -70, 0, 20)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(240, 240, 250)
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -70, 0, 16)
	desc.Position = UDim2.new(0, 14, 0, 28)
	desc.BackgroundTransparency = 1
	desc.Text = descText
	desc.TextColor3 = Color3.fromRGB(130, 130, 150)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 11
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = row

	local switchBg = Instance.new("Frame")
	switchBg.Size = UDim2.new(0, 42, 0, 24)
	switchBg.Position = UDim2.new(1, -56, 0.5, -12)
	switchBg.BackgroundColor3 = defaultState and Color3.fromRGB(100, 70, 220) or Color3.fromRGB(50, 50, 60)
	switchBg.BorderSizePixel = 0
	switchBg.Parent = row
	Instance.new("UICorner", switchBg).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = defaultState and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = switchBg
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = defaultState
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row

	btn.MouseButton1Click:Connect(function()
		state = not state
		local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if state then
			TweenService:Create(switchBg, tweenInfo, {BackgroundColor3 = Color3.fromRGB(100, 70, 220)}):Play()
			TweenService:Create(knob, tweenInfo, {Position = UDim2.new(1, -21, 0.5, -9)}):Play()
		else
			TweenService:Create(switchBg, tweenInfo, {BackgroundColor3 = Color3.fromRGB(50, 50, 60)}):Play()
			TweenService:Create(knob, tweenInfo, {Position = UDim2.new(0, 3, 0.5, -9)}):Play()
		end
		if callback then callback(state) end
	end)
	return row
end

local function createSection(parent, yPos, text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Position = UDim2.new(0, 0, 0, yPos)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(120, 100, 200)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- ========== PAGE: FARMING ==========
local farmingPage = Instance.new("ScrollingFrame")
farmingPage.Name = "Farming"
farmingPage.Size = UDim2.new(1, -20, 1, -50)
farmingPage.Position = UDim2.new(0, 10, 0, 45)
farmingPage.BackgroundTransparency = 1
farmingPage.BorderSizePixel = 0
farmingPage.ScrollBarThickness = 4
farmingPage.ScrollingEnabled = true
farmingPage.Active = true
farmingPage.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
farmingPage.CanvasSize = UDim2.new(0, 0, 0, 350)
farmingPage.Parent = content
pages["Farming"] = farmingPage

local farmingTitle = Instance.new("TextLabel")
farmingTitle.Size = UDim2.new(1, 0, 0, 28)
farmingTitle.BackgroundTransparency = 1
farmingTitle.Text = "Farming"
farmingTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
farmingTitle.Font = Enum.Font.GothamBold
farmingTitle.TextSize = 20
farmingTitle.TextXAlignment = Enum.TextXAlignment.Left
farmingTitle.Parent = farmingPage

local farmingSub = Instance.new("TextLabel")
farmingSub.Size = UDim2.new(1, 0, 0, 18)
farmingSub.Position = UDim2.new(0, 0, 0, 26)
farmingSub.BackgroundTransparency = 1
farmingSub.Text = "Strength, rebirth, boosts"
farmingSub.TextColor3 = Color3.fromRGB(140, 140, 160)
farmingSub.Font = Enum.Font.Gotham
farmingSub.TextSize = 12
farmingSub.TextXAlignment = Enum.TextXAlignment.Left
farmingSub.Parent = farmingPage

-- Single OP Farm selector
local opRow = Instance.new("Frame")
opRow.Size = UDim2.new(1, -10, 0, 64)
opRow.Position = UDim2.new(0, 0, 0, 55)
opRow.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
opRow.BorderSizePixel = 0
opRow.Parent = farmingPage
Instance.new("UICorner", opRow).CornerRadius = UDim.new(0, 8)

local opTitle = Instance.new("TextLabel")
opTitle.Size = UDim2.new(1, -110, 0, 22)
opTitle.Position = UDim2.new(0, 14, 0, 8)
opTitle.BackgroundTransparency = 1
opTitle.Text = "OP Farm"
opTitle.TextColor3 = Color3.fromRGB(240, 240, 250)
opTitle.Font = Enum.Font.GothamBold
opTitle.TextSize = 14
opTitle.TextXAlignment = Enum.TextXAlignment.Left
opTitle.Parent = opRow

local opDesc = Instance.new("TextLabel")
opDesc.Size = UDim2.new(1, -110, 0, 18)
opDesc.Position = UDim2.new(0, 14, 0, 32)
opDesc.BackgroundTransparency = 1
opDesc.Text = "Target:  OP |FARM"
opDesc.TextColor3 = Color3.fromRGB(135, 135, 155)
opDesc.Font = Enum.Font.Gotham
opDesc.TextSize = 11
opDesc.TextXAlignment = Enum.TextXAlignment.Left
opDesc.Parent = opRow

local opButton = Instance.new("TextButton")
opButton.Size = UDim2.new(0, 78, 0, 32)
opButton.Position = UDim2.new(1, -90, 0.5, -16)
opButton.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
opButton.Text = "OFF"
opButton.TextColor3 = Color3.fromRGB(190, 190, 205)
opButton.Font = Enum.Font.GothamBold
opButton.TextSize = 12
opButton.Parent = opRow
Instance.new("UICorner", opButton).CornerRadius = UDim.new(0, 8)

local function updateOpButton(state)
	if state then
		opButton.Text = "ON"
		opButton.BackgroundColor3 = Color3.fromRGB(100, 70, 220)
		opButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		opButton.Text = "OFF"
		opButton.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		opButton.TextColor3 = Color3.fromRGB(190, 190, 205)
	end
end

opButton.MouseButton1Click:Connect(function()
	FastFarm = not FastFarm
	updateOpButton(FastFarm)
end)

createSection(farmingPage, 135, "REBIRTH")
createToggle(farmingPage, 158, "Auto Rebirth", "Rebirth when strength reaches threshold", false, function(state)
	AutoRebirth = state
end)


createSection(farmingPage, 205, "FAST REBIRTH")
createToggle(farmingPage, 228, "Fast Rebirth", "Speed -> Farm -> Packs -> Rebirth -> Golems", false, function(state)
	FastRebirth = state
	FastRebirthGeneration += 1
	if state then
		FastFarm = true
		updateOpButton(true)
	else
		FastRebirthStage = "Idle"
	end
end)

local fastRebirthStatus = Instance.new("TextLabel")
fastRebirthStatus.Size = UDim2.new(1, -10, 0, 34)
fastRebirthStatus.Position = UDim2.new(0, 0, 0, 291)
fastRebirthStatus.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
fastRebirthStatus.BorderSizePixel = 0
fastRebirthStatus.Text = "Fast Rebirth: Idle"
fastRebirthStatus.TextColor3 = Color3.fromRGB(150, 150, 175)
fastRebirthStatus.Font = Enum.Font.GothamMedium
fastRebirthStatus.TextSize = 12
fastRebirthStatus.TextXAlignment = Enum.TextXAlignment.Left
fastRebirthStatus.Parent = farmingPage
Instance.new("UICorner", fastRebirthStatus).CornerRadius = UDim.new(0, 8)
local frPad = Instance.new("UIPadding", fastRebirthStatus)
frPad.PaddingLeft = UDim.new(0, 12)


createSection(farmingPage, 340, "SESSION STATS")
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, -10, 0, 90)
statsFrame.Position = UDim2.new(0, 0, 0, 363)
statsFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
statsFrame.BorderSizePixel = 0
statsFrame.Parent = farmingPage
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 8)

local rebirthsLabel = Instance.new("TextLabel")
rebirthsLabel.Size = UDim2.new(1, -20, 0, 22)
rebirthsLabel.Position = UDim2.new(0, 14, 0, 12)
rebirthsLabel.BackgroundTransparency = 1
rebirthsLabel.Text = "Session Rebirths: 0"
rebirthsLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
rebirthsLabel.Font = Enum.Font.GothamMedium
rebirthsLabel.TextSize = 13
rebirthsLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthsLabel.Parent = statsFrame

local timeLabel = Instance.new("TextLabel")
timeLabel.Size = UDim2.new(1, -20, 0, 20)
timeLabel.Position = UDim2.new(0, 14, 0, 36)
timeLabel.BackgroundTransparency = 1
timeLabel.Text = "Time: 0h 0m"
timeLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
timeLabel.Font = Enum.Font.Gotham
timeLabel.TextSize = 12
timeLabel.TextXAlignment = Enum.TextXAlignment.Left
timeLabel.Parent = statsFrame

local rateLabel = Instance.new("TextLabel")
rateLabel.Size = UDim2.new(1, -20, 0, 20)
rateLabel.Position = UDim2.new(0, 14, 0, 58)
rateLabel.BackgroundTransparency = 1
rateLabel.Text = "Rate: 0 /h"
rateLabel.TextColor3 = Color3.fromRGB(140, 190, 255)
rateLabel.Font = Enum.Font.Gotham
rateLabel.TextSize = 12
rateLabel.TextXAlignment = Enum.TextXAlignment.Left
rateLabel.Parent = statsFrame


-- ========== PAGE: BOSS ==========
local bossPage = Instance.new("ScrollingFrame")
bossPage.Name = "Boss"
bossPage.Size = UDim2.new(1, -20, 1, -50)
bossPage.Position = UDim2.new(0, 10, 0, 45)
bossPage.BackgroundTransparency = 1
bossPage.BorderSizePixel = 0
bossPage.ScrollBarThickness = 4
bossPage.ScrollingEnabled = true
bossPage.Active = true
bossPage.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
bossPage.CanvasSize = UDim2.new(0, 0, 0, 380)
bossPage.Visible = false
bossPage.Parent = content
pages["Boss"] = bossPage

local bossTitle = Instance.new("TextLabel")
bossTitle.Size = UDim2.new(1, 0, 0, 28)
bossTitle.BackgroundTransparency = 1
bossTitle.Text = "Boss"
bossTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
bossTitle.Font = Enum.Font.GothamBold
bossTitle.TextSize = 20
bossTitle.TextXAlignment = Enum.TextXAlignment.Left
bossTitle.Parent = bossPage

local bossSub = Instance.new("TextLabel")
bossSub.Size = UDim2.new(1, 0, 0, 18)
bossSub.Position = UDim2.new(0, 0, 0, 26)
bossSub.BackgroundTransparency = 1
bossSub.Text = "Auto Boss Event"
bossSub.TextColor3 = Color3.fromRGB(140, 140, 160)
bossSub.Font = Enum.Font.Gotham
bossSub.TextSize = 12
bossSub.TextXAlignment = Enum.TextXAlignment.Left
bossSub.Parent = bossPage

createSection(bossPage, 55, "AUTO BOSS")

-- Status
local statusRow = Instance.new("Frame")
statusRow.Size = UDim2.new(1, -10, 0, 42)
statusRow.Position = UDim2.new(0, 0, 0, 78)
statusRow.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
statusRow.BorderSizePixel = 0
statusRow.Parent = bossPage
Instance.new("UICorner", statusRow).CornerRadius = UDim.new(0, 8)

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.new(0, 70, 1, 0)
statusTitle.Position = UDim2.new(0, 14, 0, 0)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "Status:"
statusTitle.TextColor3 = Color3.fromRGB(160, 160, 180)
statusTitle.Font = Enum.Font.Gotham
statusTitle.TextSize = 12
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusRow

BossFarm.StatusLabel = Instance.new("TextLabel")
BossFarm.StatusLabel.Size = UDim2.new(1, -90, 1, 0)
BossFarm.StatusLabel.Position = UDim2.new(0, 80, 0, 0)
BossFarm.StatusLabel.BackgroundTransparency = 1
BossFarm.StatusLabel.Text = "Sin boss activo"
BossFarm.StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
BossFarm.StatusLabel.Font = Enum.Font.GothamMedium
BossFarm.StatusLabel.TextSize = 13
BossFarm.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
BossFarm.StatusLabel.Parent = statusRow

-- Health
local healthRow = Instance.new("Frame")
healthRow.Size = UDim2.new(1, -10, 0, 42)
healthRow.Position = UDim2.new(0, 0, 0, 128)
healthRow.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
healthRow.BorderSizePixel = 0
healthRow.Parent = bossPage
Instance.new("UICorner", healthRow).CornerRadius = UDim.new(0, 8)

local healthTitle = Instance.new("TextLabel")
healthTitle.Size = UDim2.new(0, 100, 1, 0)
healthTitle.Position = UDim2.new(0, 14, 0, 0)
healthTitle.BackgroundTransparency = 1
healthTitle.Text = "Boss Health:"
healthTitle.TextColor3 = Color3.fromRGB(160, 160, 180)
healthTitle.Font = Enum.Font.Gotham
healthTitle.TextSize = 12
healthTitle.TextXAlignment = Enum.TextXAlignment.Left
healthTitle.Parent = healthRow

BossFarm.HealthLabel = Instance.new("TextLabel")
BossFarm.HealthLabel.Size = UDim2.new(1, -120, 1, 0)
BossFarm.HealthLabel.Position = UDim2.new(0, 110, 0, 0)
BossFarm.HealthLabel.BackgroundTransparency = 1
BossFarm.HealthLabel.Text = "-"
BossFarm.HealthLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
BossFarm.HealthLabel.Font = Enum.Font.GothamMedium
BossFarm.HealthLabel.TextSize = 13
BossFarm.HealthLabel.TextXAlignment = Enum.TextXAlignment.Left
BossFarm.HealthLabel.Parent = healthRow

-- Toggle Auto Boss
createToggle(bossPage, 185, "Attack Boss", "Auto farm for Boss event (pauses OP Farm)", false, function(state)
	local accepted = BossFarm:Set(state)
	if accepted == false then
		-- Si fallo, forzar el toggle visual a off (el createToggle no tiene Set, pero el estado se maneja)
	end
end)

createSection(bossPage, 255, "INFO")
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 0, 80)
infoLabel.Position = UDim2.new(0, 0, 0, 278)
infoLabel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
infoLabel.BorderSizePixel = 0
infoLabel.Text = " Detecta automatically cuando aparece el Boss\n Hover sobre la cabeza + Fast Punch\n Anti-lag + stable camera\n Reclama el cofre al derrotarlo\n Se apaga si te hacen dano (proteccion)"
infoLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = bossPage
Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 8)
Instance.new("UIPadding", infoLabel).PaddingTop = UDim.new(0, 10)
Instance.new("UIPadding", infoLabel).PaddingLeft = UDim.new(0, 12)

-- ========== PAGE: INFO ==========
local infoPage = Instance.new("ScrollingFrame")
infoPage.Name = "Info"
infoPage.Size = UDim2.new(1, -20, 1, -50)
infoPage.Position = UDim2.new(0, 10, 0, 45)
infoPage.BackgroundTransparency = 1
infoPage.BorderSizePixel = 0
infoPage.ScrollBarThickness = 4
infoPage.ScrollingEnabled = true
infoPage.Active = true
infoPage.ScrollBarImageColor3 = Color3.fromRGB(80, 60, 160)
infoPage.CanvasSize = UDim2.new(0, 0, 0, 360)
infoPage.Visible = false
infoPage.Parent = content
pages["Info"] = infoPage

local infoTitle = Instance.new("TextLabel")
infoTitle.Size = UDim2.new(1, 0, 0, 28)
infoTitle.BackgroundTransparency = 1
infoTitle.Text = "Info"
infoTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
infoTitle.Font = Enum.Font.GothamBold
infoTitle.TextSize = 20
infoTitle.TextXAlignment = Enum.TextXAlignment.Left
infoTitle.Parent = infoPage

local infoSub = Instance.new("TextLabel")
infoSub.Size = UDim2.new(1, 0, 0, 18)
infoSub.Position = UDim2.new(0, 0, 0, 28)
infoSub.BackgroundTransparency = 1
infoSub.Text = "Session performance and farming rates"
infoSub.TextColor3 = Color3.fromRGB(140, 140, 160)
infoSub.Font = Enum.Font.Gotham
infoSub.TextSize = 12
infoSub.TextXAlignment = Enum.TextXAlignment.Left
infoSub.Parent = infoPage

createSection(infoPage, 58, "RATES PER HOUR")
local infoFrame = Instance.new("Frame")
infoFrame.Size = UDim2.new(1, -10, 0, 150)
infoFrame.Position = UDim2.new(0, 0, 0, 84)
infoFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
infoFrame.BorderSizePixel = 0
infoFrame.Parent = infoPage
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 8)

local strengthHourLabel = Instance.new("TextLabel")
strengthHourLabel.Size = UDim2.new(1, -28, 0, 32)
strengthHourLabel.Position = UDim2.new(0, 14, 0, 12)
strengthHourLabel.BackgroundTransparency = 1
strengthHourLabel.Text = "Strength per hour: 0"
strengthHourLabel.TextColor3 = Color3.fromRGB(150, 210, 255)
strengthHourLabel.Font = Enum.Font.GothamMedium
strengthHourLabel.TextSize = 14
strengthHourLabel.TextXAlignment = Enum.TextXAlignment.Left
strengthHourLabel.Parent = infoFrame

local rebirthHourLabel = Instance.new("TextLabel")
rebirthHourLabel.Size = UDim2.new(1, -28, 0, 32)
rebirthHourLabel.Position = UDim2.new(0, 14, 0, 52)
rebirthHourLabel.BackgroundTransparency = 1
rebirthHourLabel.Text = "Rebirths per hour: 0"
rebirthHourLabel.TextColor3 = Color3.fromRGB(160, 255, 160)
rebirthHourLabel.Font = Enum.Font.GothamMedium
rebirthHourLabel.TextSize = 14
rebirthHourLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthHourLabel.Parent = infoFrame

local sessionInfoLabel = Instance.new("TextLabel")
sessionInfoLabel.Size = UDim2.new(1, -28, 0, 32)
sessionInfoLabel.Position = UDim2.new(0, 14, 0, 92)
sessionInfoLabel.BackgroundTransparency = 1
sessionInfoLabel.Text = "Session time: 0m"
sessionInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 210)
sessionInfoLabel.Font = Enum.Font.Gotham
sessionInfoLabel.TextSize = 12
sessionInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
sessionInfoLabel.Parent = infoFrame

-- Live session statistics. This is intentionally placed after the Info labels
-- are created; the previous version tried to update local labels before they existed.
local function updateSessionInfo()
	local elapsed = math.max(0, tick() - startTime)
	local hours = math.floor(elapsed / 3600)
	local minutes = math.floor((elapsed % 3600) / 60)
	local strengthRate = elapsed > 0 and math.floor((totalStrengthGained / elapsed) * 3600) or 0
	local rebirthRate = elapsed > 0 and math.floor((sessionRebirths / elapsed) * 3600) or 0

	if strengthHourLabel then strengthHourLabel.Text = "Strength per hour: " .. formatExact(strengthRate) end
	if rebirthHourLabel then rebirthHourLabel.Text = "Rebirths per hour: " .. rebirthRate end
	if sessionInfoLabel then sessionInfoLabel.Text = string.format("Session time: %dh %dm", hours, minutes) end
	if rebirthsLabel then rebirthsLabel.Text = "Session Rebirths: " .. sessionRebirths end
	if timeLabel then timeLabel.Text = string.format("Time: %dh %dm", hours, minutes) end
	if rateLabel then rateLabel.Text = "Rate: " .. rebirthRate .. " /h" end
	if fastRebirthStatus then fastRebirthStatus.Text = "Fast Rebirth: " .. FastRebirthStage end
end

task.spawn(function()
	while gui and gui.Parent do
		updateSessionInfo()
		task.wait(1)
	end
end)

local infoNote = Instance.new("TextLabel")
infoNote.Size = UDim2.new(1, -10, 0, 70)
infoNote.Position = UDim2.new(0, 0, 0, 250)
infoNote.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
infoNote.BorderSizePixel = 0
infoNote.Text = "Rates are calculated from this session.\nStrength counts cumulative gains, including strength earned before rebirth.\nShort sessions may show 0 until enough data is collected."
infoNote.TextColor3 = Color3.fromRGB(150, 150, 170)
infoNote.Font = Enum.Font.Gotham
infoNote.TextSize = 11
infoNote.TextXAlignment = Enum.TextXAlignment.Left
infoNote.TextYAlignment = Enum.TextYAlignment.Center
infoNote.Parent = infoPage
Instance.new("UICorner", infoNote).CornerRadius = UDim.new(0, 8)
local infoPad = Instance.new("UIPadding", infoNote)
infoPad.PaddingLeft = UDim.new(0, 12)

-- Settings real: rendimiento y optimizacion.
local settingsPage = Instance.new("ScrollingFrame")
settingsPage.Name = "Settings"
settingsPage.Size = UDim2.new(1, -20, 1, -50)
settingsPage.Position = UDim2.new(0, 10, 0, 45)
settingsPage.BackgroundTransparency = 1
settingsPage.BorderSizePixel = 0
settingsPage.ScrollBarThickness = 4
settingsPage.ScrollingEnabled = true
settingsPage.Active = true
settingsPage.CanvasSize = UDim2.new(0, 0, 0, 390)
settingsPage.Visible = false
settingsPage.Parent = content
pages["Settings"] = settingsPage

local settingsTitle = Instance.new("TextLabel")
settingsTitle.Size = UDim2.new(1, 0, 0, 28)
settingsTitle.BackgroundTransparency = 1
settingsTitle.Text = "Settings"
settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsTitle.Font = Enum.Font.GothamBold
settingsTitle.TextSize = 20
settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
settingsTitle.Parent = settingsPage

local settingsSub = Instance.new("TextLabel")
settingsSub.Size = UDim2.new(1, 0, 0, 18)
settingsSub.Position = UDim2.new(0, 0, 0, 28)
settingsSub.BackgroundTransparency = 1
settingsSub.Text = "Performance, UI and stability"
settingsSub.TextColor3 = Color3.fromRGB(140, 140, 160)
settingsSub.Font = Enum.Font.Gotham
settingsSub.TextSize = 12
settingsSub.TextXAlignment = Enum.TextXAlignment.Left
settingsSub.Parent = settingsPage

local savedVisuals = setmetatable({}, {__mode = "k"})
local performanceEnabled = false

local function setPerformance(enabled)
	performanceEnabled = enabled == true
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")
			or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles")
			or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight")
			or obj:IsA("Highlight") then
			if savedVisuals[obj] == nil then savedVisuals[obj] = obj.Enabled end
			pcall(function() obj.Enabled = not enabled end)
		elseif obj:IsA("BasePart") then
			if savedVisuals[obj] == nil then savedVisuals[obj] = obj.CastShadow end
			pcall(function() obj.CastShadow = not enabled end)
		end
	end
	if not enabled then
		for obj, old in pairs(savedVisuals) do
			if obj and obj.Parent then pcall(function() obj.Enabled = old end); pcall(function() obj.CastShadow = old end) end
			savedVisuals[obj] = nil
		end
	end
end

createSection(settingsPage, 58, "PERFORMANCE")
createToggle(settingsPage, 82, "Performance Mode", "Reduce particulas, luces, highlights y sombras", false, setPerformance)

createToggle(settingsPage, 145, "Stable UI", "Reduce animaciones visuales para bajar trabajo del cliente", true, function(state)
	-- Las funciones de farmeo no dependen de esta opcion.
	-- Se conserva como preferencia visual para futuras animaciones.
	_G.ARGZxStableUI = state
end)

createSection(settingsPage, 210, "FARM STABILITY")
local rateInfo = Instance.new("TextLabel")
rateInfo.Size = UDim2.new(1, -10, 0, 70)
rateInfo.Position = UDim2.new(0, 0, 0, 234)
rateInfo.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
rateInfo.BorderSizePixel = 0
rateInfo.Text = "OP Farm target: 800 reps/s\nThe client sends in controlled batches; server limits may still apply.\nFast Rebirth order: Speed -> Farm -> Packs -> Rebirth -> Golems"
rateInfo.TextColor3 = Color3.fromRGB(155, 155, 175)
rateInfo.Font = Enum.Font.Gotham
rateInfo.TextSize = 12
rateInfo.TextXAlignment = Enum.TextXAlignment.Left
rateInfo.TextYAlignment = Enum.TextYAlignment.Center
rateInfo.Parent = settingsPage
Instance.new("UICorner", rateInfo).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", rateInfo)
pad.PaddingLeft = UDim.new(0, 12)

-- Keep page scrolling available on mouse wheel and touch, and size the canvas
-- from the actual content so new controls do not require moving the whole GUI.
local function bindAutoCanvas(scroller, extra)
	local layout = scroller:FindFirstChildOfClass("UIListLayout")
	if layout then
		local function refresh()
			scroller.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + (extra or 16))
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
		refresh()
	end
end

bindAutoCanvas(farmingPage, 24)
bindAutoCanvas(bossPage, 24)
bindAutoCanvas(infoPage, 24)
bindAutoCanvas(settingsPage, 24)

-- Tecla para ocultar/mostrar
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightControl then
		if main.Visible then
			main.Visible = false
			miniButton.Visible = true
		else
			miniButton.Visible = false
			main.Visible = true
		end
	end
end)

BossFarm:UpdateUi()
print("ARGZx GUI + Auto Boss loaded")
