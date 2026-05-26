--[[
    Survive Homelander ESP – Full-body + Temp V (original)
    F1 = toggle Player ESP, F2 = refresh Temp V, F3 = toggle watermark
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- ========== RANGE ==========
local PLAYER_RANGE = 200
local TEMP_RANGE = 200

-- ========== PLAYER ESP (full body) ==========
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

-- Speed detection
local SUPE_SPEED_THRESHOLD = 24
local function isSupeBySpeed(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed then
        return hum.WalkSpeed > SUPE_SPEED_THRESHOLD
    end
    return false
end

-- Homelander / Stormfront detection
local function getSupeModel(playerName, modelName)
    local folder = workspace:FindFirstChild(playerName)
    if folder then
        return folder:FindFirstChild(modelName)
    end
    return nil
end

-- Full character bounds (original working version)
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

local function getPlayerColor(p, character)
    if getSupeModel(p.Name, "Homelander") then
        return Color3.fromRGB(220, 40, 40)    -- red
    end
    if getSupeModel(p.Name, "Stormfront") then
        return Color3.fromRGB(160, 80, 255)   -- purple
    end
    if isSupeBySpeed(character) then
        return Color3.fromRGB(255, 160, 30)   -- orange
    end
    return Color3.fromRGB(0, 180, 255)        -- cool cyan
end

local function drawPlayer(p)
    if not playerEspEnabled then return end
    if p == LP then return end   -- skip self
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dist = (Camera.Position - hrp.Position).Magnitude
    if dist > PLAYER_RANGE then
        if playerDrawings[p.Name] then
            playerDrawings[p.Name].box.Visible = false
            playerDrawings[p.Name].text.Visible = false
            playerDrawings[p.Name].line.Visible = false
        end
        return
    end
    local bounds = charBounds(char)
    if not bounds then return end

    local key = p.Name
    if not playerDrawings[key] then
        local box = Drawing.new("Square")
        box.Filled = false
        box.Thickness = 2
        local text = Drawing.new("Text")
        text.Outline = true
        text.Center = true
        text.Size = 13
        text.Color = Color3.fromRGB(255,255,255)
        local line = Drawing.new("Line")
        line.Thickness = 1
        playerDrawings[key] = { box = box, text = text, line = line }
    end
    local d = playerDrawings[key]
    local color = getPlayerColor(p, char)
    d.box.Color = color
    d.line.Color = color
    d.box.Position = bounds.pos
    d.box.Size = bounds.size
    d.box.Visible = true
    d.text.Text = p.Name .. " [" .. math.floor(bounds.depth) .. "m]"
    d.text.Position = Vector2.new(bounds.pos.X + bounds.size.X / 2, bounds.pos.Y - 16)
    d.text.Visible = true
    local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
    d.line.From = origin
    d.line.To = bounds.pos + Vector2.new(bounds.size.X * 0.5, bounds.size.Y)
    d.line.Visible = true
end

-- ========== TEMP V ESP (original recursive) ==========
local tempVDrawings = {}
local tempVParts = {}

function forceRefreshTempV()
    local root = workspace:FindFirstChild("TempV")
    if not root then
        tempVParts = {}
        notify("Temp V not found", "Refresh", 2)
        print("[TempV] Nothing to refresh")
        if watermarkText then updateWatermarkText() end
        return
    end
    local function collect(inst, list)
        if inst:IsA("BasePart") or inst:IsA("MeshPart") then
            table.insert(list, inst)
        end
        for _, child in ipairs(inst:GetChildren()) do
            collect(child, list)
        end
    end
    local newParts = {}
    collect(root, newParts)
    tempVParts = newParts
    local msg = "Found " .. #tempVParts .. " parts"
    notify(msg, "Temp V Refreshed", 2)
    print("[TempV] Refreshed " .. msg)
    if watermarkText then updateWatermarkText() end
end

_G.refreshTempV = forceRefreshTempV

task.spawn(function()
    while true do
        task.wait(20)
        forceRefreshTempV()
    end
end)
forceRefreshTempV()

local function drawTempV()
    local active = {}
    for _, part in ipairs(tempVParts) do
        local key = tostring(part)
        active[key] = true
        if part and part.Position then
            local dist = (Camera.Position - part.Position).Magnitude
            if dist <= TEMP_RANGE then
                local pos, onScreen = WorldToScreen(part.Position)
                if onScreen and pos then
                    if not tempVDrawings[key] then
                        local box = Drawing.new("Square")
                        box.Filled = false
                        box.Color = Color3.fromRGB(0, 210, 255)
                        box.Thickness = 2
                        local text = Drawing.new("Text")
                        text.Outline = true
                        text.Center = true
                        text.Size = 13
                        text.Color = Color3.fromRGB(255,255,255)
                        tempVDrawings[key] = { box = box, text = text }
                    end
                    local size = math.clamp(1000 / dist, 25, 80)
                    local half = size / 2
                    local d = tempVDrawings[key]
                    d.box.Position = pos - Vector2.new(half, half)
                    d.box.Size = Vector2.new(size, size)
                    d.box.Visible = true
                    d.text.Text = "Temp V [" .. math.floor(dist) .. "m]"
                    d.text.Position = pos - Vector2.new(0, half + 10)
                    d.text.Visible = true
                else
                    if tempVDrawings[key] then tempVDrawings[key].box.Visible = false; tempVDrawings[key].text.Visible = false end
                end
            else
                if tempVDrawings[key] then tempVDrawings[key].box.Visible = false; tempVDrawings[key].text.Visible = false end
            end
        else
            if tempVDrawings[key] then tempVDrawings[key].box.Visible = false; tempVDrawings[key].text.Visible = false end
        end
    end
    for key, d in pairs(tempVDrawings) do
        if not active[key] then
            d.box.Visible = false
            d.text.Visible = false
        end
    end
end

-- ========== WATERMARK (draggable) ==========
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
creditText.Text = "Made by d.x.z. - v3.5"
creditText.Size = 11
creditText.Color = Color3.fromRGB(200, 200, 200)
creditText.Outline = true
creditText.Center = false
creditText.ZIndex = 101
creditText.Visible = true

local BAR_WIDTH = 390
local BAR_HEIGHT = 26
local PADDING = 4

local barX = 20
local barY = 80

local function updateWatermarkText()
    local status = playerEspEnabled and "ON" or "OFF"
    watermarkText.Text = "Survive Homelander | ESP: " .. status .. " | Temp V: " .. #tempVParts
end

local function repositionWatermark(x, y)
    barX = x
    barY = y
    watermarkBg.Position = Vector2.new(barX, barY)
    watermarkBg.Size = Vector2.new(BAR_WIDTH, BAR_HEIGHT)
    watermarkText.Position = Vector2.new(barX + PADDING, barY + (BAR_HEIGHT - watermarkText.Size)/2)
    creditText.Position = Vector2.new(barX + PADDING, barY + BAR_HEIGHT + 2)
end

repositionWatermark(barX, barY)

local function toggleWatermark()
    watermarkVisible = not watermarkVisible
    watermarkBg.Visible = watermarkVisible
    watermarkText.Visible = watermarkVisible
    creditText.Visible = watermarkVisible
    notify(watermarkVisible and "Watermark ON" or "Watermark OFF", "Watermark", 1)
end
_G.toggleWatermark = toggleWatermark

updateWatermarkText()

-- ========== KEYBINDS ==========
task.spawn(function()
    local lastF1, lastF2, lastF3 = false, false, false
    while true do
        task.wait(0.1)
        local f1 = iskeypressed(112)
        local f2 = iskeypressed(113)
        local f3 = iskeypressed(114)
        if f1 and not lastF1 then togglePlayerESP() end
        if f2 and not lastF2 then forceRefreshTempV() end
        if f3 and not lastF3 then toggleWatermark() end
        lastF1, lastF2, lastF3 = f1, f2, f3
    end
end)

-- ========== DRAGGING ==========
local draggingWatermark = false
local dragOffsetX, dragOffsetY = 0, 0
local lastMouse = false
task.spawn(function()
    while true do
        task.wait(0.05)
        local mousePressed = ismouse1pressed()
        local mPos = Vector2.new(Mouse.X, Mouse.Y)

        if mousePressed and not lastMouse then
            local bgPos = watermarkBg.Position
            if mPos.X >= bgPos.X and mPos.X <= bgPos.X + BAR_WIDTH and
               mPos.Y >= bgPos.Y and mPos.Y <= bgPos.Y + BAR_HEIGHT then
                draggingWatermark = true
                dragOffsetX = mPos.X - barX
                dragOffsetY = mPos.Y - barY
            end
        end

        if draggingWatermark and mousePressed then
            local newX = mPos.X - dragOffsetX
            local newY = mPos.Y - dragOffsetY
            repositionWatermark(newX, newY)
        end

        if not mousePressed and lastMouse then
            draggingWatermark = false
        end

        lastMouse = mousePressed
    end
end)

-- ========== MAIN RENDER ==========
RunService.RenderStepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        drawPlayer(p)
    end
    drawTempV()
end)

-- Startup message (no commas)
task.spawn(function()
    wait(1)
    notify("This script is beta use at own risk", "Warning", 5)
    print("[WARNING] ESP is beta use at own risk")
end)

print("Survive Homelander ESP v3.5 – Full body players + Temp V. F1 toggle F2 refresh F3 watermark")
notify("Full-body ESP restored", "ESP v3.5", 4)
