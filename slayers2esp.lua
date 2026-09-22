--==============================================================
--   Made by d.x.z.
--   Slayers 2 ESP - Final (with Final Selection)
--   Version 1.0
--
--   Place 136406881576517:
--     Sea Crystals, Lost Pages, Spider Lilies, Horse, Coins, Gemstones
--   Place 75556147183481:
--     Apples, Bananas, Grapes, Nichirin Katanas
--==============================================================

local CONFIG = {
    Version = "1.0",

    Places = {
        [136406881576517] = "Slayers 2",
        [75556147183481]  = "Final Selection Exam",
    },

    FastRefresh        = 0.15,
    SlowRefresh        = 0.75,
    LilyScanRefresh    = 1.0,
    DynamicScanRefresh = 0.5,
    MissingThreshold   = 2,

    CrystalRange = 500,

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
        Gemstone       = Color3.fromRGB(190, 120, 255),
        Apple          = Color3.fromRGB(220,  70,  70),
        Banana         = Color3.fromRGB(240, 220,  80),
        Grapes         = Color3.fromRGB(160,  90, 220),
        Nichirin       = Color3.fromRGB(200, 230, 255),
    },

    Credit = "d.x.z.",
    Debug  = false,
}

local PLACE_NAME = CONFIG.Places[game.PlaceId]
if not PLACE_NAME then
    warn(("[ESP] Unsupported place id: %s"):format(tostring(game.PlaceId)))
    return
end

print(("[ESP] Made by %s - v%s  [%s]"):format(CONFIG.Credit, CONFIG.Version, PLACE_NAME))
pcall(function()
    notify("Made by " .. CONFIG.Credit, "Unified ESP v" .. CONFIG.Version, 5)
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
-- Fixed-slot tracker
----------------------------------------------------------------
local function makeTracker(spec)
    local t = {
        spec       = spec,
        slots      = spec.slots,
        entries    = {},
        draws      = {},
        found      = -1,
        seen       = {},
        baseline   = {},
        slotColors = {},
    }

    for _, i in ipairs(t.slots) do
        local label = spec.numbered and (spec.label .. i) or spec.label

        t.entries[i] = { part = nil, pos = nil, dist = math.huge, text = "" }
        t.seen[i] = nil
        t.draws[i] = {
            box  = draw("Square", { Color = spec.color, Size = CONFIG.BoxSize, Visible = false }),
            name = draw("Text", {
                Color = spec.color, Text = label,
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

    return t
end

local function countFound(t)
    local n = 0
    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        if e.part and e.part.Parent then n = n + 1 end
    end
    return n
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

local function detectTracker(t)
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

local function renderTracker(t, hrp)
    local hrpPos = hrp and getPosition(hrp) or nil

    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        local d = t.draws[i]

        local show = e.part and e.part.Parent
            and e.pos and hrpPos
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

----------------------------------------------------------------
-- Dynamic manager (variable-count items with cleanup)
----------------------------------------------------------------
local function makeManager(prefix, color, threshold, anchorPartName)
    local M = {
        prefix    = prefix,
        color     = color,
        threshold = threshold or CONFIG.MissingThreshold,
        anchor    = anchorPartName,

        entries   = {},
        draws     = {},
        seen      = {},
        missCount = {},
        lastTotal = -1,

        nextScan = 0,
        cache    = {},
        highest  = 0,
    }

    function M.ensureDrawings(i)
        if M.draws[i] then return end
        M.draws[i] = {
            box  = draw("Square", { Color = M.color, Size = CONFIG.BoxSize, Visible = false }),
            name = draw("Text", {
                Color = M.color, Text = M.prefix .. i,
                Font = CONFIG.Font.Name, Size = 14,
                Center = true, Outline = true, Visible = false,
            }),
            dist = draw("Text", {
                Color = M.color, Text = "",
                Font = CONFIG.Font.Dist, Size = 13,
                Center = true, Outline = true, Visible = false,
            }),
        }
    end

    function M.destroySlot(i)
        local d = M.draws[i]
        if d then
            pcall(function() d.box:Remove()  end)
            pcall(function() d.name:Remove() end)
            pcall(function() d.dist:Remove() end)
            M.draws[i] = nil
        end
        M.entries[i]   = nil
        M.seen[i]      = nil
        M.missCount[i] = nil
        if CONFIG.Debug then
            print(("[%s] slot %d cleared"):format(M.prefix, i))
        end
    end

    local function resolve(inst)
        if not inst then return nil end
        if M.anchor then
            local found = inst:FindFirstChild(M.anchor, true)
            if found and found:IsA("BasePart") then return found end
        end
        if inst:IsA("BasePart") then return inst end
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
        return nil
    end

    function M.scan()
        local map, highest = {}, 0
        local ok, children = pcall(function() return WKS:GetChildren() end)
        if not ok or not children then return map, highest end

        local safe = M.prefix:gsub("(%W)", "%%%1")

        for _, c in ipairs(children) do
            local n = getName(c)
            local numStr = string.match(n, "^" .. safe .. "(%d+)$")
            if numStr then
                local num = tonumber(numStr)
                if num then
                    local part = resolve(c)
                    if part then
                        map[num] = part
                        if num > highest then highest = num end
                    end
                end
            end
        end
        return map, highest
    end

    function M.get()
        local now = tick()
        if now < M.nextScan then return M.cache, M.highest end
        M.nextScan = now + CONFIG.DynamicScanRefresh
        local map, highest = M.scan()
        M.cache, M.highest = map, highest
        return map, highest
    end

    function M.refresh(hrp)
        local found, _ = M.get()
        local hrpPos = hrp and getPosition(hrp) or nil

        local alive, actualHighest = {}, 0
        for i, part in pairs(found) do
            if part and part.Parent then
                alive[i] = true
                if i > actualHighest then actualHighest = i end
            end
        end

        for i = 1, actualHighest do
            if alive[i] then M.ensureDrawings(i) end
        end

        for i = 1, actualHighest do
            if alive[i] then
                local e = M.entries[i]
                if not e then
                    e = { part = nil, pos = nil, dist = math.huge, text = "" }
                    M.entries[i] = e
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

        local indices = {}
        for i in pairs(M.draws) do indices[#indices + 1] = i end
        for _, i in ipairs(indices) do
            if alive[i] then
                M.missCount[i] = 0
            else
                local mc = (M.missCount[i] or 0) + 1
                M.missCount[i] = mc
                if mc >= M.threshold then M.destroySlot(i) end
            end
        end
    end

    function M.report(force)
        local found, highest = M.cache, M.highest
        local alive, total = {}, 0
        for i = 1, highest do
            local part = found[i]
            if part and part.Parent then
                alive[i] = true
                total = total + 1
            end
        end

        local live = {}
        for i = 1, highest do
            local present = alive[i] and true or false
            local seen = M.seen[i]
            if seen == nil then
                M.seen[i] = present
            elseif seen and not present then
                live[#live + 1] = i
                M.seen[i] = false
            elseif not seen and present then
                M.seen[i] = true
            end
        end

        if not force and #live > 0 then
            for _, i in ipairs(live) do
                print(("[Quest] %s%d COLLECTED JUST NOW  (%d present)"):format(
                    M.prefix, i, total))
            end
        end

        local changed = force or total ~= M.lastTotal or #live > 0
        if not changed then return end
        M.lastTotal = total

        if total > 0 then
            local names = {}
            for i = 1, highest do
                if alive[i] then names[#names + 1] = M.prefix .. i end
            end
            print(("[Quest] %s present: %d  [%s]"):format(
                M.prefix, total, table.concat(names, ", ")))
        else
            print(("[Quest] %s present: 0"):format(M.prefix))
        end
    end

    function M.render(hrp)
        local hrpPos = hrp and getPosition(hrp) or nil
        for i, e in pairs(M.entries) do
            local d = M.draws[i]
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

    return M
end

----------------------------------------------------------------
-- HRP
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

----------------------------------------------------------------
-- Active collections
----------------------------------------------------------------
local ActiveTrackers = {}
local ActiveManagers = {}
local FinalReporters = {}   -- list of functions to run on the slow loop

----------------------------------------------------------------
-- PLACE 1: Slayers 2 — Sea Crystal / Lost Page / Spider Lily / Horse /
--                  Coin / Gemstone
----------------------------------------------------------------
if PLACE_NAME == "Slayers 2" then

    -- Finders ------------------------------------------------------
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
        local holder = npcs:FindFirstChild("Horse")
        if not holder then return nil end
        local horse = holder:FindFirstChild("Horse")
        if not horse then return nil end
        local head = horse:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
        if horse.PrimaryPart then return horse.PrimaryPart end
        for _, d in ipairs(horse:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
        return nil
    end

    -- Spider Lily colour scanning --------------------------------
    local STEM_HINTS = {
        "stem","leaf","leaves","stalk","branch","root","trunk","grass","foliage",
    }

    local function isStem(name)
        if type(name) ~= "string" then return false end
        local low = string.lower(name)
        for i = 1, #STEM_HINTS do
            if string.find(low, STEM_HINTS[i], 1, true) then return true end
        end
        return false
    end

    local function classify(col)
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
                if not isStem(dn) then
                    local col = getColor(d)
                    if col then
                        local kind = classify(col)
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

    local _lilyResults, _lilyNext = {}, 0

    local function scanLilies()
        local now = tick()
        if now < _lilyNext then return _lilyResults end
        _lilyNext = now + CONFIG.LilyScanRefresh

        local debree = WKS:FindFirstChild("Debree")
        if not debree then _lilyResults = {} return _lilyResults end

        local list = {}
        for _, c in ipairs(debree:GetChildren()) do
            local low = string.lower(getName(c))
            if string.find(low, "spider", 1, true)
                and string.find(low, "lily", 1, true) then
                local hasRoot = false
                local ok, descs = pcall(function() return c:GetDescendants() end)
                if ok and descs then
                    local pc = 0
                    for _, d in ipairs(descs) do
                        local isPart = false
                        pcall(function() isPart = d:IsA("BasePart") end)
                        if isPart then pc = pc + 1 end
                        if not hasRoot and getName(d) == "RootPart" then
                            hasRoot = true
                        end
                    end
                    if hasRoot and pc >= 3 then
                        local flavour, anchor = analyseLily(c)
                        if anchor then
                            list[#list + 1] = {
                                model = c, flavour = flavour,
                                anchor = anchor, address = getAddress(c),
                            }
                        end
                    end
                end
            end
        end

        table.sort(list, function(a, b) return a.address < b.address end)
        _lilyResults = list
        return list
    end

    -- Fixed-slot trackers ----------------------------------------
    local CrystalTracker = makeTracker({
        label = "Sea Crystal", color = CONFIG.Palette.Crystal,
        range = CONFIG.CrystalRange, finder = finder.seaCrystal,
        slots = {1,2,3,4,5}, numbered = true,
    })
    local PageTracker = makeTracker({
        label = "Lost Page", color = CONFIG.Palette.Page,
        range = nil, finder = finder.lostPage,
        slots = {1,2,3,4,5}, numbered = true,
    })
    local LilyTracker = makeTracker({
        label = "Spider Lily", color = CONFIG.Palette.SpiderLilyRed,
        range = nil, finder = function() return nil end,
        slots = {1,2,3,4}, numbered = false,
    })
    local HorseTracker = makeTracker({
        label = "Horse", color = CONFIG.Palette.Horse,
        range = nil, finder = finder.horse,
        slots = {1}, numbered = false,
    })

    ActiveTrackers = { CrystalTracker, PageTracker, LilyTracker, HorseTracker }

    -- Dynamic managers --------------------------------------------
    local CoinMgr = makeManager(
        "Coin", CONFIG.Palette.Coin, CONFIG.MissingThreshold
    )
    local GemMgr = makeManager(
        "Gemstone", CONFIG.Palette.Gemstone, CONFIG.MissingThreshold,
        "Cube.009"
    )

    ActiveManagers = { CoinMgr, GemMgr }

    -- Lily slot colour helper -------------------------------------
    local function applyLilyColor(slot, flavour)
        if not LilyTracker.draws[slot] then return end
        local newColor, newLabel
        if flavour == "red" then
            newColor, newLabel = CONFIG.Palette.SpiderLilyRed, "Red Spider Lily"
        elseif flavour == "blue" then
            newColor, newLabel = CONFIG.Palette.SpiderLilyBlue, "Blue Spider Lily"
        else
            return
        end
        if LilyTracker.slotColors[slot] ~= newColor then
            LilyTracker.slotColors[slot] = newColor
            local d = LilyTracker.draws[slot]
            d.box.Color  = newColor
            d.name.Color = newColor
            d.dist.Color = newColor
            d.name.Text  = newLabel
        end
    end

    -- Fast loop (lily + horse) ------------------------------------
    task.spawn(function()
        while true do
            pcall(function()
                local hrp = getHrp()

                local models = scanLilies()
                for i = 1, #LilyTracker.slots do
                    local entry = models[i]
                    local e = LilyTracker.entries[i]
                    if entry then
                        applyLilyColor(i, entry.flavour)
                        e.part = entry.anchor
                    else
                        e.part = nil
                    end
                end

                refreshTracker(LilyTracker, hrp)
                refreshTracker(HorseTracker, hrp)

                -- Lily reporting
                local sLive = detectTracker(LilyTracker)
                local s = countFound(LilyTracker)
                if s ~= LilyTracker.found then
                    LilyTracker.found = s
                    if s > 0 then
                        local parts = {}
                        for _, slot in ipairs(LilyTracker.slots) do
                            local e = LilyTracker.entries[slot]
                            if e.part and e.part.Parent then
                                local c = LilyTracker.slotColors[slot]
                                local f = (c == CONFIG.Palette.SpiderLilyRed) and "Red" or "Blue"
                                parts[#parts + 1] = ("slot %d (%s)"):format(slot, f)
                            end
                        end
                        print(("[Quest] Spider Lilies present: %d  [%s]"):format(
                            s, table.concat(parts, ", ")))
                    end
                end
                for _, _ in ipairs(sLive) do
                    print("[Quest] Spider Lily COLLECTED JUST NOW")
                end

                -- Horse reporting
                local hLive = detectTracker(HorseTracker)
                local h = countFound(HorseTracker)
                if #hLive > 0 then print("[Quest] Horse gone") end
                if h ~= HorseTracker.found then
                    HorseTracker.found = h
                    if h > 0 then print("[Quest] Horse present") end
                end
            end)
            task.wait(CONFIG.FastRefresh)
        end
    end)

    -- Slow loop (crystals + pages + coins + gemstones) -----------
    local function slowPass(force)
        local hrp = getHrp()
        refreshTracker(CrystalTracker, hrp)
        refreshTracker(PageTracker, hrp)

        local cLive = detectTracker(CrystalTracker)
        local pLive = detectTracker(PageTracker)
        local c = countFound(CrystalTracker)
        local p = countFound(PageTracker)

        if not force then
            for _, i in ipairs(cLive) do
                print(("[Quest] Sea Crystal%d COLLECTED JUST NOW  (%d/5 left)"):format(i, c))
            end
            for _, i in ipairs(pLive) do
                print(("[Quest] Lost Page%d COLLECTED JUST NOW  (%d/5 left)"):format(i, p))
            end
        end

        if force or c ~= CrystalTracker.found or p ~= PageTracker.found
            or #cLive > 0 or #pLive > 0 then
            CrystalTracker.found = c
            PageTracker.found    = p
            print(("[Quest] Sea Crystals: %d/5 present, %d/5 gone"):format(c, 5 - c))
            print(("[Quest] Lost Pages:   %d/5 present, %d/5 gone"):format(p, 5 - p))
        end

        CoinMgr.refresh(hrp)
        CoinMgr.report(force)
        GemMgr.refresh(hrp)
        GemMgr.report(force)
    end

    FinalReporters[#FinalReporters + 1] = slowPass

    task.spawn(function()
        while true do
            pcall(function() slowPass(false) end)
            task.wait(CONFIG.SlowRefresh)
        end
    end)

----------------------------------------------------------------
-- PLACE 2: Final Selection Exam — Apple / Banana / Grapes / Nichirin Katana
----------------------------------------------------------------
elseif PLACE_NAME == "Final Selection Exam" then

    local AppleMgr = makeManager(
        "Apple", CONFIG.Palette.Apple, CONFIG.MissingThreshold
    )
    local BananaMgr = makeManager(
        "Banana", CONFIG.Palette.Banana, CONFIG.MissingThreshold
    )
    local GrapesMgr = makeManager(
        "Grapes", CONFIG.Palette.Grapes, CONFIG.MissingThreshold
    )
    local NichirinMgr = makeManager(
        "Nichirin Katana", CONFIG.Palette.Nichirin,
        CONFIG.MissingThreshold, "Place Holder - Nichirin"
    )

    ActiveManagers = { AppleMgr, BananaMgr, GrapesMgr, NichirinMgr }

    local function pass(force)
        local hrp = getHrp()
        for _, m in ipairs(ActiveManagers) do
            m.refresh(hrp)
            m.report(force)
        end
    end

    FinalReporters[#FinalReporters + 1] = pass

    task.spawn(function()
        while true do
            pcall(function() pass(false) end)
            task.wait(CONFIG.FastRefresh)
        end
    end)
end

----------------------------------------------------------------
-- Baseline
----------------------------------------------------------------
task.spawn(function()
    task.wait(2)
    pcall(function()
        for _, fn in ipairs(FinalReporters) do fn(true) end
    end)
end)

----------------------------------------------------------------
-- Renderer
----------------------------------------------------------------
RUN.RenderStepped:Connect(function()
    local hrp = getHrp()
    for _, t in ipairs(ActiveTrackers) do
        pcall(function() renderTracker(t, hrp) end)
    end
    for _, m in ipairs(ActiveManagers) do
        pcall(function() m.render(hrp) end)
    end
end)
