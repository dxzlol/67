--=============================================================================
--  Massacre ESP v7.0 — by d.x.z
--  Release build
--  * Folder: vanta
--  * Logo: vanta_logo2.b64.dat
--  * Toggle notifications
--=============================================================================

if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
    error("[Massacre ESP] Drawing API not available")
end

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Workspace   = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function now()
    local ok, t = pcall(tick); if ok and type(t) == "number" then return t end
    return os.clock()
end
local function clamp(v, lo, hi) if v < lo then return lo end if v > hi then return hi end return v end

--=============================================================================
-- LOGO
--=============================================================================
local LOGO_URL   = "https://raw.githubusercontent.com/dxzlol/67/refs/heads/main/vanta_logo2.b64.dat"
local LOGO_CACHE = "vanta_logo2_cache.dat"

--=============================================================================
-- GAME GUARD
--=============================================================================
local TARGET_GAME_ID = 10765806602
local _gameOK = false
do
    local okG, gid = pcall(function() return game.GameId end)
    if okG and gid == TARGET_GAME_ID then _gameOK = true
    elseif okG and gid ~= 0 then
        warn(string.format("[Massacre ESP] Wrong game (GameId=%s). Aborting.", tostring(gid)))
        return
    else
        task.spawn(function()
            for _ = 1, 60 do
                task.wait(0.5)
                local ok, g = pcall(function() return game.GameId end)
                if ok and g ~= 0 then
                    if g == TARGET_GAME_ID then _gameOK = true
                    else warn(string.format("[Massacre ESP] Wrong game (GameId=%s).", tostring(g))) end
                    return
                end
            end
            warn("[Massacre ESP] GameId never resolved (30s).")
        end)
    end
end

--=============================================================================
-- CLEANUP
--=============================================================================
do
    if type(_G.MatchaESP_Unload) == "function" then pcall(_G.MatchaESP_Unload) end
    _G.MatchaESP_Unload  = nil
    _G.MatchaESP_Running = false
end

--=============================================================================
-- VANTA loading screen
--=============================================================================
local VANTA = (function()
    _G.VANTA_NO_AUTORUN = true

    local function fetchLogo()
        if type(isfile) == "function" and isfile(LOGO_CACHE) then
            local ok, c = pcall(readfile, LOGO_CACHE)
            if ok and type(c) == "string" and #c > 100 then return c end
        end
        local raw
        if type(httpget) == "function" then local ok, r = pcall(httpget, LOGO_URL); if ok then raw = r end
        elseif type(game) == "table" and game.HttpGet then local ok, r = pcall(function() return game:HttpGet(LOGO_URL) end); if ok then raw = r end end
        if not raw or raw == "" or raw:sub(1, 3) == "404" then return nil end
        local b64 = raw:gsub("%s+", "")
        if #b64 < 100 then return nil end
        if type(writefile) == "function" then pcall(writefile, LOGO_CACHE, b64) end
        return b64
    end
    local function resolveImage(src)
        if not src or src == "" then return nil end
        if type(src) == "string" and #src > 8 then
            local h = src:sub(1, 8)
            if h:sub(1,4) == "\137PNG" or h:sub(1,2) == "\255\216" or h:sub(1,3) == "GIF" then return src end
        end
        if type(src) == "string" and #src > 16 then
            local t = src:gsub("%s+", "")
            if (t:sub(1,5) == "iVBOR" or t:sub(1,4) == "/9j/" or t:sub(1,6) == "R0lGOD") and type(base64decode) == "function" then
                local ok, r = pcall(base64decode, t); if ok and r and #r > 8 then return r end
            end
        end
        return nil
    end

    local CFG = {
        version = "inline build",
        duration=2.8, fade_in=0.30, fade_out=0.40, skip_vk=0x1B,
        c_bg=Color3.fromRGB(10,7,4), c_accent=Color3.fromRGB(255,145,0),
        c_seg_off=Color3.fromRGB(35,26,18), c_text=Color3.fromRGB(220,200,170),
        c_pct=Color3.fromRGB(255,145,0),
        c_wm_text="MASSACRE ESP  -  d.x.z",
        c_wm_size=13,
        c_wm_y=52,
        c_wm_color=nil,
        corner_pad=26, corner_len=46, corner_thick=2,
        bar_segments=32, bar_width=520, bar_height=8, bar_gap=3, bar_offset_y=380,
        text_size=13, pct_size=11,
        logo_source=nil, logo_w=720, logo_h=720,
        status_msgs = {{0.15,"ENGAGING"},{0.45,"LOADING MODULES"},{0.75,"CALIBRATING"},{1.00,"MASSACRE READY"}},
        z=20000,
    }

    local Screen = {}; Screen.__index = Screen
    function Screen.new(c) local s=setmetatable({},Screen); s.cfg=c; s.running=false; s.skipRequested=false; s.startTime=0; s.corner={}; s.segments={}; return s end
    function Screen:_font(n) if Drawing.Fonts and Drawing.Fonts[n] then return Drawing.Fonts[n] end return 0 end
    function Screen:build(sz)
        local c, z = self.cfg, self.cfg.z
        self.overlay = Drawing.new("Square"); self.overlay.Filled=true; self.overlay.Color=c.c_bg; self.overlay.Transparency=1
        self.overlay.Size=sz; self.overlay.Position=Vector2.new(0,0); self.overlay.ZIndex=z; self.overlay.Visible=true
        for i=1,8 do local l=Drawing.new("Line"); l.Color=c.c_accent; l.Thickness=c.corner_thick; l.Transparency=1; l.ZIndex=z+5; l.Visible=true; self.corner[i]=l end
        local bytes = resolveImage(c.logo_source)
        if bytes then local img=Drawing.new("Image"); img.Data=bytes; img.Size=Vector2.new(c.logo_w,c.logo_h); img.Transparency=0; img.ZIndex=z+2; img.Visible=true; self.logo=img end
        for i=1,c.bar_segments do local s=Drawing.new("Square"); s.Filled=true; s.Color=c.c_seg_off; s.Transparency=1; s.Size=Vector2.new(0,c.bar_height); s.ZIndex=z+3; s.Visible=true; self.segments[i]=s end
        self.status = Drawing.new("Text"); self.status.Text="BOOTING"; self.status.Font=self:_font("Monospace"); self.status.Size=c.text_size; self.status.Color=c.c_text; self.status.Center=true; self.status.Outline=false; self.status.Transparency=0; self.status.ZIndex=z+4; self.status.Visible=true
        self.percent = Drawing.new("Text"); self.percent.Text="0%"; self.percent.Font=self:_font("System"); self.percent.Size=c.pct_size; self.percent.Color=c.c_pct; self.percent.Center=false; self.percent.Outline=false; self.percent.Transparency=0; self.percent.ZIndex=z+4; self.percent.Visible=true

        if c.c_wm_text and #c.c_wm_text > 0 then
            self.watermark = Drawing.new("Text")
            self.watermark.Text = c.c_wm_text
            self.watermark.Font = self:_font("Monospace")
            self.watermark.Size = c.c_wm_size or 13
            self.watermark.Color = c.c_wm_color or c.c_accent
            self.watermark.Center = true
            self.watermark.Outline = false
            self.watermark.Transparency = 0
            self.watermark.ZIndex = z + 6
            self.watermark.Visible = true
        end
    end
    function Screen:_resolveStatus(p) local m=self.cfg.status_msgs; for i=1,#m do if p<m[i][1] then return m[i][2] end end; return m[#m][2] end
    function Screen:update(nw,sz)
        local c=self.cfg; local vx,vy=sz.X,sz.Y; local cx,cy=vx/2,vy/2
        local el=nw-self.startTime; local pr=math.clamp(el/c.duration,0,1); local fade
        if el<c.fade_in then fade=el/c.fade_in elseif el>c.duration-c.fade_out then fade=1-(el-(c.duration-c.fade_out))/c.fade_out else fade=1 end
        self.overlay.Size=sz; self.overlay.Transparency=fade*0.94
        if self.logo then local zoom=math.min(1,el/(c.fade_in*2)); local sc=0.85+0.15*zoom; local w,h=c.logo_w*sc,c.logo_h*sc; self.logo.Size=Vector2.new(w,h); self.logo.Position=Vector2.new(cx-w/2,cy-h/2); self.logo.Transparency=fade*zoom end
        local pad,len=c.corner_pad,c.corner_len; local ba=fade*(0.6+0.4*math.sin(nw*3.5))
        self.corner[1].From=Vector2.new(pad,pad); self.corner[1].To=Vector2.new(pad+len,pad)
        self.corner[2].From=Vector2.new(pad,pad); self.corner[2].To=Vector2.new(pad,pad+len)
        self.corner[3].From=Vector2.new(vx-pad-len,pad); self.corner[3].To=Vector2.new(vx-pad,pad)
        self.corner[4].From=Vector2.new(vx-pad,pad); self.corner[4].To=Vector2.new(vx-pad,pad+len)
        self.corner[5].From=Vector2.new(pad,vy-pad); self.corner[5].To=Vector2.new(pad+len,vy-pad)
        self.corner[6].From=Vector2.new(pad,vy-pad-len); self.corner[6].To=Vector2.new(pad,vy-pad)
        self.corner[7].From=Vector2.new(vx-pad-len,vy-pad); self.corner[7].To=Vector2.new(vx-pad,vy-pad)
        self.corner[8].From=Vector2.new(vx-pad,vy-pad-len); self.corner[8].To=Vector2.new(vx-pad,vy-pad)
        for i=1,8 do self.corner[i].Transparency=ba; self.corner[i].Color=c.c_accent end
        local barY=math.min(cy+c.bar_offset_y,vy-c.bar_height-50); local barX=cx-c.bar_width/2
        local segW=(c.bar_width-c.bar_gap*(c.bar_segments-1))/c.bar_segments; local filled=math.floor(pr*c.bar_segments+0.5)
        for i=1,c.bar_segments do local s=self.segments[i]; s.Position=Vector2.new(barX+(i-1)*(segW+c.bar_gap),barY); s.Size=Vector2.new(segW,c.bar_height); s.Color=(i<=filled) and c.c_accent or c.c_seg_off; s.Transparency=fade end
        self.status.Position=Vector2.new(cx,barY+c.bar_height+22); self.status.Transparency=fade
        local s=self:_resolveStatus(pr); if self.status.Text~=s then self.status.Text=s end
        self.percent.Text=string.format("%d%%",math.floor(pr*100)); self.percent.Position=Vector2.new(barX+c.bar_width+14,barY-4); self.percent.Transparency=fade
        if self.watermark then
            self.watermark.Position = Vector2.new(cx, c.c_wm_y or 52)
            self.watermark.Color = c.c_wm_color or c.c_accent
            self.watermark.Transparency = fade
        end
    end
    function Screen:destroy()
        pcall(function() self.overlay:Remove() end); if self.logo then pcall(function() self.logo:Remove() end) end
        for _,l in ipairs(self.corner) do pcall(function() l:Remove() end) end
        for _,s in ipairs(self.segments) do pcall(function() s:Remove() end) end
        if self.status then pcall(function() self.status:Remove() end) end
        if self.percent then pcall(function() self.percent:Remove() end) end
        if self.watermark then pcall(function() self.watermark:Remove() end) end
    end
    function Screen:start(onDone)
        self.onComplete=onDone; self.startTime=tick(); self.running=true; self.skipRequested=false
        local cam=workspace.CurrentCamera; local sz0=(cam and cam.ViewportSize) or Vector2.new(1920,1080)
        self:build(sz0)
        task.spawn(function()
            while self.running do
                local nw=tick(); local c2=workspace.CurrentCamera; local sz=(c2 and c2.ViewportSize) or sz0
                if self.cfg.skip_vk and type(iskeypressed)=="function" then pcall(function() if iskeypressed(self.cfg.skip_vk) then self.skipRequested=true end end) end
                if nw-self.startTime>=self.cfg.duration or self.skipRequested then self.running=false; self:destroy(); if self.onComplete then pcall(self.onComplete) end; return end
                self:update(nw,sz); task.wait()
            end
            self:destroy()
        end)
    end
    function Screen:stop() self.running=false end

    local Vanta={}; local activeInstance=nil; local logoCache=nil
    local function getLogo() if logoCache~=nil then return logoCache end; logoCache=fetchLogo() or false; return logoCache or nil end
    local function mergeCfg(ovr) local c={}; for k,v in pairs(CFG) do c[k]=v end; c.logo_source=getLogo(); if ovr then for k,v in pairs(ovr) do c[k]=v end end; return c end
    Vanta.Config=CFG
    Vanta.Mount=function(overrides,onDone)
        if activeInstance and activeInstance.running then activeInstance:stop() end
        activeInstance=nil
        local c=mergeCfg(overrides); if c.duration<=0 then if onDone then pcall(onDone) end return nil end
        local inst=Screen.new(c); activeInstance=inst
        inst:start(function() activeInstance=nil; if onDone then pcall(onDone) end end)
        return inst
    end
    Vanta.Stop=function() if activeInstance then activeInstance:stop() end activeInstance=nil end
    _G.Vanta=Vanta
    return Vanta
end)()

--=============================================================================
-- API check
--=============================================================================
local API = { WorldToScreen = type(WorldToScreen) == "function", CameraPosition = false }
do
    local cam = Workspace.CurrentCamera
    if cam then
        local ok1, pos = pcall(function() return cam.Position end)
        if ok1 and pos then API.CameraPosition = true end
    end
end

--=============================================================================
-- Drawing helpers
--=============================================================================
local ESP_Z = -100
local WHITE = Color3.fromRGB(255, 255, 255)

local function setZ(d) if d then pcall(function() d.ZIndex = ESP_Z end) end return d end
local function newSquare(color, thickness, filled)
    local s = Drawing.new("Square"); s.Color=color; s.Thickness=thickness or 1; s.Filled=filled or false; s.Visible=false
    return setZ(s)
end
local function newText(color, size, center)
    local t = Drawing.new("Text"); t.Color=color; t.Size=size or 13; t.Center=center or false; t.Outline=true; t.Visible=false
    return setZ(t)
end
local function newLine(color, thickness)
    local l = Drawing.new("Line"); l.Color=color; l.Thickness=thickness or 1; l.Visible=false
    return setZ(l)
end
local function removeDrawing(d) if d then pcall(function() d:Remove() end) end end
local function vec3DistSq(a, b)
    local dx, dy, dz = a.X-b.X, a.Y-b.Y, a.Z-b.Z
    return dx*dx + dy*dy + dz*dz
end
local function vec3Offset(v, dx, dy, dz) return Vector3.new(v.X+dx, v.Y+dy, v.Z+dz) end
local function worldToScreen(pos)
    local ok, sp, on = pcall(WorldToScreen, pos)
    if not ok or not sp then return nil, false end
    return sp, on
end

--=============================================================================
-- Config
--=============================================================================
local CFG = {
    PlayerBox=true, PlayerName=true, PlayerHealth=true, PlayerDistance=true, PlayerSnapline=true,
    MaxPlayerDist=500,
    ItemsEnabled=true,
    ItemBox=true, ItemText=true, MaxItemDist=50,
    CleanupEnabled=true,
    ShowAllPlayers=false,
    InfoColor=Color3.fromRGB(200, 200, 200),
}

--=============================================================================
-- Team helpers
--=============================================================================
local function getTeamName(player)
    if not player then return nil end
    local ok, team = pcall(function() return player.Team end)
    if ok and team then
        local ok2, name = pcall(function() return team.Name end)
        if ok2 and type(name) == "string" then
            local l = string.lower(name)
            if l == "alive" then return "Alive" end
            if l == "lobby" then return "Lobby" end
        end
    end
    local ok3, char = pcall(function() return player.Character end)
    if ok3 and char then
        local f = Workspace:FindFirstChild("Alive")
        if f then local okA, inside = pcall(function() return char:IsDescendantOf(f) end); if okA and inside then return "Alive" end end
        local lf = Workspace:FindFirstChild("Lobby")
        if lf then local okL, inside = pcall(function() return char:IsDescendantOf(lf) end); if okL and inside then return "Lobby" end end
    end
    return nil
end

local _aliveFolderExists = false
local function shouldShowPlayer(player)
    if player == LocalPlayer then return false end
    if CFG.ShowAllPlayers then return true end
    local team = getTeamName(player)
    if team == "Alive" then return true end
    if team == "Lobby" then return false end
    return not _aliveFolderExists
end

--=============================================================================
-- Spectate detection
--=============================================================================
local function isSpectating()
    local ok, team = pcall(function() return LocalPlayer.Team end)
    if ok and team then
        local ok2, name = pcall(function() return team.Name end)
        if ok2 and type(name) == "string" then
            if string.lower(name):find("spect") then return true end
        end
    end
    local ok3, char = pcall(function() return LocalPlayer.Character end)
    if ok3 and char then
        for _, fname in ipairs({"Spectators", "Spectator", "Spectate", "Dead"}) do
            local f = Workspace:FindFirstChild(fname)
            if f then
                local okA, inside = pcall(function() return char:IsDescendantOf(f) end)
                if okA and inside then return true end
            end
        end
    end
    return false
end

--=============================================================================
-- Cleanup entity helpers — includes The Asset
--=============================================================================
local CLEANUP_CONTAINERS = { "Alive", "Cleanup", "Entities", "NPCs", "Mobs", "Characters" }
local CLEANUP_NUMBER_WORDS = { ["one"] = true, ["two"] = true, ["three"] = true, ["four"] = true }

local function isCleanupName(name)
    if type(name) ~= "string" then return false end
    local l = string.lower(name)
    if l == "cleanup" then return true end
    if l == "the asset" then return true end
    local suffix = l:match("^cleanup%s+(%a+)$")
    if suffix and CLEANUP_NUMBER_WORDS[suffix] then return true end
    return false
end

local function hasHumanoid(inst)
    if not inst then return false end
    local okH, hum = pcall(function() return inst:FindFirstChildOfClass("Humanoid") end)
    if not okH or not hum then return false end
    local okR, hrp = pcall(function() return inst:FindFirstChild("HumanoidRootPart") end)
    if not okR or not hrp then return false end
    return true
end

local function findCleanupEntities()
    local found, seen = {}, {}
    local okC, kids = pcall(function() return Workspace:GetChildren() end)
    if okC and kids then
        for _, child in ipairs(kids) do
            if not seen[child] and isCleanupName(child.Name) and hasHumanoid(child) then
                seen[child] = true
                found[#found+1] = child
            end
        end
    end
    for _, cname in ipairs(CLEANUP_CONTAINERS) do
        local folder = Workspace:FindFirstChild(cname)
        if folder then
            local okF, fkids = pcall(function() return folder:GetChildren() end)
            if okF and fkids then
                for _, child in ipairs(fkids) do
                    if not seen[child] and isCleanupName(child.Name) and hasHumanoid(child) then
                        seen[child] = true
                        found[#found+1] = child
                    end
                end
            end
        end
    end
    return found
end

local cleanupEntities = {}
local cleanupVisibility = {}
local _createdCleanupToggles = {}
local _pendingCleanupRescan = false
local _cleanupTabRef = nil

local function scanCleanupEntities() cleanupEntities = findCleanupEntities() end
local function isCleanupVisible(name)
    local v = cleanupVisibility[name]
    if v == nil then return true end
    return v
end

--=============================================================================
-- Item helpers
--=============================================================================
local function cleanItemName(raw)
    if not raw then return "" end
    local s = tostring(raw)
    return (s:gsub("_[Dd]rop$",""):gsub("_[Ll]oot$",""):gsub("_[Ii]tem$",""):gsub("_+$",""))
end

local function findPartNamed(inst, name, depth)
    if not inst or not name or #name == 0 then return nil end
    local okF, direct = pcall(function() return inst:FindFirstChild(name) end)
    if okF and direct then
        local okA, isBP = pcall(function() return direct:IsA("BasePart") end)
        if okA and isBP then return direct end
    end
    depth = depth or 0; if depth >= 3 then return nil end
    local okC, kids = pcall(function() return inst:GetChildren() end)
    if not okC or not kids then return nil end
    for _, c in ipairs(kids) do
        local p = findPartNamed(c, name, depth+1); if p then return p end
    end
    return nil
end

local function findAnyPart(inst, depth)
    if not inst then return nil end
    local okA, isBP = pcall(function() return inst:IsA("BasePart") end)
    if okA and isBP then return inst end
    local okF, direct = pcall(function() return inst:FindFirstChildWhichIsA("BasePart") end)
    if okF and direct then return direct end
    depth = depth or 0; if depth >= 3 then return nil end
    local okC, kids = pcall(function() return inst:GetChildren() end)
    if not okC or not kids then return nil end
    for _, c in ipairs(kids) do
        local p = findAnyPart(c, depth+1); if p then return p end
    end
    return nil
end

local function resolveItemPart(inst)
    if not inst then return nil end
    for _, nm in ipairs({"Handle", "Main", "Handling", "Part"}) do
        local p = findPartNamed(inst, nm)
        if p then return p end
    end
    return findAnyPart(inst)
end

--=============================================================================
-- Colors
--=============================================================================
local _itemColors, _itemColorKeys = {}, {}
local function colorForItem(name)
    if _itemColors[name] then return _itemColors[name] end
    local seed = (#name % 7) * 0.13 + (string.byte(name, 1) or 0) / 255
    for i = 1, 2000 do
        local h = (seed + i * 0.38196601125) % 1
        local c = Color3.fromHSV(h, 0.6, 0.9)
        local k = string.format("%.3f_%.3f_%.3f", c.R, c.G, c.B)
        if not _itemColorKeys[k] then _itemColorKeys[k] = true; _itemColors[name] = c; return c end
    end
    return Color3.new(0, 1, 0.6)
end

local _entityColorCache, _entityColorKeys = {}, {}
local function assignEntityColor(name)
    if _entityColorCache[name] then return _entityColorCache[name] end
    local seed = (#name % 7) * 0.13 + (string.byte(name, 1) or 0) / 255
    for i = 1, 2000 do
        local h = (seed + i * 0.61803398875) % 1
        local c = Color3.fromHSV(h, 0.65, 0.95)
        local k = string.format("%.3f_%.3f_%.3f", c.R, c.G, c.B)
        if not _entityColorKeys[k] then _entityColorKeys[k] = true; _entityColorCache[name] = c; return c end
    end
    _entityColorCache[name] = WHITE; return WHITE
end

--=============================================================================
-- Drawing pools
--=============================================================================
local MAX_PLAYER_SLOTS = 32
local MAX_ITEM_SLOTS   = 64

local playerSlots, itemSlots = {}, {}
for i = 1, MAX_PLAYER_SLOTS do
    playerSlots[i] = {
        box=newSquare(WHITE,1.5,false), name=newText(WHITE,13,true),
        info=newText(CFG.InfoColor,12,true), hpBg=newSquare(Color3.fromRGB(40,40,40),0,true),
        hpFill=newSquare(Color3.fromRGB(0,255,0),0,true), tracer=newLine(WHITE,1),
    }
end
for i = 1, MAX_ITEM_SLOTS do
    itemSlots[i] = { box=newSquare(WHITE,1,false), text=newText(WHITE,12,true) }
end

local function hidePlayerSlot(s)
    s.box.Visible=false; s.name.Visible=false; s.info.Visible=false
    s.hpBg.Visible=false; s.hpFill.Visible=false; s.tracer.Visible=false
end
local function hideItemSlot(s) s.box.Visible=false; s.text.Visible=false end
for i = 1, MAX_PLAYER_SLOTS do hidePlayerSlot(playerSlots[i]) end
for i = 1, MAX_ITEM_SLOTS   do hideItemSlot(itemSlots[i])     end

--=============================================================================
-- Item tracking
--=============================================================================
local ITEM_CONTAINERS = { "Drops", "RoundLoot" }
local knownItems      = {}
local detectedNames   = {}
local lastItemScan    = 0
local itemVisibility  = {}
local _createdToggles = {}
local _pendingRescan    = false
local _pendingNotifyMsg = nil
local _itemTabRef       = nil
local _lastAutoDetect   = 0
local MAX_TOGGLES       = 100

local function isItemEnabled(name)
    local v = itemVisibility[name]
    if v == nil then return true end
    return v
end

local function scanItems()
    local found, names = {}, {}
    for _, cname in ipairs(ITEM_CONTAINERS) do
        local container = Workspace:FindFirstChild(cname)
        if container then
            for _, child in ipairs(container:GetChildren()) do
                local part = resolveItemPart(child)
                if part then
                    found[child] = part
                    local clean = cleanItemName(child.Name)
                    names[clean] = (names[clean] or 0) + 1
                end
            end
        end
    end
    knownItems = found
    detectedNames = names
end

--=============================================================================
-- Render
--=============================================================================
local lastPlayerErr, lastItemErr = nil, nil
local dbg = { players=0, alive=0, cleanup=0, pSlots=0, iSlots=0, frames=0 }
local _wasSpectating = false
local _lastSpectateNotify = 0

local function renderEntities(cam, camPos)
    _aliveFolderExists = Workspace:FindFirstChild("Alive") ~= nil
    local maxDistSq = CFG.MaxPlayerDist * CFG.MaxPlayerDist
    local vs = cam.ViewportSize
    local vsX = (vs and vs.X) or 1280
    local vsY = (vs and vs.Y) or 720

    local toRender = {}
    local alreadySeen = {}
    local players = Players:GetPlayers()
    dbg.players = 0; dbg.alive = 0; dbg.cleanup = 0

    for i = 1, #players do
        local player = players[i]
        if player ~= LocalPlayer then
            dbg.players = dbg.players + 1
            if shouldShowPlayer(player) then
                dbg.alive = dbg.alive + 1
                local char = player.Character
                if char and not alreadySeen[char] then
                    alreadySeen[char] = true
                    toRender[#toRender+1] = { model = char, name = player.Name }
                end
            end
        end
    end

    if CFG.CleanupEnabled then
        for i = 1, #cleanupEntities do
            local entity = cleanupEntities[i]
            if not alreadySeen[entity] and isCleanupVisible(entity.Name) then
                dbg.cleanup = dbg.cleanup + 1
                alreadySeen[entity] = true
                toRender[#toRender+1] = { model = entity, name = entity.Name }
            end
        end
    end

    local used = 0
    for i = 1, #toRender do
        if used >= MAX_PLAYER_SLOTS then break end
        local info = toRender[i]
        local char = info.model
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            local hp = hum.Health or 0
            if hp > 0 then
                local pos = hrp.Position
                if pos then
                    local distSq = vec3DistSq(camPos, pos)
                    if distSq <= maxDistSq then
                        local rootS, rootOn = worldToScreen(pos)
                        if rootS and rootOn then
                            local dist = math.sqrt(distSq)
                            local headS, headOn = worldToScreen(vec3Offset(pos, 0, 1.6, 0))
                            local footS, footOn = worldToScreen(vec3Offset(pos, 0, -1.6, 0))
                            local boxH
                            if headS and headOn and footS and footOn then
                                boxH = math.abs(footS.Y - headS.Y)
                            end
                            if not boxH or boxH ~= boxH or boxH < 4 or boxH > 2000 then
                                local fov = math.rad(cam.FieldOfView or 70)
                                boxH = (vsY * 3.2) / (2 * math.max(dist, 1) * math.tan(fov * 0.5))
                            end
                            boxH = clamp(boxH, 10, 800)
                            local boxW = boxH * 0.55
                            local bx = rootS.X - boxW * 0.5
                            local by = rootS.Y - boxH * 0.5
                            used = used + 1
                            local slot = playerSlots[used]
                            local col  = assignEntityColor(info.name)

                            slot.box.Position = Vector2.new(bx, by)
                            slot.box.Size = Vector2.new(boxW, boxH)
                            slot.box.Color = col; slot.box.Visible = CFG.PlayerBox
                            slot.name.Text = info.name
                            slot.name.Position = Vector2.new(rootS.X, by - 30)
                            slot.name.Color = col; slot.name.Visible = CFG.PlayerName

                            local parts = {}
                            if CFG.PlayerHealth then parts[#parts+1] = string.format("HP %d", math.floor(hp)) end
                            if CFG.PlayerDistance then parts[#parts+1] = string.format("%dm", math.floor(dist)) end
                            if #parts > 0 then
                                slot.info.Text = table.concat(parts, "  |  ")
                                slot.info.Position = Vector2.new(rootS.X, by - 16)
                                slot.info.Color = CFG.InfoColor
                                slot.info.Visible = true
                            else slot.info.Visible = false end

                            local maxHp = hum.MaxHealth or 100
                            local ratio = clamp(hp / math.max(maxHp, 1), 0, 1)
                            local barX = bx - 6
                            slot.hpBg.Position = Vector2.new(barX, by)
                            slot.hpBg.Size = Vector2.new(3, boxH)
                            slot.hpBg.Visible = CFG.PlayerHealth
                            slot.hpFill.Position = Vector2.new(barX, by + boxH * (1 - ratio))
                            slot.hpFill.Size = Vector2.new(3, boxH * ratio)
                            slot.hpFill.Color = Color3.fromRGB(
                                math.floor(255 * (1 - ratio)), math.floor(255 * ratio), 60)
                            slot.hpFill.Visible = CFG.PlayerHealth

                            slot.tracer.From = Vector2.new(vsX * 0.5, vsY)
                            slot.tracer.To = Vector2.new(rootS.X, by + boxH)
                            slot.tracer.Color = col; slot.tracer.Visible = CFG.PlayerSnapline
                        end
                    end
                end
            end
        end
    end
    for i = used + 1, MAX_PLAYER_SLOTS do hidePlayerSlot(playerSlots[i]) end
    dbg.pSlots = used
end

local function renderItems(cam, camPos)
    if not CFG.ItemsEnabled or (not CFG.ItemBox and not CFG.ItemText) then
        for i = 1, MAX_ITEM_SLOTS do hideItemSlot(itemSlots[i]) end
        dbg.iSlots = 0
        return
    end

    local maxDistSq = CFG.MaxItemDist * CFG.MaxItemDist
    local candidates = {}

    for inst, part in pairs(knownItems) do
        if part and part.Parent then
            local pp = part.Position
            if pp then
                local distSq = vec3DistSq(camPos, pp)
                if distSq <= maxDistSq then
                    local name = cleanItemName(inst.Name)
                    if isItemEnabled(name) then
                        local sp, on = worldToScreen(pp)
                        if sp and on then
                            candidates[#candidates+1] = { name=name, dist=math.sqrt(distSq), screen=sp }
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local used = 0
    local cap = math.min(#candidates, MAX_ITEM_SLOTS)
    for i = 1, cap do
        local c = candidates[i]
        used = used + 1
        local slot = itemSlots[used]
        local size = clamp(1400 / math.max(c.dist, 1), 6, 60)
        local col  = colorForItem(c.name)
        slot.box.Position = Vector2.new(c.screen.X - size * 0.5, c.screen.Y - size * 0.5)
        slot.box.Size = Vector2.new(size, size)
        slot.box.Color = col; slot.box.Visible = CFG.ItemBox
        slot.text.Text = c.name
        slot.text.Position = Vector2.new(c.screen.X, c.screen.Y - size * 0.5 - 14)
        slot.text.Color = col; slot.text.Visible = CFG.ItemText
    end
    for i = used + 1, MAX_ITEM_SLOTS do hideItemSlot(itemSlots[i]) end
    dbg.iSlots = used
end

--=============================================================================
-- Nova + toggle notifications
--=============================================================================
local RENDER_CONN = nil
local NOVA_WINDOW = nil
local _cleanupDone = false
local _setupTime = 0
local _NOTIF_SUPPRESS = 2.0

local function notifToggle(name, value)
    if _cleanupDone or not NOVA_WINDOW then return end
    if now() - _setupTime < _NOTIF_SUPPRESS then return end
    pcall(function()
        NOVA_WINDOW:Notify({
            Title    = name,
            Content  = value and "Enabled" or "Disabled",
            Duration = 2,
        })
    end)
end

local function cleanupESP()
    if _cleanupDone then return end
    _cleanupDone = true
    _G.MatchaESP_Running = false
    if RENDER_CONN then pcall(function() RENDER_CONN:Disconnect() end) end
    for i = 1, MAX_PLAYER_SLOTS do
        removeDrawing(playerSlots[i].box); removeDrawing(playerSlots[i].name)
        removeDrawing(playerSlots[i].info); removeDrawing(playerSlots[i].hpBg)
        removeDrawing(playerSlots[i].hpFill); removeDrawing(playerSlots[i].tracer)
    end
    for i = 1, MAX_ITEM_SLOTS do
        removeDrawing(itemSlots[i].box); removeDrawing(itemSlots[i].text)
    end
    pcall(function() if VANTA and VANTA.Stop then VANTA.Stop() end end)
end

local function loadNova()
    local src
    local ok = pcall(function() src = game:HttpGet("https://raw.githubusercontent.com/Martinikaws/Nova/main/Nova.lua") end)
    if not ok or not src or #src < 100 then return nil, "HttpGet failed" end
    local ok2 = pcall(function() loadstring(src)() end)
    if not ok2 then return nil, "loadstring failed" end
    local Nova = _G.Nova
    if not Nova or type(Nova.CreateWindow) ~= "function" then return nil, "Nova not exposed" end
    return Nova
end

local function ensureItemToggle(tab, cleanName)
    if _createdToggles[cleanName] then return false end
    local flag = "itm_" .. cleanName:gsub("[^%w]", "_")
    local ok = pcall(function()
        tab:Toggle({
            Name = cleanName, Default = true, Flag = flag,
            Callback = function(v)
                itemVisibility[cleanName] = v
                notifToggle(cleanName, v)
            end,
        })
    end)
    if not ok then return false end
    _createdToggles[cleanName] = true
    return true
end

local function getMissingItemNames()
    local missing = {}
    for n in pairs(detectedNames) do
        if not _createdToggles[n] then missing[#missing+1] = n end
    end
    table.sort(missing)
    return missing
end

local function populateItemToggles(tab)
    if _cleanupDone or not tab then return 0, 0 end
    pcall(scanItems)
    local missing = getMissingItemNames()
    local existing = 0
    for _ in pairs(_createdToggles) do existing = existing + 1 end
    local budget = MAX_TOGGLES - existing
    if budget <= 0 then return 0, #missing end
    local added = 0
    for i = 1, math.min(#missing, budget) do
        if ensureItemToggle(tab, missing[i]) then added = added + 1 end
    end
    return added, #missing
end

local function ensureCleanupToggle(tab, name)
    if _createdCleanupToggles[name] then return false end
    local flag = "cln_" .. name:gsub("[^%w]", "_")
    local ok = pcall(function()
        tab:Toggle({
            Name = name, Default = true, Flag = flag,
            Callback = function(v)
                cleanupVisibility[name] = v
                notifToggle(name, v)
            end,
        })
    end)
    if not ok then return false end
    _createdCleanupToggles[name] = true
    return true
end

local function getMissingCleanupNames()
    local missing = {}
    for i = 1, #cleanupEntities do
        local n = cleanupEntities[i].Name
        if not _createdCleanupToggles[n] then missing[#missing+1] = n end
    end
    table.sort(missing)
    return missing
end

local function populateCleanupToggles(tab)
    if _cleanupDone or not tab then return 0 end
    pcall(scanCleanupEntities)
    local added = 0
    for i = 1, #cleanupEntities do
        if ensureCleanupToggle(tab, cleanupEntities[i].Name) then added = added + 1 end
    end
    return added
end

local function setupNova(Nova)
    _setupTime = now()

    NOVA_WINDOW = Nova:CreateWindow({
        Title      = "Massacre ESP",
        Subtitle   = "by d.x.z",
        ConfigName = "massacre_esp",
        Folder     = "vanta",
        ToggleKey  = "RightShift",
        Accent     = "ff3030",
        Size       = {640, 620},
        OnUnload   = function()
            pcall(function()
                if NOVA_WINDOW and NOVA_WINDOW.SetToggleKey then
                    NOVA_WINDOW:SetToggleKey("None")
                end
            end)
            cleanupESP()
        end,
    })
    local win = NOVA_WINDOW

    -- Player tab
    local PlayerTab = win:Tab("Player")
    PlayerTab:Section("Player ESP")
    PlayerTab:Toggle({Name="Boxes", Default=true, Flag="p_box",
        Callback=function(v) CFG.PlayerBox = v; notifToggle("Boxes", v) end})
    PlayerTab:Toggle({Name="Names", Default=true, Flag="p_name",
        Callback=function(v) CFG.PlayerName = v; notifToggle("Names", v) end})
    PlayerTab:Toggle({Name="Health Bar", Default=true, Flag="p_hp",
        Callback=function(v) CFG.PlayerHealth = v; notifToggle("Health Bar", v) end})
    PlayerTab:Toggle({Name="Distance", Default=true, Flag="p_dist",
        Callback=function(v) CFG.PlayerDistance = v; notifToggle("Distance", v) end})
    PlayerTab:Toggle({Name="Tracers", Default=true, Flag="p_tracer",
        Callback=function(v) CFG.PlayerSnapline = v; notifToggle("Tracers", v) end})
    PlayerTab:Slider({Name="Max Distance", Min=50, Max=2000, Default=500, Increment=10, Suffix="m",
        Flag="p_range", Callback=function(v) CFG.MaxPlayerDist = v end})
    PlayerTab:Section("Filter")
    PlayerTab:Toggle({Name="Show all players (ignore team)", Default=false, Flag="p_all",
        Callback=function(v) CFG.ShowAllPlayers = v; notifToggle("Show all players", v) end})

    -- Cleanup tab
    local CleanupTab = win:Tab("Cleanup")
    CleanupTab:Section("Cleanup ESP")
    CleanupTab:Toggle({Name="Enable Cleanup ESP", Default=true, Flag="c_enabled",
        Callback=function(v) CFG.CleanupEnabled = v; notifToggle("Cleanup ESP", v) end})
    CleanupTab:Label("Scans Workspace.Alive for Cleanup One through Four and The Asset.")
    CleanupTab:Button({
        Name = "Rescan for cleanup entities",
        Callback = function() _pendingCleanupRescan = true end,
    })
    CleanupTab:Section("Entities")
    _cleanupTabRef = CleanupTab

    pcall(scanCleanupEntities)
    local initialCleanup = populateCleanupToggles(CleanupTab)
    if initialCleanup == 0 then
        CleanupTab:Label("None found yet. Auto-detected every 2s.")
    end

    -- Item tab
    local ItemTab = win:Tab("Item")
    ItemTab:Section("Item ESP")
    ItemTab:Toggle({Name="Enable Item ESP", Default=true, Flag="i_enabled",
        Callback=function(v) CFG.ItemsEnabled = v; notifToggle("Item ESP", v) end})
    ItemTab:Toggle({Name="Boxes", Default=true, Flag="i_box",
        Callback=function(v) CFG.ItemBox = v; notifToggle("Item Boxes", v) end})
    ItemTab:Toggle({Name="Text", Default=true, Flag="i_text",
        Callback=function(v) CFG.ItemText = v; notifToggle("Item Text", v) end})
    ItemTab:Slider({Name="Max Distance", Min=1, Max=200, Default=50, Increment=1, Suffix="m",
        Flag="i_range", Callback=function(v) CFG.MaxItemDist = v end})
    ItemTab:Button({
        Name = "Rescan for new items",
        Callback = function() _pendingRescan = true end,
    })
    ItemTab:Section("Item Filters")
    _itemTabRef = ItemTab

    pcall(scanItems)
    local names = {}
    for n in pairs(detectedNames) do names[#names+1] = n end
    table.sort(names)
    local added0 = 0
    for _, n in ipairs(names) do
        if added0 >= MAX_TOGGLES then break end
        if ensureItemToggle(ItemTab, n) then added0 = added0 + 1 end
    end
    if added0 == 0 then
        ItemTab:Label("None yet. Auto-detected every 2s.")
    end

    -- Status tab
    local StatusTab = win:Tab("Status")
    StatusTab:Section("VANTA")
    local vantaLoader = "UNAVAILABLE"
    if VANTA and VANTA.Mount then vantaLoader = "READY" end
    StatusTab:Label("Loader: " .. vantaLoader)
    StatusTab:Label("Accent: #ff3030")
    StatusTab:Label("Skip key: ESC")
    StatusTab:Label("Logo: " .. LOGO_URL:match("[^/]+$"))
    StatusTab:Label("Config: vanta/massacre_esp.json")

    StatusTab:Section("Diagnostics")
    StatusTab:Label("GameId: " .. tostring(TARGET_GAME_ID))
    StatusTab:Label("WorldToScreen: " .. (API.WorldToScreen and "OK" or "MISSING"))
    StatusTab:Label("Camera.Position: " .. (API.CameraPosition and "OK" or "MISSING"))
    local statusLine = StatusTab:Label("Waiting for first frame...")
    local errorLine  = StatusTab:Label("No errors.")
    _G.__MassacreESP_StatusLine = statusLine
    _G.__MassacreESP_ErrorLine  = errorLine
    _G.__MassacreESP_LastStatusUpdate = 0

    pcall(function()
        win:Notify({Title="Massacre ESP", Content="by d.x.z", Duration=4})
    end)
end

--=============================================================================
-- Deferred UI work
--=============================================================================
local function processPendingUI()
    if _cleanupDone or not _G.MatchaESP_Running then return end
    if not NOVA_WINDOW then return end

    if _pendingRescan then
        _pendingRescan = false
        if _itemTabRef then
            local ok, added = pcall(populateItemToggles, _itemTabRef)
            if ok and added and added > 0 then
                _pendingNotifyMsg = string.format("Added %d item toggles", added)
            end
        end
    end
    if _pendingCleanupRescan then
        _pendingCleanupRescan = false
        if _cleanupTabRef then
            local ok, added = pcall(populateCleanupToggles, _cleanupTabRef)
            if ok and added and added > 0 then
                _pendingNotifyMsg = string.format("Added %d cleanup toggles", added)
            end
        end
    end
    if _pendingNotifyMsg then
        local msg = _pendingNotifyMsg
        _pendingNotifyMsg = nil
        pcall(function()
            NOVA_WINDOW:Notify({Title="Rescan", Content=msg, Duration=2})
        end)
    end
end

--=============================================================================
-- Spectate monitor
--=============================================================================
local function monitorSpectate()
    if _cleanupDone or not _G.MatchaESP_Running then return end
    local spectating = isSpectating()
    local t = now()
    if spectating and not _wasSpectating then
        _wasSpectating = true
        if t - _lastSpectateNotify > 5 then
            _lastSpectateNotify = t
            pcall(function()
                if NOVA_WINDOW then
                    NOVA_WINDOW:Notify({
                        Title   = "WARNING",
                        Content = "Lag may happen due to scanning while spectating.",
                        Duration = 6,
                    })
                end
            end)
            pcall(function()
                if type(notify) == "function" then
                    notify("Lag may happen due to scanning while spectating.", "WARNING", 6)
                end
            end)
        end
    elseif not spectating and _wasSpectating then
        _wasSpectating = false
    end
end

--=============================================================================
-- Render loop
--=============================================================================
local function renderFrame()
    if _cleanupDone or not _G.MatchaESP_Running then return end
    dbg.frames = dbg.frames + 1

    local cam = Workspace.CurrentCamera; if not cam then return end
    local camPos = cam.Position; if not camPos then return end

    local ok1, err1 = pcall(renderEntities, cam, camPos)
    if not ok1 and not lastPlayerErr then
        lastPlayerErr = tostring(err1)
        warn("[Massacre ESP] renderEntities error: " .. lastPlayerErr)
    end

    local t = now()
    if t - lastItemScan > 0.5 then
        lastItemScan = t
        pcall(scanItems)
        pcall(scanCleanupEntities)
    end

    local ok2, err2 = pcall(renderItems, cam, camPos)
    if not ok2 and not lastItemErr then
        lastItemErr = tostring(err2)
        warn("[Massacre ESP] renderItems error: " .. lastItemErr)
    end
end

local function startRenderLoop()
    pcall(scanItems)
    pcall(scanCleanupEntities)
    RENDER_CONN = RunService.RenderStepped:Connect(function()
        if _cleanupDone or not _G.MatchaESP_Running then return end

        pcall(processPendingUI)
        pcall(monitorSpectate)

        local t0 = now()
        if t0 - _lastAutoDetect >= 2.0 then
            _lastAutoDetect = t0
            if not _pendingRescan and #getMissingItemNames() > 0 then _pendingRescan = true end
            if not _pendingCleanupRescan and #getMissingCleanupNames() > 0 then _pendingCleanupRescan = true end
        end

        local ok, err = pcall(renderFrame)
        if not ok and not lastPlayerErr then
            lastPlayerErr = tostring(err)
            warn("[Massacre ESP] renderFrame error: " .. lastPlayerErr)
        end

        local t = now()
        if t - (_G.__MassacreESP_LastStatusUpdate or 0) >= 1.0 and _G.__MassacreESP_StatusLine then
            _G.__MassacreESP_LastStatusUpdate = t
            pcall(function()
                local toggleCount = 0
                for _ in pairs(_createdToggles) do toggleCount = toggleCount + 1 end
                local cleanupToggleCount = 0
                for _ in pairs(_createdCleanupToggles) do cleanupToggleCount = cleanupToggleCount + 1 end
                _G.__MassacreESP_StatusLine:SetText(string.format(
                    "frames: %d\n" ..
                    "players: %d  alive: %d  drawing: %d/%d\n" ..
                    "cleanup: %s  found: %d  shown: %d  filters: %d\n" ..
                    "items: %s  drawing: %d/%d  filters: %d",
                    dbg.frames,
                    dbg.players, dbg.alive, dbg.pSlots, MAX_PLAYER_SLOTS,
                    CFG.CleanupEnabled and "ON" or "OFF",
                    #cleanupEntities, dbg.cleanup, cleanupToggleCount,
                    CFG.ItemsEnabled and "ON" or "OFF",
                    dbg.iSlots, MAX_ITEM_SLOTS, toggleCount))
            end)
            pcall(function()
                local errs = {}
                if lastPlayerErr then errs[#errs+1] = "Entity: " .. lastPlayerErr end
                if lastItemErr   then errs[#errs+1] = "Item:   " .. lastItemErr   end
                if #errs > 0 then _G.__MassacreESP_ErrorLine:SetText(table.concat(errs, "\n"))
                else _G.__MassacreESP_ErrorLine:SetText("No errors.") end
            end)
        end
    end)
end

local function startESP()
    local Nova, err = loadNova()
    if Nova then
        local ok, msg = pcall(setupNova, Nova)
        if not ok then warn("[Massacre ESP] Nova setup failed: " .. tostring(msg)); NOVA_WINDOW = nil end
    else
        warn("[Massacre ESP] Nova unavailable - " .. tostring(err))
    end
    startRenderLoop()
    _G.MatchaESP_Running = true
    pcall(function() if type(notify) == "function" then notify("Massacre ESP by d.x.z", "Massacre", 4) end end)
end

_G.MatchaESP_Unload = function()
    _G.MatchaESP_Running = false
    cleanupESP()

    local win = NOVA_WINDOW
    NOVA_WINDOW = nil

    if win then
        pcall(function()
            if win.SetToggleKey then win:SetToggleKey("None") end
        end)
        pcall(function() win:Destroy() end)
    end

    for k in pairs(_createdToggles) do _createdToggles[k] = nil end
    for k in pairs(_createdCleanupToggles) do _createdCleanupToggles[k] = nil end
    for k in pairs(itemVisibility) do itemVisibility[k] = nil end
    for k in pairs(cleanupVisibility) do cleanupVisibility[k] = nil end
    cleanupEntities = {}
    _itemTabRef = nil
    _cleanupTabRef = nil
    _G.__MassacreESP_StatusLine = nil
    _G.__MassacreESP_ErrorLine = nil
    print("[Massacre ESP] Unloaded")
end

--=============================================================================
-- Boot
--=============================================================================
local function guardedStart()
    if _gameOK == false then
        local okG, gid = pcall(function() return game.GameId end)
        if okG and gid ~= 0 then
            if gid ~= TARGET_GAME_ID then
                warn("[Massacre ESP] Wrong game at start. Aborting.")
                pcall(function() if VANTA and VANTA.Stop then VANTA.Stop() end end)
                return
            end
            _gameOK = true
        end
    end
    if _gameOK == false then
        warn("[Massacre ESP] Game check failed. Aborting.")
        pcall(function() if VANTA and VANTA.Stop then VANTA.Stop() end end)
        return
    end
    startESP()
end

if VANTA and VANTA.Mount then
    VANTA.Mount({
        duration = 2.8,
        c_accent  = Color3.fromRGB(255, 48, 48),
        c_pct     = Color3.fromRGB(255, 48, 48),
        c_seg_off = Color3.fromRGB(40, 15, 15),
        c_text    = Color3.fromRGB(230, 210, 210),
        c_bg      = Color3.fromRGB(12, 6, 6),
        c_wm_text = "MASSACRE ESP  -  d.x.z",
        c_wm_size = 13,
        c_wm_y    = 52,
        status_msgs = {
            {0.15, "ENGAGING"}, {0.45, "LOADING MODULES"},
            {0.75, "CALIBRATING"}, {1.00, "MASSACRE READY"},
        },
    }, guardedStart)
else
    guardedStart()
end
