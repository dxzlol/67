-- MatchaUI Library
-- A custom, lightweight Drawing-based UI library

local MatchaUI = {}
MatchaUI.__index = MatchaUI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Theme / Styling
local Theme = {
    Background = Color3.fromRGB(20, 22, 20),
    Topbar = Color3.fromRGB(30, 34, 30),
    Border = Color3.fromRGB(48, 62, 52),
    Accent = Color3.fromRGB(106, 218, 142),
    Text = Color3.fromRGB(240, 248, 242),
    SubText = Color3.fromRGB(150, 175, 158),
    ElementBg = Color3.fromRGB(35, 40, 35)
}

-- Input State
local Input = {
    X = 0,
    Y = 0,
    Held = false,
    Clicked = false,
    Released = false
}

local function UpdateInput()
    local currentlyHeld = ismouse1pressed() == true
    Input.X = Mouse.X
    Input.Y = Mouse.Y
    Input.Clicked = currentlyHeld and not Input.Held
    Input.Released = not currentlyHeld and Input.Held
    Input.Held = currentlyHeld
end

local function IsHovering(x, y, w, h)
    return Input.X >= x and Input.X <= x + w and Input.Y >= y and Input.Y <= y + h
end

-- Drawing Helpers
local function CreateRect(z, filled, color)
    local rect = Drawing.new("Square")
    rect.ZIndex = z
    rect.Filled = filled
    rect.Color = color
    rect.Visible = true
    return rect
end

local function CreateText(z, size, color, center)
    local text = Drawing.new("Text")
    text.ZIndex = z
    text.Size = size
    text.Color = color
    text.Center = center
    text.Outline = true
    text.Font = Drawing.Fonts.UI
    text.Visible = true
    return text
end

-- Core Library Functions
function MatchaUI.createWindow(title, width, height)
    local Window = {
        Title = title or "MatchaUI Window",
        X = 100,
        Y = 100,
        W = width or 400,
        H = height or 400,
        Tabs = {},
        ActiveTab = nil,
        Dragging = false,
        DragOffset = Vector2.new(0, 0),
        
        -- Drawings
        Drawings = {
            Bg = CreateRect(1, true, Theme.Background),
            Border = CreateRect(2, false, Theme.Border),
            Topbar = CreateRect(2, true, Theme.Topbar),
            Title = CreateText(3, 14, Theme.Accent, false)
        }
    }
    
    function Window:addTab(name)
        local Tab = {
            Name = name,
            Sections = {},
            Window = self,
            Drawings = {
                Text = CreateText(3, 13, Theme.SubText, true)
            }
        }
        
        function Tab:addSection(name)
            local Section = {
                Name = name,
                Elements = {},
                Drawings = {
                    Title = CreateText(3, 13, Theme.Text, false),
                    Line = CreateRect(3, true, Theme.Border)
                }
            }
            
            function Section:addToggle(name, default, callback)
                local Toggle = {
                    Type = "Toggle",
                    Name = name,
                    Value = default or false,
                    Callback = callback,
                    Drawings = {
                        Label = CreateText(3, 13, Theme.Text, false),
                        Box = CreateRect(3, true, Theme.ElementBg),
                        BoxBorder = CreateRect(4, false, Theme.Border),
                        Indicator = CreateRect(4, true, Theme.Accent)
                    }
                }
                table.insert(self.Elements, Toggle)
                return Toggle
            end

            function Section:addButton(name, callback)
                local Button = {
                    Type = "Button",
                    Name = name,
                    Callback = callback,
                    Drawings = {
                        Box = CreateRect(3, true, Theme.ElementBg),
                        BoxBorder = CreateRect(4, false, Theme.Border),
                        Label = CreateText(4, 13, Theme.Text, true)
                    }
                }
                table.insert(self.Elements, Button)
                return Button
            end
            
            function Section:addSlider(name, min, max, default, callback)
                local Slider = {
                    Type = "Slider",
                    Name = name,
                    Min = min or 0,
                    Max = max or 100,
                    Value = default or min,
                    Callback = callback,
                    Dragging = false,
                    Drawings = {
                        Label = CreateText(3, 13, Theme.Text, false),
                        Value = CreateText(3, 13, Theme.SubText, false),
                        Bg = CreateRect(3, true, Theme.ElementBg),
                        Fill = CreateRect(4, true, Theme.Accent)
                    }
                }
                table.insert(self.Elements, Slider)
                return Slider
            end
            
            table.insert(self.Sections, Section)
            return Section
        end
        
        table.insert(self.Tabs, Tab)
        if not self.ActiveTab then self.ActiveTab = Tab end
        return Tab
    end
    
    -- Main Render Loop for this Window
    RunService.RenderStepped:Connect(function()
        UpdateInput()
        
        -- Window Dragging Logic
        if IsHovering(Window.X, Window.Y, Window.W, 30) and Input.Clicked then
            Window.Dragging = true
            Window.DragOffset = Vector2.new(Input.X - Window.X, Input.Y - Window.Y)
        end
        if Input.Released then Window.Dragging = false end
        if Window.Dragging then
            Window.X = Input.X - Window.DragOffset.X
            Window.Y = Input.Y - Window.DragOffset.Y
        end
        
        -- Render Window Base
        Window.Drawings.Bg.Position = Vector2.new(Window.X, Window.Y)
        Window.Drawings.Bg.Size = Vector2.new(Window.W, Window.H)
        Window.Drawings.Border.Position = Vector2.new(Window.X, Window.Y)
        Window.Drawings.Border.Size = Vector2.new(Window.W, Window.H)
        Window.Drawings.Topbar.Position = Vector2.new(Window.X, Window.Y)
        Window.Drawings.Topbar.Size = Vector2.new(Window.W, 30)
        Window.Drawings.Title.Position = Vector2.new(Window.X + 10, Window.Y + 8)
        Window.Drawings.Title.Text = Window.Title
        
        -- Render Tabs
        local tabWidth = Window.W / math.max(#Window.Tabs, 1)
        for i, tab in ipairs(Window.Tabs) do
            local tx = Window.X + (tabWidth * (i - 1))
            local ty = Window.Y + 30
            
            tab.Drawings.Text.Position = Vector2.new(tx + (tabWidth / 2), ty + 8)
            tab.Drawings.Text.Text = tab.Name
            tab.Drawings.Text.Color = (Window.ActiveTab == tab) and Theme.Accent or Theme.SubText
            
            if IsHovering(tx, ty, tabWidth, 30) and Input.Clicked then
                Window.ActiveTab = tab
            end
            
            -- Hide/Show sections based on active tab
            local isActive = (Window.ActiveTab == tab)
            local currentY = ty + 40
            
            for _, section in ipairs(tab.Sections) do
                section.Drawings.Title.Visible = isActive
                section.Drawings.Line.Visible = isActive
                
                if isActive then
                    section.Drawings.Title.Position = Vector2.new(Window.X + 15, currentY)
                    section.Drawings.Title.Text = section.Name
                    section.Drawings.Line.Position = Vector2.new(Window.X + 15 + section.Drawings.Title.TextBounds.X + 5, currentY + 6)
                    section.Drawings.Line.Size = Vector2.new(Window.W - 40 - section.Drawings.Title.TextBounds.X, 1)
                    currentY = currentY + 25
                end
                
                for _, el in ipairs(section.Elements) do
                    for _, dwg in pairs(el.Drawings) do dwg.Visible = isActive end
                    
                    if isActive then
                        if el.Type == "Toggle" then
                            el.Drawings.Label.Position = Vector2.new(Window.X + 20, currentY)
                            el.Drawings.Label.Text = el.Name
                            
                            local boxX = Window.X + Window.W - 35
                            el.Drawings.Box.Position = Vector2.new(boxX, currentY)
                            el.Drawings.Box.Size = Vector2.new(16, 16)
                            el.Drawings.BoxBorder.Position = Vector2.new(boxX, currentY)
                            el.Drawings.BoxBorder.Size = Vector2.new(16, 16)
                            
                            el.Drawings.Indicator.Position = Vector2.new(boxX + 2, currentY + 2)
                            el.Drawings.Indicator.Size = Vector2.new(12, 12)
                            el.Drawings.Indicator.Visible = el.Value
                            
                            if IsHovering(Window.X + 20, currentY, Window.W - 40, 16) and Input.Clicked then
                                el.Value = not el.Value
                                if type(el.Callback) == "function" then el.Callback(el.Value) end
                            end
                            currentY = currentY + 25
                            
                        elseif el.Type == "Button" then
                            local btnW = Window.W - 40
                            el.Drawings.Box.Position = Vector2.new(Window.X + 20, currentY)
                            el.Drawings.Box.Size = Vector2.new(btnW, 24)
                            el.Drawings.BoxBorder.Position = Vector2.new(Window.X + 20, currentY)
                            el.Drawings.BoxBorder.Size = Vector2.new(btnW, 24)
                            
                            local isHoveringBtn = IsHovering(Window.X + 20, currentY, btnW, 24)
                            el.Drawings.BoxBorder.Color = isHoveringBtn and Theme.Accent or Theme.Border
                            
                            el.Drawings.Label.Position = Vector2.new(Window.X + 20 + (btnW / 2), currentY + 5)
                            el.Drawings.Label.Text = el.Name
                            
                            if isHoveringBtn and Input.Clicked then
                                if type(el.Callback) == "function" then el.Callback() end
                            end
                            currentY = currentY + 30
                            
                        elseif el.Type == "Slider" then
                            el.Drawings.Label.Position = Vector2.new(Window.X + 20, currentY)
                            el.Drawings.Label.Text = el.Name
                            el.Drawings.Value.Position = Vector2.new(Window.X + Window.W - 45, currentY)
                            el.Drawings.Value.Text = tostring(el.Value)
                            
                            local sX, sY, sW = Window.X + 20, currentY + 18, Window.W - 40
                            el.Drawings.Bg.Position = Vector2.new(sX, sY)
                            el.Drawings.Bg.Size = Vector2.new(sW, 6)
                            
                            local fillWidth = math.clamp((el.Value - el.Min) / (el.Max - el.Min), 0, 1) * sW
                            el.Drawings.Fill.Position = Vector2.new(sX, sY)
                            el.Drawings.Fill.Size = Vector2.new(fillWidth, 6)
                            
                            if IsHovering(sX, sY - 5, sW, 16) and Input.Clicked then el.Dragging = true end
                            if Input.Released then el.Dragging = false end
                            
                            if el.Dragging then
                                local pct = math.clamp((Input.X - sX) / sW, 0, 1)
                                local newVal = math.floor(el.Min + (pct * (el.Max - el.Min)))
                                if newVal ~= el.Value then
                                    el.Value = newVal
                                    if type(el.Callback) == "function" then el.Callback(el.Value) end
                                end
                            end
                            currentY = currentY + 35
                        end
                    end
                end
            end
        end
    end)
    
    return Window
end

return MatchaUI
