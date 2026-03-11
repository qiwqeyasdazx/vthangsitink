repeat wait() until game:IsLoaded() and game.Players.LocalPlayer:FindFirstChild("DataLoaded")
if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)") then
    repeat
        wait()
        local l_Remotes_0 = game.ReplicatedStorage:WaitForChild("Remotes")
        l_Remotes_0.CommF_:InvokeServer("SetTeam", getgenv().team)
        task.wait(3)
    until not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main (minimal)")
end
repeat task.wait() until game.Players.LocalPlayer.PlayerGui:FindFirstChild("Main")

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleSvc      = game:GetService("TeleportService")
local HttpSvc      = game:GetService("HttpService")
local UserInput    = game:GetService("UserInputService")
local lp           = Players.LocalPlayer
local ch           = function() return lp.Character end

local CFG = {
    TELEPORT_INTERVAL = 2,
    HOP_INTERVAL      = 300,
    RAID_DIST         = 300,
    RESET_INTERVAL    = 7,
}

local ST = {
    farmOn       = true,
    hopOn        = false,
    bountyEarned = 0,
    lastBounty   = 0,
    targIdx      = 1,
    hopTimer     = 0,
    resetTimer   = 0,
    escapingZone = false,
}

local ServerBlacklist = {}

local function getCurrentBounty()
    local ok, val = pcall(function() return lp.Data.Bounty.Value end)
    return ok and val or 0
end

local function getTeamName()
    return lp.Team and lp.Team.Name or "None"
end

local function getPVPCount()
    local count = 0
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local pvpTag = p.Character:FindFirstChild("PVP") or
                                   (p.PlayerGui:FindFirstChild("Main") and p.PlayerGui.Main:FindFirstChild("PVP"))
                    if pvpTag then count += 1 end
                end
            end
        end
    end)
    return count
end

local function inSafe(hrp)
    local r = false
    pcall(function()
        local wo = workspace["_WorldOrigin"]
        if wo and wo:FindFirstChild("SafeZones") then
            for _, v in pairs(wo.SafeZones:GetChildren()) do
                if v:IsA("BasePart") and (v.Position - hrp.Position).Magnitude <= 450 then
                    r = true return
                end
            end
        end
        if r then return end
        local mainGui = lp.PlayerGui:FindFirstChild("Main") if not mainGui then return end
        for _, n in ipairs({"SafeZone","[OLD]SafeZone"}) do
            local f = mainGui:FindFirstChild(n)
            if f and f.Visible then r = true return end
        end
    end)
    return r
end

local function checkRaid(plr)
    local r = false
    pcall(function()
        local wo   = workspace["_WorldOrigin"] if not wo then return end
        local locs = wo:FindFirstChild("Locations") if not locs then return end
        local isl  = locs:FindFirstChild("Island 1") if not isl then return end
        local hrp  = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - isl.Position).Magnitude < CFG.RAID_DIST then r = true end
    end)
    return r
end

local function hopServer()
    local ok, _ = pcall(function()
        table.insert(ServerBlacklist, game.JobId)
        local url  = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(game.PlaceId)
        local data = HttpSvc:JSONDecode(game:HttpGet(url))
        local Z = nil
        for _, s in ipairs(data.data) do
            if s.playing and s.maxPlayers and s.playing > 5 and s.playing < s.maxPlayers - 2 then
                local bad = false
                for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true break end end
                if not bad then Z = s break end
            end
        end
        if not Z then
            for _, s in ipairs(data.data) do
                if s.playing and s.maxPlayers and s.playing > 10 and s.playing < s.maxPlayers then
                    local bad = false
                    for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true break end end
                    if not bad then Z = s break end
                end
            end
        end
        if not Z and #data.data > 0 then
            for _, s in ipairs(data.data) do
                local bad = false
                for _, bl in ipairs(ServerBlacklist) do if bl == s.id then bad = true break end end
                if not bad then Z = s break end
            end
        end
        if not Z and #data.data > 0 then Z = data.data[1] end
        if Z and Z.id then TeleSvc:TeleportToPlaceInstance(game.PlaceId, Z.id)
        else TeleSvc:Teleport(game.PlaceId) end
    end)
    if not ok then TeleSvc:Teleport(game.PlaceId) end
end

lp.AncestryChanged:Connect(function(_, parent)
    if not parent then
        pcall(function() TeleSvc:Teleport(game.PlaceId) end)
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(p)
    if p == lp then
        pcall(function() TeleSvc:Teleport(game.PlaceId) end)
    end
end)

lp.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        task.spawn(function() TeleSvc:Teleport(game.PlaceId) end)
    end
end)

local function escapeAndTeleport(targ)
    local myC   = ch()
    local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local thrp = targ and targ.Character and targ.Character:FindFirstChild("HumanoidRootPart")

    ST.escapingZone = true

    local highPos = myHRP.Position + Vector3.new(0, 3000, 0)
    local flyPart = Instance.new("Part")
    flyPart.Anchored = true
    flyPart.CanCollide = false
    flyPart.Transparency = 1
    flyPart.Size = Vector3.new(1,1,1)
    flyPart.CFrame = myHRP.CFrame
    flyPart.Parent = workspace

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = myHRP
    weld.Part1 = flyPart
    weld.Parent = flyPart

    local hum = myC:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end

    local tween = TweenService:Create(flyPart, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(highPos)
    })
    tween:Play()

    task.spawn(function()
        task.wait(0.6)
        if thrp then
            pcall(function()
                myHRP.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 3, 0))
                getgenv().targ = targ
            end)
        end
        tween:Cancel()
        weld:Destroy()
        flyPart:Destroy()
        if hum then hum.PlatformStand = false end
        ST.escapingZone = false
    end)
end

local function doReset()
    pcall(function()
        local c = ch() if not c then return end
        local hum = c:FindFirstChild("Humanoid") if not hum then return end
        hum.Health = 0
    end)
end

task.spawn(function()
    repeat task.wait() until game:IsLoaded()
    repeat task.wait() until lp and lp.Character
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/AnhDangNhoEm/TuanAnhIOS/refs/heads/main/koby"))()
    end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local c = ch() if not c then return end
            local hum = c:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local rem = game.ReplicatedStorage:FindFirstChild("Remotes")
            if not rem then return end
            local cf = rem:FindFirstChild("CommF_") if not cf then return end
            cf:InvokeServer("BusoHaki", true)
            cf:InvokeServer("KenbunHaki", true)
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        ST.resetTimer += 1
        if ST.resetTimer >= CFG.RESET_INTERVAL then
            ST.resetTimer = 0
            doReset()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(CFG.TELEPORT_INTERVAL)
        if not ST.farmOn then continue end

        local myC   = ch()
        local myHRP = myC and myC:FindFirstChild("HumanoidRootPart")
        if myHRP and inSafe(myHRP) and not ST.escapingZone then
            local plrList = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not inSafe(hrp) and not checkRaid(p) then
                        table.insert(plrList, p)
                    end
                end
            end
            local targ = #plrList > 0 and plrList[1] or nil
            task.spawn(function() escapeAndTeleport(targ) end)
            continue
        end

        local plrList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and not inSafe(hrp) and not checkRaid(p) then
                    table.insert(plrList, p)
                end
            end
        end
        if #plrList == 0 then continue end
        ST.targIdx = (ST.targIdx % #plrList) + 1
        local targ = plrList[ST.targIdx]
        if targ and targ.Character then
            local thrp = targ.Character:FindFirstChild("HumanoidRootPart")
            if thrp and myHRP then
                pcall(function()
                    myHRP.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 3, 0))
                end)
                getgenv().targ = targ
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not ST.farmOn then return end
    pcall(function()
        local targ = getgenv().targ
        if not targ or not targ.Character then return end
        local c = ch() if not c then return end
        local tool = c:FindFirstChildOfClass("Tool")
        if not tool or tool.ToolTip ~= "Blox Fruit" then return end
        local th = targ.Character:FindFirstChild("HumanoidRootPart") if not th then return end
        if inSafe(th) or checkRaid(targ) then return end
        local lcr = tool:FindFirstChild("LeftClickRemote") if not lcr then return end
        lcr:FireServer(Vector3.new(0.01, -500, 0.01), 1, true)
        lcr:FireServer(false)
    end)
end)

task.spawn(function()
    while true do
        task.wait(1)
        ST.hopTimer += 1
        if ST.hopOn and ST.hopTimer >= CFG.HOP_INTERVAL then
            ST.hopTimer = 0
            task.spawn(hopServer)
        end
        local cur   = getCurrentBounty()
        local delta = cur - ST.lastBounty
        if delta > 0 then ST.bountyEarned += delta end
        ST.lastBounty = cur
    end
end)

local guiParent
if typeof(gethui) == "function" then
    guiParent = gethui()
else
    guiParent = game:GetService("CoreGui")
end

local sg = Instance.new("ScreenGui")
sg.Name = "AutoBountyUI"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = guiParent

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 310, 0, 330)
main.Position = UDim2.new(0.5, -155, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(8, 4, 18)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(90, 0, 160)
mainStroke.Thickness = 2

local dragging, dragStart, startPos = false, nil, nil
main.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = inp.Position
        startPos = main.Position
    end
end)
main.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInput.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = inp.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                   startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 0, 40)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)
local tcFix = Instance.new("Frame", titleBar)
tcFix.Size = UDim2.new(1, 0, 0.5, 0)
tcFix.Position = UDim2.new(0, 0, 0.5, 0)
tcFix.BackgroundColor3 = Color3.fromRGB(18, 0, 40)
tcFix.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0.72, 0, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "⚡ AUTO BOUNTY M1  |  TRon Void"
titleLbl.TextColor3 = Color3.fromRGB(190, 90, 255)
titleLbl.TextSize = 12
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local statusPill = Instance.new("Frame", titleBar)
statusPill.Size = UDim2.new(0, 66, 0, 18)
statusPill.Position = UDim2.new(1, -74, 0.5, -9)
statusPill.BackgroundColor3 = Color3.fromRGB(50, 0, 100)
statusPill.BorderSizePixel = 0
Instance.new("UICorner", statusPill).CornerRadius = UDim.new(1, 0)
local statusTxt = Instance.new("TextLabel", statusPill)
statusTxt.Size = UDim2.new(1, 0, 1, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Text = "● ATIVO"
statusTxt.TextColor3 = Color3.fromRGB(185, 80, 255)
statusTxt.TextSize = 10
statusTxt.Font = Enum.Font.GothamBold
TweenService:Create(statusPill, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundColor3 = Color3.fromRGB(85, 0, 165)
}):Play()

local infoFrame = Instance.new("Frame", main)
infoFrame.Size = UDim2.new(1, -18, 0, 170)
infoFrame.Position = UDim2.new(0, 9, 0, 50)
infoFrame.BackgroundColor3 = Color3.fromRGB(13, 4, 28)
infoFrame.BorderSizePixel = 0
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 10)
local ifs = Instance.new("UIStroke", infoFrame)
ifs.Color = Color3.fromRGB(50, 0, 100)
ifs.Thickness = 1

local function makeRow(parent, y, icon, label)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -16, 0, 28)
    row.Position = UDim2.new(0, 8, 0, y)
    row.BackgroundTransparency = 1
    local sep = Instance.new("Frame", row)
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.Position = UDim2.new(0, 0, 1, -1)
    sep.BackgroundColor3 = Color3.fromRGB(35, 0, 70)
    sep.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.56, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon .. " " .. label
    lbl.TextColor3 = Color3.fromRGB(135, 65, 185)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(0.44, 0, 1, 0)
    val.Position = UDim2.new(0.56, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "—"
    val.TextColor3 = Color3.fromRGB(220, 165, 255)
    val.TextSize = 11
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    return val
end

local valBounty = makeRow(infoFrame,  6,  "💰", "Bounty Atual")
local valTeam   = makeRow(infoFrame,  38, "🏴", "Team")
local valPVP    = makeRow(infoFrame,  70, "⚔",  "PVP Fora Zona")
local valEarned = makeRow(infoFrame, 102, "📈", "Bounty Farmado")
local valTimer  = makeRow(infoFrame, 134, "⏱",  "Próx. Hop")

local hopFrame = Instance.new("Frame", main)
hopFrame.Size = UDim2.new(1, -18, 0, 42)
hopFrame.Position = UDim2.new(0, 9, 0, 232)
hopFrame.BackgroundColor3 = Color3.fromRGB(13, 4, 28)
hopFrame.BorderSizePixel = 0
Instance.new("UICorner", hopFrame).CornerRadius = UDim.new(0, 10)
local hfs = Instance.new("UIStroke", hopFrame)
hfs.Color = Color3.fromRGB(50, 0, 100)
hfs.Thickness = 1

local hopLbl = Instance.new("TextLabel", hopFrame)
hopLbl.Size = UDim2.new(0.65, 0, 1, 0)
hopLbl.Position = UDim2.new(0, 12, 0, 0)
hopLbl.BackgroundTransparency = 1
hopLbl.Text = "🌐 Hop Server (11/12)"
hopLbl.TextColor3 = Color3.fromRGB(195, 130, 255)
hopLbl.TextSize = 11
hopLbl.Font = Enum.Font.GothamSemibold
hopLbl.TextXAlignment = Enum.TextXAlignment.Left

local hopPill = Instance.new("Frame", hopFrame)
hopPill.Size = UDim2.new(0, 46, 0, 22)
hopPill.Position = UDim2.new(1, -56, 0.5, -11)
hopPill.BackgroundColor3 = Color3.fromRGB(35, 8, 60)
hopPill.BorderSizePixel = 0
Instance.new("UICorner", hopPill).CornerRadius = UDim.new(1, 0)

local hopKnob = Instance.new("Frame", hopPill)
hopKnob.Size = UDim2.new(0, 16, 0, 16)
hopKnob.Position = UDim2.new(0, 3, 0.5, -8)
hopKnob.BackgroundColor3 = Color3.fromRGB(80, 0, 140)
hopKnob.BorderSizePixel = 0
Instance.new("UICorner", hopKnob).CornerRadius = UDim.new(1, 0)

local hopState = false
hopFrame.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        hopState = not hopState
        ST.hopOn = hopState
        ST.hopTimer = 0
        TweenService:Create(hopKnob, TweenInfo.new(0.18), {
            Position = hopState and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),
            BackgroundColor3 = hopState and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,0,140)
        }):Play()
        TweenService:Create(hopPill, TweenInfo.new(0.18), {
            BackgroundColor3 = hopState and Color3.fromRGB(60,0,120) or Color3.fromRGB(35,8,60)
        }):Play()
    end
end)

local resetBtn = Instance.new("TextButton", main)
resetBtn.Size = UDim2.new(1, -18, 0, 34)
resetBtn.Position = UDim2.new(0, 9, 0, 284)
resetBtn.BackgroundColor3 = Color3.fromRGB(18, 0, 40)
resetBtn.BorderSizePixel = 0
resetBtn.Text = "🔄  Reset Bounty Earned"
resetBtn.TextColor3 = Color3.fromRGB(175, 85, 255)
resetBtn.TextSize = 12
resetBtn.Font = Enum.Font.GothamSemibold
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 10)
local rbs = Instance.new("UIStroke", resetBtn)
rbs.Color = Color3.fromRGB(90, 0, 160)
rbs.Thickness = 1
resetBtn.MouseButton1Click:Connect(function()
    ST.bountyEarned = 0
    TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(55,0,115)}):Play()
    task.wait(0.12)
    TweenService:Create(resetBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18,0,40)}):Play()
end)

RunService.Heartbeat:Connect(function()
    valBounty.Text = tostring(getCurrentBounty())
    valTeam.Text   = getTeamName()
    valPVP.Text    = tostring(getPVPCount())
    valEarned.Text = tostring(ST.bountyEarned)
    local rem = CFG.HOP_INTERVAL - ST.hopTimer
    valTimer.Text  = ("%d:%02d"):format(math.floor(rem/60), rem%60)
    if ST.escapingZone then
        statusTxt.Text = "🟡 SAINDO ZONA"
    else
        statusTxt.Text = "● ATIVO"
    end
end)
