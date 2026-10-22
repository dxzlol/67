--=============================================================================
--  Matcha ESP - Alive players + Items, with GUI
--  v12: dynamic per-player colors (no dupes), hard-coded item colors
--=============================================================================

local VERSION = "v12"

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local LocalPlayer = Players and Players.LocalPlayer

local CFG = {
    PlayerBox        = true,
    PlayerSnapline   = true,
    PlayerName       = true,
    PlayerHealth     = true,
    PlayerDistance   = true,
    MaxPlayerDist    = 500,

    Items            = true,
    ItemBox          = true,
    ItemText         = true,
    MaxItemDist      = 50,
    ItemRescanRate   = 0.5,

    NewTagDurationMin = 5,
    NewTagDurationMax = 10,

    QuietSeconds     = 1.0,

    RequireRoundForNewTag    = true,
    TreatUnknownPhaseAsRound = false,
    HideItemsWhenNotInRound  = false,
    DebugPhase               = false,
    DebugTeams               = false,

    PlayerPollRate   = 0.5,

    ColorInfo        = Color3.fromRGB(220, 220, 220),
    ColorNew         = Color3.fromRGB(255, 255, 180),
    FontSize         = 14,

    -- Optional per-player overrides by exact name
    CustomColors     = {},
}

local ALIVE_TEAM = "Alive"
local LOBBY_TEAM = "Lobby"

--=============================================================================
-- UTIL
--=============================================================================
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function now()
    local ok, t = pcall(tick)
    if ok and type(t) == "number" then return t end
    return os and os.clock and os.clock() or 0
end

local _scriptStart = now()

local function safeConnect(signal, fn)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(fn) end)
    if ok then return conn end
    return nil
end

local function setTextSize(obj, size)
    if pcall(function() obj.FontSize = size end) then return end
    pcall(function() obj.Size = size end)
end

local function newSquare(color, thickness, filled)
    local s = Drawing.new("Square")
    s.Color     = color
    s.Thickness = thickness or 1
    s.Filled    = filled or false
    s.Visible   = false
    return s
end

local function newLine(color, thickness)
    local l = Drawing.new("Line")
    l.Color     = color
    l.Thickness = thickness or 1
    l.Visible   = false
    return l
end

local function newText(color, size)
    local t = Drawing.new("Text")
    t.Color   = color
    t.Center  = true
    t.Outline = true
    t.Visible = false
    setTextSize(t, size or CFG.FontSize)
    return t
end

local function removeDrawing(d)
    if d then pcall(function() d:Remove() end) end
end

local function findPart(inst, depth)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") and inst.PrimaryPart then return inst.PrimaryPart end
    local direct = inst:FindFirstChildWhichIsA("BasePart")
    if direct then return direct end
    depth = depth or 0
    if depth >= 3 then return nil end
    for _, child in ipairs(inst:GetChildren()) do
        local p = findPart(child, depth + 1)
        if p then return p end
    end
    return nil
end

local function findPartNamed(inst, partName, depth)
    if not inst or not partName or #partName == 0 then return nil end
    local direct = inst:FindFirstChild(partName)
    if direct and direct:IsA("BasePart") then return direct end
    depth = depth or 0
    if depth >= 3 then return nil end
    for _, child in ipairs(inst:GetChildren()) do
        local p = findPartNamed(child, partName, depth + 1)
        if p then return p end
    end
    return nil
end

--=============================================================================
-- ITEM NAME / WEAPON HELPERS
--=============================================================================
local WEAPON_NAMES = {
    ["glock 17"]     = true,
    ["spas-12"]      = true,
    ["ak-47"]        = true,
    ["uzi"]          = true,
    ["knife"]        = true,
    ["bat"]          = true,
    ["sledgehammer"] = true,
}

local function cleanItemName(rawName)
    if not rawName then return "" end
    local s = tostring(rawName)
    s = s:gsub("_[Dd]rop$", "")
    s = s:gsub("_[Ll]oot$", "")
    s = s:gsub("_[Ii]tem$", "")
    s = s:gsub("_+$", "")
    return s
end

local function isWeapon(rawName)
    local s = string.lower(cleanItemName(rawName))
    if WEAPON_NAMES[s] then return true end
    return s:find("glock")   ~= nil or
           s:find("ak%-47")  ~= nil or
           s:find("spas")    ~= nil or
           s:find("uzi")     ~= nil or
           s:find("knife")   ~= nil or
           s:find("bat")     ~= nil or
           s:find("sledge")  ~= nil or
           s:find("pistol")  ~= nil or
           s:find("rifle")   ~= nil or
           s:find("shotgun") ~= nil or
           s:find("smg")     ~= nil or
           s:find("m4")      ~= nil or
           s:find("mp5")     ~= nil or
           s:find("ar%-")    ~= nil
end

-- Weapons: Main -> Handle -> Handling -> part-named-after-item -> any BasePart
local function resolveItemPart(inst, isWeaponFlag)
    if not inst then return nil end
    if isWeaponFlag then
        local main = findPartNamed(inst, "Main")
        if main then return main end

        local handle = findPartNamed(inst, "Handle")
        if handle then return handle end

        -- Sledgehammers use "Handling" instead of "Handle"
        local handling = findPartNamed(inst, "Handling")
        if handling then return handling end

        local clean = cleanItemName(inst.Name)
        if #clean > 0 then
            local named = findPartNamed(inst, clean)
            if named then return named end
        end
    end
    return findPart(inst)
end

--=============================================================================
-- COLOR SYSTEM
--  Players: dynamic pool, hue-stepped, dedup via exact RGB key.
--  Items:   hard-coded per name; unknown items fall into a separate pool.
--=============================================================================
local function colorKey(c)
    return string.format("%.3f_%.3f_%.3f", c.R, c.G, c.B)
end

-- ---- Players ---------------------------------------------------------------
local _playerColorMap      = {}   -- [player] = Color3
local _usedPlayerColorKeys = {}   -- [key] = true

local function releasePlayerColor(player)
    local c = _playerColorMap[player]
    if not c then return end
    _usedPlayerColorKeys[colorKey(c)] = nil
    _playerColorMap[player] = nil
end

-- Golden-ratio hue stepping; guarantees coverage before collision.
local function pickFreshPlayerColor()
    local seed = math.random()
    for i = 1, 2000 do
        local h = (seed + i * 0.61803398875) % 1
        local s = 0.60 + (i % 3) * 0.12
        local v = 0.82 + (i % 2) * 0.14
        local c = Color3.fromHSV(h, s, v)
        local k = colorKey(c)
        if not _usedPlayerColorKeys[k] then
            _usedPlayerColorKeys[k] = true
            return c
        end
    end
    return Color3.new(1, 1, 1)
end

local function assignPlayerColor(player)
    if _playerColorMap[player] then return _playerColorMap[player] end

    local pname = tostring(player.Name)
    if CFG.CustomColors[pname] then
        local c = CFG.CustomColors[pname]
        _usedPlayerColorKeys[colorKey(c)] = true
        _playerColorMap[player] = c
        return c
    end

    local c = pickFreshPlayerColor()
    _playerColorMap[player] = c
    return c
end

-- ---- Items -----------------------------------------------------------------
-- Hard-coded per-item colors. Add more names as needed.
local ITEM_HARDCODED_COLORS = {
    -- Weapons
    ["Glock 17"]     = Color3.fromRGB(255,  90,  90),
    ["SPAS-12"]      = Color3.fromRGB(255, 140,  50),
    ["AK-47"]        = Color3.fromRGB(255,  60,  60),
    ["UZI"]          = Color3.fromRGB(180, 100, 255),
    ["Knife"]        = Color3.fromRGB(255, 120, 200),
    ["Bat"]          = Color3.fromRGB(240, 180,  80),
    ["Sledgehammer"] = Color3.fromRGB(200, 140,  90),
    -- Ammo
    ["Rifle Rounds"]  = Color3.fromRGB(  0, 255, 170),
    ["Pistol Rounds"] = Color3.fromRGB(100, 220, 200),
    ["Shells"]        = Color3.fromRGB(  0, 200, 130),
    -- Healing / utility
    ["Medkit"]        = Color3.fromRGB(100, 255, 120),
    ["Bandage"]       = Color3.fromRGB(150, 255, 150),
    ["Armor"]         = Color3.fromRGB(100, 180, 255),
    ["Vest"]          = Color3.fromRGB( 80, 160, 220),
}

local _itemFallbackColors     = {}   -- [cleanName] = Color3
local _usedItemFallbackKeys   = {}   -- [key] = true

local function pickFreshItemFallbackColor()
    local seed = math.random()
    for i = 1, 2000 do
        -- Different step from player pool so fallback items don't resemble players
        local h = (seed + i * 0.38196601125) % 1
        local s = 0.55 + (i % 3) * 0.15
        local v = 0.80 + (i % 2) * 0.15
        local c = Color3.fromHSV(h, s, v)
        local k = colorKey(c)
        if not _usedItemFallbackKeys[k] then
            _usedItemFallbackKeys[k] = true
            return c
        end
    end
    return Color3.new(0, 255, 170)
end

local function colorForItem(cleanName)
    if ITEM_HARDCODED_COLORS[cleanName] then
        return ITEM_HARDCODED_COLORS[cleanName]
    end
    if _itemFallbackColors[cleanName] then
        return _itemFallbackColors[cleanName]
    end
    local c = pickFreshItemFallbackColor()
    _itemFallbackColors[cleanName] = c
    return c
end

--=============================================================================
-- PHASE DETECTOR
--=============================================================================
local PlayersSvc = Players
local _cache = {}
local _lastSlotRetry = 0
local _lastStablePhase = "intermission"

local function _find(p, n, tries, gap)
    tries = tries or 3; gap = gap or 0.05
    for _ = 1, tries do
        if p then
            local c = p:FindFirstChild(n)
            if c then return c end
        end
        wait(gap)
    end
    return nil
end

local function _resolve()
    local LP = PlayersSvc.LocalPlayer
    if not LP then return nil, nil, nil, nil end
    if _cache.hud then
        local ok, parent = pcall(function() return _cache.hud.Parent end)
        if not ok or not parent then _cache = {} end
    end
    if not _cache.hud then
        local PG = _find(LP, "PlayerGui", 20, 0.1)
        local HUD = PG and _find(PG, "GameHUD", 10, 0.1)
        if not HUD then return nil, nil, nil, nil end
        _cache.hud = HUD
        local TC = _find(HUD, "TimerCollage", 3)
        local OC = _find(HUD, "ObjectiveCollage", 3)
        _cache.roundSlot = TC and _find(TC, "ClockSlot", 3) or nil
        _cache.objSlot   = OC and _find(OC, "ClockSlot", 3) or nil
        _cache.phaseLabel = nil
        if TC then
            for _, n in ipairs({
                "GameStatus", "GameStatusLabel", "Status",
                "Phase", "PhaseLabel", "GameStatusText",
            }) do
                local c = TC:FindFirstChild(n)
                if c then _cache.phaseLabel = c; break end
            end
        end
        return _cache.hud, _cache.roundSlot, _cache.objSlot, _cache.phaseLabel
    end
    if not _cache.roundSlot or not _cache.objSlot or not _cache.phaseLabel then
        local t = now()
        if t - _lastSlotRetry >= 1.0 then
            _lastSlotRetry = t
            local HUD = _cache.hud
            local TC = HUD:FindFirstChild("TimerCollage")
            local OC = HUD:FindFirstChild("ObjectiveCollage")
            if TC and not _cache.roundSlot then
                _cache.roundSlot = TC:FindFirstChild("ClockSlot")
            end
            if OC and not _cache.objSlot then
                _cache.objSlot = OC:FindFirstChild("ClockSlot")
            end
            if TC and not _cache.phaseLabel then
                for _, n in ipairs({
                    "GameStatus", "GameStatusLabel", "Status",
                    "Phase", "PhaseLabel", "GameStatusText",
                }) do
                    local c = TC:FindFirstChild(n)
                    if c then _cache.phaseLabel = c; break end
                end
            end
        end
    end
    return _cache.hud, _cache.roundSlot, _cache.objSlot, _cache.phaseLabel
end

local function _hasDigits(slot)
    if not slot then return false end
    local ok, desc = pcall(function() return slot:GetDescendants() end)
    if not ok or type(desc) ~= "table" then return false end
    local singleDigits = 0
    local checked = 0
    for i = 1, #desc do
        if checked >= 100 then break end
        checked = checked + 1
        local inst = desc[i]
        local okC, cls = pcall(function() return inst.ClassName end)
        if okC and (cls == "TextLabel" or cls == "TextButton") then
            local okV, vis = pcall(function() return inst.Visible end)
            local skip = okV and vis == false
            if not skip then
                local okT, t = pcall(function() return inst.Text end)
                if okT and t then
                    local s = tostring(t)
                    if #s == 1 and s:match("%d") then
                        singleDigits = singleDigits + 1
                        if singleDigits >= 3 then return true end
                    end
                    if #s >= 2 and s:find("%d%d") then return true end
                end
            end
        end
    end
    return singleDigits >= 3
end

local function _phaseText(label)
    if not label then return nil end
    local ok, t = pcall(function() return label.Text end)
    if not ok or not t then return nil end
    local s = tostring(t)
    if #s == 0 then return nil end
    return s
end

function getPhase()
    local HUD, roundSlot, objSlot, phaseLabel = _resolve()
    if not HUD then return "unknown" end
    local text     = _phaseText(phaseLabel)
    local low      = text and string.lower(text) or ""
    local hasObj   = _hasDigits(objSlot)
    local hasRound = _hasDigits(roundSlot)
    if CFG.DebugPhase then
        print(string.format("[%s phase-debug] text='%s' obj=%s round=%s lastStable=%s",
            VERSION, tostring(text), tostring(hasObj), tostring(hasRound), _lastStablePhase))
    end
    if low:find("result", 1, true) then _lastStablePhase = "results"; return "results" end
    if hasObj then _lastStablePhase = "round"; return "round" end
    if low:find("voting", 1, true) or low:find("vote", 1, true) then
        _lastStablePhase = "voting"; return "voting"
    end
    if low:find("intermission", 1, true) or low:find("inter", 1, true) then
        _lastStablePhase = "intermission"; return "intermission"
    end
    if hasRound then _lastStablePhase = "intermission"; return "intermission" end
    if _lastStablePhase == "round" then return "round" end
    return "intermission"
end

function isRoundActive() return getPhase() == "round" end

local _w = { running = false, last = nil, interval = 0.25 }

function startPhaseWatcher(cbs)
    cbs = cbs or {}
    if _w.running then return end
    _w.running = true
    _w.last = getPhase()
    if _w.last == "round" and cbs.onRoundStart then pcall(cbs.onRoundStart, "unknown") end
    local spawnFn
    if type(spawn) == "function" then spawnFn = spawn
    elseif type(task) == "table" and type(task.spawn) == "function" then spawnFn = task.spawn
    else warn("[phase] no spawn available"); return end
    spawnFn(function()
        while _w.running do
            wait(_w.interval)
            local p = getPhase()
            if p ~= _w.last then
                local prev = _w.last
                _w.last = p
                if cbs.onPhaseChange then pcall(cbs.onPhaseChange, p, prev) end
                if p == "round" and prev ~= "round" then
                    if cbs.onRoundStart then pcall(cbs.onRoundStart, prev) end
                elseif prev == "round" and p ~= "round" then
                    if cbs.onRoundEnd then pcall(cbs.onRoundEnd, p) end
                end
                if p == "results" and cbs.onResults then pcall(cbs.onResults) end
            end
            if cbs.onTick then pcall(cbs.onTick, p) end
        end
    end)
end

function stopPhaseWatcher() _w.running = false end

local currentPhase = "unknown"

local function isRoundLike()
    if currentPhase == "round" then return true end
    if currentPhase == "unknown" and CFG.TreatUnknownPhaseAsRound then return true end
    return false
end

local function itemsVisibleThisPhase()
    if not CFG.HideItemsWhenNotInRound then return true end
    if currentPhase == "round" then return true end
    if currentPhase == "results" then return true end
    if currentPhase == "unknown" then return true end
    return false
end

--=============================================================================
-- TEAM DETECTION
--=============================================================================
local function matchTeamName(raw)
    if not raw or type(raw) ~= "string" then return nil end
    if raw == ALIVE_TEAM then return ALIVE_TEAM end
    if raw == LOBBY_TEAM then return LOBBY_TEAM end
    local lower = string.lower(raw)
    if lower == string.lower(ALIVE_TEAM) then return ALIVE_TEAM end
    if lower == string.lower(LOBBY_TEAM) then return LOBBY_TEAM end
    return nil
end

local function getPlayerTeamName(player)
    if not player then return nil end

    local okT, team = pcall(function() return player.Team end)
    if okT and team then
        local okN, tname = pcall(function() return team.Name end)
        local matched = matchTeamName(tname)
        if matched then return matched end
    end

    local okC, char = pcall(function() return player.Character end)
    if okC and char then
        local okP, parent = pcall(function() return char.Parent end)
        if okP and parent then
            local okPN, pname = pcall(function() return parent.Name end)
            local matched = matchTeamName(pname)
            if matched then return matched end

            local cur = parent
            for _ = 1, 3 do
                if not cur then break end
                local okCP, up = pcall(function() return cur.Parent end)
                if not okCP or not up then break end
                cur = up
                local okUP, uname = pcall(function() return cur.Name end)
                local umatched = matchTeamName(uname)
                if umatched then return umatched end
            end
        end

        local aliveFolder = Workspace:FindFirstChild(ALIVE_TEAM)
        if aliveFolder then
            local okA, inside = pcall(function() return char:IsDescendantOf(aliveFolder) end)
            if okA and inside then return ALIVE_TEAM end
        end

        local lobbyFolder = Workspace:FindFirstChild(LOBBY_TEAM)
        if lobbyFolder then
            local okL, inside = pcall(function() return char:IsDescendantOf(lobbyFolder) end)
            if okL and inside then return LOBBY_TEAM end
        end
    end

    return nil
end

local function isAlivePlayer(player)
    return getPlayerTeamName(player) == ALIVE_TEAM
end

--=============================================================================
-- PLAYER ESP
--=============================================================================
local playerDrawings = {}

local function buildDrawing(player)
    local col = assignPlayerColor(player)
    return {
        color = col,
        box   = newSquare(col, 1.5, false),
        line  = newLine(col, 1),
        name  = newText(col, CFG.FontSize),
        info  = newText(CFG.ColorInfo, CFG.FontSize - 1),
    }
end

local function addPlayer(player)
    if not player then return end
    if player == LocalPlayer then return end
    if playerDrawings[player] then return end
    playerDrawings[player] = buildDrawing(player)
end

local function removePlayer(player)
    local d = playerDrawings[player]
    if not d then return end
    removeDrawing(d.box)
    removeDrawing(d.line)
    removeDrawing(d.name)
    removeDrawing(d.info)
    playerDrawings[player] = nil
    releasePlayerColor(player)
end

local function hidePlayer(d)
    d.box.Visible  = false
    d.line.Visible = false
    d.name.Visible = false
    d.info.Visible = false
end

local function renderPlayer(player, d)
    if not isAlivePlayer(player) then hidePlayer(d) return end
    local char = player.Character
    if not char then hidePlayer(d) return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then hidePlayer(d) return end
    local cam = Workspace.CurrentCamera
    if not cam then hidePlayer(d) return end
    local rootPos = hrp.Position
    local dist = (cam.CFrame.Position - rootPos).Magnitude
    if dist > CFG.MaxPlayerDist then hidePlayer(d) return end
    local screen, onScreen = WorldToScreen(rootPos)
    if not screen or not onScreen then hidePlayer(d) return end
    local boxH
    local hs, hon = WorldToScreen(rootPos + Vector3.new(0, 1.6, 0))
    local fs, fon = WorldToScreen(rootPos - Vector3.new(0, 1.6, 0))
    if hs and fs and hon and fon then boxH = math.abs(fs.Y - hs.Y) end
    if not boxH or boxH ~= boxH or boxH < 4 or boxH > 2000 then
        local fov = math.rad(cam.FieldOfView or 70)
        local vs  = cam.ViewportSize
        boxH = (vs.Y * 3.2) / (2 * math.max(dist, 1) * math.tan(fov * 0.5))
    end
    boxH = clamp(boxH, 10, 800)
    local boxW = boxH * 0.55
    d.box.Color    = d.color
    d.box.Size     = Vector2.new(boxW, boxH)
    d.box.Position = Vector2.new(screen.X - boxW * 0.5, screen.Y - boxH * 0.5)
    d.box.Visible  = CFG.PlayerBox
    local vs = cam.ViewportSize
    d.line.Color   = d.color
    d.line.From    = Vector2.new(vs.X * 0.5, vs.Y)
    d.line.To      = Vector2.new(screen.X, screen.Y + boxH * 0.5)
    d.line.Visible = CFG.PlayerSnapline
    d.name.Color    = d.color
    d.name.Text     = tostring(player.Name)
    d.name.Position = Vector2.new(screen.X, screen.Y - boxH * 0.5 - 16)
    d.name.Visible  = CFG.PlayerName
    local parts = {}
    if CFG.PlayerHealth then parts[#parts + 1] = string.format("HP: %d", math.floor(hum.Health)) end
    if CFG.PlayerDistance then parts[#parts + 1] = string.format("%dm", math.floor(dist)) end
    if #parts > 0 then
        d.info.Color    = CFG.ColorInfo
        d.info.Text     = table.concat(parts, "  |  ")
        d.info.Position = Vector2.new(screen.X, screen.Y - boxH * 0.5 - 30)
        d.info.Visible  = true
    else
        d.info.Visible  = false
    end
end

--=============================================================================
-- ITEM ESP
--=============================================================================
local ITEM_CONTAINERS = { "Drops", "RoundLoot" }
local itemDrawings    = {}
local lastItemScan    = -math.huge

local _knownItems         = {}
local _lastItemChangeAt   = _scriptStart
local _itemsInitialized   = false

local function resetItemState()
    for inst, d in pairs(itemDrawings) do
        removeDrawing(d.text)
        removeDrawing(d.box)
        itemDrawings[inst] = nil
    end
    _knownItems       = {}
    _lastItemChangeAt = now()
    _itemsInitialized = false
end

local function clearAllNewTags()
    for _, d in pairs(itemDrawings) do d.newUntil = 0 end
end

local function newTagDuration()
    local lo = CFG.NewTagDurationMin or 5
    local hi = CFG.NewTagDurationMax or 10
    if lo < 5 then lo = 5 end
    if hi > 10 then hi = 10 end
    if hi < lo then hi = lo end
    return lo + (hi - lo) * math.random()
end

local function scanItems()
    local found = {}
    for _, cname in ipairs(ITEM_CONTAINERS) do
        local container = Workspace:FindFirstChild(cname)
        if container then
            for _, child in ipairs(container:GetChildren()) do
                local part = resolveItemPart(child, isWeapon(child.Name))
                if part then
                    found[child] = { cname = cname, part = part }
                else
                    for _, sub in ipairs(child:GetChildren()) do
                        local subPart = resolveItemPart(sub, isWeapon(sub.Name))
                        if subPart then
                            found[sub] = { cname = cname, part = subPart }
                        end
                    end
                end
            end
        end
    end

    local newInstances = {}
    for inst, info in pairs(found) do
        if not _knownItems[inst] then
            newInstances[#newInstances + 1] = {
                inst = inst, cname = info.cname, part = info.part,
            }
        end
    end

    local removedCount = 0
    for inst in pairs(_knownItems) do
        if not found[inst] then
            removedCount = removedCount + 1
            _knownItems[inst] = nil
            local d = itemDrawings[inst]
            if d then
                removeDrawing(d.text)
                removeDrawing(d.box)
                itemDrawings[inst] = nil
            end
        end
    end

    local quiet = _itemsInitialized and (now() - _lastItemChangeAt) >= CFG.QuietSeconds
    if #newInstances > 0 or removedCount > 0 then
        _lastItemChangeAt = now()
    end

    for _, info in ipairs(newInstances) do
        _knownItems[info.inst] = true
        local clean = cleanItemName(info.inst.Name)
        local col   = colorForItem(clean)
        local isNew = quiet
        itemDrawings[info.inst] = {
            text      = newText(col, CFG.FontSize - 1),
            box       = newSquare(col, 1, false),
            baseColor = col,
            part      = info.part,
            newUntil  = isNew and (now() + newTagDuration()) or 0,
        }
    end

    if quiet and #newInstances > 0 then
        for _, info in ipairs(newInstances) do
            pcall(function()
                notify(
                    string.format("[%s] New %s: %s", VERSION, info.cname, cleanItemName(info.inst.Name)),
                    "MatchaESP", 3
                )
            end)
        end
    end

    _itemsInitialized = true
end

local function isItemEnabled(itemName)
    if not UI or not UI.GetValue then return true end
    local id = "itm_" .. itemName:gsub("[^%w]", "_")
    local ok, v = pcall(UI.GetValue, id)
    if ok and type(v) == "boolean" then return v end
    return true
end

local function renderItems()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if not itemsVisibleThisPhase() then
        for _, d in pairs(itemDrawings) do
            d.text.Visible = false
            d.box.Visible  = false
        end
        return
    end
    local t = now()
    for inst, d in pairs(itemDrawings) do
        local ok = pcall(function()
            local part = d.part
            if not part or not part.Parent then
                part = resolveItemPart(inst, isWeapon(inst.Name))
                if part then
                    d.part = part
                else
                    d.text.Visible = false
                    d.box.Visible  = false
                    return
                end
            end

            local cleanName = cleanItemName(inst.Name)
            if not isItemEnabled(cleanName) then
                d.text.Visible = false
                d.box.Visible  = false
                return
            end

            local pos = part.Position
            local dist = (cam.CFrame.Position - pos).Magnitude
            if dist > CFG.MaxItemDist then
                d.text.Visible = false
                d.box.Visible  = false
                return
            end

            local screen, onScreen = WorldToScreen(pos)
            if not screen or not onScreen then
                d.text.Visible = false
                d.box.Visible  = false
                return
            end

            local size = clamp(1400 / math.max(dist, 1), 6, 60)
            d.box.Size     = Vector2.new(size, size)
            d.box.Position = Vector2.new(screen.X - size * 0.5, screen.Y - size * 0.5)
            d.box.Visible  = CFG.ItemBox

            local isNew = d.newUntil and d.newUntil > 0 and t < d.newUntil
            local prefix = isNew and "[NEW] " or ""
            d.text.Color    = isNew and CFG.ColorNew or d.baseColor
            d.text.Text     = string.format("%s%s  [%dm]", prefix, cleanName, math.floor(dist))
            d.text.Position = Vector2.new(screen.X, screen.Y - size * 0.5 - 14)
            d.text.Visible  = CFG.ItemText
        end)
        if not ok then d.text.Visible = false d.box.Visible = false end
    end
end

--=============================================================================
-- ALIVE TRACKING
--=============================================================================
local _knownAlive         = {}
local _lastAliveChangeAt  = _scriptStart
local _aliveInitialized   = false

local function updateAliveTracking()
    local currentAlive = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlivePlayer(p) then
            currentAlive[p] = true
        end
    end

    local newAlive = {}
    for p in pairs(currentAlive) do
        if not _knownAlive[p] then
            newAlive[#newAlive + 1] = p
        end
    end

    local removedCount = 0
    for p in pairs(_knownAlive) do
        if not currentAlive[p] then
            removedCount = removedCount + 1
            _knownAlive[p] = nil
        end
    end

    local quiet = _aliveInitialized and (now() - _lastAliveChangeAt) >= CFG.QuietSeconds
    if #newAlive > 0 or removedCount > 0 then
        _lastAliveChangeAt = now()
    end

    for _, p in ipairs(newAlive) do
        _knownAlive[p] = true
    end

    if CFG.DebugTeams then
        local names = {}
        for p in pairs(currentAlive) do names[#names + 1] = tostring(p.Name) end
        print(string.format("[%s team-debug] alive=%d (%s) new=%d quiet=%s",
            VERSION, #names, table.concat(names, ","),
            #newAlive, tostring(quiet)))
    end

    if quiet and #newAlive > 0 then
        for _, p in ipairs(newAlive) do
            pcall(function()
                notify(tostring(p.Name) .. " joined Alive", "MatchaESP", 2)
            end)
        end
    end

    _aliveInitialized = true
end

local function resetAliveState()
    _knownAlive        = {}
    _lastAliveChangeAt = now()
    _aliveInitialized  = false
end

--=============================================================================
-- PLAYER POLL
--=============================================================================
local lastPlayerPoll = -math.huge

local function pollPlayers()
    local t = now()
    if t - lastPlayerPoll < CFG.PlayerPollRate then return end
    lastPlayerPoll = t
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if not ok or not list then return end
    local current = {}
    for _, p in ipairs(list) do
        current[p] = true
        if p ~= LocalPlayer and not playerDrawings[p] then addPlayer(p) end
    end
    local toRemove = {}
    for p in pairs(playerDrawings) do
        if not current[p] then toRemove[#toRemove + 1] = p end
    end
    for _, p in ipairs(toRemove) do removePlayer(p) end
    pcall(updateAliveTracking)
end

--=============================================================================
-- GUI
--=============================================================================
local UI_AVAILABLE = type(UI) == "table" and type(UI.AddTab) == "function"

local _lastUIRead     = 0
local _lastNamesScan  = 0
local _knownItemNames = {}
local _createdToggles = {}

local function readUIConfig()
    if not UI_AVAILABLE then return end
    local t = now()
    if t - _lastUIRead < 0.1 then return end
    _lastUIRead = t
    local function tog(id, key)
        local ok, v = pcall(UI.GetValue, id)
        if ok and type(v) == "boolean" then CFG[key] = v end
    end
    local function num(id, key, lo, hi)
        local ok, v = pcall(UI.GetValue, id)
        if ok and type(v) == "number" then
            CFG[key] = clamp(v, lo or -1e9, hi or 1e9)
        end
    end
    tog("esp_pbox",   "PlayerBox")
    tog("esp_pline",  "PlayerSnapline")
    tog("esp_pname",  "PlayerName")
    tog("esp_php",    "PlayerHealth")
    tog("esp_pdist",  "PlayerDistance")
    num("esp_prange", "MaxPlayerDist", 10, 1000)

    tog("esp_ibox",   "ItemBox")
    tog("esp_itext",  "ItemText")
    num("esp_irange", "MaxItemDist", 1, 50)
end

local function refreshKnownItemNames()
    local t = now()
    if t - _lastNamesScan < 1.0 then return end
    _lastNamesScan = t
    for _, cname in ipairs(ITEM_CONTAINERS) do
        local container = Workspace:FindFirstChild(cname)
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if resolveItemPart(child, isWeapon(child.Name)) then
                    _knownItemNames[cleanItemName(child.Name)] = true
                else
                    for _, sub in ipairs(child:GetChildren()) do
                        if resolveItemPart(sub, isWeapon(sub.Name)) then
                            _knownItemNames[cleanItemName(sub.Name)] = true
                        end
                    end
                end
            end
        end
    end
end

local function mkToggle(sec, id, label, default)
    if _createdToggles[id] then return end
    _createdToggles[id] = true
    pcall(function() sec:Toggle(id, label, default) end)
end

local function mkSliderInt(sec, id, label, min, max, default)
    if _createdToggles[id] then return end
    _createdToggles[id] = true
    pcall(function() sec:SliderInt(id, label, min, max, default) end)
end

if UI_AVAILABLE then
    pcall(function()
        UI.AddTab("ESP", function(tab)
            local psec = tab:Section("Player ESP", "Left")
            mkToggle(psec,   "esp_pbox",   "Boxes",     true)
            mkToggle(psec,   "esp_pline",  "Tracers",   true)
            mkToggle(psec,   "esp_pname",  "Names",     true)
            mkToggle(psec,   "esp_php",    "Health",    true)
            mkToggle(psec,   "esp_pdist",  "Distance",  true)
            mkSliderInt(psec,"esp_prange", "Player Range", 50, 1000, 500)

            local isec = tab:Section("Item ESP", "Right")
            mkToggle(isec,    "esp_ibox",   "Boxes", true)
            mkToggle(isec,    "esp_itext",  "Text",  true)
            mkSliderInt(isec, "esp_irange", "Item Range", 1, 50, 50)

            refreshKnownItemNames()
            local sortedNames = {}
            for name in pairs(_knownItemNames) do
                sortedNames[#sortedNames + 1] = name
            end
            table.sort(sortedNames)
            for _, name in ipairs(sortedNames) do
                local id = "itm_" .. name:gsub("[^%w]", "_")
                mkToggle(isec, id, name, true)
            end
        end)
    end)
else
    print(string.format("[MatchaESP %s] UI library not available - using CFG defaults only", VERSION))
end

--=============================================================================
-- RENDER FRAME
--=============================================================================
local function renderFrame(_dt)
    readUIConfig()
    pcall(pollPlayers)
    for player, d in pairs(playerDrawings) do
        local ok = pcall(renderPlayer, player, d)
        if not ok then hidePlayer(d) end
    end
    local t = now()
    if t - lastItemScan >= CFG.ItemRescanRate then
        lastItemScan = t
        pcall(scanItems)
    end
    pcall(renderItems)
end

--=============================================================================
-- BOOT
--=============================================================================
do
    local ok, list = pcall(function() return Players:GetPlayers() end)
    if ok and list then for _, p in ipairs(list) do addPlayer(p) end end
end
pcall(scanItems)

currentPhase = getPhase()
startPhaseWatcher({
    onPhaseChange = function(p) currentPhase = p end,
    onTick        = function(p) currentPhase = p end,
    onRoundStart  = function(prev)
        resetItemState()
        resetAliveState()
        print(string.format("[MatchaESP %s] Round started (from %s) - state reset",
            VERSION, tostring(prev)))
    end,
    onRoundEnd = function(_next)
        clearAllNewTags()
    end,
})

do
    local spawnFn = (type(task) == "table" and type(task.spawn) == "function") and task.spawn or spawn
    if type(spawnFn) == "function" then
        spawnFn(function()
            for _ = 1, 20 do
                wait(0.25)
                if currentPhase ~= "unknown" then
                    print(string.format("[MatchaESP %s] Phase OK - current: %s",
                        VERSION, currentPhase))
                    return
                end
            end
            print(string.format("[MatchaESP %s] Phase = unknown after 5s. HUD names may differ.", VERSION))
        end)
    end
end

local renderConn
if RunService then
    renderConn = safeConnect(RunService.RenderStepped, renderFrame)
    if not renderConn then renderConn = safeConnect(RunService.Heartbeat, renderFrame) end
    if not renderConn then renderConn = safeConnect(RunService.Stepped, renderFrame) end
end

_G.MatchaESP_Running = true
if not renderConn then
    print(string.format("[MatchaESP %s] No render event found, using wait() loop", VERSION))
    task.spawn(function()
        while _G.MatchaESP_Running do
            pcall(renderFrame)
            wait(0.03)
        end
    end)
end

--=============================================================================
-- UNLOAD
--=============================================================================
_G.MatchaESP_Unload = function()
    _G.MatchaESP_Running = false
    pcall(stopPhaseWatcher)
    if renderConn then pcall(function() renderConn:Disconnect() end) end
    for player in pairs(playerDrawings) do removePlayer(player) end
    for inst, d in pairs(itemDrawings) do
        removeDrawing(d.text)
        removeDrawing(d.box)
        itemDrawings[inst] = nil
    end
    pcall(function() UI.RemoveTab("ESP") end)
    print(string.format("[MatchaESP %s] Unloaded.", VERSION))
end

pcall(function()
    notify("Alive + Item ESP " .. VERSION .. " loaded", "MatchaESP", 4)
end)
print(string.format("[MatchaESP %s] Loaded - Alive team only - Items: Drops / RoundLoot - ItemDist=%d",
    VERSION, CFG.MaxItemDist))
