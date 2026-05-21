-- ============================================================
--  TOMMY HUB v5  |  PREMIUM
-- ============================================================

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local CoreGui             = game:GetService("CoreGui")
local VIM                 = game:GetService("VirtualInputManager")

local lp     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
--  GLOBAL STATE
-- ============================================================
getgenv().SelectedPlayer    = nil
getgenv().TPDirectActive    = false
getgenv().KillTrackerActive = false
getgenv().SkyTrackerActive  = false
getgenv().InstaTPSkyHeight  = 300
getgenv().WalkOnWater       = false
getgenv().NoclipEnabled     = false
getgenv().SpinEnabled       = false
getgenv().SpinSpeed         = 50
getgenv().MagnetEnabled     = false
getgenv().MagnetRange       = 800
getgenv().MagnetDistance    = 6
getgenv().PullForce         = 0.7

_G.WalkSpeedValue   = 40
_G.WalkSpeedEnabled = false
_G.JumpPowerValue   = 50
_G.JumpPowerEnabled = false

local skyConnection        = nil
local DashEnabled          = false
local DashConnection       = nil
local DashLenght           = 1
local autoV4               = false
local v4Connection         = nil
local GhostTpEnabled       = false
local GhostTpConnection    = nil
local ghostFrameCounter    = 0
local GHOST_RATIO          = 2
local GhostCFrame          = nil
local BlinkMode            = false
local XOffset,YOffset,ZOffset = 0,1.5,3.5
local flying               = false
local flySpeed             = 60
local bv,bg
local ESPEnabled           = false
local ESPObjects           = {}
local ESPColor             = Color3.new(0,1,1)
local FastAttackEnabled    = false
local FastAttackRange      = 5000
local FastAttackConnection = nil
local FruitAttack          = false
local Tracers_Enabled      = false
local Tracers_Color        = Color3.fromRGB(255,165,0)
local Tracers_Thickness    = 1.5
local TracerLines          = {}
local Farm_OrbitActive     = false
local Farm_AboveActive     = false
local Farm_MagnetActive    = false
local Farm_RaidActive      = false
local Farm_OrbitSpeed      = 5
local Farm_OrbitDistance   = 15
local Farm_AboveHeight     = 12
local Farm_MagnetHeight    = -4
local Farm_MagnetForce     = 0.15
local Farm_RaidSpeed       = 16
local AntiTP_Enabled       = false
local AntiTP_Threshold     = 10
local AntiTP_LastPos       = nil
local AntiTP_Connection    = nil
local FakeLag_Enabled      = false
local FakeLag_Interval     = 0.1
local FakeLag_Duration     = 0.05
local Unbreakable          = false
local UnbreakableConnection= nil
local fruitConnsP          = {}
local fruitConnsN          = {}

-- ============================================================
--  UTILS
-- ============================================================
local function TpTo(cframe)
    local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cframe end
end

local function GetNearestPlayer()
    local nearest,dist = nil,math.huge
    if not lp.Character or not lp.Character:FindFirstChild("HumanoidRootPart") then return nil end
    for _,v in pairs(Players:GetPlayers()) do
        if v~=lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local d=(lp.Character.HumanoidRootPart.Position-v.Character.HumanoidRootPart.Position).Magnitude
            if d<dist then dist=d; nearest=v end
        end
    end
    return nearest
end

local function AttackMultipleTargets(targets)
    pcall(function()
        local Modules=ReplicatedStorage:WaitForChild("Modules",3); if not Modules then return end
        local Net=Modules:WaitForChild("Net",3); if not Net then return end
        local RA=Net:FindFirstChild("RE/RegisterAttack"); local RH=Net:FindFirstChild("RE/RegisterHit"); if not RA or not RH then return end
        RA:FireServer(0)
        for _,t in pairs(targets) do local head=t:FindFirstChild("Head"); if head then RH:FireServer(head,targets) end end
    end)
end

-- ============================================================
--  ESP
-- ============================================================
local function ClearESP()
    for _,obj in pairs(ESPObjects) do if obj then obj:Destroy() end end
    ESPObjects={}
end

local function CreateESP(target)
    if not target or not target:FindFirstChild("Head") or target.Head:FindFirstChild("TommyESP") then return end
    local bb=Instance.new("BillboardGui",target.Head)
    bb.Name="TommyESP"; bb.Adornee=target.Head
    bb.Size=UDim2.new(0,100,0,50); bb.StudsOffset=Vector3.new(0,3,0); bb.AlwaysOnTop=true
    local lbl=Instance.new("TextLabel",bb)
    lbl.BackgroundTransparency=1; lbl.Size=UDim2.new(1,0,1,0)
    lbl.Font="GothamBold"; lbl.TextSize=13; lbl.TextStrokeTransparency=0.5; lbl.TextColor3=ESPColor
    task.spawn(function()
        while bb and bb.Parent and ESPEnabled do
            pcall(function()
                local d=math.floor((lp.Character.HumanoidRootPart.Position-target.HumanoidRootPart.Position).Magnitude)
                lbl.Text=target.Name.."\n["..d.."m]"
            end)
            task.wait(0.5)
        end
        if bb then bb:Destroy() end
    end)
    table.insert(ESPObjects,bb)
end

local function UpdateESP()
    ClearESP(); if not ESPEnabled then return end
    for _,p in pairs(Players:GetPlayers()) do if p~=lp and p.Character then CreateESP(p.Character) end end
    local enemies=workspace:FindFirstChild("Enemies")
    if enemies then for _,npc in pairs(enemies:GetChildren()) do CreateESP(npc) end end
end

-- ============================================================
--  FLIGHT
-- ============================================================
local function stopFlying()
    flying=false
    if bv then bv:Destroy(); bv=nil end
    if bg then bg:Destroy(); bg=nil end
    pcall(function()
        if lp.Character then
            local hum=lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            local anim=lp.Character:FindFirstChild("Animate"); if anim then anim.Disabled=false end
        end
    end)
end

local function startFlying()
    local char=lp.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    stopFlying(); flying=true
    local root=char.HumanoidRootPart
    local anim=char:FindFirstChild("Animate"); if anim then anim.Disabled=true end
    bg=Instance.new("BodyGyro",root); bg.D=100; bg.P=9e4; bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.CFrame=root.CFrame
    bv=Instance.new("BodyVelocity",root); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9)
    task.spawn(function()
        while flying and char.Parent and root.Parent do
            local cam=workspace.CurrentCamera; local camCF=cam.CFrame
            local fwd=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z).Unit
            local right=Vector3.new(camCF.RightVector.X,0,camCF.RightVector.Z).Unit
            local vel=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel=vel+fwd*flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel=vel-fwd*flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel=vel+right*flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel=vel-right*flySpeed end
            local yVel=0
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then yVel=flySpeed end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then yVel=-flySpeed end
            bv.Velocity=Vector3.new(vel.X,yVel,vel.Z)
            bg.CFrame=CFrame.new(root.Position)*CFrame.Angles(0,math.atan2(-camCF.LookVector.X,-camCF.LookVector.Z),0)
            task.wait()
        end
        stopFlying()
    end)
end

-- ============================================================
--  GHOST TP
-- ============================================================
local function StartGhostInstaTp()
    if GhostTpConnection then GhostTpConnection:Disconnect() end
    ghostFrameCounter=0
    pcall(function()
        if not GhostCFrame then
            local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            GhostCFrame=hrp and hrp.CFrame or CFrame.new(0,0,0)
        end
    end)
    GhostTpConnection=RunService.Heartbeat:Connect(function()
        if not GhostTpEnabled or not getgenv().SelectedPlayer then return end
        pcall(function()
            local char=lp.Character; local target=Players:FindFirstChild(getgenv().SelectedPlayer)
            if not (char and target and target.Character) then return end
            local hrp=char:FindFirstChild("HumanoidRootPart")
            local targetHRP=target.Character:FindFirstChild("HumanoidRootPart")
            if not (hrp and targetHRP) then return end
            ghostFrameCounter+=1
            local targetCF=targetHRP.CFrame*CFrame.new(XOffset,YOffset,ZOffset)
            if BlinkMode then hrp.CFrame=targetCF
            elseif ghostFrameCounter%GHOST_RATIO==0 then hrp.CFrame=GhostCFrame or targetCF
            else hrp.CFrame=targetCF end
        end)
    end)
end

-- ============================================================
--  MAGNETO
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.02)
        if getgenv().MagnetEnabled then
            pcall(function()
                local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                local function Atraer(e)
                    local eHRP=e:FindFirstChild("HumanoidRootPart"); local eHum=e:FindFirstChild("Humanoid")
                    if eHRP and eHum and eHum.Health>0 then
                        if (eHRP.Position-myHRP.Position).Magnitude<=getgenv().MagnetRange then
                            eHRP.CFrame=eHRP.CFrame:Lerp(myHRP.CFrame*CFrame.new(0,0,-getgenv().MagnetDistance),getgenv().PullForce)
                            eHRP.CanCollide=false
                        end
                    end
                end
                local enemies=workspace:FindFirstChild("Enemies"); if enemies then for _,npc in pairs(enemies:GetChildren()) do Atraer(npc) end end
                for _,p in pairs(Players:GetPlayers()) do if p~=lp and p.Character then Atraer(p.Character) end end
            end)
        end
    end
end)

-- ============================================================
--  RUNTIME LOOPS
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
            local char=lp.Character; if not char then return end
            local hum=char:FindFirstChildOfClass("Humanoid"); local hrp=char:FindFirstChild("HumanoidRootPart"); if not hum then return end
            if _G.WalkSpeedEnabled then hum.WalkSpeed=_G.WalkSpeedValue end
            if _G.JumpPowerEnabled then hum.JumpPower=_G.JumpPowerValue; hum.UseJumpPower=true else hum.UseJumpPower=false end
            if _G.MaxSlopeEnabled then hum.MaxSlopeAngle=89 end
            if _G.AntiFriccionEnabled and hrp and hum.MoveDirection.Magnitude>0 then
                hrp.Velocity=Vector3.new(hum.MoveDirection.X*_G.WalkSpeedValue,hrp.Velocity.Y,hum.MoveDirection.Z*_G.WalkSpeedValue)
            end
        end)
    end
end)

lp.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    pcall(function()
        local hum=char:WaitForChild("Humanoid",5); if not hum then return end
        if _G.WalkSpeedEnabled then hum.WalkSpeed=_G.WalkSpeedValue end
        if _G.JumpPowerEnabled then hum.JumpPower=_G.JumpPowerValue; hum.UseJumpPower=true end
    end)
end)

RunService.Heartbeat:Connect(function()
    if not lp.Character then return end
    local root=lp.Character:FindFirstChild("HumanoidRootPart")
    if getgenv().WalkOnWater and root and root.Position.Y<20 then
        root.CFrame=CFrame.new(root.Position.X,21,root.Position.Z)*(root.CFrame-root.Position)
    end
    if getgenv().NoclipEnabled then for _,v in pairs(lp.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end end
    if getgenv().SpinEnabled and root then root.CFrame=root.CFrame*CFrame.Angles(0,math.rad(getgenv().SpinSpeed),0) end
end)

task.spawn(function()
    while true do
        task.wait(0.01)
        pcall(function()
            local root=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not root or lp.Character.Humanoid.Health<=0 or GhostTpEnabled then return end
            if getgenv().SkyTrackerActive then
                root.CFrame=root.CFrame+Vector3.new(0,9999,0)
            elseif getgenv().SelectedPlayer then
                local tp=Players:FindFirstChild(getgenv().SelectedPlayer)
                if tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart") then
                    local tRoot=tp.Character.HumanoidRootPart
                    if getgenv().TPDirectActive then root.CFrame=tRoot.CFrame*CFrame.new(0,1.5,3.5)
                    elseif getgenv().KillTrackerActive then root.CFrame=tRoot.CFrame+Vector3.new(0,getgenv().InstaTPSkyHeight,0) end
                end
            end
        end)
    end
end)

task.spawn(function() while true do task.wait(3); if ESPEnabled then UpdateESP() end end end)
task.spawn(function() while true do task.wait(FakeLag_Interval); if FakeLag_Enabled then local s=tick(); while tick()-s<FakeLag_Duration do end end end end)

-- Farm loops
local function GetNearestNPC()
    local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
    local c,b=nil,math.huge
    for _,v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v~=lp.Character then
            local hum=v:FindFirstChildOfClass("Humanoid"); local hrp=v:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health>0 and not Players:GetPlayerFromCharacter(v) then
                local d=(myHRP.Position-hrp.Position).Magnitude; if d<b then b=d; c=v end
            end
        end
    end
    return c
end

task.spawn(function()
    while true do
        task.wait()
        if Farm_OrbitActive then pcall(function()
            local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
            local npc=GetNearestNPC(); if not npc then return end
            local npcHRP=npc:FindFirstChild("HumanoidRootPart"); if not npcHRP then return end
            local t=tick()*Farm_OrbitSpeed
            myHRP.CFrame=myHRP.CFrame:Lerp(CFrame.lookAt(npcHRP.Position+Vector3.new(math.cos(t)*Farm_OrbitDistance,3,math.sin(t)*Farm_OrbitDistance),npcHRP.Position),0.2)
        end) end
        if Farm_AboveActive then pcall(function()
            local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
            local npc=GetNearestNPC(); if not npc then return end
            local npcHRP=npc:FindFirstChild("HumanoidRootPart"); if not npcHRP then return end
            myHRP.CFrame=myHRP.CFrame:Lerp(CFrame.new(npcHRP.Position+Vector3.new(0,Farm_AboveHeight,0)),0.15)
        end) end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.02)
        if Farm_MagnetActive then pcall(function()
            local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
            local npc=GetNearestNPC(); if not npc then return end
            local npcHRP=npc:FindFirstChild("HumanoidRootPart"); if not npcHRP then return end
            npcHRP.CFrame=npcHRP.CFrame:Lerp(CFrame.new(myHRP.Position+Vector3.new(0,Farm_MagnetHeight,0)),Farm_MagnetForce)
            npcHRP.CanCollide=false
        end) end
        if Farm_RaidActive then pcall(function()
            local char=lp.Character; local myHRP=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid"); if not myHRP or not hum then return end
            local npc=GetNearestNPC(); if not npc then return end
            local npcHRP=npc:FindFirstChild("HumanoidRootPart"); if not npcHRP then return end
            hum.WalkSpeed=Farm_RaidSpeed; hum:MoveTo(npcHRP.Position)
        end) end
    end
end)

-- ============================================================
--  GUI PREMIUM
-- ============================================================
pcall(function() CoreGui:FindFirstChild("TommyHubV5"):Destroy() end)

local ScreenGui=Instance.new("ScreenGui",CoreGui)
ScreenGui.Name="TommyHubV5"; ScreenGui.ResetOnSpawn=false
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; ScreenGui.DisplayOrder=999

local C={
    bg    = Color3.fromRGB(8,8,12),
    panel = Color3.fromRGB(12,12,18),
    card  = Color3.fromRGB(16,16,24),
    acc   = Color3.fromRGB(120,60,255),
    acc2  = Color3.fromRGB(80,200,255),
    text  = Color3.fromRGB(220,220,240),
    muted = Color3.fromRGB(100,100,130),
    green = Color3.fromRGB(60,220,120),
    red   = Color3.fromRGB(220,60,60),
    gold  = Color3.fromRGB(240,180,60),
}

local function mk(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    if parent then o.Parent=parent end
    return o
end
local function corner(r,p) mk("UICorner",{CornerRadius=UDim.new(0,r or 8)},p) end
local function stroke(col,thick,p) mk("UIStroke",{Color=col,Thickness=thick or 1},p) end
local function label(txt,font,size,col,xa,parent)
    return mk("TextLabel",{Text=txt,Font=font or Enum.Font.Gotham,TextSize=size or 12,TextColor3=col or C.text,BackgroundTransparency=1,TextXAlignment=xa or Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},parent)
end

-- MAIN
local FULL=UDim2.new(0,460,0,580)
local MINI=UDim2.new(0,220,0,42)
local minimized=false

local Main=mk("Frame",{Size=FULL,Position=UDim2.new(0.5,-230,0.05,0),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,Draggable=true},ScreenGui)
corner(14,Main); stroke(C.acc,1.5,Main)

task.spawn(function()
    local t=0; local s=Main:FindFirstChildOfClass("UIStroke")
    while s and s.Parent do task.wait(0.06); t+=0.06; s.Transparency=0.3+0.4*math.abs(math.sin(t*0.6)) end
end)

-- TOP BAR
local TopBar=mk("Frame",{Size=UDim2.new(1,0,0,42),BackgroundColor3=C.panel,BorderSizePixel=0},Main)
corner(14,TopBar); stroke(C.acc,1,TopBar)
mk("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=C.panel,BorderSizePixel=0},TopBar)

local avOuter=mk("Frame",{Size=UDim2.new(0,30,0,30),Position=UDim2.new(0,6,0.5,-15),BackgroundColor3=C.bg,BorderSizePixel=0},TopBar)
corner(15,avOuter); stroke(C.acc,1.5,avOuter)
local avImg=mk("ImageLabel",{Size=UDim2.new(1,-4,1,-4),Position=UDim2.new(0,2,0,2),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Crop},avOuter)
corner(13,avImg)
task.spawn(function()
    local ok,url=pcall(function() return Players:GetUserThumbnailAsync(lp.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end)
    if ok then avImg.Image=url end
end)

local titleLbl=label("👑 TOMMY HUB  v5",Enum.Font.GothamBlack,14,C.text,Enum.TextXAlignment.Left,TopBar)
titleLbl.Size=UDim2.new(0,180,1,0); titleLbl.Position=UDim2.new(0,42,0,0)
local verLbl=label("PREMIUM  |  "..lp.Name,Enum.Font.Gotham,8,C.acc,Enum.TextXAlignment.Left,TopBar)
verLbl.Size=UDim2.new(0,180,0,12); verLbl.Position=UDim2.new(0,42,1,-14)

local function topBtn(txt,x,col)
    local b=mk("TextButton",{Size=UDim2.new(0,24,0,24),Position=UDim2.new(1,x,0.5,-12),BackgroundColor3=col,Text=txt,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBlack,TextSize=13,BorderSizePixel=0,AutoButtonColor=false},TopBar)
    corner(6,b); return b
end
local closeBtn=topBtn("✕",-30,C.red)
local minBtn=topBtn("−",-58,Color3.fromRGB(60,60,100))
closeBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
minBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    Main:TweenSize(minimized and MINI or FULL,Enum.EasingDirection.Out,Enum.EasingStyle.Quint,0.25,true)
    minBtn.Text=minimized and "+" or "−"
end)

-- TAB BAR — dentro del main con scroll horizontal para que no se salga
local TabBarContainer=mk("Frame",{Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,0,44),BackgroundColor3=C.panel,BorderSizePixel=0,ClipsDescendants=true},Main)
local TabBar=mk("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ScrollBarThickness=0,BorderSizePixel=0,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.X},TabBarContainer)
mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,3),HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center},TabBar)
mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},TabBar)

-- CONTENT
local Content=mk("Frame",{Size=UDim2.new(1,0,1,-80),Position=UDim2.new(0,0,0,80),BackgroundTransparency=1,ClipsDescendants=true},Main)

local function makePage()
    local p=mk("ScrollingFrame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Visible=false,ScrollBarThickness=3,ScrollBarImageColor3=C.acc,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,2000)},Content)
    mk("UIListLayout",{Padding=UDim.new(0,5),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},p)
    mk("UIPadding",{PaddingTop=UDim.new(0,6),PaddingBottom=UDim.new(0,6)},p)
    return p
end

local tabNames={"👥 Players","💥 Kill","👾 NPCs","⚙️ Misc","🌐 TP","🛡️ Anti","🌾 Farm"}
local pages={}
for i=1,#tabNames do pages[i]=makePage() end

local allTabs={}

local function showPage(idx)
    for _,p in pairs(pages) do p.Visible=false end
    pages[idx].Visible=true
    for i,t in pairs(allTabs) do
        TweenService:Create(t,TweenInfo.new(0.15),{BackgroundColor3=i==idx and C.acc:Lerp(C.bg,0.3) or C.card}):Play()
        t.TextColor3=i==idx and C.text or C.muted
    end
end

for i,name in pairs(tabNames) do
    local t=mk("TextButton",{Size=UDim2.new(0,60,0,26),Text=name,BackgroundColor3=C.card,TextColor3=C.muted,Font=Enum.Font.GothamBold,TextSize=8,BorderSizePixel=0,AutoButtonColor=false},TabBar)
    corner(6,t); stroke(C.acc,1,t)
    t.MouseButton1Click:Connect(function() showPage(i) end)
    table.insert(allTabs,t)
end
showPage(1)

-- ============================================================
--  HELPERS
-- ============================================================
local pageOrder={}; for i=1,#pages do pageOrder[i]=1 end

local function addSec(pageIdx,txt)
    local f=mk("Frame",{Size=UDim2.new(1,-12,0,22),LayoutOrder=pageOrder[pageIdx],BackgroundColor3=C.acc:Lerp(C.bg,0.65),BorderSizePixel=0},pages[pageIdx])
    corner(5,f)
    local l=label("  "..txt,Enum.Font.GothamBold,10,C.acc2,Enum.TextXAlignment.Left,f)
    l.Size=UDim2.new(1,0,1,0)
    pageOrder[pageIdx]+=1
    return f
end

local function addToggle(pageIdx,txt,cb)
    local btn=mk("TextButton",{Size=UDim2.new(1,-12,0,34),LayoutOrder=pageOrder[pageIdx],BackgroundColor3=C.card,Text="",BorderSizePixel=0,AutoButtonColor=false},pages[pageIdx])
    corner(8,btn); stroke(C.acc,1,btn)
    local lbl=label(txt,Enum.Font.GothamSemibold,11,C.text,Enum.TextXAlignment.Left,btn)
    lbl.Size=UDim2.new(1,-44,1,0); lbl.Position=UDim2.new(0,8,0,0)
    local dot=mk("Frame",{Size=UDim2.new(0,13,0,13),Position=UDim2.new(1,-24,0.5,-6.5),BackgroundColor3=C.muted,BorderSizePixel=0},btn)
    corner(7,dot)
    local state=false
    btn.MouseButton1Click:Connect(function()
        state=not state
        TweenService:Create(dot,TweenInfo.new(0.15),{BackgroundColor3=state and C.green or C.muted}):Play()
        TweenService:Create(btn,TweenInfo.new(0.15),{BackgroundColor3=state and C.card:Lerp(C.acc,0.12) or C.card}):Play()
        if cb then cb(state) end
    end)
    pageOrder[pageIdx]+=1
    return btn,dot
end

local function addBtn2(pageIdx,txt,col,cb)
    local btn=mk("TextButton",{Size=UDim2.new(1,-12,0,32),LayoutOrder=pageOrder[pageIdx],BackgroundColor3=(col or C.acc):Lerp(C.bg,0.5),Text=txt,TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=11,BorderSizePixel=0,AutoButtonColor=false},pages[pageIdx])
    corner(8,btn); stroke(col or C.acc,1,btn)
    btn.MouseButton1Click:Connect(function() if cb then cb() end end)
    btn.MouseEnter:Connect(function() TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=(col or C.acc):Lerp(Color3.new(1,1,1),0.08)}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=(col or C.acc):Lerp(C.bg,0.5)}):Play() end)
    pageOrder[pageIdx]+=1
    return btn
end

-- ============================================================
--  PAGE 1: PLAYERS
-- ============================================================
addSec(1,"👤 Seleccion")
addBtn2(1,"⚡ TP Directo",C.acc,function()
    if getgenv().SelectedPlayer then
        local t=Players:FindFirstChild(getgenv().SelectedPlayer)
        if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") then TpTo(t.Character.HumanoidRootPart.CFrame) end
    end
end)
addBtn2(1,"🌐 TP a Todos",C.acc2,function()
    task.spawn(function() for _,p in pairs(Players:GetPlayers()) do if p~=lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then TpTo(p.Character.HumanoidRootPart.CFrame); task.wait(0.5) end end end)
end)

addSec(1,"🎯 Trackers")
addToggle(1,"📍 Insta TP (Pegado)",function(v) getgenv().TPDirectActive=v end)
addToggle(1,"💀 Kill Tracker",function(v) getgenv().KillTrackerActive=v end)
addToggle(1,"☁️ Sky Tracker",function(v) getgenv().SkyTrackerActive=v end)
addToggle(1,"👁️ Spectate",function(v)
    if v and getgenv().SelectedPlayer then
        local t=Players:FindFirstChild(getgenv().SelectedPlayer)
        if t and t.Character and t.Character:FindFirstChild("Humanoid") then Camera.CameraSubject=t.Character.Humanoid end
    else if lp.Character and lp.Character:FindFirstChild("Humanoid") then Camera.CameraSubject=lp.Character.Humanoid end end
end)
addToggle(1,"👻 Ghost TP",function(v)
    GhostTpEnabled=v
    if v then StartGhostInstaTp() else if GhostTpConnection then GhostTpConnection:Disconnect() end end
end)
addToggle(1,"💫 Blink Mode",function(v) BlinkMode=v end)

addSec(1,"📋 Player List")
local pScroll=mk("ScrollingFrame",{Size=UDim2.new(1,-12,0,180),LayoutOrder=pageOrder[1],BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.acc,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},pages[1])
corner(8,pScroll); stroke(C.acc,1,pScroll)
mk("UIListLayout",{Padding=UDim.new(0,4),HorizontalAlignment=Enum.HorizontalAlignment.Center},pScroll)
mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4)},pScroll)
pageOrder[1]+=1

local function CreatePlayerCard(player)
    if player==lp then return end
    local card=mk("Frame",{Size=UDim2.new(1,-4,0,48),BackgroundColor3=C.card,BorderSizePixel=0},pScroll)
    corner(8,card); stroke(C.acc,1,card)
    local av=mk("ImageLabel",{Size=UDim2.new(0,34,0,34),Position=UDim2.new(0,6,0.5,-17),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150",BorderSizePixel=0},card)
    corner(17,av)
    local nl=label(player.DisplayName,Enum.Font.GothamBold,11,C.text,Enum.TextXAlignment.Left,card)
    nl.Size=UDim2.new(1,-110,0,16); nl.Position=UDim2.new(0,46,0,8)
    local bb=mk("Frame",{Size=UDim2.new(1,-110,0,5),Position=UDim2.new(0,46,0,28),BackgroundColor3=C.bg,BorderSizePixel=0},card)
    corner(3,bb)
    local bf=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=C.green,BorderSizePixel=0},bb)
    corner(3,bf)
    local selBtn=mk("TextButton",{Size=UDim2.new(0,50,0,24),Position=UDim2.new(1,-58,0.5,-12),BackgroundColor3=C.acc:Lerp(C.bg,0.4),Text="SELECT",TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=9,BorderSizePixel=0,AutoButtonColor=false},card)
    corner(6,selBtn); stroke(C.acc,1,selBtn)
    selBtn.MouseButton1Click:Connect(function()
        getgenv().SelectedPlayer=player.Name
        for _,c in pairs(pScroll:GetChildren()) do if c:IsA("Frame") then TweenService:Create(c,TweenInfo.new(0.15),{BackgroundColor3=C.card}):Play() end end
        TweenService:Create(card,TweenInfo.new(0.15),{BackgroundColor3=C.card:Lerp(C.acc,0.18)}):Play()
    end)
    local conn=RunService.RenderStepped:Connect(function()
        if not player or not player.Parent then conn:Disconnect(); card:Destroy(); return end
        pcall(function()
            local hum=player.Character and player.Character:FindFirstChild("Humanoid")
            if hum then local hp=math.clamp(hum.Health/hum.MaxHealth,0,1); bf.Size=UDim2.new(hp,0,1,0); bf.BackgroundColor3=Color3.fromHSV(hp*0.35,0.8,1) end
        end)
    end)
end

for _,p in pairs(Players:GetPlayers()) do CreatePlayerCard(p) end
Players.PlayerAdded:Connect(CreatePlayerCard)
Players.PlayerRemoving:Connect(function(p) if pScroll:FindFirstChild(p.Name) then pScroll[p.Name]:Destroy() end end)

-- ============================================================
--  PAGE 2: KILLAURA PLAYERS
-- ============================================================
addSec(2,"⚡ Fast Attack")
addToggle(2,"⚡ Fast Attack (Players)",function(v)
    FastAttackEnabled=v
    if v then
        if FastAttackConnection then task.cancel(FastAttackConnection) end
        FastAttackConnection=task.spawn(function()
            while FastAttackEnabled do
                task.wait(0.08)
                pcall(function()
                    local char=lp.Character; if not char then return end
                    local myHRP=char:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                    local Modules=ReplicatedStorage:WaitForChild("Modules",3); if not Modules then return end
                    local Net=Modules:WaitForChild("Net",3); if not Net then return end
                    local RA=Net:FindFirstChild("RE/RegisterAttack"); local RH=Net:FindFirstChild("RE/RegisterHit"); if not RA or not RH then return end
                    local targets={}
                    for _,pl in pairs(Players:GetPlayers()) do
                        if pl~=lp and pl.Character then
                            local pHum=pl.Character:FindFirstChild("Humanoid"); local pHRP=pl.Character:FindFirstChild("HumanoidRootPart"); local pH=pl.Character:FindFirstChild("Head")
                            if pHum and pHRP and pH and pHum.Health>0 and (pHRP.Position-myHRP.Position).Magnitude<=FastAttackRange then table.insert(targets,{pl.Character,pH}) end
                        end
                    end
                    if #targets>0 then RA:FireServer(0); for _,t in pairs(targets) do RH:FireServer(t[2],targets) end end
                end)
            end
        end)
    else if FastAttackConnection then task.cancel(FastAttackConnection); FastAttackConnection=nil end end
end)

addSec(2,"🍎 Fruit Attack (Players)")
local fruitsData={
    {"🦊 Kitsune","Kitsune-Kitsune",{1,true},function(d) return vector.create(d.X,d.Y,d.Z) end},
    {"💢 Pain","Pain-Pain",{1,true},function(d) return vector.create(d.X,0,d.Z) end},
    {"🐉 Dragon","Dragon-Dragon",{1},function(d) return vector.create(d.X,d.Y,d.Z) end},
    {"🐅 Tiger","Tiger-Tiger",{3},function(d) return vector.create(d.X,d.Y,d.Z) end},
    {"🦖 T-Rex","T-Rex-T-Rex",{1},function(d) return vector.create(d.X,d.Y,d.Z) end},
    {"🌀 Control","Control-Control",{1,true},function(d) return vector.create(d.X,d.Y,d.Z) end},
    {"🦊 Empyrean","Empyrean (Kitsune)-Empyrean (Kitsune)",{4,true},function(d) return vector.create(d.X,d.Y,d.Z) end},
}

for _,f in pairs(fruitsData) do
    addToggle(2,f[1].." | Players",function(v)
        if fruitConnsP[f[2]] then task.cancel(fruitConnsP[f[2]]); fruitConnsP[f[2]]=nil end
        if v then fruitConnsP[f[2]]=task.spawn(function()
            while fruitConnsP[f[2]] do
                task.wait(0.01)
                local target=GetNearestPlayer(); if not target or not target.Character then continue end
                local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                local tHRP=target.Character:FindFirstChild("HumanoidRootPart")
                if myHRP and tHRP then
                    local dir=(tHRP.Position-myHRP.Position).Unit
                    pcall(function() lp.Character:WaitForChild(f[2]):WaitForChild("LeftClickRemote"):FireServer(f[4](dir),table.unpack(f[3])) end)
                end
            end
        end) end
    end)
end

-- ============================================================
--  PAGE 3: KILLAURA NPCs
-- ============================================================
addSec(3,"👾 Fast Attack NPCs")
addToggle(3,"⚡ Fast Attack (NPCs)",function(v)
    local conn=nil; local active=v
    if v then conn=task.spawn(function()
        while active do
            task.wait(0.08)
            pcall(function()
                local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                local Modules=ReplicatedStorage:WaitForChild("Modules",3); if not Modules then return end
                local Net=Modules:WaitForChild("Net",3); if not Net then return end
                local RA=Net:FindFirstChild("RE/RegisterAttack"); local RH=Net:FindFirstChild("RE/RegisterHit"); if not RA or not RH then return end
                local targets={}; local enemies=workspace:FindFirstChild("Enemies")
                if enemies then for _,npc in pairs(enemies:GetChildren()) do
                    local hum=npc:FindFirstChild("Humanoid"); local hrp=npc:FindFirstChild("HumanoidRootPart"); local head=npc:FindFirstChild("Head")
                    if hum and hrp and head and hum.Health>0 and (hrp.Position-myHRP.Position).Magnitude<=FastAttackRange then table.insert(targets,{npc,head}) end
                end end
                if #targets>0 then RA:FireServer(0); for _,t in pairs(targets) do RH:FireServer(t[2],targets) end end
            end)
        end
    end) end
end)

addSec(3,"🍎 Fruit Attack (NPCs)")
for _,f in pairs(fruitsData) do
    addToggle(3,f[1].." | NPCs",function(v)
        if fruitConnsN[f[2]] then task.cancel(fruitConnsN[f[2]]); fruitConnsN[f[2]]=nil end
        if v then fruitConnsN[f[2]]=task.spawn(function()
            while fruitConnsN[f[2]] do
                task.wait(0.01)
                local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then continue end
                local enemies=workspace:FindFirstChild("Enemies"); if not enemies then continue end
                for _,npc in pairs(enemies:GetChildren()) do
                    local hum=npc:FindFirstChild("Humanoid"); local npcHRP=npc:FindFirstChild("HumanoidRootPart")
                    if hum and npcHRP and hum.Health>0 and (npcHRP.Position-myHRP.Position).Magnitude<=50 then
                        local dir=(npcHRP.Position-myHRP.Position).Unit
                        pcall(function() lp.Character:WaitForChild(f[2]):WaitForChild("LeftClickRemote"):FireServer(f[4](dir),table.unpack(f[3])) end)
                    end
                end
            end
        end) end
    end)
end

-- ============================================================
--  PAGE 4: MISC
-- ============================================================
addSec(4,"🚀 Movimiento")
addToggle(4,"🚀 Speed",function(v) _G.WalkSpeedEnabled=v end)
addToggle(4,"⬆️ Super Salto",function(v) _G.JumpPowerEnabled=v; pcall(function() local h=lp.Character:FindFirstChildOfClass("Humanoid"); if h then h.UseJumpPower=v end end) end)
addToggle(4,"👻 Noclip",function(v) getgenv().NoclipEnabled=v end)
addToggle(4,"🌊 Walk on Water",function(v) getgenv().WalkOnWater=v end)
addToggle(4,"🔄 Spin",function(v) getgenv().SpinEnabled=v end)
addToggle(4,"✈️ Vuelo",function(v) if v then startFlying() else stopFlying() end end)
addToggle(4,"🔥 Anti-Friccion",function(v) _G.AntiFriccionEnabled=v end)
addToggle(4,"📐 Anti-Pendiente",function(v) _G.MaxSlopeEnabled=v; pcall(function() local h=lp.Character:FindFirstChildOfClass("Humanoid"); if h then h.MaxSlopeAngle=v and 89 or 45 end end) end)

addSec(4,"⚔️ Combate")
addToggle(4,"⚡ Fast Attack (All)",function(v)
    FastAttackEnabled=v
    if v then
        if FastAttackConnection then task.cancel(FastAttackConnection) end
        FastAttackConnection=task.spawn(function()
            while FastAttackEnabled do
                task.wait(0.08)
                pcall(function()
                    local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                    local Modules=ReplicatedStorage:WaitForChild("Modules",3); if not Modules then return end
                    local Net=Modules:WaitForChild("Net",3); if not Net then return end
                    local RA=Net:FindFirstChild("RE/RegisterAttack"); local RH=Net:FindFirstChild("RE/RegisterHit"); if not RA or not RH then return end
                    local targets={}
                    for _,pl in pairs(Players:GetPlayers()) do if pl~=lp and pl.Character then local h=pl.Character:FindFirstChild("Humanoid"); local hrp=pl.Character:FindFirstChild("HumanoidRootPart"); local head=pl.Character:FindFirstChild("Head"); if h and hrp and head and h.Health>0 and (hrp.Position-myHRP.Position).Magnitude<=FastAttackRange then table.insert(targets,{pl.Character,head}) end end end
                    local enemies=workspace:FindFirstChild("Enemies"); if enemies then for _,npc in pairs(enemies:GetChildren()) do local h=npc:FindFirstChild("Humanoid"); local hrp=npc:FindFirstChild("HumanoidRootPart"); local head=npc:FindFirstChild("Head"); if h and hrp and head and h.Health>0 and (hrp.Position-myHRP.Position).Magnitude<=FastAttackRange then table.insert(targets,{npc,head}) end end end
                    if #targets>0 then RA:FireServer(0); for _,t in pairs(targets) do RH:FireServer(t[2],targets) end end
                end)
            end
        end)
    else if FastAttackConnection then task.cancel(FastAttackConnection); FastAttackConnection=nil end end
end)
addToggle(4,"🧲 Magneto",function(v) getgenv().MagnetEnabled=v end)
addToggle(4,"🔰 Unbreakable",function(v)
    Unbreakable=v
    if v then UnbreakableConnection=task.spawn(function() while Unbreakable do task.wait(0.1); if lp.Character then lp.Character:SetAttribute("UnbreakableAll",true) end end end)
    else if UnbreakableConnection then task.cancel(UnbreakableConnection) end; if lp.Character then lp.Character:SetAttribute("UnbreakableAll",false) end end
end)
addToggle(4,"🔮 Auto V4",function(v)
    autoV4=v
    if v then v4Connection=task.spawn(function() while autoV4 do task.wait(0.5); pcall(function() lp:WaitForChild("Backpack"):WaitForChild("Awakening"):WaitForChild("RemoteFunction"):InvokeServer(true) end) end end)
    else if v4Connection then task.cancel(v4Connection) end end
end)

addSec(4,"👁️ ESP")
addToggle(4,"👁️ Player ESP",function(v) ESPEnabled=v; if v then UpdateESP() else ClearESP() end end)

addSec(4,"📷 Camara")
addBtn2(4,"🔁 Reset Camara",C.acc2,function() lp.CameraMaxZoomDistance=100; lp.CameraMinZoomDistance=0.5 end)
addBtn2(4,"📡 Extend Zoom",C.acc,function() lp.CameraMaxZoomDistance=2000 end)

-- ============================================================
--  PAGE 5: TELEPORTS
-- ============================================================
addSec(5,"🏝️ Sea 1")
for _,l in pairs({{"🏝️ Starter Island",CFrame.new(-1251.7,5.1,-1310.5)},{"🌴 Jungle Island",CFrame.new(1536.9,4.8,147.4)},{"🏴 Pirate Village",CFrame.new(-1303.9,4.8,569.4)},{"⚔️ Marine Fortress",CFrame.new(-953.8,5.0,3923.7)},{"🏰 Skypiea",CFrame.new(-4743.8,872.5,-1484.5)},{"🌋 Magma Village",CFrame.new(909.6,4.9,4248.1)},{"❄️ Ice Island",CFrame.new(1459.9,105.0,-3234.4)}}) do addBtn2(5,l[1],C.acc2,function() TpTo(l[2]) end) end
addSec(5,"🌊 Sea 2")
for _,l in pairs({{"⛩️ Flower Hill",CFrame.new(-2468.1,71.0,738.5)},{"🏰 Haunted Castle",CFrame.new(-3026.8,63.2,-2493.9)},{"❄️ Ice Cream Island",CFrame.new(5139.3,74.2,-3256.8)},{"🔥 Fire Island",CFrame.new(3929.6,5.0,2475.9)},{"🌊 Baratie",CFrame.new(3900.0,10.0,900.0)}}) do addBtn2(5,l[1],C.acc,function() TpTo(l[2]) end) end
addSec(5,"🏰 Sea 3")
for _,l in pairs({{"🏯 Haunted Castle S3",CFrame.new(-4500.0,60.0,6000.0)},{"❄️ Tundra",CFrame.new(2500.0,150.0,8500.0)},{"🔥 Cursed Ship",CFrame.new(-700.0,5.0,5500.0)},{"🏰 Castle on the Sea",CFrame.new(-3000.0,20.0,9500.0)},{"🗺️ Barco Maldito",CFrame.new(923.2,125.1,32852.8)},{"🏰 Tiki Outpost",CFrame.new(-16826.959,58.296,317.767)},{"🌸 Reino de Rosa",CFrame.new(-401.334,335.200,642.977)}}) do addBtn2(5,l[1],Color3.fromRGB(130,40,230),function() TpTo(l[2]) end) end
addSec(5,"🛠️ Util")
addBtn2(5,"🌐 TP a Todos",C.acc,function() task.spawn(function() for _,p in pairs(Players:GetPlayers()) do if p~=lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then TpTo(p.Character.HumanoidRootPart.CFrame); task.wait(0.5) end end end) end)
addBtn2(5,"🗑️ Remove Touch Interest",C.red,function() for _,d in pairs(game:GetDescendants()) do if d:IsA("TouchTransmitter") then d:Destroy() end end end)

-- ============================================================
--  PAGE 6: ANTI BUDDHA
-- ============================================================
addSec(6,"🛡️ Defensas")
addToggle(6,"🛡️ Anti TP",function(v)
    AntiTP_Enabled=v
    if v then
        pcall(function() local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if hrp then AntiTP_LastPos=hrp.CFrame end end)
        if AntiTP_Connection then AntiTP_Connection:Disconnect() end
        AntiTP_Connection=RunService.Heartbeat:Connect(function()
            if not AntiTP_Enabled then return end
            pcall(function()
                local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
                if AntiTP_LastPos then
                    if (hrp.Position-AntiTP_LastPos.Position).Magnitude>AntiTP_Threshold then hrp.CFrame=AntiTP_LastPos
                    else AntiTP_LastPos=hrp.CFrame end
                else AntiTP_LastPos=hrp.CFrame end
            end)
        end)
    else AntiTP_Enabled=false; if AntiTP_Connection then AntiTP_Connection:Disconnect() end; AntiTP_LastPos=nil end
end)
addToggle(6,"💧 Walk on Water",function(v) getgenv().WalkOnWater=v end)
addToggle(6,"🌊 Fake Lag",function(v) FakeLag_Enabled=v end)
addToggle(6,"📡 Tracers",function(v) Tracers_Enabled=v end)

addSec(6,"👥 Player List (HP)")
local plScroll=mk("ScrollingFrame",{Size=UDim2.new(1,-12,0,170),LayoutOrder=pageOrder[6],BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.acc,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y},pages[6])
corner(8,plScroll); stroke(C.acc,1,plScroll)
mk("UIListLayout",{Padding=UDim.new(0,4),HorizontalAlignment=Enum.HorizontalAlignment.Center},plScroll)
mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4)},plScroll)
pageOrder[6]+=1

local function CreatePLCard(player)
    if player==lp then return end
    local card=mk("Frame",{Size=UDim2.new(1,-4,0,44),BackgroundColor3=C.card,BorderSizePixel=0},plScroll)
    corner(8,card); stroke(C.acc,1,card)
    local av=mk("ImageLabel",{Size=UDim2.new(0,32,0,32),Position=UDim2.new(0,5,0.5,-16),BackgroundTransparency=1,Image="rbxthumb://type=AvatarHeadShot&id="..player.UserId.."&w=150&h=150",BorderSizePixel=0},card)
    corner(16,av)
    local nl=label(player.DisplayName,Enum.Font.GothamBold,10,C.text,Enum.TextXAlignment.Left,card)
    nl.Size=UDim2.new(1,-50,0,14); nl.Position=UDim2.new(0,42,0,8)
    local bb=mk("Frame",{Size=UDim2.new(1,-50,0,5),Position=UDim2.new(0,42,0,26),BackgroundColor3=C.bg,BorderSizePixel=0},card)
    corner(3,bb)
    local bf=mk("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=C.green,BorderSizePixel=0},bb)
    corner(3,bf)
    local conn=RunService.RenderStepped:Connect(function()
        if not player or not player.Parent then conn:Disconnect(); card:Destroy(); return end
        pcall(function()
            local hum=player.Character and player.Character:FindFirstChild("Humanoid")
            if hum then local hp=math.clamp(hum.Health/hum.MaxHealth,0,1); bf.Size=UDim2.new(hp,0,1,0); bf.BackgroundColor3=Color3.fromHSV(hp*0.35,0.8,1) end
        end)
    end)
end
for _,p in pairs(Players:GetPlayers()) do CreatePLCard(p) end
Players.PlayerAdded:Connect(CreatePLCard)

-- Tracers
local function CreateTracer(player)
    if player==lp then return end
    local line=Drawing.new("Line"); line.Visible=false; line.Color=Tracers_Color; line.Thickness=Tracers_Thickness; line.Transparency=1
    local conn
    conn=RunService.RenderStepped:Connect(function()
        if not Players:FindFirstChild(player.Name) then line:Remove(); conn:Disconnect(); TracerLines[player]=nil; return end
        if Tracers_Enabled and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local myPos,myOn=Camera:WorldToViewportPoint(lp.Character.HumanoidRootPart.Position)
            local ePos,eOn=Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if myOn and eOn then line.From=Vector2.new(myPos.X,myPos.Y); line.To=Vector2.new(ePos.X,ePos.Y); line.Color=Tracers_Color; line.Thickness=Tracers_Thickness; line.Visible=true
            else line.Visible=false end
        else line.Visible=false end
    end)
    TracerLines[player]={line=line,conn=conn}
end
for _,p in pairs(Players:GetPlayers()) do CreateTracer(p) end
Players.PlayerAdded:Connect(CreateTracer)
Players.PlayerRemoving:Connect(function(p) if TracerLines[p] then TracerLines[p].line:Remove(); TracerLines[p].conn:Disconnect(); TracerLines[p]=nil end end)

-- ============================================================
--  PAGE 7: FARM
-- ============================================================
addSec(7,"🌾 NPC Farm")
addToggle(7,"🔄 Orbitar NPC",function(v) Farm_OrbitActive=v; if v then Farm_AboveActive=false end end)
addToggle(7,"⬆️ Arriba del NPC",function(v) Farm_AboveActive=v; if v then Farm_OrbitActive=false end end)
addToggle(7,"🧲 Magneto NPC",function(v) Farm_MagnetActive=v end)
addToggle(7,"🚶 Raid Mode",function(v) Farm_RaidActive=v end)
addBtn2(7,"➡️ Siguiente Sala",C.acc2,function()
    local myHRP=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    for _,name in pairs({"Next","Gate","Portal","Door","Exit"}) do
        for _,obj in pairs(workspace:GetDescendants()) do
            if obj.Name:find(name) and (obj:IsA("BasePart") or obj:IsA("Model")) then
                local pos=obj:IsA("Model") and obj:GetPivot().Position or obj.Position
                myHRP.CFrame=CFrame.new(pos+Vector3.new(0,3,0)); return
            end
        end
    end
end)

-- ============================================================
--  DRAGGABLE
-- ============================================================
local d2,ds2,sp2=false,nil,nil
TopBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        d2=true; ds2=i.Position; sp2=Main.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then d2=false end end)
    end
end)
TopBar.InputChanged:Connect(function(i)
    if d2 and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local delta=i.Position-ds2
        Main.Position=UDim2.new(sp2.X.Scale,sp2.X.Offset+delta.X,sp2.Y.Scale,sp2.Y.Offset+delta.Y)
    end
end)

print("👑 Tommy Hub v5 | Premium | Loaded")

