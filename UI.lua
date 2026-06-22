--[[
    Merged UI: WaifuUI visuals + HomesickUI API
    Fully self‑contained – no syntax errors, all fixes applied.
--]]

-- ====================== CORE DRAWING ENGINE ======================
local DrawingNew = Drawing.new
local V2 = Vector2.new
local C3 = Color3.fromRGB
local C3N = Color3.new
local C3HEX = Color3.fromHex
local HSV = Color3.fromHSV

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin
local clock = os.clock
local remove = table.remove
local concat = table.concat

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function bool(value) return value == true end

local Players = game:GetService("Players")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local Fonts = (type(Drawing) == "table" and Drawing.Fonts) or {}
local FontSystem = Fonts.System or Fonts.UI or 0
local FontBold = Fonts.SystemBold or FontSystem
local FontUI = Fonts.UI or FontSystem
local FontMono = Fonts.Monospace or FontUI
local FontMinecraft = Fonts.Minecraft or FontSystem
local FontPixel = Fonts.Pixel or FontSystem
local FontFortnite = Fonts.Fortnite or FontSystem

local FontWidths = {}
FontWidths[FontSystem] = 0.52
FontWidths[FontBold] = 0.56
FontWidths[FontUI] = 0.48
FontWidths[FontMono] = 0.56
FontWidths[FontMinecraft] = 0.58
FontWidths[FontPixel] = 0.55
FontWidths[FontFortnite] = 0.54

local DRAW_VISIBLE = 1
local FRAME_WAIT = 1 / 240
local MENU_KEY = "f1"

local PAD = 10
local TITLE_H = 36
local TAB_H = 30
local ROW_H = 28
local CONTROL_H = 22
local SECTION_HEAD_H = 22
local CONTENT_PAD = 8
local DEFAULT_W = 430
local DEFAULT_H = 500
local MINIMIZED_H = 42
local TAB_MIN_W = 80

local SHADOW_ALPHA = {0.10, 0.07, 0.05, 0.03, 0.015}
local KEYBIND_MODES = {"Hold", "Toggle", "Always"}

local Theme = {
    bg = C3(16, 22, 18),
    surface = C3(24, 32, 26),
    surface2 = C3(34, 44, 36),
    surface3 = C3(44, 56, 46),
    text = C3(235, 245, 235),
    sub = C3(130, 160, 130),
    accent = C3(88, 196, 120),
    green = C3(52, 199, 89),
    red = C3(255, 69, 58),
    yellow = C3(255, 204, 0),
    unsafe = C3(255, 226, 84),
    border = C3(48, 62, 52),
    toggleOn = C3(88, 196, 120),
    toggleOff = C3(65, 85, 68),
    knob = C3(255, 255, 255),
    white = C3(255, 255, 255),
    black = C3(0, 0, 0),
}

local ProjectState = {
    alive = true,
    destroyed = false,
    rendering = false,
    open = true,
    x = 100, y = 80,
    w = DEFAULT_W, h = DEFAULT_H,
    defaultH = DEFAULT_H,
    minimized = false,
    title = "Merged UI",
    tabs = {},
    activeTab = nil,
    activeIndex = 0,
    drag = nil,
    sliderDrag = nil,
    scrollDrag = nil,
    focus = nil,
    dropdown = nil,
    colorpicker = nil,
    copiedColor = nil,
    activities = {},
    activityId = 0,
    mouseX = 0, mouseY = 0,
    hasMouse = false,
    focusedWindow = true,
    inputState = nil,
    tooltipText = nil,
    tooltipAt = 0,
    tooltipX = 0, tooltipY = 0,
    showWaifu = true,
    waifuDrawing = nil,
    lastFrame = clock(),
    lastErrorAt = 0,
    searchOpen = false,
    searchQuery = "",
    searchCacheQuery = nil,
    searchResults = nil,
    searchScrollY = 0,
    searchMaxScroll = 0,
    tabScrollX = 0,
    tabTargetScrollX = 0,
    tabScrollToActive = false,
    diagnosticsEnabled = false,
    watermarkEnabled = false,
    watermarkTitle = "",
    watermarkX = 20, watermarkY = 20,
    watermarkDrag = nil,
    activityText = "",
    errorCount = 0,
    windowControlsStyle = "Windows",
    customControls = {
        align = "right",
        closeColor = C3(255, 95, 87),
        minColor = C3(255, 189, 46),
        restoreColor = C3(39, 201, 63)
    },
    panels = {}
}

local Pool = { sq = {}, tx = {}, ln = {}, ci = {}, tr = {}, im = {} }
local PoolIndex = { sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0 }
local PoolHighWater = { sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0 }
local TypeMap = { sq = "Square", tx = "Text", ln = "Line", ci = "Circle", tr = "Triangle", im = "Image" }

local Input = {}
local InputOrder = {}

local function addInput(name, id, char, shifted)
    name = string.lower(tostring(name))
    if not Input[name] then InputOrder[#InputOrder + 1] = name end
    Input[name] = { id = id, held = false, click = false, released = false, char = char, shifted = shifted }
end

addInput("m1", 0x01)
addInput("m2", 0x02)
addInput("backspace", 0x08)
addInput("tab", 0x09)
addInput("enter", 0x0D)
addInput("shift", 0x10)
addInput("ctrl", 0x11)
addInput("alt", 0x12)
addInput("pause", 0x13)
addInput("capslock", 0x14)
addInput("esc", 0x1B)
addInput("space", 0x20, " ", " ")
addInput("pageup", 0x21)
addInput("pagedown", 0x22)
addInput("end", 0x23)
addInput("home", 0x24)
addInput("left", 0x25)
addInput("up", 0x26)
addInput("right", 0x27)
addInput("down", 0x28)
addInput("insert", 0x2D)
addInput("delete", 0x2E)

local shiftedDigits = {")", "!", "@", "#", "$", "%", "^", "&", "*", "("}
for i = 0, 9 do addInput(tostring(i), 0x30 + i, tostring(i), shiftedDigits[i + 1]) end
for i = 0, 25 do local ch = string.char(97 + i); addInput(ch, 0x41 + i, ch, string.upper(ch)) end
for i = 1, 12 do addInput("f" .. tostring(i), 0x6F + i) end
addInput("numpad0", 0x60, "0", "0")
addInput("numpad1", 0x61, "1", "1")
addInput("numpad2", 0x62, "2", "2")
addInput("numpad3", 0x63, "3", "3")
addInput("numpad4", 0x64, "4", "4")
addInput("numpad5", 0x65, "5", "5")
addInput("numpad6", 0x66, "6", "6")
addInput("numpad7", 0x67, "7", "7")
addInput("numpad8", 0x68, "8", "8")
addInput("numpad9", 0x69, "9", "9")
addInput("multiply", 0x6A, "*", "*")
addInput("add", 0x6B, "+", "+")
addInput("subtract", 0x6D, "-", "-")
addInput("decimal", 0x6E, ".", ".")
addInput("divide", 0x6F, "/", "/")
addInput("lshift", 0xA0)
addInput("rshift", 0xA1)
addInput("lctrl", 0xA2)
addInput("rctrl", 0xA3)
addInput("lalt", 0xA4)
addInput("ralt", 0xA5)
addInput("semicolon", 0xBA, ";", ":")
addInput("plus", 0xBB, "=", "+")
addInput("comma", 0xBC, ",", "<")
addInput("minus", 0xBD, "-", "_")
addInput("period", 0xBE, ".", ">")
addInput("slash", 0xBF, "/", "?")
addInput("tilde", 0xC0, "`", "~")
addInput("lbracket", 0xDB, "[", "{")
addInput("backslash", 0xDC, "\\", "|")
addInput("rbracket", 0xDD, "]", "}")
addInput("quote", 0xDE, "'", "\"")

local UI = {}
_G.UI = UI

local function viewportSize()
    local camera = Workspace.CurrentCamera
    if camera and camera.ViewportSize then return camera.ViewportSize.X, camera.ViewportSize.Y end
    return 1920, 1080
end

local function colorChanged(a, b)
    if not a or not b then return a ~= b end
    return abs(a.R - b.R) > 0.001 or abs(a.G - b.G) > 0.001 or abs(a.B - b.B) > 0.001
end

local function copyArray(source)
    local out = {}
    if type(source) == "table" then for i = 1, #source do out[i] = source[i] end
    elseif source ~= nil then out[1] = source end
    return out
end

local function normalizeKey(value)
    if value == nil then return nil end
    value = string.lower(tostring(value))
    if value == "" or value == "-" or value == "none" or value == "nil" or value == "unbound" then return nil end
    return value
end

local function normalizeMode(value)
    if value == "Toggle" or value == "Always" then return value end
    return "Hold"
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, result = pcall(callback, ...)
    if not ok then warn("Merged UI callback error: " .. tostring(result)) return end
    return result
end

local function applyInputState(force)
    local desired = not ProjectState.open
    if force or ProjectState.inputState ~= desired then
        ProjectState.inputState = desired
        setrobloxinput(desired)
    end
end

local function setOpen(open)
    open = bool(open)
    if ProjectState.open == open then return end
    ProjectState.open = open
    ProjectState.drag = nil
    ProjectState.sliderDrag = nil
    ProjectState.scrollDrag = nil
    ProjectState.dropdown = nil
    ProjectState.colorpicker = nil
    ProjectState.focus = nil
    applyInputState(false)
end

local function clampWindow()
    local vw, vh = viewportSize()
    ProjectState.x = clamp(ProjectState.x, 0, max(0, vw - min(80, ProjectState.w)))
    ProjectState.y = clamp(ProjectState.y, 0, max(0, vh - min(40, ProjectState.h)))
end

local function getMouse()
    if not Mouse then LocalPlayer = Players.LocalPlayer; Mouse = LocalPlayer and LocalPlayer:GetMouse() end
    if Mouse then
        ProjectState.mouseX = Mouse.X; ProjectState.mouseY = Mouse.Y
        ProjectState.hasMouse = true; return Mouse.X, Mouse.Y
    end
    ProjectState.hasMouse = false
    return nil, nil
end

local function over(x, y, w, h)
    return ProjectState.hasMouse and ProjectState.mouseX >= x and ProjectState.mouseX <= x + w and ProjectState.mouseY >= y and ProjectState.mouseY <= y + h
end

local function resetPool()
    for k, _ in pairs(PoolIndex) do PoolIndex[k] = 0 end
end

local function getDrawing(kind)
    if not ProjectState.alive or ProjectState.destroyed then return nil end
    PoolIndex[kind] = PoolIndex[kind] + 1
    local index = PoolIndex[kind]; local list = Pool[kind]
    local object = list[index]
    if not object then
        local ok, created = pcall(DrawingNew, TypeMap[kind])
        if not ok or not created then return nil end
        object = created; list[index] = object
    end
    if index > PoolHighWater[kind] then PoolHighWater[kind] = index end
    object.Visible = true
    return object
end

local function hideUnused()
    for kind, list in pairs(Pool) do
        local cur = PoolIndex[kind]; local high = PoolHighWater[kind]
        if cur < high then for i = cur + 1, high do list[i].Visible = false end end
        if cur > high then PoolHighWater[kind] = cur end
    end
end

local function hideAll()
    for kind, list in pairs(Pool) do for i = 1, #list do list[i].Visible = false end end
end

local function rect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then return end
    local d = getDrawing("sq"); if not d then return end
    d.Position = V2(x, y); d.Size = V2(w, h); d.Color = color; d.Filled = true
    d.Corner = radius or 0; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function strokeRect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then return end
    local d = getDrawing("sq"); if not d then return end
    d.Position = V2(x, y); d.Size = V2(w, h); d.Color = color; d.Filled = false
    d.Corner = radius or 0; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function textWidth(value, size, font)
    local multiplier = FontWidths[font] or 0.52
    return #tostring(value or "") * ((size or 13) * multiplier)
end

local function trimText(value, maxWidth, size, font)
    value = tostring(value or ""); if maxWidth <= 0 then return "" end
    local multiplier = FontWidths[font] or 0.52; local maxChars = floor(maxWidth / ((size or 13) * multiplier))
    if maxChars <= 0 then return "" end
    if #value <= maxChars then return value end
    if maxChars <= 2 then return "" end
    return string.sub(value, 1, maxChars - 2) .. ".."
end

local function txt(value, x, y, color, size, font, z, centered, outline, maxWidth, transparency)
    if value == nil or value == "" then return end
    if not color or type(color) ~= "userdata" then
        color = Theme.text
    end
    if maxWidth then
        value = trimText(value, maxWidth, size, font)
        if value == "" then return end
    else
        value = tostring(value)
    end
    local d = getDrawing("tx")
    if not d then return end
    d.Text = value
    d.Position = V2(x, y)
    d.Color = color
    d.Size = size or 13
    d.Font = font or FontSystem
    d.ZIndex = (z or 1) + 10
    d.Center = centered == true
    d.Outline = outline == true
    d.Transparency = transparency or DRAW_VISIBLE
end

local function centerY(y, h) return y + h / 2 end
local function textTop(y, h, size) return floor(y + (h - (size or 13)) / 2 + 0.5) end

local function line(x1, y1, x2, y2, color, z, thickness, transparency)
    local d = getDrawing("ln"); if not d then return end
    d.From = V2(x1, y1); d.To = V2(x2, y2); d.Color = color; d.Thickness = thickness or 1
    d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function circle(x, y, radius, color, z, filled, thickness, sides, transparency)
    local d = getDrawing("ci"); if not d then return end
    d.Position = V2(x, y); d.Radius = radius; d.Color = color; d.Filled = filled ~= false
    d.Thickness = thickness or 1; d.NumSides = sides or 32; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function triangle(a, b, c, color, z, filled, transparency)
    local d = getDrawing("tr"); if not d then return end
    d.PointA = a; d.PointB = b; d.PointC = c; d.Color = color; d.Filled = filled ~= false
    d.Thickness = 1; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function drawChevronDown(x, y, color, z)
    triangle(V2(x, y), V2(x + 8, y), V2(x + 4, y + 5), color, z, true)
end

local function snapValue(raw, item)
    local minVal = item.min or 0; local maxVal = item.max or 100; local step = item.step or 1
    if step <= 0 then step = 1 end
    local steps = floor(((raw - minVal) / step) + 0.5 + 0.0001)
    return clamp(minVal + steps * step, minVal, maxVal)
end

local function setDropdownValue(item, value, fire)
    local newValue = copyArray(value); local changed = #newValue ~= #item.value
    for i = 1, max(#item.value, #newValue) do if item.value[i] ~= newValue[i] then changed = true; break end end
    for i = #item.value, 1, -1 do item.value[i] = nil end
    for i = 1, #newValue do item.value[i] = newValue[i] end
    if changed and fire ~= false then safeCallback(item.callback, item.value) end
end

local function setItemValue(item, value, fire)
    if item.type == "dropdown" then setDropdownValue(item, value, fire); return end
    if item.type == "slider" then value = tonumber(value) or item.value or item.min or 0; value = snapValue(value, item)
    elseif item.type == "toggle" then value = value == true
    elseif item.type == "textbox" then value = tostring(value or "") end
    local changed = item.value ~= value; item.value = value
    if changed and fire ~= false then safeCallback(item.callback, value) end
end

local keybindItems = {}

local function makeItem(section, item)
    section.items[#section.items + 1] = item
    local handle = { item = item }
    item.handle = handle
    function handle:Set(value) setItemValue(item, value, true); return self end
    function handle:DependsOn(parentHandle) item.dependsOn = parentHandle; return self end
    if item.type == "toggle" then
        function handle:AddKeybind(defaultKey, mode, canChange, callback)
            local keybind = {
                value = normalizeKey(defaultKey), mode = normalizeMode(mode), canChange = canChange ~= false,
                callback = callback, listening = false, listenAt = 0,
            }
            item.keybind = keybind; keybindItems[#keybindItems + 1] = item
            local keyHandle = {}
            function keyHandle:Set(newKey, newMode)
                keybind.value = normalizeKey(newKey); if newMode then keybind.mode = normalizeMode(newMode) end
                safeCallback(keybind.callback, keybind.value and Input[keybind.value] and Input[keybind.value].id or nil, keybind.mode)
                return self
            end
            return keyHandle
        end
        function handle:AddColorpicker(label, defaultColor, overwrite, callback)
            local picker = {
                label = tostring(label or "Color"), value = defaultColor or Theme.accent,
                overwrite = overwrite == true, callback = callback,
            }
            item.colorpicker = picker
            local colorHandle = {}
            function colorHandle:Set(newColor)
                if newColor and colorChanged(picker.value, newColor) then picker.value = newColor; safeCallback(picker.callback, newColor) end
                return self
            end
            return colorHandle
        end
    elseif item.type == "dropdown" then
        function handle:UpdateChoices(newChoices) item.choices = copyArray(newChoices); return self end
    end
    function handle:AddTooltip(tooltip) item.tooltip = tooltip; return self end
    return handle
end

local function createSection(tab, name)
    local section = { name = tostring(name or "Section"), items = {}, collapsed = false }
    tab.sections[#tab.sections + 1] = section
    local sectionApi = {}
    function sectionApi:Label(label, color, tooltip)
        if type(color) == "string" and not tooltip then tooltip = color; color = nil end
        return makeItem(section, { type = "label", label = tostring(label or ""), color = color or Theme.text, tooltip = tooltip })
    end
    function sectionApi:Toggle(label, default, callback, unsafe, tooltip)
        return makeItem(section, { type = "toggle", label = tostring(label or "Toggle"), value = default == true, callback = callback, unsafe = unsafe == true, tooltip = tooltip })
    end
    function sectionApi:Slider(label, default, step, minValue, maxValue, suffix, callback, tooltip)
        local item = { type = "slider", label = tostring(label or "Slider"), value = tonumber(default) or 0, defaultValue = tonumber(default) or 0, step = tonumber(step) or 1, min = tonumber(minValue) or 0, max = tonumber(maxValue) or 100, suffix = suffix or "", callback = callback, tooltip = tooltip }
        item.value = snapValue(item.value, item)
        return makeItem(section, item)
    end
    function sectionApi:Dropdown(label, default, choices, multi, callback, tooltip)
        return makeItem(section, { type = "dropdown", label = tostring(label or "Dropdown"), value = copyArray(default), choices = copyArray(choices), multi = multi == true, callback = callback, tooltip = tooltip })
    end
    function sectionApi:Button(label, callback, tooltip)
        return makeItem(section, { type = "button", label = tostring(label or "Button"), callback = callback, tooltip = tooltip })
    end
    function sectionApi:Textbox(label, default, callback, tooltip)
        return makeItem(section, { type = "textbox", label = tostring(label or "Textbox"), value = tostring(default or ""), callback = callback, tooltip = tooltip })
    end
    function sectionApi:Divider(label)
        return makeItem(section, { type = "divider", label = label and tostring(label) or nil })
    end
    return sectionApi
end

local CustomPresets = {}

function UI:SetMenuKey(key)
    if type(key) == "number" or (type(key) == "string" and tonumber(key) ~= nil) then
        local vk = tonumber(key)
        for name, input in pairs(Input) do if input.id == vk then key = name; break end end
    end
    MENU_KEY = normalizeKey(key) or "f1"
    return self
end

function UI:SetTheme(overrides)
    if type(overrides) == "table" then for k, v in pairs(overrides) do if Theme[k] ~= nil then Theme[k] = v end end end
    return self
end

function UI:AddThemePreset(name, colors)
    if type(name) == "string" and type(colors) == "table" then CustomPresets[name] = colors end
    return self
end

function UI:IsOpen() return ProjectState.open == true end
function UI:SetOpen(bool) setOpen(bool == true); return self end
function UI:GetDrawing(kind) return getDrawing(kind) end
function UI:SetTitle(text) ProjectState.title = tostring(text or "Merged UI"); return self end
function UI:SetPos(x, y) ProjectState.x = tonumber(x) or ProjectState.x; ProjectState.y = tonumber(y) or ProjectState.y; clampWindow(); return self end
function UI:SetSize(w, h)
    ProjectState.w = max(300, tonumber(w) or ProjectState.w)
    ProjectState.h = max(120, tonumber(h) or ProjectState.h)
    if ProjectState.h > MINIMIZED_H then ProjectState.defaultH = ProjectState.h; ProjectState.minimized = false end
    clampWindow(); return self
end
function UI:Center()
    local vw, vh = viewportSize()
    ProjectState.x = floor(vw / 2 - ProjectState.w / 2); ProjectState.y = floor(vh / 2 - ProjectState.h / 2)
    clampWindow(); return self
end
function UI:SetControlsStyle(style, options)
    style = tostring(style or "Windows")
    if style == "macOS" or style == "Windows" or style == "Linux" or style == "Custom" then
        ProjectState.windowControlsStyle = style
    end
    if style == "Custom" and type(options) == "table" then
        ProjectState.customControls = ProjectState.customControls or {}
        for k, v in pairs(options) do ProjectState.customControls[k] = v end
    end
    return self
end
-- ====================== ADD RegisterActivity TO UI ======================
function UI:RegisterActivity(callback)
    ProjectState.activityId = ProjectState.activityId + 1
    local activity = {
        id = ProjectState.activityId,
        callback = callback,
        alive = true,
    }
    ProjectState.activities[#ProjectState.activities + 1] = activity
    return {
        Remove = function()
            activity.alive = false
        end,
    }
end

-- ====================== RENDERING FUNCTIONS ======================
local function lerpColor(c1, c2, t) return C3N(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t) end
local function smoothValue(current, target, speed)
    local dt = ProjectState.dt or 1/60; if dt <= 0 then dt = 1/60 end
    return current + (target - current) * (1 - math.exp(-(speed or 15) * dt))
end

local function rebuildSearchResults()
    local query = string.lower(ProjectState.searchQuery or "")
    if ProjectState.searchCacheQuery == query and ProjectState.searchResults then return ProjectState.searchResults end
    local results = {}
    if query ~= "" then
        for _, t in ipairs(ProjectState.tabs) do
            for _, s in ipairs(t.sections) do
                for _, item in ipairs(s.items) do
                    if item.type ~= "divider" and item.type ~= "label" and string.find(string.lower(item.label), query, 1, true) then
                        results[#results + 1] = item
                    end
                end
            end
        end
    end
    ProjectState.searchCacheQuery = query; ProjectState.searchResults = results
    return results
end

local PRESET_SWATCHES = { C3(0, 122, 255), C3(114, 178, 21), C3(255, 69, 58), C3(255, 204, 0), C3(255, 105, 180), C3(160, 32, 240), C3(255, 255, 255), C3(0, 0, 0) }

local toHsv
local function toHex(color)
    local r = floor(color.R * 255 + 0.5); local g = floor(color.G * 255 + 0.5); local b = floor(color.B * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

local function isItemDisabled(item)
    if not item then return false end
    local dep = item.dependsOn; if dep and dep.item then if not dep.item.value or isItemDisabled(dep.item) then return true end end
    return false
end

local function getFocusableItems()
    local list = {}
    if ProjectState.searchOpen then list[#list + 1] = "search" end
    if ProjectState.searchOpen and ProjectState.searchQuery ~= "" then
        local results = rebuildSearchResults()
        for i = 1, #results do
            local item = results[i]
            if (item.type == "textbox" or item.type == "slider") and not isItemDisabled(item) then
                list[#list + 1] = item
            end
        end
    elseif ProjectState.activeTab then
        for _, s in ipairs(ProjectState.activeTab.sections) do
            if not s.collapsed then
                for _, item in ipairs(s.items) do
                    if (item.type == "textbox" or item.type == "slider") and not isItemDisabled(item) then
                        list[#list + 1] = item
                    end
                end
            end
        end
    end
    return list
end

local function tooltip(text, x, y)
    if not text or text == "" then return end
    if ProjectState.tooltipText ~= text then ProjectState.tooltipAt = clock() end
    ProjectState.tooltipText = text; ProjectState.tooltipX = x; ProjectState.tooltipY = y
end

local function renderTooltip()
    local textValue = ProjectState.tooltipText
    if not textValue or clock() - ProjectState.tooltipAt < 0.35 then return end
    local width = min(260, textWidth(textValue, 12) + 16)
    local x = ProjectState.tooltipX + 12; local y = ProjectState.tooltipY + 18
    local vw, vh = viewportSize(); x = clamp(x, 8, max(8, vw - width - 8)); y = clamp(y, 8, max(8, vh - 32))
    rect(x, y, width, 28, Theme.black, 140, 6, 0.92); strokeRect(x, y, width, 28, Theme.border, 141, 6)
    txt(textValue, x + 8, textTop(y, 28, 12), Theme.text, 12, FontUI, 142, false, false, width - 16)
end

local function spawnDropdown(kind, x, y, w, choices, value, multi, callback, item, keybind)
    local vw, vh = viewportSize()
    local height = multi and min(#choices * 22 + 30, 234) or min(#choices * 22 + 6, 210)
    ProjectState.dropdown = {
        kind = kind, x = clamp(x, 8, max(8, vw - w - 8)), y = clamp(y, 8, max(8, vh - height - 8)),
        w = w, h = height, choices = choices, value = value, multi = multi == true, callback = callback, item = item, keybind = keybind, scrollOffset = 0
    }
    ProjectState.colorpicker = nil
end

local function renderDropdown(click)
    local dd = ProjectState.dropdown; if not dd then return click end
    local isMulti = dd.multi == true
    local headerH = isMulti and 24 or 0
    local maxRows = floor((dd.h - 6 - headerH) / 22)
    dd.scrollOffset = dd.scrollOffset or 0
    local isHoveredDropdown = over(dd.x - 4, dd.y - 4, dd.w + 8, dd.h + 8)
    if isHoveredDropdown then
        if Input.down.click then dd.scrollOffset = min(#dd.choices - maxRows, dd.scrollOffset + 1)
        elseif Input.up.click then dd.scrollOffset = max(0, dd.scrollOffset - 1)
        elseif Input.pagedown.click then dd.scrollOffset = min(#dd.choices - maxRows, dd.scrollOffset + maxRows)
        elseif Input.pageup.click then dd.scrollOffset = max(0, dd.scrollOffset - maxRows) end
    end
    dd.scrollOffset = clamp(dd.scrollOffset, 0, max(0, #dd.choices - maxRows))
    rect(dd.x - 1, dd.y - 1, dd.w + 2, dd.h + 2, Theme.border, 110, 6)
    rect(dd.x, dd.y, dd.w, dd.h, Theme.surface2, 111, 6)  -- fixed background
    if isMulti then
        local btnW = (dd.w - 12) / 2; local btnY = dd.y + 4; local btnH = 18
        local selectAllX = dd.x + 4; local clearAllX = dd.x + 8 + btnW
        local hoverSelectAll = over(selectAllX, btnY, btnW, btnH)
        local hoverClearAll = over(clearAllX, btnY, btnW, btnH)
        rect(selectAllX, btnY, btnW, btnH, hoverSelectAll and Theme.surface3 or Theme.surface2, 112, 4)
        strokeRect(selectAllX, btnY, btnW, btnH, hoverSelectAll and Theme.accent or Theme.border, 113, 4)
        txt("Select All", selectAllX + btnW / 2, centerY(btnY, btnH), Theme.text, 11, FontUI, 113, true)
        rect(clearAllX, btnY, btnW, btnH, hoverClearAll and Theme.surface3 or Theme.surface2, 112, 4)
        strokeRect(clearAllX, btnY, btnW, btnH, hoverClearAll and Theme.accent or Theme.border, 113, 4)
        txt("Clear All", clearAllX + btnW / 2, centerY(btnY, btnH), Theme.text, 11, FontUI, 113, true)
        line(dd.x + 4, dd.y + 25, dd.x + dd.w - 4, dd.y + 25, Theme.border, 113)
        if click then
            if hoverSelectAll then
                if dd.item then setDropdownValue(dd.item, dd.choices, true)
                else for vi = #dd.value, 1, -1 do dd.value[vi] = nil end; for i = 1, #dd.choices do dd.value[i] = dd.choices[i] end; safeCallback(dd.callback, dd.value) end
                click = false
            elseif hoverClearAll then
                if dd.item then setDropdownValue(dd.item, {}, true)
                else for vi = #dd.value, 1, -1 do dd.value[vi] = nil end; safeCallback(dd.callback, dd.value) end
                click = false
            end
        end
    end
    if dd.scrollOffset > 0 then triangle(V2(dd.x + dd.w - 14, dd.y + headerH + 8), V2(dd.x + dd.w - 6, dd.y + headerH + 8), V2(dd.x + dd.w - 10, dd.y + headerH + 4), Theme.sub, 115, true) end
    if dd.scrollOffset + maxRows < #dd.choices then triangle(V2(dd.x + dd.w - 14, dd.y + dd.h - 8), V2(dd.x + dd.w - 6, dd.y + dd.h - 8), V2(dd.x + dd.w - 10, dd.y + dd.h - 4), Theme.sub, 115, true) end
    for idx = 1, min(#dd.choices, maxRows) do
        local actualIndex = idx + dd.scrollOffset
        local choice = dd.choices[actualIndex]; if not choice then break end
        local rowY = dd.y + 3 + headerH + (idx - 1) * 22
        local selected = false
        if dd.kind == "keymode" then selected = dd.keybind and dd.keybind.mode == choice
        else for vi = 1, #dd.value do if dd.value[vi] == choice then selected = true; break end end end
        local hovered = over(dd.x, rowY, dd.w, 22)
        if hovered then rect(dd.x + 2, rowY, dd.w - 4, 22, Theme.surface3, 112, 3) end
        txt(tostring(choice), dd.x + 8, textTop(rowY, 22, 13), selected and Theme.accent or Theme.text, 13, FontUI, 113, false, false, dd.w - 24)
        if click and hovered then
            if dd.kind == "keymode" then dd.keybind.mode = choice; safeCallback(dd.keybind.callback, dd.keybind.value and Input[dd.keybind.value] and Input[dd.keybind.value].id or nil, dd.keybind.mode); ProjectState.dropdown = nil
            elseif dd.multi then
                if dd.item then
                    local newValue = copyArray(dd.value)
                    if selected then for vi = #newValue, 1, -1 do if newValue[vi] == choice then remove(newValue, vi) end end else newValue[#newValue + 1] = choice end
                    setDropdownValue(dd.item, newValue, true)
                else
                    if selected then for vi = #dd.value, 1, -1 do if dd.value[vi] == choice then remove(dd.value, vi) end end else dd.value[#dd.value + 1] = choice end
                    safeCallback(dd.callback, dd.value)
                end
            else
                if dd.item then setDropdownValue(dd.item, {choice}, true)
                else local changed = dd.value[1] ~= choice or #dd.value ~= 1; for vi = #dd.value, 1, -1 do dd.value[vi] = nil end; dd.value[1] = choice; if changed then safeCallback(dd.callback, dd.value) end end
                ProjectState.dropdown = nil
            end
            return false
        end
    end
    if click and not isHoveredDropdown then ProjectState.dropdown = nil; return false end
    return click
end

toHsv = function(color)
    local r, g, b = color and color.R or 1, color and color.G or 1, color and color.B or 1
    local high = max(r, g, b); local low = min(r, g, b); local delta = high - low
    local hue, saturation = 0, high > 0 and delta / high or 0
    if delta > 0 then
        if high == r then hue = ((g - b) / delta) % 6
        elseif high == g then hue = ((b - r) / delta) + 2
        else hue = ((r - g) / delta) + 4 end
        hue = hue / 6
    end
    return hue, saturation, high
end

local function spawnColorpicker(x, y, picker)
    local h, s, v = toHsv(picker.value)
    local vw, vh = viewportSize(); local w, height = 200, 220
    ProjectState.colorpicker = {
        x = clamp(x, 8, max(8, vw - w - 8)), y = clamp(y, 8, max(8, vh - height - 8)),
        w = w, h = height, picker = picker, hue = h, sat = s, val = v, value = picker.value, _hexInput = nil
    }
    ProjectState.dropdown = nil
end

local function renderColorpicker(click, held)
    local cp = ProjectState.colorpicker; if not cp then return click end
    local x, y, w, h = cp.x, cp.y, cp.w, cp.h
    rect(x, y, w, h, Theme.surface2, 110, 8)  -- fixed background
    strokeRect(x, y, w, h, Theme.border, 111, 8)
    txt(cp.picker.label, x + 10, y + 8, Theme.text, 13, FontBold, 112, false, false, w - 20)
    local palX, palY = x + 10, y + 28; local palW, palH = w - 20, 82; local cell = 18
    for gx = palX, palX + palW - 1, cell do
        local sx = clamp((gx - palX) / palW, 0, 1)
        for gy = palY, palY + palH - 1, cell do
            local sy = 1 - clamp((gy - palY) / palH, 0, 1)
            rect(gx, gy, cell, cell, HSV(cp.hue, sx, sy), 113, 0)
        end
    end
    if held and over(palX, palY, palW, palH) then
        cp.sat = clamp((ProjectState.mouseX - palX) / palW, 0, 1)
        cp.val = 1 - clamp((ProjectState.mouseY - palY) / palH, 0, 1)
    end
    local markerX = palX + cp.sat * palW; local markerY = palY + (1 - cp.val) * palH
    circle(markerX, markerY, 4, Theme.white, 116, false, 2, 20)
    local hueX, hueY = x + 10, y + 118; local hueW, hueH = w - 20, 10
    for gx = hueX, hueX + hueW - 1, 12 do rect(gx, hueY, 12, hueH, HSV((gx - hueX) / hueW, 1, 1), 113, 0) end
    if held and over(hueX, hueY, hueW, hueH) then cp.hue = clamp((ProjectState.mouseX - hueX) / hueW, 0, 1) end
    rect(hueX + cp.hue * hueW - 2, hueY - 1, 4, hueH + 2, Theme.white, 116, 1)
    local swY = y + 136; local swW = 14; local swSpacing = (w - 20 - (swW * #PRESET_SWATCHES)) / (#PRESET_SWATCHES - 1)
    for i = 1, #PRESET_SWATCHES do
        local swColor = PRESET_SWATCHES[i]; local swX = x + 10 + (i - 1) * (swW + swSpacing)
        local hovered = over(swX, swY, swW, swW)
        rect(swX, swY, swW, swW, swColor, 114, 2); strokeRect(swX, swY, swW, swW, hovered and Theme.accent or Theme.border, 115, 2)
        if click and hovered then
            local h_s, s_s, v_s = toHsv(swColor); cp.hue = h_s; cp.sat = s_s; cp.val = v_s; cp.value = swColor; click = false
        end
    end
    local hexY = y + 158; local hexW = w - 20; local hexH = 22
    local hexFocused = ProjectState.focus == cp; local hexHovered = over(x + 10, hexY, hexW, hexH)
    rect(x + 10, hexY, hexW, hexH, hexFocused and Theme.surface2 or hexHovered and Theme.surface3 or Theme.surface2, 114, 4)
    strokeRect(x + 10, hexY, hexW, hexH, hexFocused and Theme.accent or Theme.border, 115, 4)
    local hexText = hexFocused and (cp._hexInput or "") or ("#" .. toHex(cp.value))
    if hexFocused and floor(clock() * 2) % 2 == 0 then hexText = hexText .. "|" end
    txt(hexText, x + 16, textTop(hexY, hexH, 12), Theme.text, 12, FontUI, 116, false, false, hexW - 12)
    if click and hexHovered then ProjectState.focus = hexFocused and nil or cp; cp._hexInput = toHex(cp.value); click = false end
    local r = floor(cp.value.R * 255 + 0.5); local g = floor(cp.value.G * 255 + 0.5); local b = floor(cp.value.B * 255 + 0.5)
    local rgbText = string.format("R: %d  G: %d  B: %d", r, g, b)
    txt(rgbText, x + 10, y + 188, Theme.sub, 11, FontUI, 114, false, false, w - 20)
    rect(x + w - 30, y + 186, 20, 14, cp.value, 114, 3); strokeRect(x + w - 30, y + 186, 20, 14, Theme.border, 115, 3)
    local final = HSV(cp.hue, cp.sat, cp.val)
    if colorChanged(final, cp.value) then cp.value = final; cp.picker.value = final; safeCallback(cp.picker.callback, final) end
    if click and not over(x, y, w, h) then
        if ProjectState.focus == cp then ProjectState.focus = nil end
        ProjectState.colorpicker = nil; return false
    end
    return click
end

local function renderToggleExtras(item, rowX, rowY, rowW, click, rightClick)
    if item.keybind then
        local keybind = item.keybind
        local keyText = keybind.listening and "..." or (keybind.value and string.upper(keybind.value) or "-")
        local keyW = 46; local keyX = rowX + rowW - 96; local keyY = rowY + 3; local keyH = 20
        local hovered = over(keyX, keyY, keyW, keyH)
        rect(keyX, keyY, keyW, keyH, Theme.surface3, 45, 4); strokeRect(keyX, keyY, keyW, keyH, hovered and Theme.accent or Theme.border, 46, 4)
        txt(keyText, keyX + keyW / 2, centerY(keyY, keyH), keybind.value and Theme.text or Theme.sub, 12, FontUI, 52, true, false, keyW - 4)
        local modeTag = keybind.mode == "Toggle" and "T" or keybind.mode == "Always" and "A" or "H"
        local modeColor = keybind.mode == "Hold" and Theme.sub or Theme.accent
        txt(modeTag, rowX + rowW - 108, centerY(rowY, ROW_H - 2), modeColor, 10, FontUI, 52, true)
        if keybind.listening then
            for i = 1, #InputOrder do
                local name = InputOrder[i]; local input = Input[name]
                if input.click and (name ~= "m1" or clock() - keybind.listenAt > 0.25) then
                    local newKey = normalizeKey(name)
                    if name == "backspace" or name == "delete" or name == "unbound" then newKey = nil end
                    keybind.value = newKey; keybind.listening = false
                    safeCallback(keybind.callback, newKey and Input[newKey] and Input[newKey].id or nil, keybind.mode)
                    break
                end
            end
        elseif click and hovered then keybind.listening = true; keybind.listenAt = clock(); click = false
        elseif rightClick and hovered and keybind.canChange then spawnDropdown("keymode", keyX, rowY + 24, 90, KEYBIND_MODES, nil, false, nil, nil, keybind); rightClick = false end
    end
    if item.colorpicker then
        local picker = item.colorpicker; local cpX = rowX + rowW - 124; local cpW = 12; local cpH = 12; local cpY = rowY + 8
        local hovered = over(cpX - 3, cpY - 3, cpW + 6, cpH + 6)
        rect(cpX, cpY, cpW, cpH, picker.value, 46, 3); strokeRect(cpX, cpY, cpW, cpH, Theme.border, 47, 3)
        if hovered then strokeRect(cpX - 2, cpY - 2, cpW + 4, cpH + 4, Theme.accent, 48, 4) end
        if click and hovered then spawnColorpicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, picker); click = false
        elseif rightClick and hovered then
            spawnDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                local selected = choice and choice[1]
                if selected == "Copy" then ProjectState.copiedColor = picker.value; pcall(setclipboard, "#" .. toHex(picker.value))
                elseif selected == "Paste" and ProjectState.copiedColor and colorChanged(picker.value, ProjectState.copiedColor) then
                    picker.value = ProjectState.copiedColor; safeCallback(picker.callback, picker.value)
                end
            end, nil, nil)
            rightClick = false
        end
    end
    return click, rightClick
end

local function renderSections(tab, click, held, rightClick, px, contY, pw, contH)
    if not tab then return click, held, rightClick end
    local sectionsToRender = tab.sections
    if ProjectState.searchOpen and ProjectState.searchQuery ~= "" then
        local results = rebuildSearchResults()
        sectionsToRender = {{ name = "Search Results (" .. #results .. ")", items = results, collapsed = false }}
    end
    local contentH = CONTENT_PAD
    for _, s in ipairs(sectionsToRender) do
        local h = SECTION_HEAD_H + CONTENT_PAD
        if not s.collapsed then h = h + #s.items * ROW_H end
        contentH = contentH + h
    end
    local viewH = max(1, contH - CONTENT_PAD * 2)
    tab.maxScroll = max(0, contentH - viewH)
    tab.scrollY = tab.scrollY or 0; tab.targetScrollY = clamp(tab.targetScrollY or tab.scrollY, 0, tab.maxScroll)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
    if tab.maxScroll > 0 and not popupBlocking and not ProjectState.focus then
        if Input.up.held then tab.targetScrollY = max(0, tab.targetScrollY - 12) end
        if Input.down.held then tab.targetScrollY = min(tab.maxScroll, tab.targetScrollY + 12) end
        if Input.pageup.click then tab.targetScrollY = max(0, tab.targetScrollY - viewH) end
        if Input.pagedown.click then tab.targetScrollY = min(tab.maxScroll, tab.targetScrollY + viewH) end
        if Input.home.click then tab.targetScrollY = 0 end
        if Input["end"].click then tab.targetScrollY = tab.maxScroll end
    end
    local dt = ProjectState.dt or 1/60; if dt <= 0 then dt = 1/60 end
    local factor = 1 - math.exp(-15 * dt)
    tab.scrollY = tab.scrollY + (tab.targetScrollY - tab.scrollY) * factor
    tab.scrollY = clamp(tab.scrollY, 0, tab.maxScroll)
    local sy = contY + CONTENT_PAD - tab.scrollY
    local clipTop = contY + 4; local clipBottom = contY + contH - 4
    local rowX = px + 12; local rowW = pw - 24
    for _, section in ipairs(sectionsToRender) do
        local sectionH = SECTION_HEAD_H + CONTENT_PAD
        if not section.collapsed then sectionH = sectionH + #section.items * ROW_H end
        if sy + sectionH >= clipTop and sy <= clipBottom then
            if sy >= clipTop and sy + SECTION_HEAD_H <= clipBottom then
                local chevronX = rowX; local textX = rowX + 16
                local headerMidY = centerY(sy, SECTION_HEAD_H)
                if section.collapsed then triangle(V2(chevronX, headerMidY - 4), V2(chevronX, headerMidY + 4), V2(chevronX + 6, headerMidY), Theme.sub, 35, true)
                else triangle(V2(chevronX, headerMidY - 3), V2(chevronX + 8, headerMidY - 3), V2(chevronX + 4, headerMidY + 2), Theme.sub, 35, true) end
                txt(string.upper(section.name), textX, textTop(sy, SECTION_HEAD_H, 12), Theme.sub, 12, FontBold, 35, false, false, rowW - 16)
                local headerHovered = over(rowX, sy, rowW, SECTION_HEAD_H)
                if click and headerHovered and not popupBlocking then section.collapsed = not section.collapsed; click = false end
            end
            if not section.collapsed then
                local rowY = sy + SECTION_HEAD_H
                for _, item in ipairs(section.items) do
                    if rowY >= clipTop and rowY + ROW_H <= clipBottom then
                        local disabled = isItemDisabled(item); local trans = disabled and 0.4 or nil
                        local hoveredRow = over(rowX, rowY, rowW, ROW_H - 2)
                        if hoveredRow and item.type ~= "divider" then
                            rect(rowX - 3, rowY, rowW + 6, ROW_H - 2, Theme.surface3, 36, 5, trans)
                            if item.tooltip and not disabled then tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY) end
                        end
                        if item.type == "label" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 13), item.color or Theme.text, 13, FontSystem, 42, false, false, rowW, trans)
                        elseif item.type == "toggle" then
                            local labelColor = item.value and Theme.text or Theme.sub
                            if item.unsafe then labelColor = Theme.unsafe elseif item.colorpicker and item.colorpicker.overwrite then labelColor = item.colorpicker.value end
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), labelColor, 14, FontSystem, 42, false, false, rowW - 160, trans)
                            if item.animT == nil then item.animT = item.value and 1 or 0 end
                            local targetT = item.value and 1 or 0
                            if item.animT ~= targetT then item.animT = smoothValue(item.animT, targetT, 24); if abs(item.animT - targetT) < 0.001 then item.animT = targetT end end
                            click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick)
                            local tx, ty = rowX + rowW - 42, rowY + 6
                            local hovered = over(tx - 4, ty - 5, 38, 24)
                            local toggleBg = lerpColor(Theme.toggleOff, Theme.toggleOn, item.animT)
                            rect(tx, ty, 30, 16, toggleBg, 42, 8, trans)
                            local knobX = tx + 6 + 18 * item.animT
                            circle(knobX, ty + 8, 6, Theme.knob, 44, true, 0, 32, trans)
                            if click and hovered and not popupBlocking and not disabled then setItemValue(item, not item.value, true); click = false end
                        elseif item.type == "slider" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local focused = ProjectState.focus == item; local bx, bw = rowX + rowW - 150, 130
                            if focused then
                                local controlY = rowY + 3
                                rect(bx, controlY, bw, CONTROL_H, Theme.surface2, 42, 4, trans); strokeRect(bx, controlY, bw, CONTROL_H, Theme.accent, 43, 4, trans)
                                local shown = tostring(item._directValue or "")
                                if floor(clock() * 2) % 2 == 0 then shown = shown .. "|" end
                                txt(shown, bx + 6, textTop(controlY, CONTROL_H, 13), Theme.text, 13, FontUI, 44, false, false, bw - 12, trans)
                            else
                                local sx, sw = rowX + rowW - 150, 104
                                local denom = max(0.0001, (item.max or 100) - (item.min or 0))
                                local frac = clamp(((item.value or 0) - (item.min or 0)) / denom, 0, 1)
                                local hot = over(sx - 6, rowY + 4, sw + 12, 22)
                                local active = (hot or ProjectState.sliderDrag == item) and not popupBlocking and not disabled
                                if item.knobAnim == nil then item.knobAnim = active and 1 or 0 end
                                local targetKnob = active and 1 or 0
                                if item.knobAnim ~= targetKnob then item.knobAnim = smoothValue(item.knobAnim, targetKnob, 18); if abs(item.knobAnim - targetKnob) < 0.001 then item.knobAnim = targetKnob end end
                                local knobRadius = 5 + 2 * item.knobAnim
                                local knobColor = lerpColor(Theme.text, Theme.accent, item.knobAnim)
                                rect(sx, rowY + 12, sw, 4, Theme.surface3, 42, 2, trans)
                                if frac > 0 then rect(sx, rowY + 12, sw * frac, 4, Theme.accent, 43, 2, trans) end
                                circle(sx + sw * frac, rowY + 14, knobRadius, knobColor, 44, true, 0, 32, trans)
                                txt(tostring(item.value) .. tostring(item.suffix or ""), sx + sw + 8, textTop(rowY, ROW_H - 2, 13), Theme.text, 13, FontSystem, 44, false, false, 42, trans)
                                if click and hot and not popupBlocking and not disabled then ProjectState.sliderDrag = item; click = false end
                                if held and not popupBlocking and not disabled and (ProjectState.sliderDrag == item or hot) then
                                    ProjectState.sliderDrag = item
                                    local raw = (item.min or 0) + denom * clamp((ProjectState.mouseX - sx) / sw, 0, 1)
                                    local snapped = snapValue(raw, item)
                                    if snapped ~= item.value then item.value = snapped; safeCallback(item.callback, snapped) end
                                end
                            end
                            local sliderAreaHovered = over(rowX + rowW - 160, rowY + 2, 150, ROW_H - 4)
                            if rightClick and sliderAreaHovered and not popupBlocking and not disabled then
                                if Input.shift.held or Input.lshift.held or Input.rshift.held then setItemValue(item, item.defaultValue or item.min or 0, true)
                                else ProjectState.focus = item; item._directValue = tostring(item.value) end
                                rightClick = false
                            end
                        elseif item.type == "dropdown" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local dx, dw = rowX + rowW - 150, 130; local controlY = rowY + 3
                            local hovered = over(dx, controlY, dw, CONTROL_H)
                            rect(dx, controlY, dw, CONTROL_H, hovered and Theme.surface3 or Theme.surface2, 42, 4, trans)
                            strokeRect(dx, controlY, dw, CONTROL_H, Theme.border, 43, 4, trans)
                            local display = item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-")
                            txt(display, dx + 6, textTop(controlY, CONTROL_H, 13), Theme.text, 13, FontUI, 44, false, false, dw - 24, trans)
                            drawChevronDown(dx + dw - 15, centerY(controlY, CONTROL_H) - 2, Theme.sub, 45)
                            if click and hovered and not popupBlocking and not disabled then spawnDropdown("item", dx, rowY + 28, dw, item.choices, item.value, item.multi, item.callback, item, nil); click = false end
                        elseif item.type == "button" then
                            local controlY = rowY + 2; local hovered = over(rowX, controlY, rowW, CONTROL_H)
                            rect(rowX, controlY, rowW, CONTROL_H, hovered and Theme.accent or Theme.surface2, 42, 6, trans)
                            strokeRect(rowX, controlY, rowW, CONTROL_H, hovered and Theme.accent or Theme.border, 43, 6, trans)
                            txt(item.label, rowX + rowW / 2, centerY(controlY, CONTROL_H), Theme.text, 14, FontSystem, 44, true, false, rowW - 16, trans)
                            if click and hovered and not popupBlocking and not disabled then safeCallback(item.callback); click = false end
                        elseif item.type == "textbox" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local bx, bw = rowX + rowW - 150, 130; local focused = ProjectState.focus == item
                            local controlY = rowY + 3; local hovered = over(bx, controlY, bw, CONTROL_H)
                            rect(bx, controlY, bw, CONTROL_H, focused and Theme.surface2 or hovered and Theme.surface3 or Theme.surface2, 42, 4, trans)
                            strokeRect(bx, controlY, bw, CONTROL_H, focused and Theme.accent or Theme.border, 43, 4, trans)
                            local shown = item.value ~= "" and item.value or item.label
                            if focused and floor(clock() * 2) % 2 == 0 then shown = tostring(item.value or "") .. "|" end
                            txt(shown, bx + 6, textTop(controlY, CONTROL_H, 13), (item.value ~= "" or focused) and Theme.text or Theme.sub, 13, FontUI, 44, false, false, bw - 12, trans)
                            if click and hovered and not popupBlocking and not disabled then ProjectState.focus = focused and nil or item; click = false end
                        elseif item.type == "divider" then
                            if item.label and item.label ~= "" then
                                local textVal = item.label; local textW = textWidth(textVal, 11, FontSystem)
                                local lineW = max(4, (rowW - textW - 16) / 2)
                                local lineY = centerY(rowY, ROW_H)
                                rect(rowX, lineY, lineW, 1, Theme.border, 42, 1)
                                txt(textVal, rowX + lineW + 8, textTop(rowY, ROW_H, 11), Theme.sub, 11, FontSystem, 43, false, false, textW + 4)
                                rect(rowX + lineW + textW + 16, lineY, lineW, 1, Theme.border, 42, 1)
                            else
                                rect(rowX, centerY(rowY, ROW_H), rowW, 1, Theme.border, 42, 1)
                            end
                        end
                    end
                    rowY = rowY + ROW_H
                end
            end
        end
        sy = sy + sectionH
    end
    if tab.maxScroll > 0 then
        local trackH = contH - CONTENT_PAD * 2
        local barH = max(22, (trackH / max(contentH, trackH)) * trackH)
        local barY = contY + CONTENT_PAD + (tab.scrollY / max(1, tab.maxScroll)) * (trackH - barH)
        local trackHovered = over(px + pw - 11, contY + CONTENT_PAD, 12, trackH)
        local overBar = over(px + pw - 11, barY, 12, barH)
        rect(px + pw - 6, contY + CONTENT_PAD, 3, trackH, Theme.surface3, 50, 2)
        rect(px + pw - 6, barY, 3, barH, Theme.sub, 51, 2)
        if click and trackHovered and not popupBlocking then
            local grab = barH / 2; if overBar then grab = clamp(ProjectState.mouseY - barY, 0, barH) end
            ProjectState.scrollDrag = { tab = tab, grab = grab }; click = false
        end
        local drag = ProjectState.scrollDrag
        if held and type(drag) == "table" and drag.tab == tab then
            local frac = clamp((ProjectState.mouseY - (contY + CONTENT_PAD) - drag.grab) / max(1, trackH - barH), 0, 1)
            tab.targetScrollY = frac * tab.maxScroll
        end
    elseif type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.tab == tab then
        ProjectState.scrollDrag = nil
    end
    return click, held, rightClick
end

local function renderTabs(click, px, py, pw)
    local count = #ProjectState.tabs; if count == 0 then return click end
    rect(px, py, pw, TAB_H, Theme.surface2, 20, 7)
    local totalW = count * TAB_MIN_W; local needsScroll = totalW > pw
    local tabW = needsScroll and TAB_MIN_W or (pw / count)
    local maxScroll = max(0, totalW - pw)
    local dt = ProjectState.dt or 1/60; if dt <= 0 then dt = 1/60 end
    local target = clamp(ProjectState.tabTargetScrollX or 0, 0, maxScroll)
    ProjectState.tabTargetScrollX = target
    local current = ProjectState.tabScrollX or 0
    local factor = 1 - math.exp(-18 * dt)
    current = current + (target - current) * factor
    current = clamp(current, 0, maxScroll)
    ProjectState.tabScrollX = current
    local scrollX = current
    local contentX = px + (needsScroll and 18 or 0)
    local contentW = pw - (needsScroll and 36 or 0)
    if needsScroll and scrollX > 1 then
        local arrowHovered = over(px, py, 18, TAB_H)
        rect(px, py, 18, TAB_H, arrowHovered and Theme.surface3 or Theme.surface2, 26, 0)
        local cy = centerY(py, TAB_H)
        triangle(V2(px + 6, cy), V2(px + 12, cy - 4), V2(px + 12, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then ProjectState.tabTargetScrollX = max(0, target - TAB_MIN_W); click = false end
    end
    if needsScroll and scrollX < maxScroll - 1 then
        local ax = px + pw - 18
        local arrowHovered = over(ax, py, 18, TAB_H)
        rect(ax, py, 18, TAB_H, arrowHovered and Theme.surface3 or Theme.surface2, 26, 0)
        local cy = centerY(py, TAB_H)
        triangle(V2(ax + 12, cy), V2(ax + 6, cy - 4), V2(ax + 6, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then ProjectState.tabTargetScrollX = min(maxScroll, target + TAB_MIN_W); click = false end
    end
    if needsScroll and ProjectState.tabScrollToActive and ProjectState.activeTab then
        local idx = ProjectState.activeIndex or 1
        local tabStart = tabW * (idx - 1); local tabEnd = tabStart + tabW
        local visibleStart = scrollX; local visibleEnd = scrollX + contentW
        if tabStart < visibleStart then ProjectState.tabTargetScrollX = tabStart
        elseif tabEnd > visibleEnd then ProjectState.tabTargetScrollX = tabEnd - contentW end
        ProjectState.tabScrollToActive = false
    end
    for i = 1, count do
        local tab = ProjectState.tabs[i]
        local tx = contentX + tabW * (i - 1) - scrollX
        local visible = tx + tabW >= contentX and tx <= contentX + contentW
        if visible then
            local active = ProjectState.activeTab == tab
            if active then
                rect(tx + 3, py + 3, tabW - 6, TAB_H - 6, Theme.accent, 22, 6)
                txt(tab.name, tx + tabW / 2, centerY(py, TAB_H), Theme.white, 13, FontBold, 25, true, false, tabW - 12)
            else
                local hovered = over(tx, py, tabW, TAB_H)
                if hovered then rect(tx + 3, py + 3, tabW - 6, TAB_H - 6, Theme.surface3, 21, 6) end
                txt(tab.name, tx + tabW / 2, centerY(py, TAB_H), hovered and Theme.text or Theme.sub, 13, FontSystem, 25, true, false, tabW - 12)
                if click and hovered then
                    ProjectState.activeTab = tab; ProjectState.activeIndex = i
                    ProjectState.dropdown = nil; ProjectState.colorpicker = nil; ProjectState.focus = nil
                    click = false; ProjectState.tabScrollToActive = true
                end
            end
        end
        if i < count then
            local sepX = contentX + tabW * i - scrollX
            if sepX >= contentX and sepX <= contentX + contentW then line(sepX, py + 5, sepX, py + TAB_H - 5, Theme.border, 23) end
        end
    end
    return click
end

local function renderWindow(click, held, rightClick)
    if not ProjectState.activeTab then return click, held, rightClick end
    local x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    local popupOpen = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
    local baseClick = popupOpen and false or click
    local baseHeld = popupOpen and false or held
    local baseRightClick = popupOpen and false or rightClick

    for i = 1, #SHADOW_ALPHA do
        local offset = i * 2
        rect(x - offset, y - offset + 6, w + offset * 2, h + offset * 2, Theme.black, 0, 12, SHADOW_ALPHA[i])
    end
    rect(x, y, w, h, Theme.surface, 5, 12); strokeRect(x, y, w, h, Theme.border, 6, 12)
    rect(x + 2, y + 2, w - 4, TITLE_H - 2, Theme.surface2, 7, 10)
    line(x + 2, y + TITLE_H, x + w - 2, y + TITLE_H, Theme.border, 8)

    local titleMidY = centerY(y, TITLE_H)
    local style = ProjectState.windowControlsStyle or "Windows"
    local searchLensX
    if style == "macOS" or (style == "Custom" and (ProjectState.customControls and ProjectState.customControls.align == "left")) then searchLensX = x + w - 30
    elseif style == "Windows" then searchLensX = x + w - 124
    elseif style == "Linux" or (style == "Custom" and (ProjectState.customControls and ProjectState.customControls.align ~= "left")) then searchLensX = x + w - 106 end

    local closeHot, minHot, restoreHot
    local searchHot = over(searchLensX - 12, titleMidY - 12, 24, 24)
    local resizeHovered = not ProjectState.minimized and over(x + w - 16, y + h - 16, 16, 16)

    if style == "macOS" then
        closeHot = over(x + 14, titleMidY - 6, 12, 12); minHot = over(x + 32, titleMidY - 6, 12, 12); restoreHot = over(x + 50, titleMidY - 6, 12, 12)
    elseif style == "Windows" then
        closeHot = over(x + w - 30, y + 2, 28, TITLE_H - 4); restoreHot = over(x + w - 60, y + 2, 28, TITLE_H - 4); minHot = over(x + w - 90, y + 2, 28, TITLE_H - 4)
    elseif style == "Linux" then
        closeHot = over(x + w - 26, titleMidY - 6, 12, 12); restoreHot = over(x + w - 50, titleMidY - 6, 12, 12); minHot = over(x + w - 74, titleMidY - 6, 12, 12)
    elseif style == "Custom" then
        local custom = ProjectState.customControls or {}
        if custom.align == "left" then
            closeHot = over(x + 14, titleMidY - 6, 12, 12); minHot = over(x + 32, titleMidY - 6, 12, 12); restoreHot = over(x + 50, titleMidY - 6, 12, 12)
        else
            closeHot = over(x + w - 26, titleMidY - 6, 12, 12); restoreHot = over(x + w - 50, titleMidY - 6, 12, 12); minHot = over(x + w - 74, titleMidY - 6, 12, 12)
        end
    end

    -- draw window controls
    if style == "macOS" then
        circle(x + 20, titleMidY, 6, closeHot and C3(255, 120, 112) or C3(255, 95, 87), 15, true)
        circle(x + 38, titleMidY, 6, minHot and C3(255, 210, 50) or C3(255, 189, 46), 15, true)
        circle(x + 56, titleMidY, 6, restoreHot and C3(70, 225, 110) or C3(39, 201, 63), 15, true)
    elseif style == "Windows" then
        local by = y + 2; local bh = TITLE_H - 4
        rect(x + w - 30, by, 28, bh, closeHot and C3(232, 17, 35) or Theme.surface2, 14, 4)
        rect(x + w - 60, by, 28, bh, restoreHot and Theme.surface3 or Theme.surface2, 14, 4)
        rect(x + w - 90, by, 28, bh, minHot and Theme.surface3 or Theme.surface2, 14, 4)
        local cx = x + w - 30 + 14; local cy = titleMidY
        line(cx - 4, cy - 4, cx + 4, cy + 4, closeHot and Theme.white or Theme.text, 15, 1.5)
        line(cx + 4, cy - 4, cx - 4, cy + 4, closeHot and Theme.white or Theme.text, 15, 1.5)
        local rx = x + w - 60 + 14; local ry = titleMidY
        strokeRect(rx - 4, ry - 4, 8, 8, restoreHot and Theme.accent or Theme.text, 15)
        local mx = x + w - 90 + 14; local my = titleMidY
        line(mx - 5, my + 3, mx + 5, my + 3, minHot and Theme.accent or Theme.text, 15, 1.5)
    elseif style == "Linux" then
        local circleRad = 6
        circle(x + w - 20, titleMidY, circleRad, closeHot and Theme.red or Theme.sub, 15, false, 1.5, 20)
        circle(x + w - 44, titleMidY, circleRad, restoreHot and Theme.green or Theme.sub, 15, false, 1.5, 20)
        circle(x + w - 68, titleMidY, circleRad, minHot and Theme.accent or Theme.sub, 15, false, 1.5, 20)
        line(x + w - 22, titleMidY - 2, x + w - 18, titleMidY + 2, closeHot and Theme.white or Theme.sub, 16, 1)
        line(x + w - 18, titleMidY - 2, x + w - 22, titleMidY + 2, closeHot and Theme.white or Theme.sub, 16, 1)
        strokeRect(x + w - 47, titleMidY - 3, 6, 6, restoreHot and Theme.accent or Theme.sub, 16)
        line(x + w - 71, titleMidY, x + w - 65, titleMidY, minHot and Theme.accent or Theme.sub, 16, 1)
    elseif style == "Custom" then
        local custom = ProjectState.customControls or {}
        local align = custom.align or "right"
        local cClose = custom.closeColor or C3(255, 95, 87); local cMin = custom.minColor or C3(255, 189, 46); local cRestore = custom.restoreColor or C3(39, 201, 63)
        local xClose, xMin, xRestore
        if align == "left" then xClose, xMin, xRestore = x + 20, x + 38, x + 56 else xClose, xMin, xRestore = x + w - 20, x + w - 68, x + w - 44 end
        circle(xClose, titleMidY, 6, closeHot and lerpColor(cClose, Theme.white, 0.3) or cClose, 15, true)
        circle(xMin, titleMidY, 6, minHot and lerpColor(cMin, Theme.white, 0.3) or cMin, 15, true)
        circle(xRestore, titleMidY, 6, restoreHot and lerpColor(cRestore, Theme.white, 0.3) or cRestore, 15, true)
    end

    if baseClick then
        if closeHot then setOpen(false); baseClick = false
        elseif minHot then ProjectState.minimized = true; ProjectState.h = MINIMIZED_H; clampWindow(); baseClick = false
        elseif restoreHot then ProjectState.minimized = false; ProjectState.h = ProjectState.defaultH; clampWindow(); baseClick = false
        elseif searchHot then
            ProjectState.searchOpen = not ProjectState.searchOpen
            ProjectState.focus = ProjectState.searchOpen and "search" or nil
            if not ProjectState.searchOpen then ProjectState.searchQuery = ""; ProjectState.searchCacheQuery = nil; ProjectState.searchResults = nil end
            baseClick = false
        elseif resizeHovered then ProjectState.resizeDrag = {ProjectState.mouseX - w, ProjectState.mouseY - h}; baseClick = false
        elseif over(x, y, w, TITLE_H) then
            local textboxArea = ProjectState.searchOpen and over(x + 70, y + 8, w - 114, CONTROL_H)
            if not textboxArea then ProjectState.drag = {ProjectState.mouseX - x, ProjectState.mouseY - y}; baseClick = false end
        end
    end

    if baseHeld and ProjectState.drag then
        ProjectState.x = ProjectState.mouseX - ProjectState.drag[1]; ProjectState.y = ProjectState.mouseY - ProjectState.drag[2]; clampWindow()
        x, y = ProjectState.x, ProjectState.y
    elseif not held then ProjectState.drag = nil end

    if held and ProjectState.resizeDrag then
        local newW = clamp(ProjectState.mouseX - ProjectState.resizeDrag[1], 300, 1000)
        local newH = clamp(ProjectState.mouseY - ProjectState.resizeDrag[2], 120, 800)
        ProjectState.w = newW; ProjectState.h = newH
        if not ProjectState.minimized then ProjectState.defaultH = newH end
        clampWindow(); w, h = ProjectState.w, ProjectState.h
    elseif not held then ProjectState.resizeDrag = nil end

    if ProjectState.searchOpen then
        local tbX, tbW = x + 70, w - 114; local tbY = y + 8
        local focused = ProjectState.focus == "search"; local hovered = over(tbX, tbY, tbW, CONTROL_H)
        rect(tbX, tbY, tbW, CONTROL_H, focused and Theme.surface2 or hovered and Theme.surface3 or Theme.surface2, 15, 4)
        strokeRect(tbX, tbY, tbW, CONTROL_H, focused and Theme.accent or Theme.border, 16, 4)
        local shown = ProjectState.searchQuery or ""
        if focused and floor(clock() * 2) % 2 == 0 then shown = shown .. "|" end
        if ProjectState.searchQuery == "" and not focused then txt("Search...", tbX + 6, textTop(tbY, CONTROL_H, 13), Theme.sub, 13, FontUI, 17, false, false, tbW - 12)
        else txt(shown, tbX + 6, textTop(tbY, CONTROL_H, 13), Theme.text, 13, FontUI, 17, false, false, tbW - 12) end
        if baseClick and hovered then ProjectState.focus = "search"; baseClick = false end
    else
        local titleX = 14
        if style == "macOS" or (style == "Custom" and (ProjectState.customControls and ProjectState.customControls.align == "left")) then titleX = 70 end
        local titleMaxW = searchLensX - (x + titleX) - 10
        txt(ProjectState.title, x + titleX, textTop(y, TITLE_H, 14), Theme.text, 14, FontBold, 16, false, false, titleMaxW)
    end

    if not ProjectState.minimized and h > MINIMIZED_H then
        line(x + w - 12, y + h - 4, x + w - 4, y + h - 12, Theme.sub, 60, 1.5)
        line(x + w - 8, y + h - 4, x + w - 4, y + h - 8, Theme.sub, 60, 1.5)
        line(x + w - 16, y + h - 4, x + w - 4, y + h - 16, Theme.sub, 60, 1.5)
    end

    if ProjectState.minimized or h <= MINIMIZED_H then return click, held, rightClick end

    local px, py = x + PAD, y + TITLE_H + PAD
    local pw, ph = w - PAD * 2, h - TITLE_H - PAD * 2
    if pw <= 40 or ph <= 40 then return click, held, rightClick end

    baseClick = renderTabs(baseClick, px, py, pw)
    local contY = py + TAB_H + 8; local contH = ph - TAB_H - 8
    rect(px, contY, pw, contH, Theme.surface2, 20, 8); strokeRect(px, contY, pw, contH, Theme.border, 21, 8)

    -- Left/Right column support
    local hasRight = false
    if ProjectState.activeTab then for _, s in ipairs(ProjectState.activeTab.sections) do if s.side == "Right" then hasRight = true; break end end end
    if hasRight then
        local halfW = floor(pw / 2) - 4
        local leftSections, rightSections = {}, {}
        for _, s in ipairs(ProjectState.activeTab.sections) do
            if s.side == "Right" then table.insert(rightSections, s) else table.insert(leftSections, s) end
        end
        local leftTab = { sections = leftSections, scrollY = ProjectState.activeTab.scrollY, targetScrollY = ProjectState.activeTab.targetScrollY, maxScroll = ProjectState.activeTab.maxScroll }
        local rightTab = { sections = rightSections, scrollY = ProjectState.activeTab.scrollY, targetScrollY = ProjectState.activeTab.targetScrollY, maxScroll = ProjectState.activeTab.maxScroll }
        baseClick, baseHeld, baseRightClick = renderSections(leftTab, baseClick, baseHeld, baseRightClick, px, contY, halfW, contH)
        baseClick, baseHeld, baseRightClick = renderSections(rightTab, baseClick, baseHeld, baseRightClick, px + halfW + 8, contY, halfW, contH)
    else
        baseClick, baseHeld, baseRightClick = renderSections(ProjectState.activeTab, baseClick, baseHeld, baseRightClick, px, contY, pw, contH)
    end

    if ProjectState.focus and baseClick and not over(px, contY, pw, contH) and not over(x + 70, y + 8, w - 114, CONTROL_H) then
        ProjectState.focus = nil; baseClick = false
    end
    return popupOpen and click or baseClick, popupOpen and held or baseHeld, popupOpen and rightClick or baseRightClick
end

-- ====================== INPUT & MAIN LOOP ======================
local function updateInput()
    local active = true
    if type(isrbxactive) == "function" then active = isrbxactive() == true end
    ProjectState.focusedWindow = active

    for i = 1, #InputOrder do
        local input = Input[InputOrder[i]]; input.click = false; input.released = false
    end
    local m1, m2 = false, false
    if active then m1 = ismouse1pressed() == true; m2 = ismouse2pressed() == true end
    Input.m1.click = m1 and not Input.m1.held; Input.m1.released = (not m1) and Input.m1.held; Input.m1.held = m1
    Input.m2.click = m2 and not Input.m2.held; Input.m2.released = (not m2) and Input.m2.held; Input.m2.held = m2

    local pollAll = ProjectState.open or ProjectState.focus ~= nil
    if not pollAll then for _, item in ipairs(keybindItems) do if item.keybind and item.keybind.listening then pollAll = true; break end end end

    if pollAll then
        for i = 1, #InputOrder do
            local name = InputOrder[i]; if name ~= "m1" and name ~= "m2" then
                local input = Input[name]; local down = false
                if active then down = iskeypressed(input.id) == true end
                input.click = down and not input.held; input.released = (not down) and input.held; input.held = down
            end
        end
    else
        local keysToPoll = {}
        if MENU_KEY then keysToPoll[MENU_KEY] = true end
        for _, item in ipairs(keybindItems) do if item.keybind and item.keybind.value then keysToPoll[item.keybind.value] = true end end
        for name, _ in pairs(keysToPoll) do
            local input = Input[name]
            if input and name ~= "m1" and name ~= "m2" then
                local down = false; if active then down = iskeypressed(input.id) == true end
                input.click = down and not input.held; input.released = (not down) and input.held; input.held = down
            end
        end
    end
end

local function processTextInput()
    if Input.tab.click then
        local items = getFocusableItems(); if #items > 0 then
            local currentIdx = nil
            for i = 1, #items do if items[i] == ProjectState.focus then currentIdx = i; break end end
            local nextIdx
            local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held
            if currentIdx then nextIdx = shifted and (currentIdx - 1 < 1 and #items or currentIdx - 1) or (currentIdx + 1 > #items and 1 or currentIdx + 1)
            else nextIdx = shifted and #items or 1 end
            local nextItem = items[nextIdx]; ProjectState.focus = nextItem
            if type(nextItem) == "table" and nextItem.type == "slider" then nextItem._directValue = tostring(nextItem.value) end
            Input.tab.click = false
        end
    end

    local item = ProjectState.focus; if not item then return end
    if item == "search" then
        if Input.enter.click or Input.esc.click then
            ProjectState.focus = nil; ProjectState.searchOpen = false; ProjectState.searchQuery = ""; ProjectState.searchCacheQuery = nil; ProjectState.searchResults = nil
            return
        end
        local value = ProjectState.searchQuery or ""; local changed = false
        local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held; local now = clock(); local any_held = false
        if Input.delete.click then value = ""; changed = true end
        for i = 1, #InputOrder do
            local name = InputOrder[i]; local input = Input[name]
            if input.click and input.char then value = value .. (shifted and input.shifted or input.char); changed = true; ProjectState.repeatKey = name; ProjectState.repeatAt = now + 0.4; any_held = true; break
            elseif input.held and input.char and ProjectState.repeatKey == name then
                any_held = true; if now >= (ProjectState.repeatAt or 0) then value = value .. (shifted and input.shifted or input.char); changed = true; ProjectState.repeatAt = now + 0.035 end; break
            elseif input.click and (name == "backspace" or name == "unbound") then value = string.sub(value, 1, max(0, #value - 1)); changed = true; ProjectState.repeatKey = name; ProjectState.repeatAt = now + 0.4; any_held = true; break
            elseif input.held and (name == "backspace" or name == "unbound") and ProjectState.repeatKey == name then
                any_held = true; if now >= (ProjectState.repeatAt or 0) then value = string.sub(value, 1, max(0, #value - 1)); changed = true; ProjectState.repeatAt = now + 0.035 end; break
            end
        end
        if not any_held then ProjectState.repeatKey = nil end
        if changed then ProjectState.searchQuery = value; ProjectState.searchCacheQuery = nil; ProjectState.searchResults = nil end
        return
    end

    if item == ProjectState.colorpicker then
        local cp = item
        if Input.enter.click or Input.esc.click then ProjectState.focus = nil; return end
        local value = cp._hexInput or ""; local changed = false
        for i = 1, #InputOrder do
            local name = InputOrder[i]; local input = Input[name]
            if input.click and input.char then
                local char = string.upper(input.char)
                if (tonumber(char) or char:match("[A-F]")) and #value < 6 then value = value .. char; changed = true end; break
            elseif input.click and (name == "backspace" or name == "unbound") then value = string.sub(value, 1, max(0, #value - 1)); changed = true; break end
        end
        if changed then
            cp._hexInput = value
            if #value == 6 then
                local ok, newColor = pcall(C3HEX, "#" .. value)
                if ok and newColor then
                    local h_v, s_v, v_v = toHsv(newColor); cp.hue = h_v; cp.sat = s_v; cp.val = v_v
                    cp.value = newColor; cp.picker.value = newColor; safeCallback(cp.picker.callback, newColor)
                end
            end
        end
        return
    end

    if type(item) ~= "table" or (item.type ~= "textbox" and item.type ~= "slider") then return end
    if Input.enter.click then
        if item.type == "slider" then local val = tonumber(item._directValue or "") or item.value or item.min or 0; setItemValue(item, val, true); item._directValue = nil end
        ProjectState.focus = nil; return
    elseif Input.esc.click then
        if item.type == "slider" then item._directValue = nil end
        ProjectState.focus = nil; return
    end
    local value = item.type == "textbox" and (item.value or "") or (item._directValue or "")
    local changed = false; local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held; local now = clock(); local any_held = false
    if Input.delete.click then value = ""; changed = true end
    for i = 1, #InputOrder do
        local name = InputOrder[i]; local input = Input[name]
        if input.click and input.char then
            local char = shifted and input.shifted or input.char
            if item.type == "slider" then if tonumber(char) or char == "." or char == "-" then value = value .. char; changed = true end
            else value = value .. char; changed = true end
            ProjectState.repeatKey = name; ProjectState.repeatAt = now + 0.4; any_held = true; break
        elseif input.held and input.char and ProjectState.repeatKey == name then
            any_held = true; if now >= (ProjectState.repeatAt or 0) then
                local char = shifted and input.shifted or input.char
                if item.type == "slider" then if tonumber(char) or char == "." or char == "-" then value = value .. char; changed = true end
                else value = value .. char; changed = true end
                ProjectState.repeatAt = now + 0.035
            end; break
        elseif input.click and (name == "backspace" or name == "unbound") then value = string.sub(value, 1, max(0, #value - 1)); changed = true; ProjectState.repeatKey = name; ProjectState.repeatAt = now + 0.4; any_held = true; break
        elseif input.held and (name == "backspace" or name == "unbound") and ProjectState.repeatKey == name then
            any_held = true; if now >= (ProjectState.repeatAt or 0) then value = string.sub(value, 1, max(0, #value - 1)); changed = true; ProjectState.repeatAt = now + 0.035 end; break
        end
    end
    if not any_held then ProjectState.repeatKey = nil end
    if changed then
        if item.type == "textbox" then
            if value ~= item.value then item.value = value; safeCallback(item.callback, value) end
        else item._directValue = value end
    end
end

local function processKeybinds()
    if ProjectState.focus then return end
    for i = 1, #keybindItems do
        local item = keybindItems[i]; local keybind = item.keybind
        if item.type == "toggle" and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
            local input = Input[keybind.value]
            if input then
                if keybind.mode == "Always" then setItemValue(item, true, true)
                elseif keybind.mode == "Toggle" and input.click then setItemValue(item, not item.value, true)
                elseif keybind.mode == "Hold" then setItemValue(item, input.held, true) end
            end
        end
    end
end

local function renderWatermark(click, held)
    if not ProjectState.watermarkEnabled then return end
    local title = ProjectState.watermarkTitle ~= "" and ProjectState.watermarkTitle or ProjectState.title or "Merged UI"
    local text = ProjectState.activityText ~= "" and (title .. " | " .. ProjectState.activityText) or title
    local w = textWidth(text, 12, FontUI) + 20; local h = 24
    local x = ProjectState.watermarkX or 20; local y = ProjectState.watermarkY or 20
    local hovered = over(x, y, w, h)
    if click and hovered then ProjectState.watermarkDrag = {ProjectState.mouseX - x, ProjectState.mouseY - y} end
    if held and ProjectState.watermarkDrag then
        ProjectState.watermarkX = ProjectState.mouseX - ProjectState.watermarkDrag[1]
        ProjectState.watermarkY = ProjectState.mouseY - ProjectState.watermarkDrag[2]
        local vw, vh = viewportSize(); ProjectState.watermarkX = clamp(ProjectState.watermarkX, 0, vw - w); ProjectState.watermarkY = clamp(ProjectState.watermarkY, 0, vh - h)
        x = ProjectState.watermarkX; y = ProjectState.watermarkY
    elseif not held then ProjectState.watermarkDrag = nil end
    rect(x, y, w, h, Theme.surface, 150, 6, 0.85); strokeRect(x, y, w, h, Theme.accent, 151, 6)
    txt(text, x + 10, textTop(y, h, 12), Theme.text, 12, FontUI, 152, false, false)
end

local function renderDiagnostics()
    if not ProjectState.diagnosticsEnabled then return end
    local vw, vh = viewportSize(); local w = 180; local kinds = {"sq", "tx", "ln", "ci", "tr", "im"}
    local h = 32 + #kinds * 16; local x = vw - w - 20; local y = 50
    rect(x, y, w, h, Theme.surface, 130, 8, 0.85); strokeRect(x, y, w, h, Theme.border, 131, 8)
    txt("DIAGNOSTICS", x + 10, y + 8, Theme.accent, 11, FontBold, 132)
    local dy = y + 24
    for _, k in ipairs(kinds) do
        local label = TypeMap[k] or k; local active = PoolIndex[k] or 0; local high = PoolHighWater[k] or 0
        txt(string.format("%s Pool: %d / %d", label, active, high), x + 10, dy, Theme.sub, 10, FontUI, 132)
        dy = dy + 16
    end
end

local function renderPanels(click, held)
    for _, panel in ipairs(ProjectState.panels) do
        if panel.visible then
            local x = panel.position.X
            local y = panel.position.Y
            local w = panel.size.X
            local h = panel.size.Y
            local hovered = over(x, y, w, 28)
            if click and hovered and not ProjectState.panelDrag then
                ProjectState.panelDrag = { panel = panel, offX = ProjectState.mouseX - x, offY = ProjectState.mouseY - y }
                click = false
            end
            if held and ProjectState.panelDrag and ProjectState.panelDrag.panel == panel then
                panel.position = V2(
                    ProjectState.mouseX - ProjectState.panelDrag.offX,
                    ProjectState.mouseY - ProjectState.panelDrag.offY
                )
                x, y = panel.position.X, panel.position.Y
            elseif not held then
                ProjectState.panelDrag = nil
            end

            rect(x, y, w, h, panel.bgColor or Theme.surface, 80, 8, 0.95)
            strokeRect(x, y, w, h, panel.accentColor or Theme.accent, 81, 8)
            if panel.showTopbar then
                rect(x, y, w, 28, panel.accentColor or Theme.accent, 82, 8)
                txt(panel.title, x + 10, textTop(y, 28, 13), Theme.text, 13, FontBold, 83, false)
            end
        end
    end
    if not held then ProjectState.panelDrag = nil end
    return click
end

local function step()
    print("STEP open:", ProjectState.open, "activeTab:", ProjectState.activeTab and ProjectState.activeTab.name or "nil")
    resetPool(); ProjectState.tooltipText = nil
    local now = clock(); local dt = now - ProjectState.lastFrame; ProjectState.lastFrame = now; ProjectState.dt = dt
    getMouse(); updateInput()

    if Input[MENU_KEY] and Input[MENU_KEY].click then setOpen(not ProjectState.open) end

    processTextInput(); processKeybinds()

    local activityParts = {}
    for i = 1, #ProjectState.activities do
        local act = ProjectState.activities[i]
        if act and act.alive then
            local result = safeCallback(act.callback, UI, dt, now)
            if result ~= nil and result ~= "" then activityParts[#activityParts + 1] = tostring(result) end
        end
    end
    ProjectState.activityText = #activityParts > 0 and concat(activityParts, " | ") or ""

    if ProjectState.open and not ProjectState.focus and not ProjectState.dropdown and not ProjectState.colorpicker and #ProjectState.tabs > 0 then
        if Input.left.click then
            local idx = max(1, (ProjectState.activeIndex or 1) - 1); ProjectState.activeTab = ProjectState.tabs[idx]; ProjectState.activeIndex = idx; ProjectState.tabScrollToActive = true
        elseif Input.right.click then
            local idx = min(#ProjectState.tabs, (ProjectState.activeIndex or 1) + 1); ProjectState.activeTab = ProjectState.tabs[idx]; ProjectState.activeIndex = idx; ProjectState.tabScrollToActive = true
        end
    end

    if Input.m1.released then ProjectState.sliderDrag = nil; ProjectState.scrollDrag = nil end

    local click = Input.m1.click; local held = Input.m1.held; local rightClick = Input.m2.click

    if not ProjectState.open or not ProjectState.focusedWindow or #ProjectState.tabs == 0 then
        if not ProjectState.open then print("UI CLOSED – returning early") end
        renderWatermark(click, held); renderDiagnostics(); click = renderPanels(click, held); hideUnused(); return
    end
    if not ProjectState.hasMouse then
        renderWatermark(click, held); renderDiagnostics(); click = renderPanels(click, held); hideUnused(); return
    end

    clampWindow()
    click, held, rightClick = renderWindow(click, held, rightClick)
    click = renderDropdown(click)
    click = renderColorpicker(click, held)
    renderTooltip()
    renderWatermark(click, held)
    renderDiagnostics()
    click = renderPanels(click, held)
    hideUnused()
end

-- ====================== HOMESICK WRAPPER API ======================
local Homesick = {}
_G.homesick = Homesick

function Homesick.createWindow(title, w, h)
    ProjectState.title = title or "Merged UI"
    ProjectState.w = tonumber(w) or DEFAULT_W; ProjectState.h = tonumber(h) or DEFAULT_H
    ProjectState.defaultH = ProjectState.h; ProjectState.minimized = false
    ProjectState.x, ProjectState.y = 100, 80; ProjectState.tabs = {}; ProjectState.activeTab = nil; ProjectState.activeIndex = 0
    ProjectState.open = true; ProjectState.searchOpen = false; ProjectState.watermarkEnabled = false
    applyInputState(true)
    local win = {}
    function win:addTab(name)
        local tab = { name = name, sections = {}, scrollY = 0, targetScrollY = 0, maxScroll = 0 }
        ProjectState.tabs[#ProjectState.tabs + 1] = tab
        if not ProjectState.activeTab then ProjectState.activeTab = tab; ProjectState.activeIndex = #ProjectState.tabs end
        local tabMethods = {}
        function tabMethods:addSection(name, side)
            local sec = { name = name, items = {}, collapsed = false, side = side or "Left" }
            tab.sections[#tab.sections + 1] = sec
            local sectionApi = createSection(tab, name)
            sectionApi.addToggle = function(self, id, label, default, callback)
                local h = sectionApi.Toggle(self, label, default, callback)
                if h then
                    h.addKeybind = h.AddKeybind
                    h.addColorpicker = h.AddColorpicker
                    h.addTooltip = h.AddTooltip
                end
                return h
            end
            sectionApi.addCheckbox = sectionApi.addToggle
            sectionApi.addSlider = function(self, id, label, default, step, minv, maxv, callback)
                step = step or 1
                return sectionApi.Slider(self, label, default, step, minv, maxv, "", callback)
            end
            sectionApi.addInput = sectionApi.Textbox
            sectionApi.addDropdown = function(self, id, label, choices, default, callback, multi)
                return sectionApi.Dropdown(self, label, default, choices, multi, callback)
            end
            sectionApi.addMultiDropdown = function(self, id, label, choices, default, callback, minSel)
                return sectionApi.Dropdown(self, label, default, choices, true, callback)
            end
            sectionApi.addButton = sectionApi.Button
            sectionApi.addSeparator = sectionApi.Divider
            sectionApi.addText = sectionApi.Label
            sectionApi.addColorpicker = function(self, id, label, default, callback)
                local item = sectionApi.Toggle(self, label, false, function() end)
                return item:AddColorpicker(label, default, false, callback)
            end
            sectionApi.addKeybind = function(self, id, label, defaultKey, mode, canChange, callback)
                local item = sectionApi.Toggle(self, label, false, function() end)
                return item:AddKeybind(defaultKey, mode, canChange, callback)
            end
            sectionApi.addTooltip = function(self, text)
                if #sec.items > 0 then sec.items[#sec.items].tooltip = text end
            end
            return sectionApi
        end
        return tabMethods
    end
    function win:setBadge(badge) ProjectState.badge = badge end
    function win:autoloadConfig(name) end
    function win:autoloadTheme(name) end
    function win:render() end
    function win:enableSearch(bool) ProjectState.searchOpen = bool end
    function win:enableWatermark(bool) ProjectState.watermarkEnabled = bool end
    function win:setTheme(overrides) UI:SetTheme(overrides) end
    function win:setControlsStyle(style, options) UI:SetControlsStyle(style, options) end
    win.visible = true
    return win
end

function Homesick:CreateBox(options)
    local panel = {
        title = options.title or "Box", showTopbar = options.showTopbar,
        position = options.position or V2(100, 100), size = options.size or V2(200, 200),
        visible = options.visible ~= false, bgColor = Theme.surface, accentColor = Theme.accent,
        elements = {}
    }
    table.insert(ProjectState.panels, panel)
    local boxApi = {}
    function boxApi:SetColor(bg, accent) panel.bgColor = bg or panel.bgColor; panel.accentColor = accent or panel.accentColor end
    function boxApi:AddText(id, text, color, size, font, align) end
    function boxApi:AddTimer(id, value, max, color) end
    function boxApi:AddButton(id, label, callback) end
    function boxApi:AddCheckbox(id, label, default, callback) end
    function boxApi:AddSlider(id, label, default, minv, maxv, step, callback) end
    function boxApi:AddColorpicker(id, label, default, callback) end
    function boxApi:AddDropdown(id, label, choices, default, callback) end
    function boxApi:AddSeparator(id, label) end
    function boxApi:SetText(id, text, color) end
    function boxApi:SetTimer(id, value, max) end
    return boxApi
end

-- ====================== STARTUP ======================
local stepConnection
local function finalDestroy()
    if ProjectState.destroyed then return end
    ProjectState.destroyed = true; ProjectState.open = false
    if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
    setrobloxinput(true)
    for kind, list in pairs(Pool) do for i = 1, #list do if list[i] then pcall(function() list[i]:Remove() end) end end end
end

function UI:Destroy() ProjectState.alive = false; if not ProjectState.rendering then finalDestroy() end; return self end

local function runStepSafe()
    if not ProjectState.alive then
        if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
        finalDestroy()
        return
    end
    ProjectState.rendering = true
    local ok, err = pcall(step)
    ProjectState.rendering = false
    if not ok then
        warn("UI STEP ERROR: " .. tostring(err))
        --ProjectState.errorCount = (ProjectState.errorCount or 0) + 1
        --if ProjectState.errorCount >= 3 then ProjectState.alive = false; finalDestroy() end
    --else 
        --ProjectState.errorCount = 0 
    end
end

local RunService = game:GetService("RunService")
if RunService and RunService.RenderStepped then
    stepConnection = RunService.RenderStepped:Connect(runStepSafe)
else
    task.spawn(function() while ProjectState.alive do runStepSafe(); task.wait(FRAME_WAIT) end end)
end
