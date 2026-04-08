--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║              PRISON LIFE - SCRIPT COMPLETO v2.0                  ║
    ║         Hub UI v7.1 | Mobile + PC | Todas as funcoes             ║
    ╚══════════════════════════════════════════════════════════════════╝
    
    FUNCOES:
    ├── ESP          → Todos / Customizado / Cores / Tracers
    ├── Jogador      → WalkSpeed / Fly / Teleporte / No-Clip / Nuke Player
    ├── Auto Prender → Loop inteligente + exclusoes
    ├── Aimbot       → FOV circulo, suavidade, wallcheck, exclusoes
    ├── Armas        → God Mode, Infinite Ammo, Kill Aura, Rapid Fire
    ├── Visuais      → FullBright, Crosshair, Radar, Nametag Distance
    ├── Misc         → Anti-AFK, Chat Spy, Notify Events, Speed Hack
    └── Config       → Temas, Keybinds, Salvar Config
]]

-- ────────────────────────────────────────────────────────────────────
--  SERVICOS
-- ────────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ────────────────────────────────────────────────────────────────────
--  ESTADO GLOBAL
-- ────────────────────────────────────────────────────────────────────
local Estado = {
    -- ESP
    espTodos        = false,
    espCustom       = false,
    espTracers      = true,
    espTracerGross  = 4,
    espTracerTransp = 0.1,
    espNometagDist  = true,
    espMaxDist      = 1000,
    hubFechado      = false,
    espJogadoresSel = {},
    corInmate       = Color3.fromRGB(255, 140,   0),
    corGuard        = Color3.fromRGB( 50, 130, 255),
    corCriminal     = Color3.fromRGB(255,  50,  50),
    corOutro        = Color3.fromRGB(255, 255, 255),

    -- Movimento
    walkspeed        = 16,
    walkspeedAtivo   = false,
    fly              = false,
    voarVel          = 50,
    noClip           = false,
    jumpPower        = 50,
    jumpPowerAtivo   = false,

    -- Auto Prender
    prenderAuto      = false,
    prenderExcluidos = {},
    prenderDelay     = 0,

    -- Aimbot
    aimbotAtivo      = false,
    aimbotFov        = IS_MOBILE and 180 or 120,
    aimbotSmooth     = 0.25,
    aimbotExcluidos  = {},
    aimbotParte      = "Head",
    aimbotWallCheck  = true,
    aimbotVerCirculo = true,

    -- Armas / Combate
    godMode          = false,
    killAura         = false,
    killAuraRange    = 15,
    killAuraCooldown = 0.5,
    rapidFire        = false,
    infiniteAmmo     = false,

    -- Visuais
    fullBright       = false,
    fullBrightBrilho = 3,
    crosshair        = false,
    crosshairCor     = Color3.fromRGB(255, 50, 50),
    radarAtivo       = false,
    radarRange       = 150,

    -- Misc
    antiAfk          = false,
    chatSpy          = false,
    notifyKills      = true,
    notifyDeath      = true,
    speedHack        = false,
    speedHackMult    = 1.5,
    teleportPad      = false,

    -- Config
    keybindToggleHub = Enum.KeyCode.RightShift,
}

-- ────────────────────────────────────────────────────────────────────
--  UTILITARIOS
-- ────────────────────────────────────────────────────────────────────
local _connections = {}
local function Track(conn) table.insert(_connections, conn); return conn end

local function GetChar(p)  return (p or LocalPlayer).Character end
local function GetHRP(p)
    local c = GetChar(p); return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum(p)
    local c = GetChar(p); return c and c:FindFirstChildOfClass("Humanoid")
end
local function ToVP(pos)
    local v, onsc = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), onsc, v.Z
end

local function CorDoTime(plr)
    if not plr or not plr.Team then return Estado.corOutro end
    local n = plr.Team.Name
    if n == "Inmates"   then return Estado.corInmate   end
    if n == "Guards"    then return Estado.corGuard    end
    if n == "Criminals" then return Estado.corCriminal end
    return Estado.corOutro
end

local function MeuTime()
    return LocalPlayer.Team and LocalPlayer.Team.Name or nil
end

local function LimparConexoes(lista)
    for _, c in pairs(lista) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    table.clear(lista)
end

-- ────────────────────────────────────────────────────────────────────
--  REMOTES CACHE
-- ────────────────────────────────────────────────────────────────────
local _remotes = {}
local function GetRemote(nome)
    if _remotes[nome] and _remotes[nome].Parent then return _remotes[nome] end
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    if r then
        _remotes[nome] = r:FindFirstChild(nome)
    end
    return _remotes[nome]
end

-- ────────────────────────────────────────────────────────────────────
--  ESP
-- ────────────────────────────────────────────────────────────────────
local _consESP  = {}
local _espDados = {}

local function EspAtivo()  return Estado.espTodos or Estado.espCustom end
local function DeveMostrarESP(plr)
    if Estado.espTodos then return true end
    if Estado.espCustom then return Estado.espJogadoresSel[plr.Name] == true end
    return false
end

local function RemoverEntradaESP(nome)
    local d = _espDados[nome]; if not d then return end
    if d.hl   and d.hl.Parent   then d.hl:Destroy()  end
    if d.gui  and d.gui.Parent  then d.gui:Destroy() end
    if d.line then pcall(function() d.line:Remove() end) end
    _espDados[nome] = nil
end

local function CriarEntradaESP(plr)
    RemoverEntradaESP(plr.Name)
    local char = plr.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local cor  = CorDoTime(plr)

    local hl = Instance.new("Highlight")
    hl.FillColor = cor; hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = 0.45; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char; hl.Parent = char

    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true; gui.Size = UDim2.new(0,150,0,80)
    gui.StudsOffset = Vector3.new(0,3.8,0); gui.Adornee = hrp; gui.Parent = hrp

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(8,8,12)
    bg.BackgroundTransparency = 0.35; bg.BorderSizePixel = 0; bg.Parent = gui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = cor; stroke.Thickness = 1.2; stroke.Transparency = 0.2; stroke.Parent = bg

    local function MkLabel(sz, pos, txt, cor2, font, bold)
        local l = Instance.new("TextLabel")
        l.Size = sz; l.Position = pos; l.BackgroundTransparency = 1
        l.Text = txt; l.TextColor3 = cor2
        l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        l.TextSize = font; l.TextXAlignment = Enum.TextXAlignment.Center
        l.TextScaled = false; l.TextWrapped = true; l.Parent = bg; return l
    end

    local nomeTxt = plr.DisplayName ~= plr.Name
        and plr.DisplayName.." ("..plr.Name..")" or plr.Name

    local lblNome = MkLabel(UDim2.new(1,-8,0,14), UDim2.new(0,4,0,3),
        nomeTxt, cor, 10, true)

    local teamName = (plr.Team and plr.Team.Name) or "Sem Time"
    local lblTime  = MkLabel(UDim2.new(1,-8,0,11), UDim2.new(0,4,0,18),
        "["..teamName.."]", cor, 9, true)

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1,-8,0,5); barBg.Position = UDim2.new(0,4,0,32)
    barBg.BackgroundColor3 = Color3.fromRGB(30,30,30); barBg.BorderSizePixel = 0; barBg.Parent = bg
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1,0); bc.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(1,0,1,0); barFill.BackgroundColor3 = Color3.fromRGB(60,220,100)
    barFill.BorderSizePixel = 0; barFill.Parent = barBg
    local bfc = Instance.new("UICorner"); bfc.CornerRadius = UDim.new(1,0); bfc.Parent = barFill

    local lblInfo = MkLabel(UDim2.new(1,-8,0,11), UDim2.new(0,4,0,40),
        "HP: ? | Dist: ?", Color3.fromRGB(200,200,200), 9, false)

    local lblStatus = MkLabel(UDim2.new(1,-8,0,10), UDim2.new(0,4,0,54),
        "", Color3.fromRGB(160,210,255), 8, false)

    local line = Drawing.new("Line")
    line.Visible = false; line.Thickness = Estado.espTracerGross
    line.Color = cor; line.Transparency = Estado.espTracerTransp

    _espDados[plr.Name] = {
        plr=plr, hl=hl, gui=gui, line=line, stroke=stroke,
        barFill=barFill, lblNome=lblNome, lblTime=lblTime,
        lblInfo=lblInfo, lblStatus=lblStatus,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do RemoverEntradaESP(nome) end
end

local function AtualizarCoresTime(nomeTime)
    for _, d in pairs(_espDados) do
        if not d.plr then continue end
        if (d.plr.Team and d.plr.Team.Name) ~= nomeTime then continue end
        local cor = CorDoTime(d.plr)
        if d.hl     then d.hl.FillColor        = cor end
        if d.stroke then d.stroke.Color        = cor end
        if d.line   then d.line.Color          = cor end
        if d.lblNome then d.lblNome.TextColor3 = cor end
        if d.lblTime then d.lblTime.TextColor3 = cor end
    end
end

local function AtualizarCoresOutros()
    for _, d in pairs(_espDados) do
        if not d.plr then continue end
        local tn = d.plr.Team and d.plr.Team.Name
        if tn == "Inmates" or tn == "Guards" or tn == "Criminals" then continue end
        local cor = Estado.corOutro
        if d.hl     then d.hl.FillColor        = cor end
        if d.stroke then d.stroke.Color        = cor end
        if d.line   then d.line.Color          = cor end
        if d.lblNome then d.lblNome.TextColor3 = cor end
        if d.lblTime then d.lblTime.TextColor3 = cor end
    end
end

local function IniciarESP()
    LimparConexoes(_consESP); LimparTodoESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then CriarEntradaESP(plr) end
    end
    table.insert(_consESP, Players.PlayerAdded:Connect(function(plr)
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.6)
            if not Estado.hubFechado and EspAtivo() then CriarEntradaESP(plr) end
        end))
    end))
    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.6)
            if not Estado.hubFechado and EspAtivo() then CriarEntradaESP(plr) end
        end))
        table.insert(_consESP, plr.CharacterRemoving:Connect(function()
            RemoverEntradaESP(plr.Name)
        end))
    end

    table.insert(_consESP, RunService.RenderStepped:Connect(function()
        if Estado.hubFechado then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if plr.Character and not _espDados[plr.Name] then CriarEntradaESP(plr)
            elseif not plr.Character and _espDados[plr.Name] then RemoverEntradaESP(plr.Name) end
        end
        local myHRP = GetHRP()
        local tracerOrig
        if myHRP then
            local sp, onSc, depth = ToVP(myHRP.Position - Vector3.new(0,2,0))
            tracerOrig = (onSc and depth > 0) and sp or nil
        end
        tracerOrig = tracerOrig or Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)

        for _, d in pairs(_espDados) do
            local plr = d.plr
            if not plr or not plr.Character then continue end
            local char = plr.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            local cor       = CorDoTime(plr)
            local deveVer   = EspAtivo() and DeveMostrarESP(plr)
            local distVal   = myHRP and (myHRP.Position - hrp.Position).Magnitude or 0
            local dentroMax = distVal <= Estado.espMaxDist

            if d.hl   then d.hl.Enabled   = deveVer and dentroMax end
            if d.gui  then d.gui.Enabled  = deveVer and dentroMax and Estado.espNometagDist end
            if d.stroke then d.stroke.Color = cor end
            if d.line   then d.line.Color   = cor end
            if d.lblNome then d.lblNome.TextColor3 = cor end
            if d.lblTime then
                d.lblTime.TextColor3 = cor
                d.lblTime.Text = "["..(plr.Team and plr.Team.Name or "Sem Time").."]"
            end

            if not deveVer then if d.line then d.line.Visible=false end; continue end

            local hp   = math.floor(hum.Health)
            local maxhp= math.floor(hum.MaxHealth)
            local pct  = maxhp > 0 and (hp/maxhp) or 0
            local dist = math.floor(distVal)

            local barCor = pct > 0.6 and Color3.fromRGB(60,220,100)
                        or pct > 0.3 and Color3.fromRGB(255,190,40)
                        or               Color3.fromRGB(220,55,55)

            if d.barFill then
                d.barFill.Size = UDim2.new(math.clamp(pct,0,1),0,1,0)
                d.barFill.BackgroundColor3 = barCor
            end
            if d.lblInfo then
                d.lblInfo.Text = "HP "..hp.."/"..maxhp.."  |  "..dist.."m"
            end
            if d.lblStatus then
                local spd = hum.MoveDirection.Magnitude > 0.1 and "correndo" or "parado"
                local wl  = (math.floor(hum.WalkSpeed) ~= 16) and " | WS:"..math.floor(hum.WalkSpeed) or ""
                d.lblStatus.Text = spd..wl
            end

            if d.line then
                local sp, onsc, depth = ToVP(hrp.Position - Vector3.new(0,2.5,0))
                if Estado.espTracers and onsc and depth > 0 and dentroMax then
                    d.line.From = tracerOrig; d.line.To = sp
                    d.line.Thickness = Estado.espTracerGross
                    d.line.Transparency = Estado.espTracerTransp
                    d.line.Visible = true
                else
                    d.line.Visible = false
                end
            end
        end
    end))
end

local function PararESP()
    LimparConexoes(_consESP); LimparTodoESP()
end

local function RecarregarESP()
    if EspAtivo() then PararESP(); IniciarESP() else PararESP() end
end

-- ────────────────────────────────────────────────────────────────────
--  RADAR
-- ────────────────────────────────────────────────────────────────────
local _radarGui = nil
local _radarHB  = nil
local RADAR_SIZE = IS_MOBILE and 110 or 130
local RADAR_POS  = IS_MOBILE and UDim2.new(0,8,1,-RADAR_SIZE-80) or UDim2.new(0,8,1,-RADAR_SIZE-60)

local function PararRadar()
    if _radarHB then _radarHB:Disconnect(); _radarHB=nil end
    if _radarGui and _radarGui.Parent then _radarGui:Destroy(); _radarGui=nil end
end

local function IniciarRadar()
    PararRadar()
    local pGui = LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name="RadarGui"; sg.ResetOnSpawn=false
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.IgnoreGuiInset=true; sg.Parent=pGui
    _radarGui = sg

    local bg = Instance.new("Frame")
    bg.Size=UDim2.new(0,RADAR_SIZE,0,RADAR_SIZE); bg.Position=RADAR_POS
    bg.BackgroundColor3=Color3.fromRGB(10,10,16); bg.BackgroundTransparency=0.25
    bg.BorderSizePixel=0; bg.Parent=sg
    local bgC=Instance.new("UICorner"); bgC.CornerRadius=UDim.new(0,RADAR_SIZE/2); bgC.Parent=bg
    local bgS=Instance.new("UIStroke"); bgS.Color=Color3.fromRGB(0,190,210)
    bgS.Thickness=1.5; bgS.Transparency=0.3; bgS.Parent=bg

    -- Cruz central
    for _, rot in ipairs({0,90}) do
        local line=Instance.new("Frame"); line.AnchorPoint=Vector2.new(0.5,0.5)
        line.Size=UDim2.new(1,-10,0,1); line.Position=UDim2.new(0.5,0,0.5,0)
        line.BackgroundColor3=Color3.fromRGB(0,190,210); line.BackgroundTransparency=0.6
        line.Rotation=rot; line.BorderSizePixel=0; line.Parent=bg
    end

    -- Ponto central (eu)
    local mePonto=Instance.new("Frame")
    mePonto.Size=UDim2.new(0,7,0,7); mePonto.AnchorPoint=Vector2.new(0.5,0.5)
    mePonto.Position=UDim2.new(0.5,0,0.5,0); mePonto.BackgroundColor3=Color3.fromRGB(120,220,255)
    mePonto.BorderSizePixel=0; mePonto.ZIndex=3; mePonto.Parent=bg
    local meC=Instance.new("UICorner"); meC.CornerRadius=UDim.new(0,99); meC.Parent=mePonto

    local lblRange=Instance.new("TextLabel")
    lblRange.Size=UDim2.new(1,0,0,12); lblRange.Position=UDim2.new(0,0,1,2)
    lblRange.BackgroundTransparency=1; lblRange.Text="RADAR "..Estado.radarRange.."m"
    lblRange.TextColor3=Color3.fromRGB(0,190,210); lblRange.Font=Enum.Font.GothamBold
    lblRange.TextSize=8; lblRange.ZIndex=3; lblRange.Parent=bg

    local _pontos = {}

    _radarHB = RunService.RenderStepped:Connect(function()
        if Estado.hubFechado or not Estado.radarAtivo then return end
        local myHRP = GetHRP(); if not myHRP then return end
        lblRange.Text = "RADAR "..Estado.radarRange.."m"

        -- limpa pontos antigos
        for _, f in ipairs(_pontos) do if f.Parent then f:Destroy() end end
        _pontos = {}

        local myCF = myHRP.CFrame
        local R = Estado.radarRange
        local HALF = RADAR_SIZE/2 - 8

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local hrp = GetHRP(plr); if not hrp then continue end
            local rel = myCF:PointToObjectSpace(hrp.Position)
            local dx, dz = -rel.Z, rel.X
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist > R then continue end
            local px = HALF + (dx/R)*HALF
            local py = HALF + (dz/R)*HALF
            px = math.clamp(px, 4, RADAR_SIZE-4)
            py = math.clamp(py, 4, RADAR_SIZE-4)

            local cor = CorDoTime(plr)
            local pt = Instance.new("Frame")
            pt.Size=UDim2.new(0,6,0,6); pt.AnchorPoint=Vector2.new(0.5,0.5)
            pt.Position=UDim2.new(0,px,0,py)
            pt.BackgroundColor3=cor; pt.BorderSizePixel=0; pt.ZIndex=4; pt.Parent=bg
            local ptC=Instance.new("UICorner"); ptC.CornerRadius=UDim.new(0,99); ptC.Parent=pt
            table.insert(_pontos, pt)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  CROSSHAIR
-- ────────────────────────────────────────────────────────────────────
local _crossGui = nil
local function PararCrosshair()
    if _crossGui and _crossGui.Parent then _crossGui:Destroy(); _crossGui=nil end
end
local function IniciarCrosshair()
    PararCrosshair()
    local pGui = LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui"); sg.Name="CrosshairGui"; sg.ResetOnSpawn=false
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.IgnoreGuiInset=true; sg.Parent=pGui
    _crossGui = sg

    local vp = Camera.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local cor = Estado.crosshairCor
    local GAP=6; local LEN=12; local THICK=2

    local function Linha(w,h,x,y)
        local f=Instance.new("Frame"); f.Size=UDim2.new(0,w,0,h)
        f.Position=UDim2.new(0,cx+x-w/2,0,cy+y-h/2)
        f.BackgroundColor3=cor; f.BorderSizePixel=0; f.ZIndex=100; f.Parent=sg
        return f
    end
    local top    = Linha(THICK, LEN,  0,-(GAP+LEN))
    local bot    = Linha(THICK, LEN,  0,  GAP)
    local left   = Linha(LEN,  THICK, -(GAP+LEN), 0)
    local right  = Linha(LEN,  THICK,   GAP,      0)
    local center = Linha(THICK,THICK, 0, 0)

    local function UpdateCor(c)
        for _, f in ipairs({top,bot,left,right,center}) do f.BackgroundColor3=c end
    end

    Track(RunService.RenderStepped:Connect(function()
        if not Estado.crosshair then return end
        local nvp = Camera.ViewportSize
        local ncx, ncy = nvp.X/2, nvp.Y/2
        if ncx ~= cx or ncy ~= cy then
            cx=ncx; cy=ncy
            top.Position    = UDim2.new(0,cx+0-THICK/2, 0,cy-(GAP+LEN)-LEN/2)
            bot.Position    = UDim2.new(0,cx+0-THICK/2, 0,cy+GAP-LEN/2)
            left.Position   = UDim2.new(0,cx-(GAP+LEN)-LEN/2, 0,cy-THICK/2)
            right.Position  = UDim2.new(0,cx+GAP-LEN/2,       0,cy-THICK/2)
            center.Position = UDim2.new(0,cx-THICK/2,          0,cy-THICK/2)
        end
        UpdateCor(Estado.crosshairCor)
    end))
end

-- ────────────────────────────────────────────────────────────────────
--  FLY
-- ────────────────────────────────────────────────────────────────────
local virtualKeys = {W=false,A=false,S=false,D=false,Space=false,Shift=false}
local _flyMobileGui = nil
local _flyHB = nil

local function RemoverBotoesMobile()
    if _flyMobileGui and _flyMobileGui.Parent then _flyMobileGui:Destroy(); _flyMobileGui=nil end
    for k in pairs(virtualKeys) do virtualKeys[k]=false end
end

local function IsKeyDown(kc)
    if UserInputService:IsKeyDown(kc) then return true end
    if kc==Enum.KeyCode.W          then return virtualKeys.W     end
    if kc==Enum.KeyCode.A          then return virtualKeys.A     end
    if kc==Enum.KeyCode.S          then return virtualKeys.S     end
    if kc==Enum.KeyCode.D          then return virtualKeys.D     end
    if kc==Enum.KeyCode.Space      then return virtualKeys.Space end
    if kc==Enum.KeyCode.LeftShift  then return virtualKeys.Shift end
    return false
end

local function CriarBotoesMobile()
    RemoverBotoesMobile()
    local pGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui"); gui.Name="FlyMobileCtrl"
    gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=pGui
    _flyMobileGui = gui
    local S=68; local ALPHA=0.35
    local function Btn(lbl,px,py,key)
        local b=Instance.new("TextButton")
        b.Size=UDim2.new(0,S,0,S); b.Position=UDim2.new(0,px,1,py)
        b.BackgroundColor3=Color3.fromRGB(20,20,30); b.BackgroundTransparency=ALPHA
        b.BorderSizePixel=0; b.Text=lbl; b.TextColor3=Color3.new(1,1,1)
        b.Font=Enum.Font.GothamBold; b.TextSize=22; b.AutoButtonColor=false; b.Parent=gui
        local co=Instance.new("UICorner"); co.CornerRadius=UDim.new(0,12); co.Parent=b
        local st=Instance.new("UIStroke"); st.Color=Color3.fromRGB(255,80,80)
        st.Thickness=1.5; st.Transparency=0.4; st.Parent=b
        local function set(on)
            virtualKeys[key]=on; b.BackgroundTransparency=on and 0.05 or ALPHA
            st.Transparency=on and 0 or 0.4
        end
        b.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch
            or i.UserInputType==Enum.UserInputType.MouseButton1 then set(true) end
        end)
        b.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch
            or i.UserInputType==Enum.UserInputType.MouseButton1 then set(false) end
        end)
    end
    local pad=14; local vpX=Camera.ViewportSize.X
    Btn("^", pad+S+pad,     -(S+pad+S+pad+8), "W")
    Btn("<", pad,            -(S+pad+8),       "A")
    Btn("v", pad+S+pad,     -(S+pad+8),       "S")
    Btn(">", pad+(S+pad)*2, -(S+pad+8),       "D")
    local rx = vpX - S - pad - 80
    Btn("+", rx, -(S+pad+S+pad+8), "Space")
    Btn("-", rx, -(S+pad+8),       "Shift")
end

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB=nil end
    RemoverBotoesMobile()
    local char = GetChar()
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand=false; hum.AutoRotate=true end
    end
    Estado.fly = false
end

local function IniciarFly()
    PararFly(); Estado.fly = true
    if UserInputService.TouchEnabled then CriarBotoesMobile() end
    local char = GetChar()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Estado.fly=false; return end
    hum.AutoRotate = false
    local bv = Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero
    bv.MaxForce=Vector3.new(1e5,1e5,1e5); bv.P=9e4; bv.Parent=hrp
    local bg = Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(1e5,1e5,1e5)
    bg.P=9e4; bg.D=1e3; bg.CFrame=CFrame.new(Vector3.zero,Camera.CFrame.LookVector); bg.Parent=hrp
    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end
        local hrp2 = GetHRP(); if not hrp2 or not bv.Parent then PararFly(); return end
        local cam = Camera.CFrame; local dir = Vector3.zero
        if IsKeyDown(Enum.KeyCode.W)         then dir=dir+cam.LookVector     end
        if IsKeyDown(Enum.KeyCode.S)         then dir=dir-cam.LookVector     end
        if IsKeyDown(Enum.KeyCode.A)         then dir=dir-cam.RightVector    end
        if IsKeyDown(Enum.KeyCode.D)         then dir=dir+cam.RightVector    end
        if IsKeyDown(Enum.KeyCode.Space)     then dir=dir+Vector3.new(0,1,0) end
        if IsKeyDown(Enum.KeyCode.LeftShift) then dir=dir-Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir=dir.Unit end
        bv.Velocity = dir * Estado.voarVel
        bg.CFrame   = CFrame.new(Vector3.zero, Vector3.new(cam.LookVector.X,0,cam.LookVector.Z))
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  NO-CLIP
-- ────────────────────────────────────────────────────────────────────
local _ncHB = nil
local function PararNoClip()
    if _ncHB then _ncHB:Disconnect(); _ncHB=nil end
    Estado.noClip = false
end
local function IniciarNoClip()
    PararNoClip(); Estado.noClip = true
    _ncHB = RunService.Stepped:Connect(function()
        if not Estado.noClip then PararNoClip(); return end
        local char = GetChar(); if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  WALKSPEED / JUMP
-- ────────────────────────────────────────────────────────────────────
local function AplicarWalkSpeed()
    local hum = GetHum(); if not hum then return end
    hum.WalkSpeed = Estado.walkspeedAtivo and Estado.walkspeed or 16
end
local function AplicarJumpPower()
    local hum = GetHum(); if not hum then return end
    hum.JumpPower = Estado.jumpPowerAtivo and Estado.jumpPower or 50
end

-- ────────────────────────────────────────────────────────────────────
--  GOD MODE
-- ────────────────────────────────────────────────────────────────────
local _godConn = nil
local function PararGodMode()
    if _godConn then _godConn:Disconnect(); _godConn=nil end
end
local function IniciarGodMode()
    PararGodMode()
    local hum = GetHum(); if not hum then return end
    hum.MaxHealth = math.huge; hum.Health = math.huge
    _godConn = RunService.Heartbeat:Connect(function()
        if not Estado.godMode then PararGodMode(); return end
        local h2 = GetHum(); if h2 then
            h2.MaxHealth = math.huge; h2.Health = math.huge
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  KILL AURA
-- ────────────────────────────────────────────────────────────────────
local _killAuraThread = nil
local function PararKillAura()
    if _killAuraThread then task.cancel(_killAuraThread); _killAuraThread=nil end
end
local function EhInimigo(plr)
    if not plr or not plr.Team then return false end
    local meuTime = MeuTime(); if not meuTime then return false end
    local time = plr.Team.Name
    if meuTime == "Inmates"   then return time=="Guards"   or time=="Criminals" end
    if meuTime == "Guards"    then return time=="Inmates"  or time=="Criminals" end
    if meuTime == "Criminals" then return time=="Inmates"  or time=="Guards"    end
    return true
end

local function IniciarKillAura()
    PararKillAura()
    _killAuraThread = task.spawn(function()
        while Estado.killAura and not Estado.hubFechado do
            local myHRP = GetHRP()
            if myHRP then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr == LocalPlayer or not EhInimigo(plr) then continue end
                    local hrp = GetHRP(plr); if not hrp then continue end
                    local hum = GetHum(plr); if not hum or hum.Health <= 0 then continue end
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    if dist <= Estado.killAuraRange then
                        local remote = GetRemote("DamagePlayer")
                        if remote then pcall(function() remote:FireServer(plr, 100) end) end
                    end
                end
            end
            task.wait(Estado.killAuraCooldown)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  INFINITE AMMO (hook)
-- ────────────────────────────────────────────────────────────────────
local _ammoConn = nil
local function IniciarInfiniteAmmo()
    if _ammoConn then _ammoConn:Disconnect(); _ammoConn=nil end
    _ammoConn = RunService.Heartbeat:Connect(function()
        if not Estado.infiniteAmmo then
            if _ammoConn then _ammoConn:Disconnect(); _ammoConn=nil end; return
        end
        local char = GetChar(); if not char then return end
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            local v = tool:FindFirstChild("AmmoCount") or tool:FindFirstChild("Ammo")
            if v and v:IsA("IntValue") then v.Value = 9999 end
        end
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                local v = tool:FindFirstChild("AmmoCount") or tool:FindFirstChild("Ammo")
                if v and v:IsA("IntValue") then v.Value = 9999 end
            end
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  FULLBRIGHT
-- ────────────────────────────────────────────────────────────────────
local _origLighting = {}
local function SalvarLighting()
    _origLighting = {
        Brightness = Lighting.Brightness,
        ClockTime  = Lighting.ClockTime,
        Ambient    = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        FogEnd     = Lighting.FogEnd,
    }
end
local function AtivarFullBright()
    SalvarLighting()
    Lighting.Brightness = Estado.fullBrightBrilho
    Lighting.ClockTime  = 12
    Lighting.Ambient    = Color3.fromRGB(178,178,178)
    Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
    Lighting.FogEnd     = 100000
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect")
        or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
end
local function DesativarFullBright()
    if _origLighting.Brightness then
        Lighting.Brightness = _origLighting.Brightness
        Lighting.ClockTime  = _origLighting.ClockTime
        Lighting.Ambient    = _origLighting.Ambient
        Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient
        Lighting.FogEnd     = _origLighting.FogEnd
    end
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect")
        or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = true
        end
    end
end

-- ────────────────────────────────────────────────────────────────────
--  ANTI AFK
-- ────────────────────────────────────────────────────────────────────
local _antiAfkConn = nil
local function IniciarAntiAfk()
    if _antiAfkConn then _antiAfkConn:Disconnect(); _antiAfkConn=nil end
    local VirtualUser = game:GetService("VirtualUser")
    _antiAfkConn = LocalPlayer.Idled:Connect(function()
        if Estado.antiAfk then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
    end)
end
local function PararAntiAfk()
    if _antiAfkConn then _antiAfkConn:Disconnect(); _antiAfkConn=nil end
end

-- ────────────────────────────────────────────────────────────────────
--  CHAT SPY
-- ────────────────────────────────────────────────────────────────────
local _chatSpyConn = nil
local function IniciarChatSpy(hub)
    if _chatSpyConn then _chatSpyConn:Disconnect(); _chatSpyConn=nil end
    local ChatService = game:GetService("TextChatService")
    _chatSpyConn = ChatService.MessageReceived:Connect(function(msg)
        if not Estado.chatSpy then return end
        if msg.TextSource and msg.TextSource.UserId ~= LocalPlayer.UserId then
            local plrName = msg.TextSource.Name or "?"
            hub:Notificar("Chat Spy", "["..plrName.."]: "..msg.Text, "info", 4)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  NOTIFY KILLS / DEATH
-- ────────────────────────────────────────────────────────────────────
local function IniciarNotificacoes(hub)
    local char = GetChar()
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            Track(hum.Died:Connect(function()
                if Estado.notifyDeath then
                    hub:Notificar("Morreu!", "Seu personagem morreu!", "erro", 3)
                end
            end))
        end
    end
    Track(LocalPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        local hum2 = newChar:FindFirstChildOfClass("Humanoid")
        if hum2 then
            Track(hum2.Died:Connect(function()
                if Estado.notifyDeath then
                    hub:Notificar("Morreu!", "Seu personagem morreu!", "erro", 3)
                end
            end))
        end
    end))
end

-- ────────────────────────────────────────────────────────────────────
--  TELEPORT PARA POSICOES DO MAPA
-- ────────────────────────────────────────────────────────────────────
local MapaTeleports = {
    ["Armory"]        = Vector3.new(185, 20, -50),
    ["Prison Gate"]   = Vector3.new(0,   5,   200),
    ["Yard"]          = Vector3.new(30,  5,   10),
    ["Cafeteria"]     = Vector3.new(-80, 5,   -20),
    ["Cell Block"]    = Vector3.new(-30, 5,   -80),
    ["Guard Base"]    = Vector3.new(150, 20,  80),
    ["Criminal Base"] = Vector3.new(-200,5,   100),
    ["Hospital"]      = Vector3.new(80,  5,   -120),
    ["Solitary"]      = Vector3.new(-120,5,   -150),
    ["Roof"]          = Vector3.new(0,   80,  0),
}

-- ────────────────────────────────────────────────────────────────────
--  AIMBOT
-- ────────────────────────────────────────────────────────────────────
local _aimbotCirculo = Drawing.new("Circle")
_aimbotCirculo.Visible = false; _aimbotCirculo.Filled = false
_aimbotCirculo.Color = Color3.fromRGB(255,255,255); _aimbotCirculo.Thickness = 1.5
_aimbotCirculo.Transparency = 0.4; _aimbotCirculo.NumSides = 64

-- Linhas de mira (crosshair style no centro do FOV)
local _aimbotCrossH = Drawing.new("Line")
_aimbotCrossH.Visible=false; _aimbotCrossH.Color=Color3.fromRGB(255,80,80)
_aimbotCrossH.Thickness=1; _aimbotCrossH.Transparency=0.3

local _aimbotCrossV = Drawing.new("Line")
_aimbotCrossV.Visible=false; _aimbotCrossV.Color=Color3.fromRGB(255,80,80)
_aimbotCrossV.Thickness=1; _aimbotCrossV.Transparency=0.3

local _aimbotHB = nil

local function TemLinhaDaVisao(orig, dest)
    local dir = dest - orig; local dist = dir.Magnitude
    if dist < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = GetChar(); if char then params.FilterDescendantsInstances={char} end
    local res = workspace:Raycast(orig, dir.Unit*dist, params)
    if not res then return true end
    local hit = res.Instance
    local hitChar = hit and (hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") and hit.Parent)
    return hitChar ~= nil
end

local function EhAlvoAimbot(plr)
    if not plr or not plr.Team then return false end
    if Estado.aimbotExcluidos[plr.Name] then return false end
    return EhInimigo(plr)
end

local function PararAimbot()
    if _aimbotHB then _aimbotHB:Disconnect(); _aimbotHB=nil end
    _aimbotCirculo.Visible=false; _aimbotCrossH.Visible=false; _aimbotCrossV.Visible=false
end

-- Aimbot mobile-friendly: o usuario segura o joystick de mira e o aimbot
-- bloqueia o personagem mais proximo do centro da tela dentro do FOV.
-- FOV padrao maior no mobile para facilitar uso.
local function IniciarAimbot()
    PararAimbot()
    _aimbotHB = RunService.RenderStepped:Connect(function()
        if not Estado.aimbotAtivo or Estado.hubFechado then
            _aimbotCirculo.Visible=false; _aimbotCrossH.Visible=false; _aimbotCrossV.Visible=false
            return
        end

        local centro = Camera.ViewportSize/2

        if Estado.aimbotVerCirculo then
            _aimbotCirculo.Position = centro
            _aimbotCirculo.Radius   = Estado.aimbotFov
            _aimbotCirculo.Visible  = true
            local sz = Estado.aimbotFov*0.03
            _aimbotCrossH.From = centro - Vector2.new(sz,0); _aimbotCrossH.To = centro + Vector2.new(sz,0)
            _aimbotCrossV.From = centro - Vector2.new(0,sz); _aimbotCrossV.To = centro + Vector2.new(0,sz)
            _aimbotCrossH.Visible=true; _aimbotCrossV.Visible=true
        else
            _aimbotCirculo.Visible=false; _aimbotCrossH.Visible=false; _aimbotCrossV.Visible=false
        end

        local melhorAlvo = nil; local melhorDist = math.huge
        local myHRP = GetHRP()

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer or not EhAlvoAimbot(plr) then continue end
            local char = plr.Character; if not char then continue end
            local parte = char:FindFirstChild(Estado.aimbotParte) or char:FindFirstChild("HumanoidRootPart")
            if not parte then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            local sp, onsc, depth = ToVP(parte.Position)
            if not onsc or depth <= 0 then continue end
            local distTela = (sp - centro).Magnitude
            if distTela > Estado.aimbotFov then continue end
            if Estado.aimbotWallCheck and myHRP then
                if not TemLinhaDaVisao(myHRP.Position, parte.Position) then continue end
            end
            if distTela < melhorDist then melhorDist=distTela; melhorAlvo=parte end
        end

        if melhorAlvo then
            local vetor = (melhorAlvo.Position - Camera.CFrame.Position).Unit
            local novaCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + vetor)
            Camera.CFrame = Camera.CFrame:Lerp(novaCF, Estado.aimbotSmooth)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  AUTO PRENDER
-- ────────────────────────────────────────────────────────────────────
local _prenderThread = nil

local function GetCriminosos()
    local lista={}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if plr.Team and plr.Team.Name=="Criminals" then
            if not Estado.prenderExcluidos[plr.Name] then table.insert(lista,plr) end
        end
    end
    return lista
end

local function TentarPrender(alvo)
    if not alvo or not alvo.Parent then return false end
    local remote = GetRemote("ArrestPlayer"); if not remote then return false end
    local inicio = tick()
    while (tick()-inicio) < 2.5 do
        if not Estado.prenderAuto or Estado.hubFechado then break end
        if not alvo or not alvo.Parent then break end
        if Estado.prenderExcluidos[alvo.Name] then break end
        local myHRP2=GetHRP(); local alvHRP=GetHRP(alvo)
        if myHRP2 and alvHRP then
            myHRP2.CFrame = alvHRP.CFrame * CFrame.new(0,0,-1.5)
        end
        pcall(function() remote:InvokeServer(alvo,1) end)
        task.wait(0)
    end
    return true
end

local function LoopPrender(hub)
    while Estado.prenderAuto and not Estado.hubFechado do
        local criminosos = GetCriminosos()
        if #criminosos == 0 then
            hub:Notificar("Auto Prender","Sem criminosos...","info",3)
            task.wait(1); continue
        end
        for _, alvo in ipairs(criminosos) do
            if not Estado.prenderAuto or Estado.hubFechado then break end
            hub:Notificar("Auto Prender","Indo ate: "..alvo.Name,"aviso",2)
            TentarPrender(alvo)
            if Estado.prenderDelay > 0 then task.wait(Estado.prenderDelay) end
        end
        task.wait(0)
    end
end

local function IniciarPrenderAuto(hub)
    Estado.prenderAuto=true
    if _prenderThread then task.cancel(_prenderThread); _prenderThread=nil end
    _prenderThread = task.spawn(function() LoopPrender(hub) end)
end

local function PararPrenderAuto()
    Estado.prenderAuto=false
    if _prenderThread then task.cancel(_prenderThread); _prenderThread=nil end
end

-- ────────────────────────────────────────────────────────────────────
--  HELPERS DROPDOWN
-- ────────────────────────────────────────────────────────────────────
local function ListarTodos()
    local l={}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(l, p.Name) end
    end
    return #l > 0 and l or {"(nenhum)"}
end

local function ListarTeleporte()
    local l={}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local e = p.DisplayName ~= p.Name and p.DisplayName.." ("..p.Name..")" or p.Name
            table.insert(l, e)
        end
    end
    return #l > 0 and l or {"(nenhum)"}
end

local function ExtrairUser(s)
    return s:match("%((.-)%)$") or s
end

-- ────────────────────────────────────────────────────────────────────
--  NUKE PLAYER (tiro multiplo de arma)
-- ────────────────────────────────────────────────────────────────────
local function NukePlayer(nomeAlvo, hub)
    local alvo = Players:FindFirstChild(nomeAlvo)
    if not alvo then hub:Notificar("Nuke","Jogador nao encontrado","erro",2); return end
    local hrp = GetHRP(alvo); if not hrp then hub:Notificar("Nuke","Sem personagem","erro",2); return end
    local myHRP = GetHRP(); if not myHRP then return end
    hub:Notificar("Nuke","Nukando "..nomeAlvo.."!","perigo" or "erro",2)
    task.spawn(function()
        for i=1,30 do
            myHRP.CFrame = hrp.CFrame * CFrame.new(0,0,-1)
            local r = GetRemote("DamagePlayer")
            if r then pcall(function() r:FireServer(alvo,100) end) end
            task.wait(0.05)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
--  CHARACTER ADDED / SPAWN
-- ────────────────────────────────────────────────────────────────────
Track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly    then IniciarFly()     end
    if Estado.noClip then IniciarNoClip()  end
    if Estado.godMode then IniciarGodMode() end
    AplicarWalkSpeed()
    AplicarJumpPower()
end))

-- ────────────────────────────────────────────────────────────────────
--  HUB
-- ────────────────────────────────────────────────────────────────────
local site = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub.lua", true
))()

local hub = site.novo("Prison Life", "Roxo", {largura=800, altura=540})

-- Notificacoes de vida/morte
IniciarNotificacoes(hub)
IniciarChatSpy(hub)
IniciarAntiAfk()

-- ════════════════════════════════════════════════════════════
-- ABA ESP
-- ════════════════════════════════════════════════════════════
local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Modos")

abaESP:CriarToggle("ESP Todos os Jogadores", Estado.espTodos, function(v)
    Estado.espTodos=v; RecarregarESP()
    hub:Notificar("ESP", v and "ESP Todos ativado!" or "ESP desativado","sucesso",2)
end)

abaESP:CriarToggle("ESP Customizado", Estado.espCustom, function(v)
    Estado.espCustom=v; RecarregarESP()
    hub:Notificar("ESP", v and "ESP Customizado!" or "ESP Custom off","info",2)
end)

abaESP:CriarSecao("Filtro de Jogadores")

local dropESPJogs = abaESP:CriarDropdown("Jogadores",ListarTodos(),function(_, selMap)
    Estado.espJogadoresSel={}
    if selMap then for k,v in pairs(selMap) do if v then Estado.espJogadoresSel[k]=true end end end
end,{multi=true,search=true,maxVisible=6,placeholder="Selecionar..."})

abaESP:CriarBotao("Atualizar Lista", function()
    dropESPJogs:AtualizarOpcoes(ListarTodos())
    hub:Notificar("ESP","Lista atualizada!","info",2)
end, {icone="🔄"})

abaESP:CriarSecao("Opcoes Visuais")

abaESP:CriarToggle("Mostrar Nametag/Info", Estado.espNometagDist, function(v)
    Estado.espNometagDist=v
end)

abaESP:CriarSlider("Distancia Maxima ESP", 50, 2000, Estado.espMaxDist, function(v)
    Estado.espMaxDist=v
end, {unidade="m"})

abaESP:CriarToggle("Mostrar Tracers", Estado.espTracers, function(v)
    Estado.espTracers=v
    if not v then for _, d in pairs(_espDados) do if d.line then d.line.Visible=false end end end
end)

abaESP:CriarSlider("Grossura Tracer", 1, 20, Estado.espTracerGross, function(v)
    Estado.espTracerGross=v
    for _, d in pairs(_espDados) do if d.line then d.line.Thickness=v end end
end, {unidade="px"})

abaESP:CriarSlider("Transparencia Tracer", 0, 90, math.floor(Estado.espTracerTransp*100), function(v)
    Estado.espTracerTransp=v/100
    for _, d in pairs(_espDados) do if d.line then d.line.Transparency=Estado.espTracerTransp end end
end, {unidade="%"})

abaESP:CriarSecao("Cores por Time")

abaESP:CriarColorPicker("Inmates", Estado.corInmate, function(c)
    Estado.corInmate=c; AtualizarCoresTime("Inmates")
end)
abaESP:CriarColorPicker("Guards", Estado.corGuard, function(c)
    Estado.corGuard=c; AtualizarCoresTime("Guards")
end)
abaESP:CriarColorPicker("Criminals", Estado.corCriminal, function(c)
    Estado.corCriminal=c; AtualizarCoresTime("Criminals")
end)
abaESP:CriarColorPicker("Outros", Estado.corOutro, function(c)
    Estado.corOutro=c; AtualizarCoresOutros()
end)

-- ════════════════════════════════════════════════════════════
-- ABA JOGADOR
-- ════════════════════════════════════════════════════════════
local abaJog = hub:CriarAba("Jogador", "🧍")

abaJog:CriarSecao("Movimento")

abaJog:CriarToggle("WalkSpeed Customizado", Estado.walkspeedAtivo, function(v)
    Estado.walkspeedAtivo=v; AplicarWalkSpeed()
    hub:Notificar("WalkSpeed", v and "Ativado! "..Estado.walkspeed.."ws" or "Resetado 16ws","sucesso",2)
end)

abaJog:CriarSlider("Velocidade", 8, 300, Estado.walkspeed, function(v)
    Estado.walkspeed=v; if Estado.walkspeedAtivo then AplicarWalkSpeed() end
end, {unidade=" ws"})

abaJog:CriarToggle("JumpPower Customizado", Estado.jumpPowerAtivo, function(v)
    Estado.jumpPowerAtivo=v; AplicarJumpPower()
    hub:Notificar("Jump", v and "Ativado! "..Estado.jumpPower or "Resetado","info",2)
end)

abaJog:CriarSlider("Altura do Pulo", 10, 400, Estado.jumpPower, function(v)
    Estado.jumpPower=v; if Estado.jumpPowerAtivo then AplicarJumpPower() end
end, {unidade=" jp"})

abaJog:CriarSecao("Habilidades")

abaJog:CriarToggle("Voar", Estado.fly, function(v)
    if v then IniciarFly(); hub:Notificar("Fly","Ativado!","sucesso",2)
    else PararFly(); hub:Notificar("Fly","Desativado","info",2) end
end)

abaJog:CriarSlider("Velocidade de Voo", 10, 500, Estado.voarVel, function(v)
    Estado.voarVel=v
end, {unidade=" ws"})

abaJog:CriarToggle("No-Clip (Atravessar paredes)", Estado.noClip, function(v)
    if v then IniciarNoClip(); hub:Notificar("No-Clip","Ativado! Cuidado!","aviso",3)
    else PararNoClip(); hub:Notificar("No-Clip","Desativado","info",2) end
end)

abaJog:CriarSecao("Teleporte para Jogador")

local dropTeleJog = abaJog:CriarDropdown("Teleportar para",ListarTeleporte(),function(entrada)
    local nome = ExtrairUser(entrada)
    local alvo = Players:FindFirstChild(nome)
    if not alvo then hub:Notificar("Teleporte","Nao encontrado","erro",2); return end
    local myHRP=GetHRP(); local alvHRP=GetHRP(alvo)
    if myHRP and alvHRP then
        myHRP.CFrame = alvHRP.CFrame * CFrame.new(0,0,-2.5)
        hub:Notificar("Teleporte","Teleportado para "..nome,"sucesso",2)
    end
end,{search=true,maxVisible=6})

abaJog:CriarBotao("Atualizar Lista Jogadores", function()
    dropTeleJog:AtualizarOpcoes(ListarTeleporte())
    hub:Notificar("Jogador","Lista atualizada!","info",2)
end, {icone="🔄"})

abaJog:CriarSecao("Teleporte para Local")

local locaisList = {}
for nome in pairs(MapaTeleports) do table.insert(locaisList, nome) end
table.sort(locaisList)

abaJog:CriarDropdown("Local do Mapa", locaisList, function(local_nome)
    local pos = MapaTeleports[local_nome]
    if not pos then hub:Notificar("Teleporte","Local desconhecido","erro",2); return end
    local myHRP = GetHRP()
    if myHRP then
        myHRP.CFrame = CFrame.new(pos + Vector3.new(0,3,0))
        hub:Notificar("Teleporte","Teleportado para "..local_nome,"sucesso",2)
    end
end, {search=true, maxVisible=6})

abaJog:CriarSecao("Nuke Jogador")

local dropNuke = abaJog:CriarDropdown("Nukear Jogador",ListarTodos(),function(nome)
    if nome ~= "(nenhum)" then NukePlayer(nome, hub) end
end,{search=true,maxVisible=6})

abaJog:CriarBotao("Atualizar Nuke Lista", function()
    dropNuke:AtualizarOpcoes(ListarTodos())
end,{icone="🔄"})

-- ════════════════════════════════════════════════════════════
-- ABA AUTO PRENDER
-- ════════════════════════════════════════════════════════════
local abaPrender = hub:CriarAba("Auto Prender", "🔒")

abaPrender:CriarCard("Como funciona","Detecta Criminals, teleporta e invoca o remote de prender. Repete para todos os alvos.",{icone="ℹ️"})

abaPrender:CriarToggle("Auto Prender Ativo", Estado.prenderAuto, function(v)
    if v then IniciarPrenderAuto(hub); hub:Notificar("Auto Prender","Ativado!","sucesso",2)
    else PararPrenderAuto(); hub:Notificar("Auto Prender","Desativado","info",2) end
end)

abaPrender:CriarSlider("Delay entre presos", 0, 5, Estado.prenderDelay, function(v)
    Estado.prenderDelay=v
end, {float=true, decimais=1, unidade="s"})

abaPrender:CriarSecao("Exclusoes")

local dropExcl = abaPrender:CriarDropdown("Excluir Jogadores",ListarTodos(),function(_, selMap)
    Estado.prenderExcluidos={}
    if selMap then for k,v in pairs(selMap) do if v then Estado.prenderExcluidos[k]=true end end end
end,{multi=true,search=true,maxVisible=6,placeholder="Nenhum excluido"})

abaPrender:CriarBotao("Atualizar Exclusoes", function()
    dropExcl:AtualizarOpcoes(ListarTodos())
end,{icone="🔄"})

-- ════════════════════════════════════════════════════════════
-- ABA AIMBOT
-- ════════════════════════════════════════════════════════════
local abaAim = hub:CriarAba("Aimbot", "🎯")

abaAim:CriarCard("Mobile","FOV maior no mobile para facilitar o uso com joystick.",{icone="📱"})

abaAim:CriarToggle("Aimbot Ativo", Estado.aimbotAtivo, function(v)
    Estado.aimbotAtivo=v
    if v then IniciarAimbot(); hub:Notificar("Aimbot","Ativado! Time: "..(MeuTime() or "?"),"sucesso",2)
    else PararAimbot(); hub:Notificar("Aimbot","Desativado","info",2) end
end)

abaAim:CriarToggle("Wall Check (sem paredes)", Estado.aimbotWallCheck, function(v)
    Estado.aimbotWallCheck=v
end)

abaAim:CriarToggle("Mostrar Circulo FOV", Estado.aimbotVerCirculo, function(v)
    Estado.aimbotVerCirculo=v
    if not v then
        _aimbotCirculo.Visible=false; _aimbotCrossH.Visible=false; _aimbotCrossV.Visible=false
    end
end)

abaAim:CriarSecao("Ajustes")

abaAim:CriarSlider("FOV (raio)", IS_MOBILE and 60 or 30, IS_MOBILE and 600 or 500,
    Estado.aimbotFov, function(v)
        Estado.aimbotFov=v
    end, {unidade="px"})

abaAim:CriarSlider("Suavidade", 1, 100, math.floor(Estado.aimbotSmooth*100), function(v)
    Estado.aimbotSmooth=v/100
end, {unidade="%"})

abaAim:CriarDropdown("Parte Alvo",{"Head","HumanoidRootPart","UpperTorso","LowerTorso"},function(p)
    Estado.aimbotParte=p; hub:Notificar("Aimbot","Mirando em: "..p,"info",2)
end,{placeholder="Head"})

abaAim:CriarSecao("Exclusoes do Aimbot")

local dropAimExcl = abaAim:CriarDropdown("Excluir",ListarTodos(),function(_, selMap)
    Estado.aimbotExcluidos={}
    if selMap then for k,v in pairs(selMap) do if v then Estado.aimbotExcluidos[k]=true end end end
end,{multi=true,search=true,maxVisible=6,placeholder="Nenhum"})

abaAim:CriarBotao("Atualizar Lista", function()
    dropAimExcl:AtualizarOpcoes(ListarTodos())
end,{icone="🔄"})

-- ════════════════════════════════════════════════════════════
-- ABA COMBATE
-- ════════════════════════════════════════════════════════════
local abaComb = hub:CriarAba("Combate", "⚔️")

abaComb:CriarSecao("Defesa")

abaComb:CriarToggle("God Mode (HP infinito)", Estado.godMode, function(v)
    Estado.godMode=v
    if v then IniciarGodMode(); hub:Notificar("God Mode","ATIVO! HP infinito","sucesso",3)
    else PararGodMode(); hub:Notificar("God Mode","Desativado","info",2) end
end)

abaComb:CriarSecao("Ataque")

abaComb:CriarToggle("Kill Aura", Estado.killAura, function(v)
    Estado.killAura=v
    if v then IniciarKillAura(); hub:Notificar("Kill Aura","Ativado!","aviso",2)
    else PararKillAura(); hub:Notificar("Kill Aura","Desativado","info",2) end
end)

abaComb:CriarSlider("Range Kill Aura", 5, 60, Estado.killAuraRange, function(v)
    Estado.killAuraRange=v
end, {unidade="m"})

abaComb:CriarSlider("Cooldown Kill Aura", 1, 20, math.floor(Estado.killAuraCooldown*10), function(v)
    Estado.killAuraCooldown = v/10
end, {float=true, decimais=1, unidade="s"})

abaComb:CriarToggle("Infinite Ammo", Estado.infiniteAmmo, function(v)
    Estado.infiniteAmmo=v
    if v then IniciarInfiniteAmmo(); hub:Notificar("Ammo","Municao infinita!","sucesso",2)
    else hub:Notificar("Ammo","Desativado","info",2) end
end)

abaComb:CriarSecao("Rapido")

abaComb:CriarBotao("Teleportar para inimigo mais proximo", function()
    local myHRP = GetHRP(); if not myHRP then return end
    local melhor=nil; local melhorDist=math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if not EhInimigo(plr) then continue end
        local hrp = GetHRP(plr); if not hrp then continue end
        local d = (myHRP.Position-hrp.Position).Magnitude
        if d < melhorDist then melhorDist=d; melhor=hrp end
    end
    if melhor then
        myHRP.CFrame = melhor.CFrame * CFrame.new(0,0,-2)
        hub:Notificar("Combate","Teleportado para inimigo proximo!","aviso",2)
    else
        hub:Notificar("Combate","Nenhum inimigo encontrado","erro",2)
    end
end, {icone="⚡"})

-- ════════════════════════════════════════════════════════════
-- ABA VISUAIS
-- ════════════════════════════════════════════════════════════
local abaVis = hub:CriarAba("Visuais", "✨")

abaVis:CriarSecao("Iluminacao")

abaVis:CriarToggle("FullBright (dia permanente)", Estado.fullBright, function(v)
    Estado.fullBright=v
    if v then AtivarFullBright(); hub:Notificar("FullBright","Ativado!","sucesso",2)
    else DesativarFullBright(); hub:Notificar("FullBright","Desativado","info",2) end
end)

abaVis:CriarSlider("Brilho FullBright", 1, 10, Estado.fullBrightBrilho, function(v)
    Estado.fullBrightBrilho=v
    if Estado.fullBright then Lighting.Brightness=v end
end)

abaVis:CriarSecao("Crosshair")

abaVis:CriarToggle("Crosshair Personalizado", Estado.crosshair, function(v)
    Estado.crosshair=v
    if v then IniciarCrosshair(); hub:Notificar("Crosshair","Ativado!","sucesso",2)
    else PararCrosshair(); hub:Notificar("Crosshair","Desativado","info",2) end
end)

abaVis:CriarColorPicker("Cor do Crosshair", Estado.crosshairCor, function(c)
    Estado.crosshairCor=c
    if Estado.crosshair then PararCrosshair(); IniciarCrosshair() end
end)

abaVis:CriarSecao("Radar Mini-Mapa")

abaVis:CriarToggle("Radar Ativo", Estado.radarAtivo, function(v)
    Estado.radarAtivo=v
    if v then IniciarRadar(); hub:Notificar("Radar","Mini-mapa ativado!","sucesso",2)
    else PararRadar(); hub:Notificar("Radar","Desativado","info",2) end
end)

abaVis:CriarSlider("Range do Radar", 50, 500, Estado.radarRange, function(v)
    Estado.radarRange=v
end, {unidade="m"})

-- ════════════════════════════════════════════════════════════
-- ABA MISC
-- ════════════════════════════════════════════════════════════
local abaMisc = hub:CriarAba("Misc", "🔧")

abaMisc:CriarSecao("Utilitarios")

abaMisc:CriarToggle("Anti-AFK", Estado.antiAfk, function(v)
    Estado.antiAfk=v
    if v then IniciarAntiAfk(); hub:Notificar("Anti-AFK","Ativo! Nao sera kickado","sucesso",2)
    else PararAntiAfk(); hub:Notificar("Anti-AFK","Desativado","info",2) end
end)

abaMisc:CriarToggle("Chat Spy (ver msgs de todos)", Estado.chatSpy, function(v)
    Estado.chatSpy=v
    hub:Notificar("Chat Spy", v and "Monitorando chats!" or "Desativado", v and "aviso" or "info", 2)
end)

abaMisc:CriarToggle("Notificar Mortes", Estado.notifyDeath, function(v)
    Estado.notifyDeath=v
end)

abaMisc:CriarSecao("Informacoes")

abaMisc:CriarCard("Seu Time", (LocalPlayer.Team and LocalPlayer.Team.Name) or "Sem Time",{
    icone="🏷️",
    destaque = LocalPlayer.Team and LocalPlayer.Team.TeamColor and
               LocalPlayer.Team.TeamColor.Color or Color3.fromRGB(100,100,100),
})

local cardPing = abaMisc:CriarCard("Ping", "Calculando...",{icone="📡"})
task.spawn(function()
    while not Estado.hubFechado do
        local start = tick()
        RunService.Heartbeat:Wait()
        local ms = math.floor((tick()-start)*1000)
        pcall(function() cardPing:SetSubtitulo(ms.." ms") end)
        task.wait(2)
    end
end)

abaMisc:CriarSecao("Jogadores Online")

local function AtualizarTabelaJogs(tbl)
    local linhas={}
    for _, p in ipairs(Players:GetPlayers()) do
        local time = (p.Team and p.Team.Name) or "N/A"
        local hrp  = GetHRP(p)
        local hp   = GetHum(p)
        table.insert(linhas, {
            p.Name,
            time,
            hp and math.floor(hp.Health).."/"..math.floor(hp.MaxHealth) or "?",
            hrp and tostring(math.floor(
                (GetHRP() and (GetHRP().Position-hrp.Position).Magnitude) or 0)).."m" or "?",
        })
    end
    tbl:SetLinhas(linhas)
end

local tblJogs = abaMisc:CriarTabela({"Nome","Time","HP","Distancia"},{})
AtualizarTabelaJogs(tblJogs)

abaMisc:CriarBotao("Atualizar Tabela", function()
    AtualizarTabelaJogs(tblJogs)
    hub:Notificar("Misc","Tabela atualizada!","info",2)
end,{icone="🔄"})

-- ════════════════════════════════════════════════════════════
-- ABA CONFIG
-- ════════════════════════════════════════════════════════════
local abaCfg = hub:CriarAba("Config", "⚙️")

abaCfg:CriarSecao("Aparencia")
hub:CriarDropdownTemas(abaCfg)

abaCfg:CriarSecao("Keybinds")

if not IS_MOBILE then
    abaCfg:CriarTeclaDeAtalho("Abrir/Fechar Hub", Estado.keybindToggleHub, function()
        -- toggle visibilidade da janela (minimizar)
        hub.Janela.Visible = not hub.Janela.Visible
    end)
end

    abaCfg:CriarTeclaDeAtalho("Teste", Estado.keybindToggleHub, function()
        print("teste")
    end)

abaCfg:CriarSecao("Informacoes do Script")

abaCfg:CriarBadges({
    {texto="Prison Life", cor=Color3.fromRGB(255,80,80),  icone="🔒"},
    {texto="v2.0",        cor=Color3.fromRGB(0,190,210),  icone="✓"},
    {texto=IS_MOBILE and "Mobile" or "PC", cor=Color3.fromRGB(148,68,255), icone="📱"},
})

abaCfg:CriarExpansivel("Creditos e Info",
    "Script Prison Life v2.0\nHub UI v7.1\n\n"..
    "Funcoes: ESP, Aimbot (mobile-friendly), Fly, No-Clip,\n"..
    "Kill Aura, God Mode, Auto Prender, Radar,\n"..
    "Crosshair, FullBright, Anti-AFK, Chat Spy e mais!"
)

abaCfg:CriarBotao("Resetar Todas as Configs", function()
    hub:Notificar("Config","Recarregue o script para resetar","aviso",3)
end,{icone="🔄"})

-- ────────────────────────────────────────────────────────────────────
--  LISTENERS DE JOGADORES (atualizar dropdowns)
-- ────────────────────────────────────────────────────────────────────
Track(Players.PlayerAdded:Connect(function()
    if Estado.hubFechado then return end
    task.wait(0.5)
    local l=ListarTodos(); local lt=ListarTeleporte()
    dropESPJogs:AtualizarOpcoes(l)
    dropTeleJog:AtualizarOpcoes(lt)
    dropExcl:AtualizarOpcoes(l)
    dropAimExcl:AtualizarOpcoes(l)
    dropNuke:AtualizarOpcoes(l)
end))

Track(Players.PlayerRemoving:Connect(function(plr)
    if Estado.hubFechado then return end
    task.wait(0.1)
    local l=ListarTodos(); local lt=ListarTeleporte()
    dropESPJogs:AtualizarOpcoes(l)
    dropTeleJog:AtualizarOpcoes(lt)
    dropExcl:AtualizarOpcoes(l)
    dropAimExcl:AtualizarOpcoes(l)
    dropNuke:AtualizarOpcoes(l)
    Estado.espJogadoresSel[plr.Name]=nil
    Estado.prenderExcluidos[plr.Name]=nil
    Estado.aimbotExcluidos[plr.Name]=nil
end))

-- ────────────────────────────────────────────────────────────────────
--  FECHAR HUB
-- ────────────────────────────────────────────────────────────────────
hub:AoFechar(function()
    Estado.hubFechado=true
    PararESP(); PararFly(); PararNoClip(); PararGodMode()
    PararKillAura(); PararPrenderAuto(); PararAimbot()
    PararCrosshair(); PararRadar(); PararAntiAfk()
    if _chatSpyConn then _chatSpyConn:Disconnect() end
    if _ammoConn    then _ammoConn:Disconnect()    end
    if Estado.fullBright then DesativarFullBright() end
    _aimbotCirculo:Remove()
    _aimbotCrossH:Remove()
    _aimbotCrossV:Remove()
    for _, c in pairs(_connections) do
        if typeof(c)=="RBXScriptConnection" then c:Disconnect() end
    end
end)

hub:Notificar("Prison Life v2.0","Script carregado! Bom jogo!","sucesso",4)
