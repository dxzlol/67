local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local activeDrawings = {}
local usedColors = {}

-- Distinct color palette pool to avoid color duplication
local colorPalette = {
    Color3.fromRGB(255, 50, 50),   -- Red
    Color3.fromRGB(50, 150, 255),  -- Blue
    Color3.fromRGB(50, 255, 50),   -- Green
    Color3.fromRGB(255, 255, 50),  -- Yellow
    Color3.fromRGB(255, 50, 255),  -- Magenta
    Color3.fromRGB(50, 255, 255),  -- Cyan
    Color3.fromRGB(255, 128, 0),   -- Orange
    Color3.fromRGB(128, 0, 255),   -- Purple
    Color3.fromRGB(255, 192, 203), -- Pink
    Color3.fromRGB(0, 255, 128)    -- Mint
}

-- Safe fallback helper for finding a player from their character model
local function getPlayerFromCharacter(character)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == character then
            return player
        end
    end
    return nil
end

-- Assigns the next available unique color from the palette
local function getNextColor()
    for _, color in ipairs(colorPalette) do
        local isUsed = false
        for _, usedColor in pairs(usedColors) do
            if usedColor == color then
                isUsed = true
                break
            end
        end
        if not isUsed then
            return color
        end
    end
    return colorPalette[math.random(1, #colorPalette)]
end

RunService.RenderStepped:Connect(function()
    local aliveFolder = workspace:FindFirstChild("Alive")
    if not aliveFolder then return end
    
    local currentAliveModels = {}
    
    -- Dynamically scan characters currently inside game.Workspace.Alive
    for _, character in ipairs(aliveFolder:GetChildren()) do
        if character:IsA("Model") then
            local player = getPlayerFromCharacter(character)
            
            -- Filter: Skip Self and Lobby team members
            local skip = false
            if player == LocalPlayer then
                skip = true
            elseif player and player.Team and player.Team.Name == "Lobby" then
                skip = true
            end
            
            if not skip then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                if hrp and humanoid and humanoid.Health > 0 then
                    currentAliveModels[character] = true
                    
                    -- Create drawing objects if they don't exist yet for this character
                    if not activeDrawings[character] then
                        local displayName = character.Name
                        if player then
                            displayName = player.Name
                        end
                        
                        local assignedColor = getNextColor()
                        usedColors[character] = assignedColor
                        
                        local box = Drawing.new("Square")
                        box.Color = assignedColor
                        box.Thickness = 1.5
                        box.Filled = false
                        box.Visible = false
                        
                        local text = Drawing.new("Text")
                        text.Color = Color3.fromRGB(255, 255, 255) -- White text for readability
                        text.Size = 13
                        text.Center = true
                        text.Outline = true
                        text.Visible = false
                        
                        activeDrawings[character] = { Box = box, Text = text, Name = displayName }
                    end
                    
                    local esp = activeDrawings[character]
                    local pos, onScreen = WorldToScreen(hrp.Position)
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    
                    -- Only display if on-screen and strictly within the 1,000 stud limit
                    if onScreen and dist <= 1000 then
                        local height = math.clamp(2500 / dist, 20, 500)
                        local width = height * 0.5
                        
                        -- Update Box
                        esp.Box.Size = Vector2.new(width, height)
                        esp.Box.Position = Vector2.new(pos.X - width / 2, pos.Y - height / 2)
                        esp.Box.Visible = true
                        
                        -- Update Text (Username + HP + Distance)
                        esp.Text.Text = string.format("%s [%d HP] [%dm]", esp.Name, math.floor(humanoid.Health), math.floor(dist))
                        esp.Text.Position = Vector2.new(pos.X, (pos.Y - height / 2) - 16)
                        esp.Text.Visible = true
                    else
                        -- Hide drawings if off-screen or further than 1,000 studs
                        esp.Box.Visible = false
                        esp.Text.Visible = false
                    end
                end
            end
        end
    end
    
    -- Clean up drawings and release assigned colors when players return to Lobby, die, or reset
    for character, esp in pairs(activeDrawings) do
        if not currentAliveModels[character] or not character.Parent then
            esp.Box:Remove()
            esp.Text:Remove()
            activeDrawings[character] = nil
            usedColors[character] = nil
        end
    end
end)

print("Alive ESP fully optimized: No self, no lobby, unique palette colors, 1k limit!")
