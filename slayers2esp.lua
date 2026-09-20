--==============================================================
--   Made by d.x.z.
--   Sea Crystal + Lost Page ESP
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
        Crystal = Color3.fromRGB(120, 200, 255),   -- light blue
        Page    = Color3.fromRGB(181, 137, 84),    -- aged-paper brown
    },
    Credit = "d.x.z.",
    Title  = "Sea Crystal + Lost Page ESP",
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
--   baselineDone[i]  = true if slot was missing the very first tick
--   seen[i]          = last observed presence (true/false)
----------------------------------------------------------------
local function tracker(spec)
    local self = {
        spec         = spec,
        entries      = {},
        draws        = {},
        found        = -1,
        seen         = {},
        baselineDone = {},    -- snapshot of "already gone at startup"
        baselineSet  = false,
    }

    for _, i in ipairs(CONFIG.Slots) do
        self.entries[i] = { part = nil, pos = nil, dist = math.huge, text = "" }
        self.seen[i] = nil
        self.draws[i] = {
            box  = draw("Square", { Color = spec.color, Size = CONFIG.BoxSize, Visible = false }),
            name = draw("Text", {
                Color = spec.color, Text = spec.label .. i,
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

----------------------------------------------------------------
-- Instantiate the two trackers
----------------------------------------------------------------
local Trackers = {
    Crystal = tracker({
        label  = "Sea Crystal",
        color  = CONFIG.Palette.Crystal,
        range  = CONFIG.CrystalRange,
        finder = finder.seaCrystal,
    }),
    Page = tracker({
        label  = "Lost Page",
        color  = CONFIG.Palette.Page,
        range  = nil,
        finder = finder.lostPage,
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
    for _, i in ipairs(CONFIG.Slots) do
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
    for _, i in ipairs(CONFIG.Slots) do
        local e = t.entries[i]
        if e.part and e.part.Parent then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------
-- Detection pass
--   returns: live[]    -> collected during this session (just now)
--            missing[] -> confirmed absent at this tick
--            respawned[] -> came back after being absent
----------------------------------------------------------------
local function detect(t)
    local live, missing, respawned = {}, {}, {}

    for _, i in ipairs(CONFIG.Slots) do
        local e = t.entries[i]
        local present = (e.part and e.part.Parent) and true or false

        if t.seen[i] == nil then
            -- First-ever observation: no "live collect", just set baseline
            t.seen[i] = present
            if not present then
                t.baselineDone[i] = true
            else
                t.baselineDone[i] = false
            end
        elseif t.seen[i] and not present then
            -- Was here, now gone -> player just picked it up
            live[#live + 1] = i
            t.seen[i] = false
        elseif not t.seen[i] and present then
            -- Came back -> respawn
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
-- Quest progress reporter
----------------------------------------------------------------
local function report(force)
    local cLive, cMissing, cRespawn = detect(Trackers.Crystal)
    local pLive, pMissing, pRespawn = detect(Trackers.Page)

    local c = countFound(Trackers.Crystal)
    local p = countFound(Trackers.Page)

    -- Announce live collections (player is doing it NOW)
    if not force then
        for _, i in ipairs(cLive) do
            print(("[Quest] Sea Crystal%d COLLECTED JUST NOW  (%d/5 left)"):format(i, c))
        end
        for _, i in ipairs(pLive) do
            print(("[Quest] Lost Page%d COLLECTED JUST NOW  (%d/5 left)"):format(i, p))
        end

        for _, i in ipairs(cRespawn) do
            print(("[Quest] Sea Crystal%d respawned"):format(i))
        end
        for _, i in ipairs(pRespawn) do
            print(("[Quest] Lost Page%d respawned"):format(i))
        end
    end

    -- Only re-print the summary when something actually changed
    local changed = force
        or c ~= Trackers.Crystal.found
        or p ~= Trackers.Page.found
        or #cLive > 0 or #pLive > 0

    if not changed then return end

    Trackers.Crystal.found = c
    Trackers.Page.found    = p

    print(("[Quest] Sea Crystals: %d/5 present, %d/5 gone"):format(c, 5 - c))
    print(("[Quest] Lost Pages:   %d/5 present, %d/5 gone"):format(p, 5 - p))

    -- Break the "gone" count into "already gone before start" vs "done now"
    local function explain(t, live, label)
        local already, justNow = {}, {}
        for _, i in ipairs(CONFIG.Slots) do
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

        -- Final completion status per-quest
        local totalGone = #already + #justNow
        if totalGone == 5 then
            if #justNow == 0 then
                print(("[Quest] %s quest was ALREADY COMPLETE on load"):format(label))
            else
                print(("[Quest] %s quest COMPLETED during this session"):format(label))
            end
        end
    end

    explain(Trackers.Crystal, cLive, "Sea Crystals")
    explain(Trackers.Page,    pLive, "Lost Pages")

    -- Live-just-completed notifications (only when the last one is picked up live)
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
        report(false)
        task.wait(CONFIG.Refresh)
    end
end)

-- First pass (baseline snapshot)
task.spawn(function()
    task.wait(1)
    refresh(Trackers.Crystal, getHrp())
    refresh(Trackers.Page, getHrp())
    report(true)
end)

----------------------------------------------------------------
-- Generic renderer
----------------------------------------------------------------
local function render(t, hrp)
    for _, i in ipairs(CONFIG.Slots) do
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
end)
