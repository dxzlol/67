--[[ Survive Homelander ESP v6.4 – TempV disappearance fix + watermark sync
 F1 = toggle ESP | F2 = refresh TempV (new colour) | F3 = toggle watermark | F4 = manual Homelander | F5 = toggle Supe Brawl --]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- ========== RANGE ==========
local PLAYER_RANGE = 200

-- ========== SUPE DETECTION ==========
local SUPE_SPEED_THRESHOLD = 24
local HOMELANDER_SPAWN_RADIUS = 10
local SPAWN_COOLDOWN = 270

-- Helper: get character model (works even if Player.Character is nil)
local function getCharacter(plr)
    local char = plr.Character
    if char then return char end
    return workspace:FindFirstChild(plr.Name)
end

local function isSupeBySpeed(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed then
        return hum.WalkSpeed > SUPE_SPEED_THRESHOLD
    end
    return false
end

local function getSupeModel(playerName, modelName)
    local folder = workspace:FindFirstChild(playerName)
    if folder then
        local model = folder:FindFirstChild(modelName)
        if model then return model end
    end
    return nil
end

-- === Homelander spawn tracker ===
local homelanderSpawnTagged = {}
local nextSpawnScan = 0

-- === Constant speed tracker ===
local speedTagged = {}

task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            local char = getCharacter(p)
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if hum.WalkSpeed and hum.WalkSpeed > SUPE_SPEED_THRESHOLD then
                        speedTagged[p.Name] = true
                    else
                        speedTagged[p.Name] = nil
                    end
                else
                    speedTagged[p.Name] = nil
                end
            else
                speedTagged[p.Name] = nil
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    homelanderSpawnTagged[plr.Name] = nil
    speedTagged[plr.Name] = nil
end)

local function getHomelanderSpawnPosition()
    local map = workspace:FindFirstChild("ActiveMap")
    if map then
        local point = map:FindFirstChild("HomelanderSpawn")
        if point and point:IsA("BasePart") then
            return point.Position
        end
    end
    return Vector3.new(439.8, 283.66, -355.53)
end

local function scanForHomelanderSpawn(force)
    if not force and tick() < nextSpawnScan then return end
    local spawnPos = getHomelanderSpawnPosition()
    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = getCharacter(p)
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - spawnPos).Magnitude
                if dist <= HOMELANDER_SPAWN_RADIUS then
                    homelanderSpawnTagged[p.Name] = true
                    print("[Spawn] Marked " .. p.Name .. " as Homelander")
                    notify(p.Name .. " marked as Homelander", "ESP", 3)
                    nextSpawnScan = tick() + SPAWN_COOLDOWN
                    found = true
                    break
                end
            end
        end
    end
    if force and not found then
        notify("No player near Homelander spawn found", "ESP", 2)
    end
end

local function getPlayerColor(p, character)
    if supeBrawlMode then
        return Color3.fromRGB(255, 80, 80)
    end
    if homelanderSpawnTagged[p.Name] then return Color3.fromRGB(220, 40, 40) end
    if getSupeModel(p.Name, "Homelander") then return Color3.fromRGB(220, 40, 40) end
    if getSupeModel(p.Name, "Stormfront") then return Color3.fromRGB(160, 80, 255) end
    if speedTagged[p.Name] then return Color3.fromRGB(255, 160, 30) end
    return Color3.fromRGB(0, 180, 255)
end

-- ========== SUPE BRAWL MODE ==========
local supeBrawlMode = false
local supeBrawlTimeout = nil

local function stopSupeBrawl()
    supeBrawlMode = false
    if supeBrawlTimeout then task.cancel(supeBrawlTimeout); supeBrawlTimeout = nil end
    notify("Supe Brawl OFF", "Mode", 2)
    if watermarkButton then watermarkButton.Color = Color3.fromRGB(0,255,0) end
    if watermarkText then updateWatermarkText() end
end

local function startSupeBrawl()
    supeBrawlMode = true
    notify("Supe Brawl ON (3 min)", "Mode", 2)
    if watermarkButton then watermarkButton.Color = Color3.fromRGB(255,0,0) end
    if watermarkText then updateWatermarkText() end
    if supeBrawlTimeout then task.cancel(supeBrawlTimeout) end
    supeBrawlTimeout = task.delay(180, function()
        supeBrawlMode = false
        notify("Supe Brawl auto-off (3 min)", "Mode", 2)
        if watermarkButton then watermarkButton.Color = Color3.fromRGB(0,255,0) end
        if watermarkText then updateWatermarkText() end
    end)
end

local function toggleSupeBrawl()
    if supeBrawlMode then stopSupeBrawl() else startSupeBrawl() end
end

-- ========== PLAYER ESP ==========
local playerEspEnabled = true
local playerDrawings = {}

function togglePlayerESP()
    playerEspEnabled = not playerEspEnabled
    local status = playerEspEnabled and "ON" or "OFF"
    notify("Player ESP " .. status, "ESP Toggle", 2)
    print("Player ESP:", status)
    if not playerEspEnabled then
        for _, d in pairs(playerDrawings) do
            if d.box then d.box.Visible = false end
            if d.text then d.text.Visible = false end
            if d.line then d.line.Visible = false end
        end
    end
    if watermarkText then updateWatermarkText() end
end

_G.togglePlayers = togglePlayerESP

-- Full character bounds
local function charBounds(mdl)
    if not mdl then return nil end
    local hrp = mdl:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local hum = mdl:FindFirstChildOfClass("Humanoid")
    local ht = 5.5
    if hum and hum.HipHeight and hum.HipHeight > 0 then
        ht = hum.HipHeight * 2 + 1.2
    end
    local topW = hrp.Position + Vector3.new(0, ht * 0.5 + 0.2, 0)
    local botW = hrp.Position - Vector3.new(0, ht * 0.5, 0)
    local topS, topOn = WorldToScreen(topW)
    local botS, botOn = WorldToScreen(botW)
    if not topOn or not botOn then return nil end
    local h = math.abs(botS.Y - topS.Y)
    if h < 0.1 then return nil end
    local w = h * 0.48
    local depth = (Camera.Position - hrp.Position).Magnitude
    return {
        pos = Vector2.new(topS.X - w * 0.5, topS.Y),
        size = Vector2.new(w, h),
        depth = depth
    }
end

local function drawPlayer(p)
    if not playerEspEnabled then return end
    if p == LP then return end

    local char = getCharacter(p)
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not supeBrawlMode then
        local dist = (Camera.Position - hrp.Position).Magnitude
        if dist > PLAYER_RANGE then
            if playerDrawings[p.Name] then
                playerDrawings[p.Name].box.Visible = false
                playerDrawings[p.Name].text.Visible = false
                playerDrawings[p.Name].line.Visible = false
                playerDrawings[p.Name].active = false
            end
            return
        end
    end

    local bounds = charBounds(char)
    if not bounds then
        if playerDrawings[p.Name] then
            playerDrawings[p.Name].box.Visible = false
            playerDrawings[p.Name].text.Visible = false
            playerDrawings[p.Name].line.Visible = false
            playerDrawings[p.Name].active = false
        end
        return
    end

    local key = p.Name
    if not playerDrawings[key] then
        local box = Drawing.new("Square")
        box.Filled = false
        box.Thickness = 2
        local text = Drawing.new("Text")
        text.Outline = true
        text.Center = true
        text.Size = 13
        text.Color = Color3.fromRGB(255, 255, 255)
        local line = Drawing.new("Line")
        line.Thickness = 1
        playerDrawings[key] = {
            box = box,
            text = text,
            line = line,
            active = true,
            lastUpdate = tick()
        }
    end

    local d = playerDrawings[key]
    local color = getPlayerColor(p, char)
    d.box.Color = color
    d.line.Color = color
    d.box.Position = bounds.pos
    d.box.Size = bounds.size
    d.box.Visible = true
    local modePrefix = supeBrawlMode and "[Brawl] " or ""
    d.text.Text = modePrefix .. p.Name .. " [" .. math.floor(bounds.depth) .. "m]"
    d.text.Position = Vector2.new(bounds.pos.X + bounds.size.X / 2, bounds.pos.Y - 16)
    d.text.Visible = true
    local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    d.line.From = origin
    d.line.To = bounds.pos + Vector2.new(bounds.size.X * 0.5, bounds.size.Y)
    d.line.Visible = true

    d.active = true
    d.lastUpdate = tick()
end

local function cleanupPlayerDrawings()
    local now = tick()
    for name, d in pairs(playerDrawings) do
        if not d.active and (now - d.lastUpdate) > 5 then
            d.box:Remove()
            d.text:Remove()
            d.line:Remove()
            playerDrawings[name] = nil
        end
    end
end

-- Dedicated death check for tagged players
local function checkTaggedDeaths()
    for name, _ in pairs(homelanderSpawnTagged) do
        local plr = Players:FindFirstChild(name)
        if plr then
            local char = getCharacter(plr)
            if not char then
                homelanderSpawnTagged[name] = nil
                print("[Death] " .. name .. " died, Homelander tag removed")
            end
        else
            homelanderSpawnTagged[name] = nil
        end
    end
end

-- ========== TEMP V ESP (Part Target, NO RANGE, PERSISTENT COLOUR, REAL-TIME SCAN) ==========
local tempVDrawings = nil
local tempVPart = nil
local tempVColour = nil  -- Persistent colour

-- Generate a random colour different from all player ESP colours
local function getRandomTempVColour()
    local reservedColors = {
        {220, 40, 40},
        {160, 80, 255},
        {255, 160, 30},
        {0, 180, 255},
        {255, 80, 80}
    }
    local function distance(r1,g1,b1, r2,g2,b2)
        return math.sqrt((r1-r2)^2 + (g1-g2)^2 + (b1-b2)^2)
    end
    local r, g, b
    repeat
        r = math.random(0,255)
        g = math.random(0,255)
        b = math.random(0,255)
        local tooClose = false
        for _, col in ipairs(reservedColors) do
            if distance(r,g,b, col[1],col[2],col[3]) < 50 then
                tooClose = true
                break
            end
        end
    until not tooClose
    return Color3.fromRGB(r, g, b)
end

-- Scan entire workspace for TempPart (anywhere)
local function findTempPartAnywhere()
    local tf = workspace:FindFirstChild("TempV")
    if tf then
        local tp = tf:FindFirstChild("TempPart")
        if tp and tp:IsA("BasePart") then
            return tp
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "TempPart" and obj:IsA("BasePart") then
            return obj
        end
    end
    return nil
end

-- Properly clear Temp V state and update watermark
local function clearTempV()
    if tempVDrawings then
        tempVDrawings.box:Remove()
        tempVDrawings.text:Remove()
        tempVDrawings = nil
    end
    tempVPart = nil
    if watermarkText then updateWatermarkText() end
end

-- Recreate drawings with current colour (or new if forced)
function forceRefreshTempV()
    -- Remove old drawings
    clearTempV()

    -- Only generate a new colour if no colour exists yet (manual refresh will override later)
    if not tempVColour then
        tempVColour = getRandomTempVColour()
    end

    local part = findTempPartAnywhere()
    if part then
        tempVPart = part
        local box = Drawing.new("Square")
        box.Filled = false
        box.Color = tempVColour
        box.Thickness = 2

        local text = Drawing.new("Text")
        text.Outline = true
        text.Center = true
        text.Size = 13
        text.Color = Color3.fromRGB(255, 255, 255)

        tempVDrawings = { box = box, text = text }
        notify("Temp V Part Found & Tracked", "Refresh", 2)
    else
        notify("Temp V Part Not Found", "Refresh", 2)
    end

    if watermarkText then updateWatermarkText() end
end

_G.refreshTempV = forceRefreshTempV

-- Manual F2: force a new colour and scan
local function manualRefreshTempV()
    tempVColour = getRandomTempVColour()
    forceRefreshTempV()
end

-- Periodic scan (every 20s) – does NOT change colour
task.spawn(function()
    while true do
        task.wait(20)
        forceRefreshTempV()
        scanForHomelanderSpawn(false)
    end
end)

-- Real‑time scan: check every 1s for TempV part
task.spawn(function()
    while true do
        task.wait(1)
        -- If we have a part but it's no longer in the workspace, clear everything
        if tempVPart and not tempVPart:IsDescendantOf(workspace) then
            clearTempV()
        end

        -- If we don't have the part, try to find it
        if not tempVPart then
            local part = findTempPartAnywhere()
            if part then
                -- Use existing colour or generate a new one
                if not tempVColour then
                    tempVColour = getRandomTempVColour()
                end
                tempVPart = part
                if not tempVDrawings then
                    local box = Drawing.new("Square")
                    box.Filled = false
                    box.Color = tempVColour
                    box.Thickness = 2
                    local text = Drawing.new("Text")
                    text.Outline = true
                    text.Center = true
                    text.Size = 13
                    text.Color = Color3.fromRGB(255, 255, 255)
                    tempVDrawings = { box = box, text = text }
                else
                    tempVDrawings.box.Color = tempVColour
                end
                if watermarkText then updateWatermarkText() end
            end
        else
            -- Part is valid, ensure drawings exist and colour matches
            if not tempVDrawings then
                local box = Drawing.new("Square")
                box.Filled = false
                box.Color = tempVColour
                box.Thickness = 2
                local text = Drawing.new("Text")
                text.Outline = true
                text.Center = true
                text.Size = 13
                text.Color = Color3.fromRGB(255, 255, 255)
                tempVDrawings = { box = box, text = text }
            elseif tempVDrawings.box.Color ~= tempVColour then
                tempVDrawings.box.Color = tempVColour
            end
        end
    end
end)

-- Initial scan
forceRefreshTempV()

local function computePartScreenBounds(part)
    if not part or not part:IsA("BasePart") then return nil end
    local cframe = part.CFrame
    local size = part.Size
    local halfSize = size / 2

    local corners = {
        cframe * Vector3.new(-halfSize.X,  halfSize.Y,  halfSize.Z),
        cframe * Vector3.new( halfSize.X,  halfSize.Y,  halfSize.Z),
        cframe * Vector3.new(-halfSize.X, -halfSize.Y,  halfSize.Z),
        cframe * Vector3.new( halfSize.X, -halfSize.Y,  halfSize.Z),
        cframe * Vector3.new(-halfSize.X,  halfSize.Y, -halfSize.Z),
        cframe * Vector3.new( halfSize.X,  halfSize.Y, -halfSize.Z),
        cframe * Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
        cframe * Vector3.new( halfSize.X, -halfSize.Y, -halfSize.Z)
    }

    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local depth = math.huge

    for _, corner in ipairs(corners) do
        local screenPos, onScreen = WorldToScreen(corner)
        if onScreen then
            if screenPos.X < minX then minX = screenPos.X end
            if screenPos.X > maxX then maxX = screenPos.X end
            if screenPos.Y < minY then minY = screenPos.Y end
            if screenPos.Y > maxY then maxY = screenPos.Y end
        end
        local cornerDepth = (Camera.Position - corner).Magnitude
        if cornerDepth < depth then depth = cornerDepth end
    end

    if minX == math.huge or maxX == -math.huge or minY == math.huge or maxY == -math.huge then
        return nil
    end

    return {
        pos = Vector2.new(minX, minY),
        size = Vector2.new(maxX - minX, maxY - minY),
        depth = depth
    }
end

local function drawTempV()
    if not tempVPart then return end
    if not tempVPart:IsDescendantOf(workspace) then
        -- If the part disappeared between the real‑time check and now, clear it
        clearTempV()
        return
    end

    local bounds = computePartScreenBounds(tempVPart)
    if not bounds then
        if tempVDrawings then
            tempVDrawings.box.Visible = false
            tempVDrawings.text.Visible = false
        end
        return
    end

    if tempVDrawings then
        tempVDrawings.box.Position = bounds.pos
        tempVDrawings.box.Size = bounds.size
        tempVDrawings.box.Visible = true
        tempVDrawings.text.Text = "Temp V [" .. math.floor(bounds.depth) .. "m]"
        tempVDrawings.text.Position = Vector2.new(bounds.pos.X + bounds.size.X / 2, bounds.pos.Y - 16)
        tempVDrawings.text.Visible = true
    end
end

-- ========== WATERMARK + SUPE BRAWL BUTTON ==========
local watermarkVisible = true
local watermarkBg = Drawing.new("Square")
watermarkBg.Filled = true
watermarkBg.Color = Color3.fromRGB(0, 0, 0)
watermarkBg.Transparency = 0.6
watermarkBg.ZIndex = 100
watermarkBg.Visible = true

local watermarkText = Drawing.new("Text")
watermarkText.Size = 14
watermarkText.Color = Color3.fromRGB(255, 255, 255)
watermarkText.Outline = true
watermarkText.Center = false
watermarkText.ZIndex = 101
watermarkText.Visible = true

local creditText = Drawing.new("Text")
creditText.Text = "Made by d.x.z. - v6.4"
creditText.Size = 11
creditText.Color = Color3.fromRGB(200, 200, 200)
creditText.Outline = true
creditText.Center = false
creditText.ZIndex = 101
creditText.Visible = true

local watermarkButton = Drawing.new("Square")
watermarkButton.Filled = true
watermarkButton.Color = Color3.fromRGB(0, 255, 0)
watermarkButton.ZIndex = 102
watermarkButton.Visible = true

local BAR_WIDTH = 380
local BAR_HEIGHT = 26
local PADDING = 4
local BUTTON_SIZE = 16
local barX = 20
local barY = 80

local function updateWatermarkText()
    local status = playerEspEnabled and "ON" or "OFF"
    local tempStatus = tempVPart and "Tracked" or "None"
    local brawlStatus = supeBrawlMode and " BRAWL" or ""
    watermarkText.Text = "Survive Homelander | ESP: " .. status .. " | Temp V: " .. tempStatus .. brawlStatus
end

local function repositionWatermark(x, y)
    barX = x
    barY = y
    watermarkBg.Position = Vector2.new(barX, barY)
    watermarkBg.Size = Vector2.new(BAR_WIDTH, BAR_HEIGHT)
    watermarkText.Position = Vector2.new(barX + PADDING, barY + (BAR_HEIGHT - watermarkText.Size) / 2)
    creditText.Position = Vector2.new(barX + PADDING, barY + BAR_HEIGHT + 2)
    watermarkButton.Position = Vector2.new(barX + BAR_WIDTH - BUTTON_SIZE - 2, barY + (BAR_HEIGHT - BUTTON_SIZE) / 2)
    watermarkButton.Size = Vector2.new(BUTTON_SIZE, BUTTON_SIZE)
end
repositionWatermark(barX, barY)

local function toggleWatermark()
    watermarkVisible = not watermarkVisible
    watermarkBg.Visible = watermarkVisible
    watermarkText.Visible = watermarkVisible
    creditText.Visible = watermarkVisible
    watermarkButton.Visible = watermarkVisible
    notify(watermarkVisible and "Watermark ON" or "Watermark OFF", "Watermark", 1)
end
_G.toggleWatermark = toggleWatermark

local function isMouseOnWatermarkButton()
    local mPos = Vector2.new(Mouse.X, Mouse.Y)
    local btnPos = watermarkButton.Position
    return mPos.X >= btnPos.X and mPos.X <= btnPos.X + BUTTON_SIZE and mPos.Y >= btnPos.Y and mPos.Y <= btnPos.Y + BUTTON_SIZE
end

updateWatermarkText()

-- ========== KEY HANDLING (fixed keys) ==========
local lastF1, lastF2, lastF3, lastF4, lastF5 = false, false, false, false, false
local wmButtonPressStarted = false
local wmButtonLastPressed = false

task.spawn(function()
    while true do
        task.wait(0.1)
        local f1 = iskeypressed(112) -- F1
        local f2 = iskeypressed(113) -- F2
        local f3 = iskeypressed(114) -- F3
        local f4 = iskeypressed(115) -- F4
        local f5 = iskeypressed(116) -- F5

        if f1 and not lastF1 then togglePlayerESP() end
        if f2 and not lastF2 then
            manualRefreshTempV()
            scanForHomelanderSpawn(false)
        end
        if f3 and not lastF3 then toggleWatermark() end
        if f4 and not lastF4 then scanForHomelanderSpawn(true) end
        if f5 and not lastF5 then toggleSupeBrawl() end

        lastF1, lastF2, lastF3, lastF4, lastF5 = f1, f2, f3, f4, f5

        -- Watermark button click detection
        local mousePressed = ismouse1pressed()
        if mousePressed and not wmButtonLastPressed then
            if watermarkVisible and isMouseOnWatermarkButton() then
                wmButtonPressStarted = true
            end
        end
        if not mousePressed and wmButtonLastPressed then
            if wmButtonPressStarted and watermarkVisible and isMouseOnWatermarkButton() then
                toggleSupeBrawl()
            end
            wmButtonPressStarted = false
        end
        wmButtonLastPressed = mousePressed
    end
end)

-- ========== DRAGGING WATERMARK ==========
local draggingWatermark = false
local dragOffsetWmX, dragOffsetWmY = 0, 0
local lastMouse = false

task.spawn(function()
    while true do
        task.wait(0.05)
        local mousePressed = ismouse1pressed()
        local mPos = Vector2.new(Mouse.X, Mouse.Y)
        if mousePressed and not lastMouse then
            local bgPos = watermarkBg.Position
            if not isMouseOnWatermarkButton() and mPos.X >= bgPos.X and mPos.X <= bgPos.X + BAR_WIDTH and mPos.Y >= bgPos.Y and mPos.Y <= bgPos.Y + BAR_HEIGHT then
                draggingWatermark = true
                dragOffsetWmX = mPos.X - barX
                dragOffsetWmY = mPos.Y - barY
            end
        end
        if draggingWatermark and mousePressed then
            repositionWatermark(mPos.X - dragOffsetWmX, mPos.Y - dragOffsetWmY)
        end
        if not mousePressed and lastMouse then
            draggingWatermark = false
        end
        lastMouse = mousePressed
    end
end)

-- ========== MAIN RENDER ==========
RunService.RenderStepped:Connect(function()
    checkTaggedDeaths()
    for _, p in ipairs(Players:GetPlayers()) do
        drawPlayer(p)
    end
    cleanupPlayerDrawings()
    drawTempV()
    -- Watermark is now synced inside clearTempV() and the real‑time loop, so this fallback is just a safety
    if watermarkText then updateWatermarkText() end
end)

-- Startup
task.spawn(function()
    wait(1)
    notify("ESP v6.4 – TempV disappearance fix", "ESP", 3)
    notify("This script is beta use at own risk", "Warning", 5)
    print("[WARNING] ESP is beta use at own risk")
    print("Survive Homelander ESP v6.4 - TempV color & clean-up fixed.")
end)
