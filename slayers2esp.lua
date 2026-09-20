--==============================================================
--   Made by d.x.z.
--   Sea Crystal + Lost Page + Spider Lily + Horse + Coin ESP
--   Version 4.4  (FINAL -TBD)
--   - Coin drawings are now fully removed when their coin
--     disappears, instead of just being hidden
--   - Coin slots below the current highest index are cleaned
--     up automatically
--==============================================================

local CONFIG = {
    Version         = "4.4",
    PlaceId         = 136406881576517,
    CrystalRange    = 500,
    Slots           = { 1, 2, 3, 4, 5 },
    SpiderLilySlots = { 1, 2, 3, 4 },

    FastRefresh     = 0.15,
    SlowRefresh     = 0.75,
    LilyScanRefresh = 1.0,
    CoinScanRefresh = 0.5,

    CoinPrefix      = "Coin",

    -- How many consecutive scans a coin must be missing before
    -- we remove its drawings. 2 = ~1s at default CoinScanRefresh.
    CoinMissingThreshold = 2,

    BoxSize = Vector2.new(20, 20),
    Offset  = { Name = Vector2.new(10, -16), Dist = Vector2.new(10, 22) },
    Font    = { Name = Drawing.Fonts.System or 0, Dist = Drawing.Fonts.UI or 0 },

    Palette = {
        Crystal        = Color3.fromRGB(120, 200, 255),
        Page           = Color3.fromRGB(181, 137, 84),
        SpiderLilyRed  = Color3.fromRGB(255, 120, 200),
        SpiderLilyBlue = Color3.fromRGB(40, 70, 255),
        Horse          = Color3.fromRGB(255, 220, 100),
        Coin           = Color3.fromRGB(220, 140, 60),
    },

    Credit = "d.x.z.",
    Title  = "Sea Crystal + Lost Page + Spider Lily + Horse + Coin ESP",
    Debug  = false,
}

if game.PlaceId ~= CONFIG.PlaceId then
    warn(("[ESP] Wrong place id: %s"):format(tostring(game.PlaceId)))
    return
end

print(("[ESP] Made by %s - v%s"):format(CONFIG.Credit, CONFIG.Version))
pcall(function()
    notify("Made by " .. CONFIG.Credit, CONFIG.Title .. " v" .. CONFIG.Version, 5)
end)

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local WKS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local PLR = game:GetService("Players")
local ME  = PLR.LocalPlayer

local CAM = WKS.CurrentCamera
local W2S = (type(WorldToScreen) == "function" and WorldToScreen)
    or function(p)
        local s, o = CAM:WorldToViewportPoint(p)
        return Vector2.new(s.X, s.Y), o
    end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function getAddress(obj)
    local a = 0
    pcall(function() a = obj.Address end)
    return a or 0
end

local function getName(obj)
    local n = "?"
    pcall(function() n = obj.Name end)
    return n or "?"
end

local function getPosition(part)
    local p
    pcall(function() p = part.Position end)
    return p
end

local function getColor(part)
    local c
    pcall(function() c = part.Color end)
    return c
end

local function getSizeMagnitude(part)
    local sz
    pcall(function() sz = part.Size end)
    if not sz then return 0 end
    local m = 0
    pcall(function() m = sz.Magnitude end)
    return m or 0
end

----------------------------------------------------------------
-- Drawing factory
----------------------------------------------------------------
local function draw(kind, props)
    local d = Drawing.new(kind)
    for k, v in next, props do
        pcall(function() d[k] = v end)
    end
    return d
end

----------------------------------------------------------------
-- Tracker factory
----------------------------------------------------------------
local function tracker(spec)
    local self = {
        spec       = spec,
        slots      = spec.slots or CONFIG.Slots,
        entries    = {},
        draws      = {},
        found      = -1,
        seen       = {},
        baseline   = {},
        slotColors = {},
    }

    for _, i in ipairs(self.slots) do
        local labelText = spec.label
        if spec.numbered then labelText = spec.label .. i end

        self.entries[i] = { part = nil, pos = nil, dist = math.huge, text = "" }
        self.seen[i] = nil
        self.draws[i] = {
            box  = draw("Square", { Color = spec.color, Size = CONFIG.BoxSize, Visible = false }),
            name = draw("Text", {
                Color = spec.color, Text = labelText,
                Font = CONFIG.Font.Name, Size = 14,
                Center = true, Outline = true, Visible = false,
            }),
            dist = draw("Text", {
                Color = spec.color, Text = "",
                Font = CONFIG.Font.Dist, Size = 13,
                Center = true, Outline = true, Visible = false,
            }),
        }
    end

    return self
end

----------------------------------------------------------------
-- Finders
----------------------------------------------------------------
local finder = {}

function finder.seaCrystal(n)
    local obj = WKS:FindFirstChild("Sea Crystal" .. n)
            or WKS:FindFirstChild("Sea Crystal " .. n)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj.PrimaryPart then return obj.PrimaryPart end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

function finder.lostPage(n)
    local holder = WKS:FindFirstChild("Lost Page" .. n)
    if not holder then return nil end
    local pages = holder:FindFirstChild("Pages") or holder
    if pages:IsA("BasePart") then return pages end
    if pages.PrimaryPart then return pages.PrimaryPart end
    for _, d in ipairs(pages:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

function finder.horse(_)
    local debree = WKS:FindFirstChild("Debree")
    if not debree then return nil end
    local regions = debree:FindFirstChild("Regions")
    if not regions then return nil end
    local misc = regions:FindFirstChild("Misc")
    if not misc then return nil end
    local npcs = misc:FindFirstChild("ActiveNpcs")
    if not npcs then return nil end
    local horseHolder = npcs:FindFirstChild("Horse")
    if not horseHolder then return nil end
    local horse = horseHolder:FindFirstChild("Horse")
    if not horse then return nil end
    local head = horse:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head end

    if horse.PrimaryPart then return horse.PrimaryPart end
    for _, d in ipairs(horse:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

----------------------------------------------------------------
-- Spider Lily helpers
----------------------------------------------------------------
local STEM_NAME_HINTS = {
    "stem", "leaf", "leaves", "stalk", "branch",
    "root", "trunk", "grass", "foliage",
}

local function nameLooksLikeStem(name)
    if type(name) ~= "string" then return false end
    local low = string.lower(name)
    for i = 1, #STEM_NAME_HINTS do
        if string.find(low, STEM_NAME_HINTS[i], 1, true) then
            return true
        end
    end
    return false
end

local function classifyColor(col)
    if not col then return "other" end
    local r, g, b
    pcall(function() r = col.R * 255 end)
    pcall(function() g = col.G * 255 end)
    pcall(function() b = col.B * 255 end)
    if not r or not g or not b then return "other" end
    if g > r + 15 and g > b + 15 then return "green" end
    if r > g + 25 and r > b + 25 then return "red"   end
    if b > r + 25 and b > g + 25 then return "blue"  end
    return "other"
end

local function analyseLily(lily)
    if not lily then return nil, nil end

    local redW, blueW = 0, 0
    local redBest, redBestW = nil, 0
    local blueBest, blueBestW = nil, 0

    local ok, descs = pcall(function() return lily:GetDescendants() end)
    if not ok or not descs then return nil, nil end

    for _, d in ipairs(descs) do
        local isPart = false
        pcall(function() isPart = d:IsA("BasePart") end)
        if isPart then
            local dn = getName(d)
            if not nameLooksLikeStem(dn) then
                local col = getColor(d)
                if col then
                    local kind = classifyColor(col)
                    if kind == "red" or kind == "blue" then
                        local w = getSizeMagnitude(d)
                        if w <= 0 then w = 1 end
                        if kind == "red" then
                            redW = redW + w
                            if w > redBestW then redBest, redBestW = d, w end
                        else
                            blueW = blueW + w
                            if w > blueBestW then blueBest, blueBestW = d, w end
                        end
                    end
                end
            end
        end
    end

    if redW == 0 and blueW == 0 then return nil, nil end
    if blueW >= redW then return "blue", blueBest end
    return "red", redBest
end

----------------------------------------------------------------
-- Lily scan cache
----------------------------------------------------------------
local _lilyResults = {}
local _lilyNext    = 0

local function scanLilies()
    local now = tick()
    if now < _lilyNext then return _lilyResults end
    _lilyNext = now + CONFIG.LilyScanRefresh

    local debree = WKS:FindFirstChild("Debree")
    if not debree then
        _lilyResults = {}
        return _lilyResults
    end

    local list = {}

    for _, c in ipairs(debree:GetChildren()) do
        local cn = getName(c)
        local low = string.lower(cn)
        if string.find(low, "spider", 1, true)
            and string.find(low, "lily", 1, true) then

            local hasRoot = false
            local ok, descs = pcall(function() return c:GetDescendants() end)
            if ok and descs then
                local partCount = 0
                for _, d in ipairs(descs) do
                    local isPart = false
                    pcall(function() isPart = d:IsA("BasePart") end)
                    if isPart then partCount = partCount + 1 end
                    if not hasRoot and getName(d) == "RootPart" then
                        hasRoot = true
                    end
                end

                if hasRoot and partCount >= 3 then
                    local flavour, anchor = analyseLily(c)
                    if anchor then
                        list[#list + 1] = {
                            model   = c,
                            flavour = flavour,
                            anchor  = anchor,
                            address = getAddress(c),
                        }
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.address < b.address end)

    if CONFIG.Debug then
        print(("[Lily] scan: %d qualifying lilies"):format(#list))
        for i, e in ipairs(list) do
            print(("  [Lily] slot %d: %s  flavour=%s  addr=0x%X"):format(
                i, getName(e.model), tostring(e.flavour), e.address
            ))
        end
    end

    _lilyResults = list
    return list
end

----------------------------------------------------------------
-- DYNAMIC COIN MANAGER
--   Auto-creates slots for Coin<N>. Removes drawings when a
--   coin disappears (collected) so nothing lingers.
----------------------------------------------------------------
local CoinManager = {
    entries     = {},   -- [index] = {part,pos,dist,text}
    draws       = {},   -- [index] = {box,name,dist}
    seen        = {},   -- [index] = last present bool
    baseline    = {},   -- [index] = was-absent-at-first-tick
    missCount   = {},   -- [index] = consecutive missing scans
    lastTotal   = -1,
}

local function ensureCoinDrawings(index)
    if CoinManager.draws[index] then return end
    CoinManager.draws[index] = {
        box  = draw("Square", {
            Color = CONFIG.Palette.Coin, Size = CONFIG.BoxSize, Visible = false
        }),
        name = draw("Text", {
            Color = CONFIG.Palette.Coin,
            Text  = CONFIG.CoinPrefix .. index,
            Font  = CONFIG.Font.Name, Size = 14,
            Center = true, Outline = true, Visible = false,
        }),
        dist = draw("Text", {
            Color = CONFIG.Palette.Coin, Text = "",
            Font  = CONFIG.Font.Dist, Size = 13,
            Center = true, Outline = true, Visible = false,
        }),
    }
end

-- Fully remove a coin slot's drawings & tracking state.
local function destroyCoinSlot(index)
    local d = CoinManager.draws[index]
    if d then
        pcall(function() d.box:Remove()  end)
        pcall(function() d.name:Remove() end)
        pcall(function() d.dist:Remove() end)
        CoinManager.draws[index] = nil
    end
    CoinManager.entries[index]   = nil
    CoinManager.seen[index]      = nil
    CoinManager.baseline[index]  = nil
    CoinManager.missCount[index] = nil

    if CONFIG.Debug then
        print(("[Coin] slot %d cleared"):format(index))
    end
end

local function scanCoins()
    local map = {}
    local highest = 0

    local ok, children = pcall(function() return WKS:GetChildren() end)
    if not ok or not children then return map, highest end

    for _, c in ipairs(children) do
        local n = getName(c)
        local numStr = string.match(n, "^" .. CONFIG.CoinPrefix .. "(%d+)$")
        if numStr then
            local num = tonumber(numStr)
            if num then
                local part = nil
                if c:IsA("BasePart") then
                    part = c
                elseif c.PrimaryPart then
                    part = c.PrimaryPart
                else
                    for _, d in ipairs(c:GetDescendants()) do
                        if d:IsA("BasePart") then
                            part = d
                            break
                        end
                    end
                end
                if part then
                    map[num] = part
                    if num > highest then highest = num end
                end
            end
        end
    end

    return map, highest
end

local _coinNext    = 0
local _coinCache   = {}
local _coinHighest = 0

local function getCoins()
    local now = tick()
    if now < _coinNext then return _coinCache, _coinHighest end
    _coinNext = now + CONFIG.CoinScanRefresh

    local map, highest = scanCoins()
    _coinCache   = map
    _coinHighest = highest
    return map, highest
end

local function refreshCoins(hrp)
    local found, highest = getCoins()
    local hrpPos = hrp and getPosition(hrp) or nil

    -- Determine which indices are currently alive
    local alive = {}
    local actualHighest = 0
    for i, part in pairs(found) do
        if part and part.Parent then
            alive[i] = true
            if i > actualHighest then actualHighest = i end
        end
    end

    -- Grow drawings for any new index
    for i = 1, actualHighest do
        if alive[i] then
            ensureCoinDrawings(i)
        end
    end

    -- Refresh each alive slot
    for i = 1, actualHighest do
        if alive[i] then
            local e = CoinManager.entries[i]
            if not e then
                e = { part = nil, pos = nil, dist = math.huge, text = "" }
                CoinManager.entries[i] = e
            end

            local part = found[i]
            e.part = part

            local pos = getPosition(part)
            if pos then e.pos = pos end

            if hrpPos and e.pos then
                local dist
                pcall(function() dist = (hrpPos - e.pos).Magnitude end)
                if dist then
                    e.dist = dist
                    e.text = ("%.1f studs"):format(dist)
                else
                    e.dist, e.text = math.huge, ""
                end
            else
                e.dist, e.text = math.huge, ""
            end
        end
    end

    -- Update miss counters and clean up dead slots
    -- Walk a snapshot of the current indices, not the live table,
    -- because destroyCoinSlot mutates the table.
    local indices = {}
    for i, _ in pairs(CoinManager.draws) do
        indices[#indices + 1] = i
    end

    for _, i in ipairs(indices) do
        if alive[i] then
            CoinManager.missCount[i] = 0
        else
            local mc = (CoinManager.missCount[i] or 0) + 1
            CoinManager.missCount[i] = mc
            if mc >= CONFIG.CoinMissingThreshold then
                destroyCoinSlot(i)
            end
        end
    end
end

local function reportCoins(force)
    local found = _coinCache
    local highest = _coinHighest

    -- Determine live set (using actual parent check)
    local alive = {}
    local total = 0
    for i = 1, highest do
        local part = found[i]
        if part and part.Parent then
            alive[i] = true
            total = total + 1
        end
    end

    -- Live pickups: seen[i] was true, now gone
    local live = {}
    for i = 1, highest do
        local present = alive[i] and true or false
        local seen = CoinManager.seen[i]

        if seen == nil then
            CoinManager.seen[i]     = present
            CoinManager.baseline[i] = not present
        elseif seen and not present then
            live[#live + 1] = i
            CoinManager.seen[i] = false
        elseif not seen and present then
            CoinManager.seen[i] = true
        end
    end

    if not force and #live > 0 then
        for _, i in ipairs(live) do
            print(("[Quest] %s%d COLLECTED JUST NOW  (%d present)"):format(
                CONFIG.CoinPrefix, i, total
            ))
        end
    end

    local changed = force or total ~= CoinManager.lastTotal or #live > 0
    if not changed then return end
    CoinManager.lastTotal = total

    if total > 0 then
        local names = {}
        for i = 1, highest do
            if alive[i] then names[#names + 1] = CONFIG.CoinPrefix .. i end
        end
        print(("[Quest] Coins present: %d  [%s]"):format(
            total, table.concat(names, ", ")
        ))
    else
        print("[Quest] Coins present: 0")
    end
end

local function renderCoins(hrp)
    local hrpPos = hrp and getPosition(hrp) or nil

    for i, e in pairs(CoinManager.entries) do
        local d = CoinManager.draws[i]
        if d then
            local show = e.part and e.part.Parent and e.pos and hrpPos
            if show then
                local sp, onScreen = W2S(e.pos)
                if onScreen then
                    local boxPos = sp - CONFIG.BoxSize
                    d.box.Position  = boxPos
                    d.name.Position = boxPos + CONFIG.Offset.Name
                    d.dist.Position = boxPos + CONFIG.Offset.Dist
                    d.dist.Text     = e.text
                    d.box.Visible, d.name.Visible, d.dist.Visible = true, true, true
                elseif d.box.Visible then
                    d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
                end
            elseif d.box.Visible then
                d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
            end
        end
    end
end

----------------------------------------------------------------
-- Trackers
----------------------------------------------------------------
local Trackers = {
    Crystal = tracker({
        label = "Sea Crystal", color = CONFIG.Palette.Crystal,
        range = CONFIG.CrystalRange, finder = finder.seaCrystal,
        slots = CONFIG.Slots, numbered = true,
    }),
    Page = tracker({
        label = "Lost Page", color = CONFIG.Palette.Page,
        range = nil, finder = finder.lostPage,
        slots = CONFIG.Slots, numbered = true,
    }),
    SpiderLily = tracker({
        label = "Spider Lily", color = CONFIG.Palette.SpiderLilyRed,
        range = nil, finder = function() return nil end,
        slots = CONFIG.SpiderLilySlots, numbered = false,
    }),
    Horse = tracker({
        label = "Horse", color = CONFIG.Palette.Horse,
        range = nil, finder = finder.horse,
        slots = { 1 }, numbered = false,
    }),
}

----------------------------------------------------------------
-- Lily slot colour
----------------------------------------------------------------
local function applyLilySlotColor(slot, flavour)
    local t = Trackers.SpiderLily
    if not t or not t.draws[slot] then return end

    local newColor, newLabel
    if flavour == "red" then
        newColor, newLabel = CONFIG.Palette.SpiderLilyRed,  "Red Spider Lily"
    elseif flavour == "blue" then
        newColor, newLabel = CONFIG.Palette.SpiderLilyBlue, "Blue Spider Lily"
    else
        return
    end

    if t.slotColors[slot] ~= newColor then
        t.slotColors[slot] = newColor
        local d = t.draws[slot]
        d.box.Color  = newColor
        d.name.Color = newColor
        d.dist.Color = newColor
        d.name.Text  = newLabel
    end
end

----------------------------------------------------------------
-- HRP + fixed-slot refresh
----------------------------------------------------------------
local function getHrp()
    local c = ME.Character
    if not c then return nil end
    local p = c.PrimaryPart
    if p and p.Parent then return p end
    local ok, found = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    if ok and found and found.Parent then return found end
    return nil
end

local function refreshTracker(t, hrp)
    local hrpPos = hrp and getPosition(hrp) or nil

    for _, i in ipairs(t.slots) do
        local e = t.entries[i]

        if not (e.part and e.part.Parent) then
            local ok, part = pcall(t.spec.finder, i)
            e.part = (ok and part) or nil
        end

        if e.part and e.part.Parent then
            local pos = getPosition(e.part)
            if pos then e.pos = pos end

            if hrpPos and e.pos then
                local dist
                pcall(function() dist = (hrpPos - e.pos).Magnitude end)
                if dist then
                    e.dist = dist
                    e.text = ("%.1f studs"):format(dist)
                else
                    e.dist, e.text = math.huge, ""
                end
            else
                e.dist, e.text = math.huge, ""
            end
        else
            e.part, e.pos, e.dist, e.text = nil, nil, math.huge, ""
        end
    end
end

local function countFound(t)
    local n = 0
    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        if e.part and e.part.Parent then n = n + 1 end
    end
    return n
end

local function detect(t)
    local live, respawned = {}, {}
    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        local present = (e.part and e.part.Parent) and true or false
        if t.seen[i] == nil then
            t.seen[i] = present
            t.baseline[i] = not present
        elseif t.seen[i] and not present then
            live[#live + 1] = i
            t.seen[i] = false
        elseif not t.seen[i] and present then
            respawned[#respawned + 1] = i
            t.seen[i] = true
        end
    end
    return live, respawned
end

----------------------------------------------------------------
-- Reporters
----------------------------------------------------------------
local function reportSpiderLily(force)
    local sLive = detect(Trackers.SpiderLily)
    local s = countFound(Trackers.SpiderLily)
    local prev = Trackers.SpiderLily.found

    if not force then
        for _, _ in ipairs(sLive) do
            print("[Quest] Spider Lily COLLECTED JUST NOW")
        end
    end

    if not force and s == prev then return end
    Trackers.SpiderLily.found = s

    if s > 0 then
        local parts = {}
        for _, slot in ipairs(Trackers.SpiderLily.slots) do
            local e = Trackers.SpiderLily.entries[slot]
            if e.part and e.part.Parent then
                local c = Trackers.SpiderLily.slotColors[slot]
                local flavour = (c == CONFIG.Palette.SpiderLilyRed) and "Red" or "Blue"
                parts[#parts + 1] = ("slot %d (%s)"):format(slot, flavour)
            end
        end
        print(("[Quest] Spider Lilies present: %d  [%s]"):format(
            s, table.concat(parts, ", ")
        ))
    end
end

local function reportQuests(force)
    local cLive, _ = detect(Trackers.Crystal)
    local pLive, _ = detect(Trackers.Page)

    local c = countFound(Trackers.Crystal)
    local p = countFound(Trackers.Page)

    local prevC = Trackers.Crystal.found
    local prevP = Trackers.Page.found

    if not force then
        for _, i in ipairs(cLive) do
            print(("[Quest] Sea Crystal%d COLLECTED JUST NOW  (%d/5 left)"):format(i, c))
        end
        for _, i in ipairs(pLive) do
            print(("[Quest] Lost Page%d COLLECTED JUST NOW  (%d/5 left)"):format(i, p))
        end
    end

    local changed = force or c ~= prevC or p ~= prevP
        or #cLive > 0 or #pLive > 0
    if not changed then return end

    Trackers.Crystal.found = c
    Trackers.Page.found    = p

    print(("[Quest] Sea Crystals: %d/5 present, %d/5 gone"):format(c, 5 - c))
    print(("[Quest] Lost Pages:   %d/5 present, %d/5 gone"):format(p, 5 - p))

    if not force then
        if prevC > 0 and c == 0 then
            pcall(function() notify("Sea Crystal quest COMPLETE!", "Quest", 5) end)
        end
        if prevP > 0 and p == 0 then
            pcall(function() notify("Lost Page quest COMPLETE!", "Quest", 5) end)
        end
    end
end

local function reportHorse(force)
    local hLive = detect(Trackers.Horse)
    local h = countFound(Trackers.Horse)
    local prev = Trackers.Horse.found

    if not force and #hLive > 0 then
        print("[Quest] Horse gone")
    end

    if not force and h == prev then return end
    Trackers.Horse.found = h

    if h > 0 then
        print("[Quest] Horse present")
    end
end

----------------------------------------------------------------
-- Fast loop: Spider Lilies + Horse
----------------------------------------------------------------
task.spawn(function()
    while true do
        pcall(function()
            local hrp = getHrp()

            local models = scanLilies()
            local t = Trackers.SpiderLily
            for i = 1, #t.slots do
                local entry = models[i]
                local e = t.entries[i]
                if entry then
                    applyLilySlotColor(i, entry.flavour)
                    e.part = entry.anchor
                else
                    e.part = nil
                end
            end

            refreshTracker(t, hrp)
            refreshTracker(Trackers.Horse, hrp)

            reportSpiderLily(false)
            reportHorse(false)
        end)
        task.wait(CONFIG.FastRefresh)
    end
end)

----------------------------------------------------------------
-- Slow loop: Sea Crystals + Lost Pages + Coins
----------------------------------------------------------------
task.spawn(function()
    while true do
        pcall(function()
            local hrp = getHrp()
            refreshTracker(Trackers.Crystal, hrp)
            refreshTracker(Trackers.Page, hrp)

            refreshCoins(hrp)
            reportCoins(false)
            reportQuests(false)
        end)
        task.wait(CONFIG.SlowRefresh)
    end
end)

----------------------------------------------------------------
-- Baseline
----------------------------------------------------------------
task.spawn(function()
    task.wait(2)
    pcall(function()
        local hrp = getHrp()
        refreshTracker(Trackers.Crystal, hrp)
        refreshTracker(Trackers.Page, hrp)

        local models = scanLilies()
        local t = Trackers.SpiderLily
        for i = 1, #t.slots do
            local entry = models[i]
            local e = t.entries[i]
            if entry then
                applyLilySlotColor(i, entry.flavour)
                e.part = entry.anchor
            end
        end
        refreshTracker(t, hrp)
        refreshTracker(Trackers.Horse, hrp)

        refreshCoins(hrp)

        reportSpiderLily(true)
        reportQuests(true)
        reportHorse(true)
        reportCoins(true)
    end)
end)

----------------------------------------------------------------
-- Renderer
----------------------------------------------------------------
local function render(t, hrp)
    local hrpPos = hrp and getPosition(hrp) or nil

    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        local d = t.draws[i]

        local show = e.part and e.part.Parent
            and e.pos
            and hrpPos
            and (t.spec.range == nil or e.dist <= t.spec.range)

        if show then
            local sp, onScreen = W2S(e.pos)
            if onScreen then
                local boxPos = sp - CONFIG.BoxSize
                d.box.Position  = boxPos
                d.name.Position = boxPos + CONFIG.Offset.Name
                d.dist.Position = boxPos + CONFIG.Offset.Dist
                d.dist.Text     = e.text
                d.box.Visible, d.name.Visible, d.dist.Visible = true, true, true
            elseif d.box.Visible then
                d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
            end
        elseif d.box.Visible then
            d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
        end
    end
end

RUN.RenderStepped:Connect(function()
    local hrp = getHrp()
    pcall(function() render(Trackers.Crystal, hrp) end)
    pcall(function() render(Trackers.Page, hrp) end)
    pcall(function() render(Trackers.SpiderLily, hrp) end)
    pcall(function() render(Trackers.Horse, hrp) end)
    pcall(function() renderCoins(hrp) end)
end)
