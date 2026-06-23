-- Robust ESP – proven self-exclusion, all features v 1.0
-- Toggles: F4 = Master | F5 = Boxes | F6 = Pickups/Crates

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

if not Drawing then notify("Drawing missing", "Error", 3) return end

-- ======================
--  Keys
-- ======================
local KEY_MASTER = 115   -- F4
local KEY_BOXES  = 116   -- F5
local KEY_LOOT   = 117   -- F6

-- ======================
--  State
-- ======================
local masterESP = true
local boxesEnabled = true
local lootESP = true

-- Spawn marking
local spawnLocations = {}
local spawnMarkedPlayers = {}

-- Pickup / crate lists
local PICKUP_MODELS = { "PhonePickup", "MedkitPickup" }
local foundPickups = {}
local crateModels = {}

-- ======================
--  Helpers
-- ======================
local function getRootPos(player)
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    return root and root:IsA("BasePart") and root.Position or nil
end

local function getHeadPos(player)
    local char = player.Character
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    return head and head:IsA("BasePart") and head.Position or nil
end

local function getTeamColor(player)
    local team = player.Team
    local name = team and team.Name
    if name == "Villain" then return Color3.fromRGB(255, 80, 80)
    elseif name == "Survivor" then return Color3.fromRGB(80, 255, 80)
    elseif name == "Lobby" then return Color3.fromRGB(160, 160, 160)
    else return Color3.fromRGB(255, 255, 255)
    end
end

local function getTeamLabel(player)
    local team = player.Team
    local name = team and team.Name or "??"
    if name == "Villain" then return "VILLAIN"
    elseif name == "Survivor" then return "SURVIVOR"
    elseif name == "Lobby" then return "LOBBY"
    else return name
    end
end

local function checkSpawnMark(player)
    -- skip self
    if player == localPlayer then return end
    if spawnMarkedPlayers[player] ~= nil then return end
    if #spawnLocations == 0 then
        spawnMarkedPlayers[player] = false
        return
    end
    local ok, loc = pcall(function() return player.RespawnLocation end)
    if not ok then
        spawnMarkedPlayers[player] = false
        return
    end
    for _, spawn in ipairs(spawnLocations) do
        if loc == spawn then
            spawnMarkedPlayers[player] = true
            return
        end
    end
    spawnMarkedPlayers[player] = false
end

-- ======================
--  Folder search (background)
-- ======================
task.spawn(function()
    local map1 = nil
    for attempt = 1, 40 do
        map1 = workspace:FindFirstChild("Map1")
        if map1 then break end
        task.wait(0.5)
    end
    if map1 then
        local function collectSpawns(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("SpawnLocation") then
                    table.insert(spawnLocations, child)
                elseif child:IsA("Folder") or child:IsA("Model") then
                    collectSpawns(child)
                end
            end
        end
        for _, folderName in ipairs({"CrateSpawns", "TempVSpawns"}) do
            local folder = map1:FindFirstChild(folderName)
            if folder then collectSpawns(folder) end
        end
        if #spawnLocations > 0 then
            notify(#spawnLocations .. " spawn locations found", "ESP", 2)
        end

        local crateFolder = map1:FindFirstChild("CrateSpawns")
        if crateFolder then
            for _, child in ipairs(crateFolder:GetChildren()) do
                if child:IsA("Model") then table.insert(crateModels, child) end
            end
            if #crateModels > 0 then notify(#crateModels .. " crate(s) found", "ESP", 2) end
        end
    end

    local foldersToCheck = {
        workspace:FindFirstChild("CrateLoot"),
        workspace:FindFirstChild("TempVPickups")
    }
    for _, folder in ipairs(foldersToCheck) do
        if folder then
            for _, modelName in ipairs(PICKUP_MODELS) do
                local model = folder:FindFirstChild(modelName)
                if model and model:IsA("Model") then
                    local col = modelName == "PhonePickup" and Color3.fromRGB(100,200,255)
                        or modelName == "MedkitPickup" and Color3.fromRGB(255,100,100)
                        or Color3.fromRGB(0,255,255)
                    table.insert(foundPickups, { model = model, color = col })
                end
            end
        end
    end
    if #foundPickups > 0 then notify(#foundPickups .. " named pickup(s) found", "ESP", 2) end
end)

-- ======================
--  Drawing system
-- ======================
local espDrawings = {}
local function clearESP()
    for _, d in ipairs(espDrawings) do
        pcall(function() d:Remove() end)
    end
    espDrawings = {}
end

local function addDrawing(d) table.insert(espDrawings, d) end

local function drawBox(topLeft, size, color)
    if size.X <= 0 or size.Y <= 0 then return end
    local box = Drawing.new("Square")
    box.Position = topLeft
    box.Size = size
    box.Color = color
    box.Filled = false
    box.Transparency = 0.5
    box.Visible = true
    addDrawing(box)
end

local function drawTextESP(text, pos, color, size)
    local d = Drawing.new("Text")
    d.Text = text
    d.Position = pos
    d.Color = color
    d.Size = size or 14
    d.Font = Drawing.Fonts.UI
    d.Outline = true
    d.Center = true
    d.Visible = true
    addDrawing(d)
end

-- ======================
--  ESP Rendering
-- ======================
local function renderESP()
    clearESP()
    if not masterESP then return end

    local myPos = getRootPos(localPlayer) or Vector3.zero

    for _, player in ipairs(Players:GetPlayers()) do
        -- ONLY THIS LINE excludes yourself – proven to work
        if player == localPlayer then continue end

        if player.Team and player.Team.Name == "Lobby" then continue end

        local rootPos = getRootPos(player)
        if not rootPos then continue end

        checkSpawnMark(player)

        local headPos = getHeadPos(player) or (rootPos + Vector3.new(0, 2, 0))
        local footPos = rootPos - Vector3.new(0, 3, 0)

        local dist = (rootPos - myPos).Magnitude
        if dist < 0.01 then continue end

        local color = getTeamColor(player)
        local label = getTeamLabel(player)

        if spawnMarkedPlayers[player] then
            color = Color3.fromRGB(255, 180, 0)
            label = "SPAWN"
        end

        local headScreen, headOn = WorldToScreen(headPos)
        local footScreen, footOn = WorldToScreen(footPos)

        if boxesEnabled and headOn and footOn then
            local boxHeight = math.abs(footScreen.Y - headScreen.Y)
            local boxWidth = boxHeight * 0.5
            local centerX = (headScreen.X + footScreen.X) / 2
            local topLeft = Vector2.new(centerX - boxWidth/2, headScreen.Y)
            drawBox(topLeft, Vector2.new(boxWidth, boxHeight), color)
        end

        local nameText = string.format("[%s] %s [%.0f]", label, player.Name, dist)
        if headOn then
            drawTextESP(nameText, Vector2.new(headScreen.X, headScreen.Y - 10), color, 14)
        elseif footOn then
            drawTextESP(nameText, Vector2.new(footScreen.X, footScreen.Y - 10), color, 14)
        else
            local rootScreen, onScreen = WorldToScreen(rootPos)
            if onScreen then
                drawTextESP(nameText, rootScreen, color, 14)
            end
        end
    end

    if lootESP then
        for _, pickup in ipairs(foundPickups) do
            local model = pickup.model
            if model and model.PrimaryPart then
                local pos = model.PrimaryPart.Position
                local screenPos, onScreen = WorldToScreen(pos)
                if onScreen then
                    local dist = (pos - myPos).Magnitude
                    drawTextESP(model.Name .. " [" .. math.floor(dist) .. "]", screenPos, pickup.color, 14)
                    local boxSize = Vector2.new(20, 20)
                    drawBox(screenPos - boxSize/2, boxSize, pickup.color)
                end
            end
        end

        for _, model in ipairs(crateModels) do
            if model and model.PrimaryPart then
                local pos = model.PrimaryPart.Position
                local screenPos, onScreen = WorldToScreen(pos)
                if onScreen then
                    local dist = (pos - myPos).Magnitude
                    drawTextESP(model.Name .. " [" .. math.floor(dist) .. "]", screenPos,
                        Color3.fromRGB(255, 215, 0), 16)
                    local boxSize = Vector2.new(30, 30)
                    drawBox(screenPos - boxSize/2, boxSize, Color3.fromRGB(255, 215, 0))
                end
            end
        end
    end
end

-- ======================
--  Main loop
-- ======================
local wasMaster, wasBoxes, wasLoot = false, false, false

notify("ESP ready – F4/F5/F6", "ESP", 4)

task.spawn(function()
    while true do
        local f4 = iskeypressed(KEY_MASTER)
        if f4 and not wasMaster then
            masterESP = not masterESP
            notify("ESP " .. (masterESP and "ON" or "OFF"), "Toggle", 2)
        end
        wasMaster = f4

        local f5 = iskeypressed(KEY_BOXES)
        if f5 and not wasBoxes then
            boxesEnabled = not boxesEnabled
            notify("Boxes " .. (boxesEnabled and "ON" or "OFF"), "Toggle", 2)
        end
        wasBoxes = f5

        local f6 = iskeypressed(KEY_LOOT)
        if f6 and not wasLoot then
            lootESP = not lootESP
            notify("Pickups + Crates " .. (lootESP and "ON" or "OFF"), "Toggle", 2)
        end
        wasLoot = f6

        renderESP()
        task.wait(1/30)
    end
end)

task.wait(math.huge)
