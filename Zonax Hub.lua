-- [[ ZONAX HUB | OFFICIAL V-FULL ]] --
-- UI: WindUI Boreal Edition
-- Creator: Vannderl

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInput  = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- ANTI-AFK (Biar gak kena kick pas farming)
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- LOAD UI LIBRARY
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal"))()

-- CREATE WINDOW
local Window = WindUI:CreateWindow({
    Title               = "Zonax Hub | Sailor Piece",
    Author              = "Vannderl",
    Folder              = "ZonaxConfigsV3",
    Size                = UDim2.fromOffset(900, 560),
    Icon                = "solar:crown-bold-duotone", 
    ModernLayout        = true,
    BackgroundVideo     = "https://files.catbox.moe/wvjy3p.mp4", 
    Watermark = {
        Enabled  = true,
        Text     = "Zonax Hub | Vannderl",
    },
})

-- TABS SETUP
local MainTab   = Window:Tab({ Title = "Main Farm", Icon = "solar:fire-bold" })
local BossTab   = Window:Tab({ Title = "Boss TP", Icon = "solar:shield-warning-bold" })
local PlayerTab = Window:Tab({ Title = "Player", Icon = "solar:user-bold" })
local MiscTab   = Window:Tab({ Title = "Misc & Settings", Icon = "solar:settings-bold" })

-- VARIABLES
_G.AutoFarm = false
_G.Noclip = false
_G.InfJump = false
local KillRange = 100000

-- [ TAB: MAIN FARM ]
MainTab:Section({ Title = "Farming & Combat" })

MainTab:Toggle({
    Title    = "Kill Aura (Global)",
    Desc     = "Otomatis Hit semua NPC & Player di Map.",
    Value    = false,
    Callback = function(state)
        _G.AutoFarm = state
        task.spawn(function()
            while _G.AutoFarm do
                pcall(function()
                    -- Hit NPCs (Logic khusus Sailor Piece)
                    if game.Workspace:FindFirstChild("NPCs") then
                        for _, v in pairs(game.Workspace.NPCs:GetChildren()) do
                            if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                                game:GetService("ReplicatedStorage").Events.Attack:FireServer(v)
                            end
                        end
                    end
                    -- Hit Players
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                            game:GetService("ReplicatedStorage").Events.Attack:FireServer(p.Character)
                        end
                    end
                end)
                task.wait(0.01)
            end
        end)
    end
})

MainTab:Button({
    Title = "Auto Clicker (Manual)",
    Callback = function()
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
    end
})

-- [ TAB: BOSS TELEPORT ]
BossTab:Section({ Title = "Boss Teleport" })

local Bosses = {"Sea Beast", "Monkey King", "Skeleton Lord", "Kraken", "Yeti", "Fishman"}
for _, boss in pairs(Bosses) do
    BossTab:Button({
        Title = "Teleport to " .. boss,
        Callback = function()
            local found = false
            for _, v in pairs(game.Workspace.NPCs:GetChildren()) do
                if v.Name == boss and v:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame
                    found = true
                    break
                end
            end
            if not found then
                WindUI:Notify({ Title = "Zonax Hub", Content = boss .. " tidak ditemukan!", Duration = 3 })
            end
        end
    })
end

-- [ TAB: PLAYER ]
PlayerTab:Section({ Title = "Character Hacks" })

PlayerTab:Slider({
    Title = "WalkSpeed",
    Min = 16, Max = 500, Value = 16,
    Callback = function(v)
        if LocalPlayer.Character then LocalPlayer.Character.Humanoid.WalkSpeed = v end
    end
})

PlayerTab:Toggle({
    Title = "Noclip",
    Value = false,
    Callback = function(state)
        _G.Noclip = state
        RunService.Stepped:Connect(function()
            if _G.Noclip and LocalPlayer.Character then
                for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end
})

PlayerTab:Toggle({
    Title = "Infinite Jump",
    Value = false,
    Callback = function(state)
        _G.InfJump = state
        UserInput.JumpRequest:Connect(function()
            if _G.InfJump and LocalPlayer.Character then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
            end
        end)
    end
})

-- [ TAB: MISC ]
MiscTab:Section({ Title = "Visuals" })

MiscTab:Button({
    Title = "Full ESP (Zonax Yellow)",
    Callback = function()
        for _, v in pairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local h = v.Character:FindFirstChild("Highlight") or Instance.new("Highlight", v.Character)
                h.FillColor = Color3.fromRGB(255, 255, 0)
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
            end
        end
    end
})

MiscTab:Section({ Title = "Support" })

MiscTab:Button({
    Title = "Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/vannderl")
        WindUI:Notify({ Title = "Copied", Content = "Link Discord masuk clipboard!", Duration = 2 })
    end
})

-- SIDEBAR LABEL
Window:SideBarLabel({ Title = "Zonax Hub Online", Icon = "solar:crown-bold" })

-- NOTIFICATION LOADED
WindUI:Notify({
    Title = "Zonax Hub Loaded",
    Content = "Script siap dipakai di Vann Executor V3!",
    Duration = 5
})
