-- Minimal ESP for Matcha
-- Each player gets random colours
-- Just box + name – no health, no distance, no roles

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local activeESP = {}
local knownPlayers = {}

-- Generate a bright random colour (once per player)
local function randomColour()
    return Color3.fromHSV(math.random(), 1, 1)
end

-- Create ESP objects (box + name) for a player
local function createESP(player)
    local esp = {}
    local isSelf = (player == LocalPlayer)
    esp.color = isSelf and Color3.fromRGB(0, 255, 255) or randomColour()
    
    -- Box
    esp.box = Drawing.new("Square")
    esp.box.Filled = false
    esp.box.Color = esp.color
    esp.box.Transparency = 0.6
    esp.box.Visible = false
    esp.box.ZIndex = 1
    
    -- Name
    esp.nameText = Drawing.new("Text")
    esp.nameText.Font = Drawing.Fonts.UI
    esp.nameText.Size = 14
    esp.nameText.Color = Color3.fromRGB(255, 255, 255)
    esp.nameText.Outline = true
    esp.nameText.Center = true
    esp.nameText.Visible = false
    esp.nameText.ZIndex = 2
    
    return esp
end

-- Clean up
local function removeESP(player)
    local esp = activeESP[player]
    if esp then
        esp.box:Remove()
        esp.nameText:Remove()
        activeESP[player] = nil
        knownPlayers[player] = nil
    end
end

-- Update a single player's ESP
local function updateESP(player, localRootPart)
    local esp = activeESP[player]
    if not esp then return end
    
    local char = player.Character
    if not char then
        esp.box.Visible = false
        esp.nameText.Visible = false
        return
    end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not rootPart or not head then
        esp.box.Visible = false
        esp.nameText.Visible = false
        return
    end
    
    local headPos = head.Position
    local footPos = rootPart.Position - Vector3.new(0, 2.5, 0)
    local headScreen, headOn = WorldToScreen(headPos)
    local footScreen, footOn = WorldToScreen(footPos)
    
    if not headOn or not footOn then
        esp.box.Visible = false
        esp.nameText.Visible = false
        return
    end
    
    local topY = headScreen.Y
    local bottomY = footScreen.Y
    local height = bottomY - topY
    if height <= 0 then
        esp.box.Visible = false
        esp.nameText.Visible = false
        return
    end
    
    local width = height * 0.55
    local leftX = headScreen.X - (width / 2)
    
    -- Box
    esp.box.Position = Vector2.new(leftX, topY)
    esp.box.Size = Vector2.new(width, height)
    esp.box.Visible = true
    
    -- Name (self gets "(YOU)")
    local isSelf = (player == LocalPlayer)
    local name = isSelf and (player.Name .. " (YOU)") or player.Name
    esp.nameText.Text = name
    esp.nameText.Position = Vector2.new(headScreen.X, topY - 14)
    esp.nameText.Visible = true
end

-- Refresh player list (add/remove)
local function refreshPlayerList()
    local currentPlayers = Players:GetPlayers()
    local newList = {}
    for _, p in ipairs(currentPlayers) do newList[p] = true end
    
    for p in pairs(knownPlayers) do
        if not newList[p] then removeESP(p) end
    end
    
    for _, p in ipairs(currentPlayers) do
        if not knownPlayers[p] then
            knownPlayers[p] = true
            activeESP[p] = createESP(p)
        end
    end
end

-- Main update loop
local function updateAll()
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot or not Camera then return end
    
    refreshPlayerList()
    
    for player, _ in pairs(activeESP) do
        updateESP(player, localRoot)
    end
end

-- Start the loop at a very low rate
spawn(function()
    while true do
        task.wait(0.2)
        pcall(updateAll)
    end
end)

notify("Minimal ESP Loaded", "Matcha", 2)
print("Minimal ESP – each player has colours, no health/distance")
