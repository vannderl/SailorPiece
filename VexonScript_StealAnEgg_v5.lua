-- Vexon Script | Steal An Egg (v5.1 - Ultra Stable & Safe)
-- Perbaikan: Penyesuaian jeda trigger, normalisasi pergerakan MoveTo, anti-cheat bypass yang lebih aman.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local ContentProvider = game:GetService("ContentProvider")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- ================= CONFIG =================
local LOGO_ASSET_ID = 105255307277742

local PICK = Vector3.new(599.43, 70.57, -327.18)
local HOME = Vector3.new(545.74, 70.57, -352.17)
local ZONES = {
    ["1. Cosmic"]         = Vector3.new(3394.70, 70.57, -324.96),
    ["2. Kitsune"]        = Vector3.new(4026.14, 70.57, -396.96),
    ["3. Gorila King"]    = Vector3.new(4798.19, 70.57, -328.09),
    ["4. Demon&Angel"]    = Vector3.new(5662.82, 70.57, -327.71),
    ["5. Lion Enchanted"] = Vector3.new(6697.20, 70.57, -349.84),
}
local NAMES = { "1. Cosmic", "2. Kitsune", "3. Gorila King", "4. Demon&Angel", "5. Lion Enchanted" }

local CRUISE_UP     = 30    
local LIFT_MIN      = 60    
local CLIMB_SPEED   = 16    
local DWELL         = 2.5   
local GRAB_SEC      = 1.5   
local GRAB_ATTEMPTS = 2     
local GRAB_RADIUS   = 80    
local STEPS         = 5     

-- ================= UTIL =================
local function jitter(a, b)
    return a + math.random() * (b - a)
end

local function randName(n)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local t = table.create(n)
    for i = 1, n do
        local k = math.random(1, #chars)
        t[i] = chars:sub(k, k)
    end
    return table.concat(t)
end

local function mmss(s)
    s = math.max(0, math.floor(s))
    return ("%02d:%02d"):format(math.floor(s / 60), s % 60)
end

-- ================= PROTEKSI KLIEN =================
local env = (getgenv and getgenv()) or _G
if env.__VexonCleanup then pcall(env.__VexonCleanup) end

local P = env.__VexonProtect
if not P then
    P = { active = true, hooked = false }
    env.__VexonProtect = P
end
P.active = true

local function installProtection()
    if P.hooked then return true end
    local wrap = newcclosure or function(f) return f end
    local isCaller = checkcaller or function() return false end
    local got = false

    if hookmetamethod and getnamecallmethod then
        local okh = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if P.active and not isCaller() then
                    if self == LocalPlayer then
                        local m = getnamecallmethod()
                        if m == "Kick" or m == "kick" then return nil end
                    elseif self == game then
                        local m = getnamecallmethod()
                        if m == "Shutdown" then return nil end
                    end
                end
                return old(self, ...)
            end))
        end)
        got = got or okh
    end

    P.hooked = got
    return got
end

local antiKickOn = installProtection()

-- ================= STATE =================
local zone = NAMES[1]
local running = false
local session = 0

local cycles, lastCycle = 0, 0
local startedAt, frozenElapsed = 0, 0
local verifyOn, blindStreak = true, 0

local setStatus = function() end
local setProgress = function() end

local function alive(id)
    return running and id == session
end

-- ================= HELPERS KARAKTER =================
local function parts()
    local c = LocalPlayer.Character
    if not c then return nil, nil end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil, nil end
    return hrp, hum
end

local function ok(id)
    return alive(id) and parts() ~= nil
end

local plat, fxConn

local function platParent()
    return workspace.CurrentCamera or workspace
end

local function feetOffset(hrp, hum)
    local base
    if hum and hum.RigType == Enum.HumanoidRigType.R6 then
        base = 3
    else
        base = (hum and hum.HipHeight or 2) + hrp.Size.Y / 2
    end
    return base + 0.5
end

local function syncPlat(hrp)
    if not plat then return end
    if plat.Parent == nil then plat.Parent = platParent() end
    local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
    local p = hrp.Position
    plat.CFrame = CFrame.new(p.X, p.Y - feetOffset(hrp, hum), p.Z)
end

local function put(hrp, pos)
    hrp.CFrame = CFrame.new(pos) * (hrp.CFrame - hrp.CFrame.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    syncPlat(hrp)
end

local function startFx()
    if fxConn then return end
    plat = Instance.new("Part")
    plat.Name = randName(10)
    plat.Size = Vector3.new(8, 1, 8)
    plat.Anchored = true
    plat.Transparency = 1
    plat.Parent = platParent()
    fxConn = RunService.Heartbeat:Connect(function()
        local hrp = parts()
        if hrp and plat then syncPlat(hrp) end
    end)
end

local function stopFx()
    if fxConn then fxConn:Disconnect() fxConn = nil end
    if plat then plat:Destroy() plat = nil end
end

-- ================= INDEX PROXIMITYPROMPT =================
local promptSet, pConns = {}, {}

local function clearIndex()
    for _, c in ipairs(pConns) do c:Disconnect() end
    table.clear(pConns)
    table.clear(promptSet)
end

local function indexPrompts(id)
    clearIndex()
    table.insert(pConns, workspace.DescendantAdded:Connect(function(d)
        if d:IsA("ProximityPrompt") then promptSet[d] = true end
    end))
    table.insert(pConns, workspace.DescendantRemoving:Connect(function(d)
        promptSet[d] = nil
    end))
    local all = workspace:GetDescendants()
    for i, d in ipairs(all) do
        if session ~= id then return end
        if d:IsA("ProximityPrompt") then promptSet[d] = true end
        if i % 3000 == 0 then task.wait() end
    end
end

local function promptPosition(pp)
    local p = pp.Parent
    if not p then return nil end
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Attachment") then return p.WorldPosition end
    if p:IsA("Model") then
        local okp, cf = pcall(p.GetPivot, p)
        if okp then return cf.Position end
    end
    local bp = p:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position or nil
end

local function nearestPrompts(origin, radius, count)
    local found = {}
    for pp in pairs(promptSet) do
        if pp.Parent and pp.Enabled then
            local pos = promptPosition(pp)
            if pos then
                local dist = (pos - origin).Magnitude
                if dist <= radius then found[#found + 1] = { pp, dist } end
            end
        end
    end
    table.sort(found, function(a, b) return a[2] < b[2] end)
    local out = {}
    for i = 1, math.min(count, #found) do out[i] = found[i][1] end
    return out
end

-- ================= MOVEMENT =================
local function lift(id, dy)
    local hrp0 = parts()
    if not hrp0 then return false end
    local targetY = hrp0.Position.Y + dy
    local deadline = tick() + math.abs(dy) / CLIMB_SPEED * 2 + 3
    while alive(id) and tick() < deadline do
        local dt = math.min(RunService.Heartbeat:Wait(), 0.1)
        local hrp = parts()
        if not hrp then return false end
        local diff = targetY - hrp.Position.Y
        if math.abs(diff) <= 0.3 then return true end
        local step = math.sign(diff) * math.min(math.abs(diff), CLIMB_SPEED * dt)
        put(hrp, hrp.Position + Vector3.new(0, step, 0))
    end
    return false
end

local function walkTo(id, pos, stopDist, maxSec)
    local hrp, hum = parts()
    if not hrp or not hum then return false end
    local function flat(h)
        return Vector3.new(pos.X - h.Position.X, 0, pos.Z - h.Position.Z).Magnitude
    end
    local deadline = tick() + (maxSec or (flat(hrp) / math.max(hum.WalkSpeed, 8) * 1.5 + 15))
    local lastPos, lastCheck = hrp.Position, tick()
    while alive(id) and tick() < deadline do
        hrp, hum = parts()
        if not hrp or not hum then return false end
        if flat(hrp) <= stopDist then return true end
        hum:MoveTo(Vector3.new(pos.X, hrp.Position.Y, pos.Z))
        if tick() - lastCheck >= 2 then
            if (hrp.Position - lastPos).Magnitude < 1 then hum.Jump = true end
            lastPos, lastCheck = hrp.Position, tick()
        end
        task.wait(0.25)
    end
    return false
end

local function reach(id, target, name)
    local hrp, hum = parts()
    if not hrp or not hum then return false end
    local start = hrp.Position
    local flat = Vector3.new(target.X - start.X, 0, target.Z - start.Z).Magnitude
    setStatus(("Menuju %s | %d stud"):format(name, math.floor(flat)))

    local lifted = flat > LIFT_MIN
    if lifted and not lift(id, CRUISE_UP) then return false end

    local arrived = walkTo(id, target, 4)
    if not arrived and ok(id) then
        arrived = walkTo(id, target, 4)
    end

    if lifted and ok(id) then
        local h = parts()
        if h then lift(id, target.Y - h.Position.Y) end
    end
    return arrived and ok(id)
end

-- ================= AMBIL EGG =================
local busy = {}
local function trigger(pp)
    if not pp.Parent then return end
    if fireproximityprompt then
        pcall(fireproximityprompt, pp)
        return
    end
    if busy[pp] then return end
    busy[pp] = true
    pcall(function()
        pp:InputHoldBegin()
        task.wait((pp.HoldDuration or 0) + 0.1)
        pp:InputHoldEnd()
    end)
    busy[pp] = nil
end

local function grab(id, sec)
    local t = tick()
    while alive(id) and tick() - t < sec do
        local hrp = parts()
        if not hrp then return end
        local list = nearestPrompts(hrp.Position, GRAB_RADIUS, 4)
        if #list == 0 then
            task.wait(0.4)
        else
            local first = list[1]
            local pos = promptPosition(first)
            local reachDist = first.MaxActivationDistance or 10
            if pos and (pos - hrp.Position).Magnitude > reachDist + 1 then
                walkTo(id, pos, math.max(reachDist - 3, 2), 8)
            else
                local fired = 0
                for _, pp in ipairs(list) do
                    local p2 = promptPosition(pp)
                    local h2 = parts()
                    if p2 and h2 and (p2 - h2.Position).Magnitude <= (pp.MaxActivationDistance or 10) + 1 then
                        task.spawn(trigger, pp)
                        fired += 1
                        if fired >= 1 then break end -- Diperlambat agar tidak spam trigger
                    end
                end
                task.wait(jitter(0.4, 0.6))
            end
        end
    end
end

local function carrySignature()
    local c = LocalPlayer.Character
    local names = {}
    local function scan(container)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then names[#names + 1] = t.Name end
        end
    end
    scan(c)
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    table.sort(names)
    return table.concat(names, "|") .. "#" .. (c and #c:GetChildren() or 0)
end

local function grabVerified(id)
    local before = carrySignature()
    local detected = false
    for attempt = 1, GRAB_ATTEMPTS do
        setStatus(("Ambil egg (%d/%d)"):format(attempt, GRAB_ATTEMPTS))
        grab(id, GRAB_SEC * attempt * jitter(1.0, 1.3))
        if not ok(id) then return false end
        if not verifyOn then return true end
        task.wait(0.2)
        if carrySignature() ~= before then
            detected = true
            break
        end
    end
    if verifyOn then
        if detected then
            blindStreak = 0
            setStatus("Egg berhasil diambil")
        else
            blindStreak += 1
            if blindStreak >= 2 then
                verifyOn = false
            end
        end
    end
    return true
end

-- ================= SIKLUS FARM =================
local function cycle(id)
    if not ok(id) then return end
    local zoneName = zone
    local target = ZONES[zoneName]
    if not target then return end
    local t0 = os.clock()
    startFx()
    setProgress(0)

    if not reach(id, PICK, "Pick") then return stopFx() end
    setProgress(1)

    grabVerified(id)
    if not ok(id) then return stopFx() end
    setProgress(2)
    local dwell = DWELL + jitter(0, 0.5)
    setStatus(("Menunggu %.1f dtk"):format(dwell))
    local waited = 0
    while waited < dwell and ok(id) do
        task.wait(0.1)
        waited += 0.1
    end
    if not ok(id) then return stopFx() end

    if not reach(id, target, zoneName) then return stopFx() end
    setProgress(3)

    setStatus("Ambil di " .. zoneName)
    grab(id, GRAB_SEC * 1.5 * jitter(1.0, 1.2))
    if not ok(id) then return stopFx() end
    setProgress(4)

    if not reach(id, HOME, "Home") then return stopFx() end
    setProgress(5)

    cycles += 1
    lastCycle = os.clock() - t0
    setStatus(("Siklus %d selesai (%s)"):format(cycles, mmss(lastCycle)))
    stopFx()
end

local idleConn
local function startAntiAfk()
    if idleConn then return end
    idleConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end
local function stopAntiAfk()
    if idleConn then idleConn:Disconnect() idleConn = nil end
end

-- ================= UI =================
local C = {
    BG    = Color3.fromRGB(9, 12, 20),
    PANEL = Color3.fromRGB(17, 23, 38),
    HOVER = Color3.fromRGB(26, 36, 60),
    BLUE  = Color3.fromRGB(52, 128, 255),
    BLUE2 = Color3.fromRGB(105, 170, 255),
    DEEP  = Color3.fromRGB(28, 66, 150),
    WHITE = Color3.fromRGB(255, 255, 255),
    GRAY  = Color3.fromRGB(135, 150, 182),
}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function stroke(o, col, th)
    return make("UIStroke", { Color = col, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local tweens = {}

local function shine(label, base)
    label.TextColor3 = C.WHITE
    local g = make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, base),
            ColorSequenceKeypoint.new(0.40, base),
            ColorSequenceKeypoint.new(0.50, C.WHITE),
            ColorSequenceKeypoint.new(0.60, base),
            ColorSequenceKeypoint.new(1, base),
        }),
        Offset = Vector2.new(-1, 0),
    }, label)
    local tw = TweenService:Create(g, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0), { Offset = Vector2.new(1, 0) })
    tw:Play()
    table.insert(tweens, tw)
end

local function applyLogo(holder)
    if not LOGO_ASSET_ID or tonumber(LOGO_ASSET_ID) == nil or tonumber(LOGO_ASSET_ID) == 0 then return end
    local img = make("ImageLabel", {
        Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
        BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
        Image = "rbxassetid://" .. tostring(LOGO_ASSET_ID), Visible = false,
    }, holder)
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ img }, function(_, status)
                if status == Enum.AssetFetchStatus.Success and img.Parent then
                    img.Visible = true
                    holder.Text = ""
                end
            end)
        end)
    end)
end

local function getParent()
    local okh, ui = pcall(function() return gethui and gethui() end)
    if okh and ui then return ui end
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if okc and core then
        local test = pcall(function()
            local f = Instance.new("Folder")
            f.Parent = core
            f:Destroy()
        end)
        if test then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local parent = getParent()
for _, p in ipairs({ parent, LocalPlayer:FindFirstChild("PlayerGui") }) do
    local o = p and p:FindFirstChild("VexonScript_SAE")
    if o then o:Destroy() end
end

local gui = make("ScreenGui", {
    Name = randName(14), ResetOnSpawn = false, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
gui.Parent = parent

local myCleanup = function()
    if gui and gui.Parent then gui:Destroy() end
end
env.__VexonCleanup = myCleanup

local W, HEADER_H, FULL_H = 240, 46, 204

local main = make("Frame", {
    Name = "Main", Size = UDim2.fromOffset(W, FULL_H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -FULL_H / 2),
    BackgroundColor3 = C.BG, BorderSizePixel = 0, Visible = false,
}, gui)
corner(main, 10)
local scale = make("UIScale", { Scale = 1 }, main)
local mainStroke = stroke(main, C.BLUE, 1.5)

local header = make("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundTransparency = 1,
}, main)

local logo = make("TextLabel", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(10, 8),
    BackgroundColor3 = C.BLUE, Text = "V", TextColor3 = C.WHITE,
    Font = Enum.Font.GothamBlack, TextSize = 18,
}, header)
corner(logo, 8)
make("UIGradient", { Color = ColorSequence.new(C.BLUE2, C.DEEP), Rotation = 90 }, logo)
applyLogo(logo)

local title = make("TextLabel", {
    Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
    Position = UDim2.fromOffset(50, 6), BackgroundTransparency = 1,
    Text = "Vexon Script", Font = Enum.Font.GothamBold, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
shine(title, C.BLUE2)

local subtitle = make("TextLabel", {
    Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
    Position = UDim2.fromOffset(50, 25), BackgroundTransparency = 1,
    Text = "Steal An Egg", Font = Enum.Font.Gotham, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
shine(subtitle, C.GRAY)

local minBtn = make("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 9),
    BackgroundColor3 = C.PANEL, Text = "-", TextColor3 = C.WHITE,
    Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, ZIndex = 6,
}, header)
corner(minBtn, 8)
stroke(minBtn, C.BLUE, 1)

local dragArea = make("Frame", {
    Size = UDim2.new(1, -48, 1, 0), BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, header)

local line = make("Frame", {
    Size = UDim2.new(1, -20, 0, 1), Position = UDim2.fromOffset(10, HEADER_H),
    BackgroundColor3 = C.DEEP, BorderSizePixel = 0,
}, main)

local body = make("Frame", {
    Name = "Body", Size = UDim2.new(1, 0, 1, -(HEADER_H + 1)),
    Position = UDim2.fromOffset(0, HEADER_H + 1), BackgroundTransparency = 1,
}, main)

local ddBtn = make("TextButton", {
    Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 9),
    BackgroundColor3 = C.PANEL, Text = "", AutoButtonColor = false,
}, body)
corner(ddBtn, 8)
stroke(ddBtn, C.BLUE, 1)

local ddText = make("TextLabel", {
    Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, Text = "Zone: " .. zone, TextColor3 = C.WHITE,
    Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
}, ddBtn)

local ddArrow = make("TextLabel", {
    Size = UDim2.fromOffset(20, 30), Position = UDim2.new(1, -24, 0, 0),
    BackgroundTransparency = 1, Text = "v", TextColor3 = C.BLUE2,
    Font = Enum.Font.GothamBold, TextSize = 12,
}, ddBtn)

local farmBtn = make("TextButton", {
    Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 47),
    BackgroundColor3 = C.PANEL, Text = "Auto Farm : OFF", TextColor3 = C.WHITE,
    Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false,
}, body)
corner(farmBtn, 8)
stroke(farmBtn, C.BLUE, 1)

local progTrack = make("Frame", {
    Size = UDim2.new(1, -20, 0, 4), Position = UDim2.fromOffset(10, 91),
    BackgroundColor3 = C.PANEL, BorderSizePixel = 0,
}, body)
corner(progTrack, 2)
local progFill = make("Frame", {
    Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.BLUE, BorderSizePixel = 0,
}, progTrack)
corner(progFill, 2)

local statusDot = make("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(12, 106),
    BackgroundColor3 = C.GRAY, BorderSizePixel = 0,
}, body)
corner(statusDot, 4)

local statusLbl = make("TextLabel", {
    Size = UDim2.new(1, -36, 0, 30), Position = UDim2.fromOffset(26, 101),
    BackgroundTransparency = 1, Text = "Status: Idle", TextColor3 = C.GRAY,
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
}, body)

local statsLbl = make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 136),
    BackgroundTransparency = 1, Text = "", TextColor3 = C.BLUE2,
    Font = Enum.Font.GothamMedium, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, body)

setStatus = function(t)
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "Status: " .. t
        statusLbl.TextColor3 = running and C.WHITE or C.GRAY
        statusDot.BackgroundColor3 = running and C.BLUE2 or C.GRAY
    end
end

setProgress = function(n)
    if progFill and progFill.Parent then
        TweenService:Create(progFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.new(math.clamp(n / STEPS, 0, 1), 0, 1, 0) }):Play()
    end
end

local function refreshStats()
    if not statsLbl or not statsLbl.Parent then return end
    local elapsed = running and (os.clock() - startedAt) or frozenElapsed
    statsLbl.Text = ("Siklus: %d | Waktu: %s"):format(cycles, mmss(elapsed))
end

task.spawn(function()
    while gui.Parent do
        refreshStats()
        task.wait(1)
    end
end)

local list = make("Frame", {
    Name = "DropList", Size = UDim2.new(1, -20, 0, #NAMES * 26 + 8),
    Position = UDim2.fromOffset(10, HEADER_H + 1 + 9 + 33),
    BackgroundColor3 = C.BG, Visible = false, ZIndex = 20, BorderSizePixel = 0,
}, main)
corner(list, 8)
stroke(list, C.BLUE, 1)

local optionBtns = {}
local function refreshOptions()
    for name, b in pairs(optionBtns) do
        b.BackgroundColor3 = (name == zone) and C.BLUE or C.PANEL
        b.TextColor3 = C.WHITE
    end
end

for i, name in ipairs(NAMES) do
    local b = make("TextButton", {
        Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 4 + (i - 1) * 26),
        BackgroundColor3 = C.PANEL, Text = name, TextColor3 = C.WHITE,
        Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, ZIndex = 21,
    }, list)
    corner(b, 6)
    optionBtns[name] = b
    b.MouseButton1Click:Connect(function()
        zone = name
        ddText.Text = "Zone: " .. name
        list.Visible = false
        ddArrow.Text = "v"
        refreshOptions()
    end)
end
refreshOptions()

ddBtn.MouseButton1Click:Connect(function()
    list.Visible = not list.Visible
    ddArrow.Text = list.Visible and "^" or "v"
end)

local function farmColor(hover)
    if running then return hover and C.BLUE2 or C.BLUE end
    return hover and C.HOVER or C.PANEL
end

local function refreshFarm()
    farmBtn.Text = running and "Auto Farm : ON" or "Auto Farm : OFF"
    farmBtn.BackgroundColor3 = farmColor(false)
end

local function stopFarm()
    if running then frozenElapsed = os.clock() - startedAt end
    running = false
    session += 1
    stopAntiAfk()
    clearIndex()
    local hrp, hum = parts()
    if hrp and hum then hum:MoveTo(hrp.Position) end
    stopFx()
    refreshFarm()
    setProgress(0)
    setStatus("Idle")
    refreshStats()
end

local function startFarm()
    running = true
    session += 1
    local id = session
    cycles, lastCycle = 0, 0
    startedAt, frozenElapsed = os.clock(), 0
    verifyOn, blindStreak = true, 0
    refreshFarm()
    setProgress(0)
    setStatus("Memuat prompt")
    startAntiAfk()
    task.spawn(function()
        indexPrompts(id)
        while alive(id) do
            if not parts() then
                setStatus("Menunggu karakter")
                task.wait(1)
            else
                local okc, err = pcall(cycle, id)
                if not okc then warn("[Vexon Script] " .. tostring(err)) end
                stopFx()
                if alive(id) then task.wait(jitter(1.0, 2.0)) end
            end
        end
    end)
end

farmBtn.MouseButton1Click:Connect(function()
    list.Visible = false
    ddArrow.Text = "v"
    if running then stopFarm() else startFarm() end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    list.Visible = false
    ddArrow.Text = "v"
    if minimized then
        body.Visible = false
        line.Visible = false
        minBtn.Text = "+"
        TweenService:Create(main, TweenInfo.new(0.2), { Size = UDim2.fromOffset(W, HEADER_H) }):Play()
    else
        minBtn.Text = "-"
        TweenService:Create(main, TweenInfo.new(0.2), { Size = UDim2.fromOffset(W, FULL_H) }):Play()
        task.delay(0.2, function()
            if not minimized and body.Parent then
                body.Visible = true
                line.Visible = true
            end
        end)
    end
end)

local dragging, dragStart, startPos
dragArea.InputBegan:Instantiate = nil
dragArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, input.Position, main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local loading = make("Frame", {
    Name = "Loading", Size = UDim2.fromOffset(250, 124),
    Position = UDim2.new(0.5, -125, 0.5, -62),
    BackgroundColor3 = C.BG, BorderSizePixel = 0,
}, gui)
corner(loading, 10)
stroke(loading, C.BLUE, 1.5)

local lLogo = make("TextLabel", {
    Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.BLUE, Text = "V", TextColor3 = C.WHITE,
    Font = Enum.Font.GothamBlack, TextSize = 22,
}, loading)
corner(lLogo, 10)
applyLogo(lLogo)

local track = make("Frame", {
    Size = UDim2.new(1, -28, 0, 8), Position = UDim2.fromOffset(14, 74),
    BackgroundColor3 = C.PANEL, BorderSizePixel = 0,
}, loading)
corner(track, 4)
local fill = make("Frame", {
    Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.BLUE, BorderSizePixel = 0,
}, track)
corner(fill, 4)

local lText = make("TextLabel", {
    Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(14, 90),
    BackgroundTransparency = 1, Text = "Memuat...", TextColor3 = C.GRAY,
    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
}, loading)

task.spawn(function()
    task.wait(0.5)
    if not gui.Parent then return end
    loading:Destroy()
    scale.Scale = 0.85
    main.Visible = true
    TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)
