--==============================================================
--   Made by d.x.z.
--   Sea Crystal + Lost Page + Spider Lily ESP
--==============================================================

local CONFIG = {
    PlaceId      = 136406881576517,
    CrystalRange = 500,
    Slots        = { 1, 2, 3, 4, 5 },
    Refresh      = 0.3,
    BoxSize      = Vector2.new(20, 20),
    Offset       = { Name = Vector2.new(10, -16), Dist = Vector2.new(10, 22) },
    Font         = { Name = Drawing.Fonts.System or 0, Dist = Drawing.Fonts.UI or 0 },
    Palette      = {
        Crystal    = Color3.fromRGB(120, 200, 255),   -- light blue
        Page       = Color3.fromRGB(181, 137, 84),    -- aged-paper brown
        SpiderLily = Color3.fromRGB(255, 120, 200),   -- soft pink
    },
    Credit = "d.x.z.",
    Title  = "Sea Crystal + Lost Page + Spider Lily ESP",
}

if game.PlaceId ~= CONFIG.PlaceId then return end

print("[ESP] Made by " .. CONFIG.Credit)
pcall(function() notify("Made by " .. CONFIG.Credit, CONFIG.Title, 5) end)

----------------------------------------------------------------
-- Services & screen-space translator
----------------------------------------------------------------
local WKS = game:GetService("Workspace")
local RUN = game:GetService("RunService")
local PLR = game:GetService("Players")
local ME  = PLR.LocalPlayer

local CAM = WKS.CurrentCamera
local W2S = type(WorldToScreen) == "function" and WorldToScreen
    or function(p)
        local s, o = CAM:WorldToViewportPoint(p)
        return Vector2.new(s.X, s.Y), o
    end

----------------------------------------------------------------
-- Small drawing factory
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
        spec    = spec,
        slots   = spec.slots or CONFIG.Slots,
        entries = {},
        draws   = {},
        found   = -1,
        seen    = {},
        baselineDone = {},
    }

    for _, i in ipairs(self.slots) do
        local labelText = spec.label
        if spec.numbered then
            labelText = spec.label .. i
        end

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
-- Category finders
----------------------------------------------------------------
local finder = {}

function finder.seaCrystal(n)
    for _, pattern in ipairs({ "Sea Crystal%d", "Sea Crystal %d" }) do
        local obj = WKS:FindFirstChild(pattern:format(n))
        if obj then
            if obj:IsA("BasePart") then return obj end
            if obj.PrimaryPart then return obj.PrimaryPart end
            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("BasePart") then return d end
            end
        end
    end
end

function finder.lostPage(n)
    local holder = WKS:FindFirstChild("Lost Page" .. n)
    if not holder then return end

    local pages = holder:FindFirstChild("Pages") or holder
    if pages:IsA("BasePart") then return pages end
    if pages.PrimaryPart then return pages.PrimaryPart end

    for _, d in ipairs(pages:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
end

-- Path: Workspace.Debree."Spider Lily".RootPart
function finder.spiderLily(_)
    local debree = WKS:FindFirstChild("Debree")
    if not debree then return end

    local lily = debree:FindFirstChild("Spider Lily")
    if not lily then return end

    local root = lily:FindFirstChild("RootPart")
    if root and root:IsA("BasePart") then
        return root
    end

    if lily.PrimaryPart then return lily.PrimaryPart end
    for _, d in ipairs(lily:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
end

----------------------------------------------------------------
-- Instantiate trackers
----------------------------------------------------------------
local Trackers = {
    Crystal = tracker({
        label    = "Sea Crystal",
        color    = CONFIG.Palette.Crystal,
        range    = CONFIG.CrystalRange,
        finder   = finder.seaCrystal,
        slots    = CONFIG.Slots,
        numbered = true,
    }),
    Page = tracker({
        label    = "Lost Page",
        color    = CONFIG.Palette.Page,
        range    = nil,
        finder   = finder.lostPage,
        slots    = CONFIG.Slots,
        numbered = true,
    }),
    SpiderLily = tracker({
        label    = "Spider Lily",
        color    = CONFIG.Palette.SpiderLily,
        range    = nil,
        finder   = finder.spiderLily,
        slots    = { 1 },
        numbered = false,
    }),
}

----------------------------------------------------------------
-- Cache helpers
----------------------------------------------------------------
local function getHrp()
    local c = ME.Character
    return c and c.PrimaryPart
end

local function refresh(t, hrp)
    for _, i in ipairs(t.slots) do
        local e = t.entries[i]

        if not (e.part and e.part.Parent) then
            e.part = t.spec.finder(i)
        end

        if e.part and e.part.Parent then
            local ok, pos = pcall(function() return e.part.Position end)
            if ok then e.pos = pos end

            if hrp and e.pos then
                e.dist = (hrp.Position - e.pos).Magnitude
                e.text = string.format("%.1f studs", e.dist)
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

----------------------------------------------------------------
-- Detection pass
----------------------------------------------------------------
local function detect(t)
    local live, missing, respawned = {}, {}, {}

    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        local present = (e.part and e.part.Parent) and true or false

        if t.seen[i] == nil then
            t.seen[i] = present
            t.baselineDone[i] = not present
        elseif t.seen[i] and not present then
            live[#live + 1] = i
            t.seen[i] = false
        elseif not t.seen[i] and present then
            respawned[#respawned + 1] = i
            t.seen[i] = true
        end

        if not present then
            missing[#missing + 1] = i
        end
    end

    return live, missing, respawned
end

----------------------------------------------------------------
-- Progress reporter
----------------------------------------------------------------
local function report(force)
    local cLive, cMissing, cRespawn = detect(Trackers.Crystal)
    local pLive, pMissing, pRespawn = detect(Trackers.Page)
    local sLive, sMissing, sRespawn = detect(Trackers.SpiderLily)

    local c = countFound(Trackers.Crystal)
    local p = countFound(Trackers.Page)
    local s = countFound(Trackers.SpiderLily)

    -- Announce live collections
    if not force then
        for _, i in ipairs(cLive) do
            print(("[Quest] Sea Crystal%d COLLECTED JUST NOW  (%d/5 left)"):format(i, c))
        end
        for _, i in ipairs(pLive) do
            print(("[Quest] Lost Page%d COLLECTED JUST NOW  (%d/5 left)"):format(i, p))
        end
        if #sLive > 0 then
            print("[Quest] Spider Lily COLLECTED JUST NOW")
        end

        for _, i in ipairs(cRespawn) do
            print(("[Quest] Sea Crystal%d respawned"):format(i))
        end
        for _, i in ipairs(pRespawn) do
            print(("[Quest] Lost Page%d respawned"):format(i))
        end
        if #sRespawn > 0 then
            print("[Quest] Spider Lily spawned")
        end
    end

    local changed = force
        or c ~= Trackers.Crystal.found
        or p ~= Trackers.Page.found
        or s ~= Trackers.SpiderLily.found
        or #cLive > 0 or #pLive > 0 or #sLive > 0

    if not changed then return end

    Trackers.Crystal.found    = c
    Trackers.Page.found       = p
    Trackers.SpiderLily.found = s

    print(("[Quest] Sea Crystals: %d/5 present, %d/5 gone"):format(c, 5 - c))
    print(("[Quest] Lost Pages:   %d/5 present, %d/5 gone"):format(p, 5 - p))

    -- Spider Lily: only report when it is present. Never "gone" / "collected".
    if s == 1 then
        print("[Quest] Spider Lily: present in the world")
    end

    -- Break down Sea Crystal / Lost Page completion state
    local function explain(t, label, total)
        local already, justNow = {}, {}
        for _, i in ipairs(t.slots) do
            local e = t.entries[i]
            local present = (e.part and e.part.Parent) and true or false
            if not present then
                if t.baselineDone[i] then
                    already[#already + 1] = i
                else
                    justNow[#justNow + 1] = i
                end
            end
        end

        if #already > 0 then
            print(("[Quest] %s already gone before start: %s"):format(
                label, table.concat(already, ", ")
            ))
        end
        if #justNow > 0 then
            print(("[Quest] %s collected during this session: %s"):format(
                label, table.concat(justNow, ", ")
            ))
        end

        local totalGone = #already + #justNow
        if totalGone == total then
            if #justNow == 0 then
                print(("[Quest] %s was ALREADY COMPLETE on load"):format(label))
            else
                print(("[Quest] %s COMPLETED during this session"):format(label))
            end
        end
    end

    explain(Trackers.Crystal, "Sea Crystals", 5)
    explain(Trackers.Page,    "Lost Pages",   5)

    -- Live-just-completed notifications
    if not force then
        if Trackers.Crystal.found > 0 and c == 0 then
            pcall(function() notify("Sea Crystal quest COMPLETE!", "Quest", 5) end)
        end
        if Trackers.Page.found > 0 and p == 0 then
            pcall(function() notify("Lost Page quest COMPLETE!", "Quest", 5) end)
        end
    end
end

----------------------------------------------------------------
-- Background loop
----------------------------------------------------------------
task.spawn(function()
    while true do
        local hrp = getHrp()
        refresh(Trackers.Crystal, hrp)
        refresh(Trackers.Page, hrp)
        refresh(Trackers.SpiderLily, hrp)
        report(false)
        task.wait(CONFIG.Refresh)
    end
end)

-- First pass (baseline snapshot)
task.spawn(function()
    task.wait(1)
    local hrp = getHrp()
    refresh(Trackers.Crystal, hrp)
    refresh(Trackers.Page, hrp)
    refresh(Trackers.SpiderLily, hrp)
    report(true)
end)

----------------------------------------------------------------
-- Generic renderer
----------------------------------------------------------------
local function render(t, hrp)
    for _, i in ipairs(t.slots) do
        local e = t.entries[i]
        local d = t.draws[i]

        local show = e.part and e.part.Parent
            and e.pos
            and hrp and hrp.Parent
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
            else
                d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
            end
        else
            d.box.Visible, d.name.Visible, d.dist.Visible = false, false, false
        end
    end
end

RUN.RenderStepped:Connect(function()
    local hrp = getHrp()
    render(Trackers.Crystal, hrp)
    render(Trackers.Page, hrp)
    render(Trackers.SpiderLily, hrp)
end)
