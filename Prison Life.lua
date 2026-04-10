local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
--  ESTADO GLOBAL
-- ══════════════════════════════════════════════════════════════
local Estado = {
    -- ESP
    espTodos            = false,
    espCustom           = false,
    espTracers          = true,
    espTracerGross      = 2,
    espTracerTransp     = 0.1,
    espTracerOrigem     = "Centro",   -- "Centro" | "Pe"
    espBoxes            = true,
    espBoxCanto         = false,      -- caixinha de canto (corner box)
    espNomes            = true,
    espDistancia        = true,
    espHP               = true,
    espHPTexto          = false,
    espSkeleton         = false,
    espHighlight        = true,
    espChaveAberta      = false,
    espMaxDist          = 1000,       -- distancia maxima ESP
    espJogadoresSel     = {},
    hubFechado          = false,

    -- Cores
    corInmate   = Color3.fromRGB(255, 140,   0),
    corGuard    = Color3.fromRGB( 50, 130, 255),
    corCriminal = Color3.fromRGB(255,  50,  50),
    corOutro    = Color3.fromRGB(255, 255, 255),

    -- Jogador
    walkspeed        = 16,
    walkspeedAtivo   = false,
    fly              = false,
    voarVel          = 50,
    noclip           = false,

    -- Auto Prender
    prenderAuto      = false,
    prenderExcluidos = {},

    -- Aimbot
    aimbotAtivo         = false,
    aimbotFov           = 120,
    aimbotSmooth        = 0.15,
    aimbotExcluidos     = {},
    aimbotParte         = "Head",
    aimbotSoloVisivel   = true,
    aimbotSilent        = false,
    aimbotPrediction    = false,
    aimbotHoldKey       = false,     -- segurar botao direito para mirar
    aimbotCorCirculo    = Color3.fromRGB(255, 255, 255),

    -- Radar
    radarAtivo      = false,
    radarMinimizado = false,
    radarZoom       = 0.05,
    radarTamanho    = 220,
    radarPosX       = nil,
    radarPosY       = nil,

    -- Chat Spy
    chatSpyAtivo   = false,
    chatSpyFiltro  = "Todos",
    chatSpyPosX    = nil,
    chatSpyPosY    = nil,

    hubAberto = true,
}

-- ══════════════════════════════════════════════════════════════
--  UTILITARIOS
-- ══════════════════════════════════════════════════════════════
local _consESP  = {}
local _espDados = {}

local function LimparConexoes(lista)
    for _, c in pairs(lista) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    table.clear(lista)
end

local function GetChar()    return LocalPlayer.Character end
local function GetHRP(plr)
    local char = plr and plr.Character or GetChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function GetHum(plr)
    local char = plr and plr.Character or GetChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function WorldToViewport(pos)
    local vp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X, vp.Y), onScreen, vp.Z
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

local function AplicarWalkSpeed()
    local hum = GetHum()
    if hum then hum.WalkSpeed = Estado.walkspeedAtivo and Estado.walkspeed or 16 end
end

local function FazerArrastavel(frame, handleBar, onMoved)
    local dragging, dragStart, startPos = false, nil, nil
    handleBar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = frame.Position
        end
    end)
    handleBar.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if onMoved then onMoved(frame.Position) end
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = inp.Position - dragStart
        local newX = startPos.X.Offset + delta.X
        local newY = startPos.Y.Offset + delta.Y
        local vp = Camera.ViewportSize
        local sz = frame.AbsoluteSize
        local px = frame.Position.X.Scale
        local py = frame.Position.Y.Scale
        newX = math.clamp(newX, -px * vp.X, vp.X * (1 - px) - sz.X)
        newY = math.clamp(newY, -py * vp.Y, vp.Y * (1 - py) - sz.Y)
        frame.Position = UDim2.new(px, newX, py, newY)
    end)
end

-- ══════════════════════════════════════════════════════════════
--  ESP — MELHORADO
-- ══════════════════════════════════════════════════════════════
local SKELETON_JOINTS = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
}

local PARTES_BB = {
    "Head","UpperTorso","LowerTorso",
    "LeftHand","RightHand","LeftFoot","RightFoot",
    "LeftLowerArm","RightLowerArm","LeftLowerLeg","RightLowerLeg",
}

local function NovoLine(cor, thick, transp)
    local l = Drawing.new("Line")
    l.Visible = false; l.Color = cor
    l.Thickness = thick or 1; l.Transparency = transp or 0
    return l
end

local function NovoText(cor, size)
    local t = Drawing.new("Text")
    t.Visible = false; t.Color = cor
    t.Size = size or 13; t.Font = Drawing.Fonts.UI
    t.Outline = true; t.OutlineColor = Color3.new(0,0,0)
    t.Center = true
    return t
end

local function NovoQuad(cor, thick, transp)
    local q = Drawing.new("Quad")
    q.Visible = false; q.Color = cor
    q.Thickness = thick or 1.5
    q.Transparency = transp or 0
    q.Filled = false
    return q
end

local function EspAtivo()
    return Estado.espTodos or Estado.espCustom
end

local function DeveMostrarESP(plr)
    if Estado.espTodos then return true end
    if Estado.espCustom then return Estado.espJogadoresSel[plr.Name] == true end
    return false
end

local function RemoverEntradaESP(nome)
    local d = _espDados[nome]
    if not d then return end
    if d.hl  and d.hl.Parent  then d.hl:Destroy()  end
    if d.gui and d.gui.Parent then d.gui:Destroy() end
    -- remove todos os drawings
    local campos = {
        "line","boxQuad",
        "boxTop","boxBottom","boxLeft","boxRight",
        "cTL1","cTL2","cTR1","cTR2","cBL1","cBL2","cBR1","cBR2",
        "hpBar","hpBarBg","hpTexto",
        "lblNome2D","lblDist2D","lblTime2D",
    }
    for _, k in ipairs(campos) do
        if d[k] then pcall(function() d[k]:Remove() end) end
    end
    if d.skeleton then
        for _, ln in pairs(d.skeleton) do pcall(function() ln:Remove() end) end
    end
    _espDados[nome] = nil
end

local function CriarEntradaESP(plr)
    RemoverEntradaESP(plr.Name)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local cor = CorDoTime(plr)

    -- Highlight 3D
    local hl = Instance.new("Highlight")
    hl.FillColor = cor; hl.OutlineColor = cor
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0.05
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char; hl.Enabled = Estado.espHighlight
    hl.Parent = char

    -- Billboard nome (3D)
    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true; gui.Size = UDim2.new(0,160,0,20)
    gui.StudsOffset = Vector3.new(0,3.2,0)
    gui.Adornee = hrp; gui.Parent = hrp

    local lblNome3D = Instance.new("TextLabel")
    lblNome3D.Size = UDim2.new(1,0,1,0)
    lblNome3D.BackgroundTransparency = 1
    lblNome3D.Text = plr.DisplayName
    lblNome3D.TextColor3 = cor
    lblNome3D.Font = Enum.Font.GothamBold
    lblNome3D.TextSize = 13
    lblNome3D.TextXAlignment = Enum.TextXAlignment.Center
    lblNome3D.TextStrokeTransparency = 0.3
    lblNome3D.TextStrokeColor3 = Color3.new(0,0,0)
    lblNome3D.Parent = gui

    -- 2D Drawings
    local tracer  = NovoLine(cor, Estado.espTracerGross, Estado.espTracerTransp)

    -- Box solida (4 linhas)
    local boxTop   = NovoLine(cor, 1.5, 0)
    local boxBot   = NovoLine(cor, 1.5, 0)
    local boxLeft  = NovoLine(cor, 1.5, 0)
    local boxRight = NovoLine(cor, 1.5, 0)

    -- Corner box (8 linhas de canto)
    local cTL1 = NovoLine(cor, 2, 0); local cTL2 = NovoLine(cor, 2, 0)
    local cTR1 = NovoLine(cor, 2, 0); local cTR2 = NovoLine(cor, 2, 0)
    local cBL1 = NovoLine(cor, 2, 0); local cBL2 = NovoLine(cor, 2, 0)
    local cBR1 = NovoLine(cor, 2, 0); local cBR2 = NovoLine(cor, 2, 0)

    -- HP
    local hpBg   = NovoLine(Color3.fromRGB(15,15,15), 5, 0)
    local hpFill = NovoLine(Color3.fromRGB(60,220,100), 4, 0)
    local hpTxt  = NovoText(Color3.fromRGB(255,255,255), 10)
    hpTxt.Center = true

    -- Labels 2D
    local nomeTxt = NovoText(cor, 13)
    local distTxt = NovoText(Color3.fromRGB(210,210,210), 11)
    local timeTxt = NovoText(cor, 10)

    -- Skeleton
    local skeleton = {}
    for _ = 1, #SKELETON_JOINTS do
        table.insert(skeleton, NovoLine(cor, 1, 0.3))
    end

    _espDados[plr.Name] = {
        plr      = plr,
        hl       = hl, gui = gui, lblNome3D = lblNome3D,
        line     = tracer,
        boxTop   = boxTop, boxBottom = boxBot,
        boxLeft  = boxLeft, boxRight = boxRight,
        cTL1=cTL1, cTL2=cTL2, cTR1=cTR1, cTR2=cTR2,
        cBL1=cBL1, cBL2=cBL2, cBR1=cBR1, cBR2=cBR2,
        hpBar    = hpFill, hpBarBg = hpBg, hpTexto = hpTxt,
        lblNome2D= nomeTxt, lblDist2D = distTxt, lblTime2D = timeTxt,
        skeleton = skeleton,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do RemoverEntradaESP(nome) end
end

local function AtualizarCoresESP(plr)
    local d = _espDados[plr and plr.Name]
    if not d then return end
    local cor = CorDoTime(plr)
    if d.hl and d.hl.Parent then d.hl.FillColor = cor; d.hl.OutlineColor = cor end
    for _, k in ipairs({"line","boxTop","boxBottom","boxLeft","boxRight",
        "cTL1","cTL2","cTR1","cTR2","cBL1","cBL2","cBR1","cBR2"}) do
        if d[k] then d[k].Color = cor end
    end
    if d.lblNome3D and d.lblNome3D.Parent then d.lblNome3D.TextColor3 = cor end
    if d.lblNome2D then d.lblNome2D.Color = cor end
    if d.lblTime2D then d.lblTime2D.Color = cor end
    for _, s in pairs(d.skeleton or {}) do s.Color = cor end
end

local function AtualizarCoresTime(nomeTime)
    for _, d in pairs(_espDados) do
        if d.plr and d.plr.Team and d.plr.Team.Name == nomeTime then
            AtualizarCoresESP(d.plr)
        end
    end
end

local function AtualizarCoresOutros()
    for _, d in pairs(_espDados) do
        if d.plr then
            local tn = d.plr.Team and d.plr.Team.Name
            if tn ~= "Inmates" and tn ~= "Guards" and tn ~= "Criminals" then
                AtualizarCoresESP(d.plr)
            end
        end
    end
end

local function GetBoundingBox2D(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local visible = false
    for _, nome in ipairs(PARTES_BB) do
        local part = char:FindFirstChild(nome)
        if part then
            local sp, onSc, depth = WorldToViewport(part.Position)
            if onSc and depth > 0 then
                visible = true
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end
    end
    if not visible then return nil end
    local pad = 5
    return {
        minX = minX - pad, minY = minY - pad,
        maxX = maxX + pad, maxY = maxY + pad,
        w = (maxX - minX) + pad*2,
        h = (maxY - minY) + pad*2,
    }
end

local function OcultarTudoESP(d)
    local campos = {
        "line","boxTop","boxBottom","boxLeft","boxRight",
        "cTL1","cTL2","cTR1","cTR2","cBL1","cBL2","cBR1","cBR2",
        "hpBar","hpBarBg","hpTexto","lblNome2D","lblDist2D","lblTime2D",
    }
    for _, k in ipairs(campos) do if d[k] then d[k].Visible = false end end
    for _, s in pairs(d.skeleton or {}) do s.Visible = false end
end

local function DesenharCornerBox(d, x1, y1, x2, y2, cor)
    local lx = math.floor((x2 - x1) * 0.22)
    local ly = math.floor((y2 - y1) * 0.22)
    local function setL(l, fx, fy, tx, ty)
        l.From = Vector2.new(fx,fy); l.To = Vector2.new(tx,ty)
        l.Color = cor; l.Visible = true
    end
    setL(d.cTL1, x1,y1, x1+lx,y1)
    setL(d.cTL2, x1,y1, x1,y1+ly)
    setL(d.cTR1, x2,y1, x2-lx,y1)
    setL(d.cTR2, x2,y1, x2,y1+ly)
    setL(d.cBL1, x1,y2, x1+lx,y2)
    setL(d.cBL2, x1,y2, x1,y2-ly)
    setL(d.cBR1, x2,y2, x2-lx,y2)
    setL(d.cBR2, x2,y2, x2,y2-ly)
end

local function OcultarCornerBox(d)
    for _, k in ipairs({"cTL1","cTL2","cTR1","cTR2","cBL1","cBL2","cBR1","cBR2"}) do
        if d[k] then d[k].Visible = false end
    end
end

local function IniciarESP()
    LimparConexoes(_consESP)
    LimparTodoESP()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then CriarEntradaESP(plr) end
    end

    table.insert(_consESP, Players.PlayerAdded:Connect(function(plr)
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Estado.hubFechado or not EspAtivo() then return end
            CriarEntradaESP(plr)
        end))
        task.wait(0.5)
        if Estado.hubFechado or not EspAtivo() then return end
        if plr.Character then CriarEntradaESP(plr) end
    end))

    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(_consESP, plr.CharacterAdded:Connect(function()
                task.wait(0.5)
                if Estado.hubFechado or not EspAtivo() then return end
                CriarEntradaESP(plr)
            end))
            table.insert(_consESP, plr.CharacterRemoving:Connect(function()
                RemoverEntradaESP(plr.Name)
            end))
        end
    end

    table.insert(_consESP, RunService.RenderStepped:Connect(function()
        if Estado.hubFechado then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if plr.Character and not _espDados[plr.Name] then
                CriarEntradaESP(plr)
            elseif not plr.Character and _espDados[plr.Name] then
                RemoverEntradaESP(plr.Name)
            end
        end

        local myHRP = GetHRP()
        local tracerOrigem
        if myHRP and Estado.espTracerOrigem == "Pe" then
            local sp, onSc, depth = WorldToViewport(myHRP.Position - Vector3.new(0,2.8,0))
            tracerOrigem = (onSc and depth > 0) and sp or nil
        end
        if not tracerOrigem then
            tracerOrigem = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end

        for _, d in pairs(_espDados) do
            local plr = d.plr
            if not plr or not plr.Character then OcultarTudoESP(d); continue end

            local char = plr.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            -- Verificar distancia maxima
            local distMag = myHRP and (myHRP.Position - hrp.Position).Magnitude or 0
            local deveVer = EspAtivo() and DeveMostrarESP(plr) and (distMag <= Estado.espMaxDist)
            local cor = CorDoTime(plr)

            if d.hl and d.hl.Parent then
                d.hl.Enabled      = deveVer and Estado.espHighlight
                d.hl.FillColor    = cor
                d.hl.OutlineColor = cor
            end
            if d.gui and d.gui.Parent then
                d.gui.Enabled = deveVer and Estado.espNomes
            end
            if d.lblNome3D and d.lblNome3D.Parent then
                d.lblNome3D.TextColor3 = cor
                d.lblNome3D.Text = plr.DisplayName
            end

            if not deveVer then OcultarTudoESP(d); continue end

            local dist  = math.floor(distMag)
            local hp    = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local pct   = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0

            local barCor
            if     pct > 0.6 then barCor = Color3.fromRGB(60, 220, 100)
            elseif pct > 0.3 then barCor = Color3.fromRGB(255, 190, 40)
            else                   barCor = Color3.fromRGB(220, 55, 55)
            end

            local bb = GetBoundingBox2D(char)
            local _, onSc, depth = WorldToViewport(hrp.Position)

            if bb and onSc and depth > 0 then
                local x1,y1,x2,y2 = bb.minX, bb.minY, bb.maxX, bb.maxY

                -- ── BOX
                if Estado.espBoxes and not Estado.espBoxCanto then
                    d.boxTop.From   = Vector2.new(x1,y1); d.boxTop.To   = Vector2.new(x2,y1); d.boxTop.Color   = cor; d.boxTop.Visible   = true
                    d.boxBottom.From= Vector2.new(x1,y2); d.boxBottom.To= Vector2.new(x2,y2); d.boxBottom.Color= cor; d.boxBottom.Visible= true
                    d.boxLeft.From  = Vector2.new(x1,y1); d.boxLeft.To  = Vector2.new(x1,y2); d.boxLeft.Color  = cor; d.boxLeft.Visible  = true
                    d.boxRight.From = Vector2.new(x2,y1); d.boxRight.To = Vector2.new(x2,y2); d.boxRight.Color = cor; d.boxRight.Visible = true
                    OcultarCornerBox(d)
                elseif Estado.espBoxes and Estado.espBoxCanto then
                    d.boxTop.Visible=false; d.boxBottom.Visible=false; d.boxLeft.Visible=false; d.boxRight.Visible=false
                    DesenharCornerBox(d, x1,y1,x2,y2, cor)
                else
                    d.boxTop.Visible=false; d.boxBottom.Visible=false; d.boxLeft.Visible=false; d.boxRight.Visible=false
                    OcultarCornerBox(d)
                end

                -- ── HP BAR (lateral esquerda)
                if Estado.espHP then
                    local barX  = x1 - 7
                    local barY1 = y1
                    local barY2 = y2
                    d.hpBarBg.From = Vector2.new(barX,barY1); d.hpBarBg.To = Vector2.new(barX,barY2)
                    d.hpBarBg.Color = Color3.fromRGB(15,15,15); d.hpBarBg.Thickness = 5; d.hpBarBg.Visible = true
                    d.hpBar.From = Vector2.new(barX,barY2); d.hpBar.To = Vector2.new(barX, barY2 - bb.h * pct)
                    d.hpBar.Color = barCor; d.hpBar.Thickness = 4; d.hpBar.Visible = true

                    if Estado.espHPTexto then
                        d.hpTexto.Position = Vector2.new(barX - 2, (barY1+barY2)/2)
                        d.hpTexto.Text = hp
                        d.hpTexto.Color = barCor; d.hpTexto.Visible = true
                    else
                        d.hpTexto.Visible = false
                    end
                else
                    d.hpBar.Visible=false; d.hpBarBg.Visible=false; d.hpTexto.Visible=false
                end

                -- ── NOME 2D
                if Estado.espNomes then
                    d.lblNome2D.Position = Vector2.new((x1+x2)/2, y1 - 18)
                    d.lblNome2D.Text = plr.DisplayName
                    d.lblNome2D.Color = cor; d.lblNome2D.Size = 13; d.lblNome2D.Visible = true
                else
                    d.lblNome2D.Visible = false
                end

                -- ── DISTANCIA + STATUS + TIME
                if Estado.espDistancia then
                    local moving   = hum.MoveDirection.Magnitude > 0.1
                    local statusIco = moving and "▶" or "◼"
                    local teamTag   = plr.Team and ("[" .. plr.Team.Name:sub(1,3):upper() .. "] ") or ""
                    local hpPct     = math.floor(pct * 100)
                    d.lblDist2D.Position = Vector2.new((x1+x2)/2, y2 + 5)
                    d.lblDist2D.Text = teamTag .. dist .. "m | " .. hp .. "hp (" .. hpPct .. "%) " .. statusIco
                    d.lblDist2D.Color = Color3.fromRGB(210,210,210)
                    d.lblDist2D.Size = 11; d.lblDist2D.Visible = true
                else
                    d.lblDist2D.Visible = false
                end

            else
                -- fora da tela
                d.boxTop.Visible=false; d.boxBottom.Visible=false; d.boxLeft.Visible=false; d.boxRight.Visible=false
                OcultarCornerBox(d)
                d.hpBar.Visible=false; d.hpBarBg.Visible=false; d.hpTexto.Visible=false
                d.lblNome2D.Visible=false; d.lblDist2D.Visible=false; d.lblTime2D.Visible=false
            end

            -- ── SKELETON
            if Estado.espSkeleton then
                for i, pair in ipairs(SKELETON_JOINTS) do
                    local pA = char:FindFirstChild(pair[1])
                    local pB = char:FindFirstChild(pair[2])
                    local sk = d.skeleton[i]
                    if pA and pB and sk then
                        local spA, okA, dA = WorldToViewport(pA.Position)
                        local spB, okB, dB = WorldToViewport(pB.Position)
                        if okA and okB and dA > 0 and dB > 0 then
                            sk.From = spA; sk.To = spB
                            sk.Color = cor; sk.Thickness = 1.2; sk.Visible = true
                        else
                            sk.Visible = false
                        end
                    elseif sk then
                        sk.Visible = false
                    end
                end
            else
                for _, s in pairs(d.skeleton or {}) do s.Visible = false end
            end

            -- ── TRACER
            if d.line then
                local alvoPos = hrp.Position - Vector3.new(0, 2.5, 0)
                local sp2, onSc2, depth2 = WorldToViewport(alvoPos)
                if Estado.espTracers and onSc2 and depth2 > 0 then
                    d.line.From = tracerOrigem; d.line.To = sp2
                    d.line.Thickness = Estado.espTracerGross
                    d.line.Transparency = Estado.espTracerTransp
                    d.line.Color = cor; d.line.Visible = true
                else
                    d.line.Visible = false
                end
            end
        end
    end))
end

local function PararESP()
    LimparConexoes(_consESP)
    LimparTodoESP()
end

local function RecarregarESP()
    if EspAtivo() then PararESP(); IniciarESP()
    else PararESP() end
end

-- ══════════════════════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════════════════════
local _noclipConn = nil

local function IniciarNoclip()
    if _noclipConn then _noclipConn:Disconnect() end
    _noclipConn = RunService.Stepped:Connect(function()
        local char = GetChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function PararNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
    local char = GetChar()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  VOAR
-- ══════════════════════════════════════════════════════════════
local virtualKeys = { W=false, A=false, S=false, D=false, Space=false, Shift=false }

local function IsKeyDown(kc)
    if UserInputService:IsKeyDown(kc) then return true end
    if kc == Enum.KeyCode.W         then return virtualKeys.W     end
    if kc == Enum.KeyCode.A         then return virtualKeys.A     end
    if kc == Enum.KeyCode.S         then return virtualKeys.S     end
    if kc == Enum.KeyCode.D         then return virtualKeys.D     end
    if kc == Enum.KeyCode.Space     then return virtualKeys.Space end
    if kc == Enum.KeyCode.LeftShift then return virtualKeys.Shift end
    return false
end

local _flyMobileGui = nil

local function RemoverBotoesMobile()
    if _flyMobileGui and _flyMobileGui.Parent then _flyMobileGui:Destroy(); _flyMobileGui = nil end
    for k in pairs(virtualKeys) do virtualKeys[k] = false end
end

local function CriarBotoesMobile()
    RemoverBotoesMobile()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyMobileControls"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui; _flyMobileGui = gui
    local BTN_SIZE = 64; local ALPHA = 0.35
    local function criarBotao(parent, label, posX, posY, key)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,BTN_SIZE,0,BTN_SIZE); btn.Position = UDim2.new(0,posX,1,posY)
        btn.BackgroundColor3 = Color3.fromRGB(20,20,30); btn.BackgroundTransparency = ALPHA
        btn.BorderSizePixel = 0; btn.Text = label; btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.AutoButtonColor = false; btn.Parent = parent
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = btn
        local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(255,80,80)
        stroke.Thickness = 1.5; stroke.Transparency = 0.4; stroke.Parent = btn
        local function setActive(on)
            virtualKeys[key] = on
            btn.BackgroundTransparency = on and 0.05 or ALPHA
            stroke.Transparency = on and 0 or 0.4
        end
        btn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then setActive(true) end
        end)
        btn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then setActive(false) end
        end)
        return btn
    end
    local pad = 12; local bS = BTN_SIZE
    local row1Y = -(bS+pad+bS+pad+8); local row2Y = -(bS+pad+8); local leftX = pad
    criarBotao(gui,"^",leftX+bS+pad,row1Y,"W"); criarBotao(gui,"<",leftX,row2Y,"A")
    criarBotao(gui,"v",leftX+bS+pad,row2Y,"S"); criarBotao(gui,">",leftX+(bS+pad)*2,row2Y,"D")
    local vp = Camera.ViewportSize; local rightX = vp.X-bS-pad-70
    criarBotao(gui,"+",rightX,row1Y,"Space"); criarBotao(gui,"-",rightX,row2Y,"Shift")
end

local _flyHB = nil

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB = nil end
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
        if hum then hum.PlatformStand = false; hum.AutoRotate = true end
    end
    Estado.fly = false
end

local function IniciarFly()
    PararFly(); Estado.fly = true
    if UserInputService.TouchEnabled then CriarBotoesMobile() end
    local char = GetChar()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Estado.fly = false; return end
    hum.AutoRotate = false
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.new(1e5,1e5,1e5); bv.P = 9e4; bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5); bg.P = 9e4; bg.D = 1e3
    bg.CFrame = CFrame.new(Vector3.zero, Camera.CFrame.LookVector); bg.Parent = hrp
    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end
        local hrp2 = GetHRP()
        if not hrp2 or not bv.Parent or not bg.Parent then PararFly(); return end
        local cam = Camera.CFrame; local dir = Vector3.zero
        if IsKeyDown(Enum.KeyCode.W)         then dir = dir + cam.LookVector     end
        if IsKeyDown(Enum.KeyCode.S)         then dir = dir - cam.LookVector     end
        if IsKeyDown(Enum.KeyCode.A)         then dir = dir - cam.RightVector    end
        if IsKeyDown(Enum.KeyCode.D)         then dir = dir + cam.RightVector    end
        if IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0) end
        if IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * Estado.voarVel
        bg.CFrame   = CFrame.new(Vector3.zero, Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z))
    end)
end

-- ══════════════════════════════════════════════════════════════
--  AIMBOT — MELHORADO
-- ══════════════════════════════════════════════════════════════
local _aimbotHB  = nil
local _aimbotAlvo = nil  -- rastreia alvo atual

local _fovCircle = Drawing.new("Circle")
_fovCircle.Visible = false; _fovCircle.Filled = false
_fovCircle.Color = Color3.fromRGB(255,255,255)
_fovCircle.Thickness = 1.5; _fovCircle.Transparency = 0.4; _fovCircle.NumSides = 80

local function TemLinhaDaVisao(origem, destino, ignorar)
    local dir = (destino - origem)
    local dist = dir.Magnitude
    if dist < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filtro = { GetChar() }
    if ignorar then table.insert(filtro, ignorar) end
    params.FilterDescendantsInstances = filtro
    local res = workspace:Raycast(origem, dir.Unit * dist, params)
    if not res then return true end
    local hit = res.Instance
    local hitChar = hit and (
        (hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") and hit.Parent) or
        (hit:FindFirstChildOfClass("Humanoid") and hit)
    )
    return hitChar ~= nil
end

local function EhAlvoAimbot(plr)
    if not plr or not plr.Team then return false end
    if Estado.aimbotExcluidos[plr.Name] then return false end
    local meuTime = MeuTime()
    if not meuTime then return false end
    local t = plr.Team.Name
    if meuTime == "Inmates"   then return t == "Guards" or t == "Criminals" end
    if meuTime == "Guards"    then return t == "Inmates" or t == "Criminals" end
    if meuTime == "Criminals" then return t == "Inmates" or t == "Guards"   end
    return false
end

-- Predicao simples de movimento
local function PreverPosicao(hrp, dt)
    if not hrp then return hrp.Position end
    local vel = hrp.AssemblyLinearVelocity
    return hrp.Position + vel * dt
end

local function PararAimbot()
    if _aimbotHB then _aimbotHB:Disconnect(); _aimbotHB = nil end
    _fovCircle.Visible = false
    _aimbotAlvo = nil
end

local function IniciarAimbot()
    PararAimbot()
    _aimbotHB = RunService.RenderStepped:Connect(function()
        if not Estado.aimbotAtivo or Estado.hubFechado then
            _fovCircle.Visible = false; return
        end

        -- Verificar se deve segurar botao direito
        if Estado.aimbotHoldKey and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            _fovCircle.Color = Estado.aimbotCorCirculo
            _fovCircle.Position = Camera.ViewportSize / 2
            _fovCircle.Radius = Estado.aimbotFov; _fovCircle.Visible = true
            return
        end

        local centro = Camera.ViewportSize / 2
        _fovCircle.Color = Estado.aimbotCorCirculo
        _fovCircle.Position = centro
        _fovCircle.Radius = Estado.aimbotFov; _fovCircle.Visible = true

        local myHRP = GetHRP()
        local melhorAlvo = nil
        local melhorDist = math.huge

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not EhAlvoAimbot(plr) then continue end
            local char = plr.Character
            if not char then continue end
            local parte = char:FindFirstChild(Estado.aimbotParte) or char:FindFirstChild("HumanoidRootPart")
            if not parte then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            local alvoPos = Estado.aimbotPrediction and myHRP
                and PreverPosicao(parte, 0.083) or parte.Position

            local sp, onScreen, depth = WorldToViewport(alvoPos)
            if not onScreen or depth <= 0 then continue end
            local distTela = (sp - centro).Magnitude
            if distTela > Estado.aimbotFov then continue end

            if Estado.aimbotSoloVisivel and myHRP then
                if not TemLinhaDaVisao(myHRP.Position, alvoPos) then continue end
            end

            if distTela < melhorDist then
                melhorDist = distTela
                melhorAlvo = parte
            end
        end

        _aimbotAlvo = melhorAlvo

        if melhorAlvo then
            local alvoPos = Estado.aimbotPrediction and myHRP
                and PreverPosicao(melhorAlvo, 0.083) or melhorAlvo.Position

            if Estado.aimbotSilent then
                -- Silent aim: desviar bala, nao camera
                -- (apenas mira a camera se silent = false)
            else
                local vetor = (alvoPos - Camera.CFrame.Position).Unit
                local novaCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + vetor)
                -- Smooth com lerp adaptativo
                local smooth = math.clamp(Estado.aimbotSmooth + (melhorDist / Estado.aimbotFov) * 0.1, 0.05, 1)
                Camera.CFrame = Camera.CFrame:Lerp(novaCF, smooth)
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  RADAR
-- ══════════════════════════════════════════════════════════════
local _radarGui = nil; local _radarFrame = nil; local _radarCanvas = nil
local _radarPontosGUI = {}; local _radarConn = nil

local function RemoverRadar()
    if _radarConn then _radarConn:Disconnect(); _radarConn = nil end
    if _radarGui and _radarGui.Parent then _radarGui:Destroy(); _radarGui = nil end
    _radarFrame = nil; _radarCanvas = nil; _radarPontosGUI = {}
end

local function CriarRadar()
    RemoverRadar()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "RadarGUI"; gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui; _radarGui = gui
    local SZ = Estado.radarTamanho; local barH = 30
    local vp = Camera.ViewportSize
    local posX = Estado.radarPosX or (vp.X - SZ - 16)
    local posY = Estado.radarPosY or (vp.Y - SZ - barH - 16)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,SZ,0,SZ+barH); frame.Position = UDim2.new(0,posX,0,posY)
    frame.BackgroundColor3 = Color3.fromRGB(8,8,14); frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0; frame.ClipsDescendants = false; frame.Parent = gui; _radarFrame = frame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = frame
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60,180,255); stroke.Thickness = 1.5; stroke.Transparency = 0.3; stroke.Parent = frame
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,barH); titleBar.BackgroundColor3 = Color3.fromRGB(15,50,100)
    titleBar.BackgroundTransparency = 0.1; titleBar.BorderSizePixel = 0; titleBar.ZIndex = 10; titleBar.Parent = frame
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,10); tc.Parent = titleBar
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1,-80,1,0); titleLbl.Position = UDim2.new(0,10,0,0)
    titleLbl.BackgroundTransparency = 1; titleLbl.Text = "📡  RADAR"
    titleLbl.TextColor3 = Color3.fromRGB(140,200,255); titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 11; titleLbl.Parent = titleBar
    local btnMin = Instance.new("TextButton")
    btnMin.Size = UDim2.new(0,26,0,20); btnMin.Position = UDim2.new(1,-56,0,5)
    btnMin.BackgroundColor3 = Color3.fromRGB(30,80,150); btnMin.BackgroundTransparency = 0.3
    btnMin.Text = "—"; btnMin.TextColor3 = Color3.fromRGB(200,220,255); btnMin.Font = Enum.Font.GothamBold
    btnMin.TextSize = 12; btnMin.BorderSizePixel = 0; btnMin.ZIndex = 12; btnMin.AutoButtonColor = false; btnMin.Parent = titleBar
    local btnMinC = Instance.new("UICorner"); btnMinC.CornerRadius = UDim.new(0,5); btnMinC.Parent = btnMin
    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0,22,0,20); btnClose.Position = UDim2.new(1,-28,0,5)
    btnClose.BackgroundColor3 = Color3.fromRGB(160,30,30); btnClose.BackgroundTransparency = 0.3
    btnClose.Text = "✕"; btnClose.TextColor3 = Color3.new(1,1,1); btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 11; btnClose.BorderSizePixel = 0; btnClose.ZIndex = 12; btnClose.AutoButtonColor = false; btnClose.Parent = titleBar
    local btnCloseC = Instance.new("UICorner"); btnCloseC.CornerRadius = UDim.new(0,5); btnCloseC.Parent = btnClose
    local canvas = Instance.new("Frame")
    canvas.Size = UDim2.new(1,-8,1,-(barH+8)); canvas.Position = UDim2.new(0,4,0,barH+4)
    canvas.BackgroundColor3 = Color3.fromRGB(4,14,28); canvas.BackgroundTransparency = 0.05
    canvas.BorderSizePixel = 0; canvas.ClipsDescendants = true; canvas.Parent = frame; _radarCanvas = canvas
    local canvasCorner = Instance.new("UICorner"); canvasCorner.CornerRadius = UDim.new(0,8); canvasCorner.Parent = canvas
    local function CriarLinhaRef(parent, sX, sY, pX, pY, transp)
        local l = Instance.new("Frame")
        l.Size = UDim2.new(sX[1],sX[2],sY[1],sY[2]); l.Position = UDim2.new(pX[1],pX[2],pY[1],pY[2])
        l.BackgroundColor3 = Color3.fromRGB(60,180,255); l.BackgroundTransparency = transp or 0.8; l.BorderSizePixel = 0; l.Parent = parent
    end
    CriarLinhaRef(canvas,{1,0},{0,1},{0,0},{0.5,-0.5},0.75)
    CriarLinhaRef(canvas,{0,1},{1,0},{0.5,-0.5},{0,0},0.75)
    local circulo = Instance.new("Frame")
    circulo.Size = UDim2.new(0.7,0,0.7,0); circulo.Position = UDim2.new(0.15,0,0.15,0)
    circulo.BackgroundTransparency = 1; circulo.BorderSizePixel = 0; circulo.Parent = canvas
    local circ2 = Instance.new("UICorner"); circ2.CornerRadius = UDim.new(1,0); circ2.Parent = circulo
    local circStroke = Instance.new("UIStroke"); circStroke.Color = Color3.fromRGB(60,180,255); circStroke.Thickness = 1; circStroke.Transparency = 0.65; circStroke.Parent = circulo
    local circOuter = Instance.new("Frame")
    circOuter.Size = UDim2.new(0.95,0,0.95,0); circOuter.Position = UDim2.new(0.025,0,0.025,0)
    circOuter.BackgroundTransparency = 1; circOuter.BorderSizePixel = 0; circOuter.Parent = canvas
    local circOuterC = Instance.new("UICorner"); circOuterC.CornerRadius = UDim.new(1,0); circOuterC.Parent = circOuter
    local circOuterS = Instance.new("UIStroke"); circOuterS.Color = Color3.fromRGB(60,180,255); circOuterS.Thickness = 1.5; circOuterS.Transparency = 0.45; circOuterS.Parent = circOuter
    local meuponto = Instance.new("Frame")
    meuponto.Size = UDim2.new(0,10,0,10); meuponto.Position = UDim2.new(0.5,-5,0.5,-5)
    meuponto.BackgroundColor3 = Color3.fromRGB(255,255,100); meuponto.BorderSizePixel = 0; meuponto.ZIndex = 5; meuponto.Parent = canvas
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(1,0); mc.Parent = meuponto
    local function CriarLabelDir(txt, px, py)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0,16,0,14); l.Position = UDim2.new(px,-8,py,-7)
        l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = Color3.fromRGB(140,200,255)
        l.Font = Enum.Font.GothamBold; l.TextSize = 9; l.ZIndex = 4; l.Parent = canvas
    end
    CriarLabelDir("N",0.5,0.02); CriarLabelDir("S",0.5,0.92)
    CriarLabelDir("L",0.92,0.5); CriarLabelDir("O",0.02,0.5)
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0,18,0,18); resizeHandle.Position = UDim2.new(1,-18,1,-18)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(40,120,200); resizeHandle.BackgroundTransparency = 0.4
    resizeHandle.Text = "⊿"; resizeHandle.TextColor3 = Color3.fromRGB(140,200,255); resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.TextSize = 11; resizeHandle.BorderSizePixel = 0; resizeHandle.ZIndex = 15; resizeHandle.AutoButtonColor = false; resizeHandle.Parent = frame
    local resizeC = Instance.new("UICorner"); resizeC.CornerRadius = UDim.new(0,4); resizeC.Parent = resizeHandle
    FazerArrastavel(frame, titleBar, function(pos)
        Estado.radarPosX = pos.X.Offset; Estado.radarPosY = pos.Y.Offset
    end)
    local resizeDragging = false; local resizeStart = nil; local resizeStartSZ = nil
    resizeHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizeDragging = true; resizeStart = inp.Position; resizeStartSZ = frame.AbsoluteSize
        end
    end)
    resizeHandle.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then resizeDragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not resizeDragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = inp.Position - resizeStart
        local newSZ = math.clamp(resizeStartSZ.X + delta.X, 120, 450)
        Estado.radarTamanho = newSZ
        frame.Size = UDim2.new(0, newSZ, 0, newSZ + barH)
    end)
    btnMin.MouseButton1Click:Connect(function()
        Estado.radarMinimizado = not Estado.radarMinimizado
        canvas.Visible = not Estado.radarMinimizado
        resizeHandle.Visible = not Estado.radarMinimizado
        if Estado.radarMinimizado then
            frame.Size = UDim2.new(0, Estado.radarTamanho, 0, barH); btnMin.Text = "▲"
        else
            frame.Size = UDim2.new(0, Estado.radarTamanho, 0, Estado.radarTamanho + barH); btnMin.Text = "—"
        end
    end)
    btnClose.MouseButton1Click:Connect(function()
        Estado.radarAtivo = false; RemoverRadar()
    end)
    _radarConn = RunService.RenderStepped:Connect(function()
        if not Estado.radarAtivo or Estado.radarMinimizado then return end
        local myHRP = GetHRP(); if not myHRP then return end
        local camY = Camera.CFrame.LookVector
        local angulo = math.atan2(camY.X, camY.Z)
        local cSZ = canvas.AbsoluteSize
        local cX = cSZ.X/2; local cY = cSZ.Y/2
        local raioMax = math.min(cX,cY) * 0.9
        for nome, ponto in pairs(_radarPontosGUI) do
            local plr = Players:FindFirstChild(nome)
            if not plr or not plr.Character then ponto:Destroy(); _radarPontosGUI[nome] = nil end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local char = plr.Character
            local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp2 then
                if _radarPontosGUI[plr.Name] then _radarPontosGUI[plr.Name].Visible = false end
                continue
            end
            local relativo = myHRP.CFrame:ToObjectSpace(hrp2.CFrame)
            local rx = relativo.Position.X; local rz = relativo.Position.Z
            local cos = math.cos(-angulo); local sin = math.sin(-angulo)
            local px = rx*cos - rz*sin; local pz = rx*sin + rz*cos
            local dx = px*Estado.radarZoom; local dz = pz*Estado.radarZoom
            local mag = math.sqrt(dx*dx + dz*dz)
            if mag > raioMax-6 then local f=(raioMax-6)/mag; dx=dx*f; dz=dz*f end
            local screenX = cX+dx; local screenY = cY+dz
            local cor = CorDoTime(plr)
            local dist3D = (myHRP.Position - hrp2.Position).Magnitude
            local ptSize = math.clamp(math.floor(12 - dist3D*0.04), 5, 12)
            local ponto = _radarPontosGUI[plr.Name]
            if not ponto or not ponto.Parent then
                ponto = Instance.new("Frame")
                ponto.BackgroundColor3 = cor; ponto.BorderSizePixel = 0; ponto.ZIndex = 3
                local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1,0); pc.Parent = ponto
                local tooltip = Instance.new("TextLabel")
                tooltip.Size = UDim2.new(0,80,0,16); tooltip.Position = UDim2.new(0.5,-40,0,-18)
                tooltip.BackgroundColor3 = Color3.fromRGB(10,10,20); tooltip.BackgroundTransparency = 0.2
                tooltip.Text = plr.Name; tooltip.TextColor3 = Color3.new(1,1,1); tooltip.Font = Enum.Font.Gotham
                tooltip.TextSize = 9; tooltip.BorderSizePixel = 0; tooltip.ZIndex = 6; tooltip.Visible = false; tooltip.Name = "Tooltip"; tooltip.Parent = ponto
                local ttc = Instance.new("UICorner"); ttc.CornerRadius = UDim.new(0,4); ttc.Parent = tooltip
                ponto.MouseEnter:Connect(function() tooltip.Visible = true end)
                ponto.MouseLeave:Connect(function() tooltip.Visible = false end)
                ponto.Parent = canvas; _radarPontosGUI[plr.Name] = ponto
            end
            ponto.Size = UDim2.new(0,ptSize,0,ptSize); ponto.BackgroundColor3 = cor
            ponto.Position = UDim2.new(0,math.floor(screenX-ptSize/2),0,math.floor(screenY-ptSize/2))
            ponto.Visible = true; ponto.Name = plr.Name
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  CHAT SPY
-- ══════════════════════════════════════════════════════════════
local _chatSpyGui = nil; local _chatSpyFrame = nil; local _chatSpyScroll = nil
local _chatSpyConn = nil; local _chatSpyMsgs = {}
local _chatSpyContagem = { Inmates=0, Guards=0, Criminals=0, Outros=0, Total=0 }

local COR_CHAT = {
    sistema=Color3.fromRGB(140,200,255), local_=Color3.fromRGB(100,255,140),
    inmate=Color3.fromRGB(255,160,50), guard=Color3.fromRGB(80,160,255),
    criminal=Color3.fromRGB(255,80,80), outro=Color3.fromRGB(220,220,220),
    titulo=Color3.fromRGB(255,200,80), sistema_msg=Color3.fromRGB(80,200,150),
}

local function GetCorChat(plr)
    if not plr or plr == LocalPlayer then return COR_CHAT.local_ end
    if not plr.Team then return COR_CHAT.outro end
    local t = plr.Team.Name
    if t == "Inmates" then return COR_CHAT.inmate end
    if t == "Guards"  then return COR_CHAT.guard  end
    if t == "Criminals" then return COR_CHAT.criminal end
    return COR_CHAT.outro
end

local function GetTimestamp()
    local t = os.time(); local sec = t%60; local min = math.floor(t/60)%60; local hr = math.floor(t/3600)%24
    return string.format("%02d:%02d:%02d", hr, min, sec)
end

local function DeveMostrarMensagem(remetente)
    local filtro = Estado.chatSpyFiltro
    if filtro == "Todos" then return true end
    local plr = Players:FindFirstChild(remetente)
    if not plr then return filtro == "Outros" end
    if not plr.Team then return filtro == "Outros" end
    return plr.Team.Name == filtro
end

local _chatContLabel = nil

local function AtualizarContagemChat()
    if not _chatContLabel then return end
    local t = _chatSpyContagem
    _chatContLabel.Text = string.format("I:%d  G:%d  C:%d  O:%d  | Total:%d", t.Inmates, t.Guards, t.Criminals, t.Outros, t.Total)
end

local function AdicionarMensagemChatSpy(remetente, texto, cor, teamName)
    if not _chatSpyScroll then return end
    teamName = teamName or "Outros"
    _chatSpyContagem.Total = _chatSpyContagem.Total + 1
    if teamName=="Inmates" then _chatSpyContagem.Inmates=_chatSpyContagem.Inmates+1
    elseif teamName=="Guards" then _chatSpyContagem.Guards=_chatSpyContagem.Guards+1
    elseif teamName=="Criminals" then _chatSpyContagem.Criminals=_chatSpyContagem.Criminals+1
    else _chatSpyContagem.Outros=_chatSpyContagem.Outros+1 end
    table.insert(_chatSpyMsgs, {r=remetente,t=texto,c=cor,team=teamName,ts=GetTimestamp()})
    if #_chatSpyMsgs > 150 then table.remove(_chatSpyMsgs,1) end
    if not DeveMostrarMensagem(remetente) then AtualizarContagemChat(); return end
    local linha = Instance.new("Frame")
    linha.Size = UDim2.new(1,-8,0,0); linha.Position = UDim2.new(0,4,0,0)
    linha.BackgroundTransparency = 1; linha.AutomaticSize = Enum.AutomaticSize.Y
    linha.Name = "ChatMsg"; linha.Parent = _chatSpyScroll
    if remetente ~= "SISTEMA" then
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = cor; bg.BackgroundTransparency = 0.92
        bg.BorderSizePixel = 0; bg.ZIndex = 0; bg.Parent = linha
        local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0,4); bgc.Parent = bg
    end
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,-4,0,0); txt.Position = UDim2.new(0,2,0,0)
    txt.BackgroundTransparency = 1; txt.AutomaticSize = Enum.AutomaticSize.Y
    txt.Text = "[" .. GetTimestamp() .. "] [" .. remetente .. "]: " .. texto
    txt.TextColor3 = cor; txt.Font = Enum.Font.Gotham; txt.TextSize = 11
    txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextWrapped = true
    txt.TextYAlignment = Enum.TextYAlignment.Top; txt.Parent = linha
    AtualizarContagemChat()
    task.defer(function()
        if _chatSpyScroll and _chatSpyScroll.Parent then
            _chatSpyScroll.CanvasPosition = Vector2.new(0, _chatSpyScroll.AbsoluteCanvasSize.Y)
        end
    end)
end

local function RecriarMensagensFiltradas()
    if not _chatSpyScroll then return end
    for _, c in ipairs(_chatSpyScroll:GetChildren()) do
        if c:IsA("Frame") and c.Name == "ChatMsg" then c:Destroy() end
    end
    for _, msg in ipairs(_chatSpyMsgs) do
        if DeveMostrarMensagem(msg.r) then
            local linha = Instance.new("Frame")
            linha.Size = UDim2.new(1,-8,0,0); linha.Position = UDim2.new(0,4,0,0)
            linha.BackgroundTransparency = 1; linha.AutomaticSize = Enum.AutomaticSize.Y
            linha.Name = "ChatMsg"; linha.Parent = _chatSpyScroll
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1,-4,0,0); txt.Position = UDim2.new(0,2,0,0)
            txt.BackgroundTransparency = 1; txt.AutomaticSize = Enum.AutomaticSize.Y
            txt.Text = "[" .. msg.ts .. "] [" .. msg.r .. "]: " .. msg.t
            txt.TextColor3 = msg.c; txt.Font = Enum.Font.Gotham; txt.TextSize = 11
            txt.TextXAlignment = Enum.TextXAlignment.Left; txt.TextWrapped = true
            txt.TextYAlignment = Enum.TextYAlignment.Top; txt.Parent = linha
        end
    end
    task.defer(function()
        if _chatSpyScroll and _chatSpyScroll.Parent then
            _chatSpyScroll.CanvasPosition = Vector2.new(0, _chatSpyScroll.AbsoluteCanvasSize.Y)
        end
    end)
end

local function CriarChatSpyGUI()
    if _chatSpyGui then return end
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "ChatSpyGUI"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = playerGui; _chatSpyGui = gui
    local vp = Camera.ViewportSize
    local posX = Estado.chatSpyPosX or 16
    local posY = Estado.chatSpyPosY or (vp.Y - 260)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,370,0,250); frame.Position = UDim2.new(0,posX,0,posY)
    frame.BackgroundColor3 = Color3.fromRGB(6,8,14); frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0; frame.Parent = gui; _chatSpyFrame = frame
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0,10); fc.Parent = frame
    local fs = Instance.new("UIStroke"); fs.Color = Color3.fromRGB(255,200,80); fs.Thickness = 1.5; fs.Transparency = 0.3; fs.Parent = frame
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,28); titleBar.BackgroundColor3 = Color3.fromRGB(60,40,0)
    titleBar.BackgroundTransparency = 0.15; titleBar.BorderSizePixel = 0; titleBar.ZIndex = 10; titleBar.Parent = frame
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,10); tc.Parent = titleBar
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1,-100,1,0); titleLbl.Position = UDim2.new(0,10,0,0)
    titleLbl.BackgroundTransparency = 1; titleLbl.Text = "💬  CHAT SPY"
    titleLbl.TextColor3 = COR_CHAT.titulo; titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 11; titleLbl.Parent = titleBar
    local btnLimpar = Instance.new("TextButton")
    btnLimpar.Size = UDim2.new(0,28,0,20); btnLimpar.Position = UDim2.new(1,-58,0,4)
    btnLimpar.BackgroundColor3 = Color3.fromRGB(80,60,0); btnLimpar.BackgroundTransparency = 0.3
    btnLimpar.Text = "🗑️"; btnLimpar.TextSize = 11; btnLimpar.BorderSizePixel = 0
    btnLimpar.ZIndex = 12; btnLimpar.AutoButtonColor = false; btnLimpar.Parent = titleBar
    local blc = Instance.new("UICorner"); blc.CornerRadius = UDim.new(0,5); blc.Parent = btnLimpar
    local btnClose2 = Instance.new("TextButton")
    btnClose2.Size = UDim2.new(0,22,0,20); btnClose2.Position = UDim2.new(1,-28,0,4)
    btnClose2.BackgroundColor3 = Color3.fromRGB(160,30,30); btnClose2.BackgroundTransparency = 0.3
    btnClose2.Text = "✕"; btnClose2.TextColor3 = Color3.new(1,1,1); btnClose2.Font = Enum.Font.GothamBold
    btnClose2.TextSize = 11; btnClose2.BorderSizePixel = 0; btnClose2.ZIndex = 12; btnClose2.AutoButtonColor = false; btnClose2.Parent = titleBar
    local btcc = Instance.new("UICorner"); btcc.CornerRadius = UDim.new(0,5); btcc.Parent = btnClose2
    local filtroBar = Instance.new("Frame")
    filtroBar.Size = UDim2.new(1,0,0,26); filtroBar.Position = UDim2.new(0,0,0,28)
    filtroBar.BackgroundColor3 = Color3.fromRGB(12,12,20); filtroBar.BackgroundTransparency = 0.2
    filtroBar.BorderSizePixel = 0; filtroBar.Parent = frame
    local filtros = {"Todos","Inmates","Guards","Criminals","Outros"}
    local filtroW = 370/#filtros; local filtroButtons = {}
    for i, f in ipairs(filtros) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,filtroW-4,0,20); btn.Position = UDim2.new(0,(i-1)*filtroW+2,0,3)
        btn.BackgroundColor3 = f=="Todos" and Color3.fromRGB(60,40,10) or Color3.fromRGB(20,20,30)
        btn.BackgroundTransparency = 0.3; btn.Text = f; btn.TextColor3 = Color3.fromRGB(200,200,200)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 10; btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = filtroBar
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,4); bc.Parent = btn
        filtroButtons[f] = btn
        btn.MouseButton1Click:Connect(function()
            Estado.chatSpyFiltro = f
            for _, fb in pairs(filtroButtons) do fb.BackgroundColor3=Color3.fromRGB(20,20,30); fb.BackgroundTransparency=0.3; fb.TextColor3=Color3.fromRGB(200,200,200) end
            btn.BackgroundColor3=Color3.fromRGB(60,40,10); btn.BackgroundTransparency=0.1; btn.TextColor3=Color3.fromRGB(255,200,80)
            RecriarMensagensFiltradas()
        end)
    end
    local contFrame = Instance.new("Frame")
    contFrame.Size = UDim2.new(1,0,0,16); contFrame.Position = UDim2.new(0,0,0,54)
    contFrame.BackgroundColor3 = Color3.fromRGB(10,10,18); contFrame.BackgroundTransparency = 0.3; contFrame.BorderSizePixel = 0; contFrame.Parent = frame
    local contLbl = Instance.new("TextLabel")
    contLbl.Size = UDim2.new(1,-8,1,0); contLbl.Position = UDim2.new(0,4,0,0)
    contLbl.BackgroundTransparency = 1; contLbl.Text = "Aguardando mensagens..."
    contLbl.TextColor3 = Color3.fromRGB(150,150,180); contLbl.Font = Enum.Font.Gotham
    contLbl.TextSize = 9; contLbl.TextXAlignment = Enum.TextXAlignment.Left; contLbl.Parent = contFrame
    _chatContLabel = contLbl
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-4,1,-76); scroll.Position = UDim2.new(0,2,0,72)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255,200,80); scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.Parent = frame; _chatSpyScroll = scroll
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,2); layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left; layout.Parent = scroll
    local resizeHandle2 = Instance.new("TextButton")
    resizeHandle2.Size = UDim2.new(0,18,0,18); resizeHandle2.Position = UDim2.new(1,-18,1,-18)
    resizeHandle2.BackgroundColor3 = Color3.fromRGB(100,80,0); resizeHandle2.BackgroundTransparency = 0.4
    resizeHandle2.Text = "⊿"; resizeHandle2.TextColor3 = Color3.fromRGB(255,200,80); resizeHandle2.Font = Enum.Font.GothamBold
    resizeHandle2.TextSize = 11; resizeHandle2.BorderSizePixel = 0; resizeHandle2.ZIndex = 15; resizeHandle2.AutoButtonColor = false; resizeHandle2.Parent = frame
    local resizeC2 = Instance.new("UICorner"); resizeC2.CornerRadius = UDim.new(0,4); resizeC2.Parent = resizeHandle2
    local resizeDrag2 = false; local resizeStart2 = nil; local resizeStartSZ2 = nil
    resizeHandle2.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            resizeDrag2=true; resizeStart2=inp.Position; resizeStartSZ2=frame.AbsoluteSize
        end
    end)
    resizeHandle2.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then resizeDrag2=false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not resizeDrag2 then return end
        if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
        local delta = inp.Position - resizeStart2
        local newW = math.clamp(resizeStartSZ2.X + delta.X, 280, 600)
        local newH = math.clamp(resizeStartSZ2.Y + delta.Y, 160, 500)
        frame.Size = UDim2.new(0,newW,0,newH)
    end)
    FazerArrastavel(frame, titleBar, function(pos) Estado.chatSpyPosX=pos.X.Offset; Estado.chatSpyPosY=pos.Y.Offset end)
    btnLimpar.MouseButton1Click:Connect(function()
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        _chatSpyMsgs = {}; _chatSpyContagem = {Inmates=0,Guards=0,Criminals=0,Outros=0,Total=0}
        AtualizarContagemChat()
        AdicionarMensagemChatSpy("SISTEMA","Chat limpo.",COR_CHAT.sistema_msg,"Outros")
    end)
    btnClose2.MouseButton1Click:Connect(function() Estado.chatSpyAtivo=false; PararChatSpy() end)
    AdicionarMensagemChatSpy("SISTEMA","Chat Spy ativado! Use os filtros acima.",COR_CHAT.sistema_msg,"Outros")
end

local function RemoverChatSpyGUI()
    if _chatSpyConn then pcall(function() _chatSpyConn:Disconnect() end); _chatSpyConn=nil end
    if _chatSpyGui and _chatSpyGui.Parent then _chatSpyGui:Destroy() end
    _chatSpyGui=nil; _chatSpyFrame=nil; _chatSpyScroll=nil; _chatContLabel=nil
end

local function IniciarChatSpy()
    CriarChatSpyGUI()
    local ok = pcall(function()
        _chatSpyConn = TextChatService.MessageReceived:Connect(function(msg)
            if not Estado.chatSpyAtivo then return end
            local autor = msg.TextSource and msg.TextSource.Name or "?"
            local plr = Players:FindFirstChild(autor)
            local nome = plr and plr.Name or autor
            local cor = GetCorChat(plr)
            local team = (plr and plr.Team and plr.Team.Name) or "Outros"
            AdicionarMensagemChatSpy(nome, msg.Text or "", cor, team)
        end)
    end)
    if not ok or not _chatSpyConn then
        local conns = {}
        local function EscutarJogador(plr)
            local c = plr.Chatted:Connect(function(msg)
                if not Estado.chatSpyAtivo then return end
                AdicionarMensagemChatSpy(plr.Name, msg, GetCorChat(plr), (plr.Team and plr.Team.Name) or "Outros")
            end)
            table.insert(conns, c)
        end
        for _, plr in ipairs(Players:GetPlayers()) do EscutarJogador(plr) end
        Players.PlayerAdded:Connect(EscutarJogador)
        _chatSpyConn = { Disconnect = function() for _, c in ipairs(conns) do c:Disconnect() end end }
    end
end

function PararChatSpy()
    if _chatSpyConn then pcall(function() _chatSpyConn:Disconnect() end); _chatSpyConn=nil end
    RemoverChatSpyGUI()
end

-- ══════════════════════════════════════════════════════════════
--  AUTO PRENDER
-- ══════════════════════════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly   then IniciarFly()   end
    if Estado.noclip then IniciarNoclip() end
    AplicarWalkSpeed()
end)

local site = loadstring(game:HttpGet("https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub.lua", true))()
local hub  = site.novo("Reboco", "Escuro")

local _prenderThread = nil; local _arrestRemote = nil

local function GetRemote()
    if _arrestRemote and _arrestRemote.Parent then return _arrestRemote end
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    _arrestRemote = r and r:FindFirstChild("ArrestPlayer") or nil
    return _arrestRemote
end

local function GetCriminosos()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team and plr.Team.Name == "Criminals"
        and not Estado.prenderExcluidos[plr.Name] then
            table.insert(lista, plr)
        end
    end
    return lista
end

local function EhCriminal(plr) return plr and plr.Team and plr.Team.Name == "Criminals" end

local function RespawnarPersonagem()
    local hum = GetHum(); if hum then hum.Health = 0 end
    local renasceu = false; local conn
    conn = LocalPlayer.CharacterAdded:Connect(function() renasceu = true; conn:Disconnect() end)
    local inicio = tick()
    while not renasceu and (tick()-inicio) < 5 do task.wait(0.05) end
    task.wait(0.5)
end

local function TentarPrender(alvo)
    if not alvo or not alvo.Parent then return false end
    if not EhCriminal(alvo) then return false end
    if Estado.prenderExcluidos[alvo.Name] then return false end
    local remote = GetRemote(); if not remote then return false end
    while Estado.prenderAuto and not Estado.hubFechado do
        if not alvo or not alvo.Parent then return false end
        if not EhCriminal(alvo) then return false end
        if Estado.prenderExcluidos[alvo.Name] then return false end
        local hum = GetHum(alvo)
        if hum and hum.Health > 0 then break end
        task.wait(0.2)
    end
    if not Estado.prenderAuto or Estado.hubFechado then return false end
    local inicio = tick()
    while (tick()-inicio) < 2 do
        if not Estado.prenderAuto or Estado.hubFechado then break end
        if not alvo or not alvo.Parent then break end
        if Estado.prenderExcluidos[alvo.Name] then break end
        local myHRP2 = GetHRP(); local alvHRP2 = GetHRP(alvo)
        if myHRP2 and alvHRP2 then myHRP2.CFrame = alvHRP2.CFrame * CFrame.new(0,0,-1) end
        xpcall(function() remote:InvokeServer(alvo, 1) end, function() end)
        task.wait(0)
    end
    return true
end

local function ExecutarCooldown()
    if not Estado.prenderAuto or Estado.hubFechado then return end
    hub:Notificar("Auto Prender","Renascendo...","sucesso",2)
    RespawnarPersonagem(); task.wait(0.2)
end

local function LoopPrender()
    local semCrimNotificado = false
    while Estado.prenderAuto and not Estado.hubFechado do
        if MeuTime() ~= "Guards" then
            hub:Notificar("Auto Prender","Voce precisa estar no time Guards!","erro",3)
            Estado.prenderAuto = false; break
        end
        local criminosos = GetCriminosos()
        if #criminosos == 0 then
            if not semCrimNotificado then semCrimNotificado=true; hub:Notificar("Auto Prender","Nenhum Criminal disponivel!","info",4) end
            task.wait(0.5); continue
        end
        semCrimNotificado = false
        for _, alvo in ipairs(criminosos) do
            if not Estado.prenderAuto or Estado.hubFechado then break end
            if MeuTime() ~= "Guards" then break end
            if not alvo or not alvo.Parent then continue end
            if not EhCriminal(alvo) then continue end
            if Estado.prenderExcluidos[alvo.Name] then continue end
            hub:Notificar("Auto Prender","Indo ate: "..alvo.Name,"aviso",2)
            local ok = TentarPrender(alvo)
            if ok then ExecutarCooldown()
            elseif not alvo or not alvo.Parent then hub:Notificar("Auto Prender","Jogador saiu do jogo.","info",2)
            else hub:Notificar("Auto Prender",alvo.Name.." nao disponivel.","info",2) end
            task.wait(0)
        end
        task.wait(0)
    end
end

local function IniciarPrenderAuto()
    if MeuTime() ~= "Guards" then hub:Notificar("Auto Prender","Apenas Guards podem usar isso!","erro",3); return end
    Estado.prenderAuto = true
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end
    _prenderThread = task.spawn(LoopPrender)
end

local function PararPrenderAuto()
    Estado.prenderAuto = false
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end
end

-- ══════════════════════════════════════════════════════════════
--  HELPERS DE LISTA
-- ══════════════════════════════════════════════════════════════
local function ListarJogadoresTodos()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then table.insert(lista, plr.Name) end
    end
    if #lista == 0 then lista = {"(nenhum)"} end
    return lista
end

local function ListarJogadoresTeleporte()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local entrada = plr.DisplayName ~= plr.Name
                and plr.DisplayName .. " (" .. plr.Name .. ")" or plr.Name
            table.insert(lista, entrada)
        end
    end
    if #lista == 0 then lista = {"(nenhum jogador)"} end
    return lista
end

local function ExtrairUsername(entrada)
    return entrada:match("%((.-)%)$") or entrada
end

local LOCAIS = {
    { nome="🗼 Torre de Vigia",    pos=Vector3.new(823.0, 125.8, 2589.0) },
    { nome="🚔 Carros da Policia", pos=Vector3.new(589.5,  98.2, 2489.8) },
    { nome="🔫 Armas da Policia",  pos=Vector3.new(817.2, 100.0, 2232.2) },
    { nome="🏛️ Patio",             pos=Vector3.new(821.3,  98.3, 2384.9) },
    { nome="💀 Base Criminosa",    pos=Vector3.new(-937.4,  94.1, 2057.4) },
}

-- ══════════════════════════════════════════════════════════════
--  ABAS DO HUB
--  Ordem: Jogador → ESP → Aimbot → Teleporte → Radar → Misc → Config
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- ABA: JOGADOR (funcoes de movimento primeiro)
-- ─────────────────────────────────────────────────────────────
local abaJogador = hub:CriarAba("Jogador", "🧍")

abaJogador:CriarSecao("Velocidade")
abaJogador:CriarToggle("Speed Hack", Estado.walkspeedAtivo, function(v)
    Estado.walkspeedAtivo = v
    AplicarWalkSpeed()
    hub:Notificar("Velocidade", v and ("Ativado! "..Estado.walkspeed.."ws") or "Resetado para 16ws", v and "sucesso" or "info", 2)
end)
abaJogador:CriarSlider("Velocidade", 8, 300, Estado.walkspeed, function(v)
    Estado.walkspeed = v
    if Estado.walkspeedAtivo then AplicarWalkSpeed() end
end, { unidade=" ws" })

abaJogador:CriarSecao("Noclip")
abaJogador:CriarTexto("Atravessa paredes, chao e objetos.\nCombina bem com Fly!")
abaJogador:CriarToggle("Noclip", Estado.noclip, function(v)
    Estado.noclip = v
    if v then IniciarNoclip(); hub:Notificar("Noclip","Ativado! Atravessando paredes.","sucesso",2)
    else PararNoclip(); hub:Notificar("Noclip","Desativado","info",2) end
end)

abaJogador:CriarSecao("Voar")
abaJogador:CriarTexto("PC: W/A/S/D = direcao | Space = subir | Shift = descer\nMobile: botoes aparecem na tela.")
abaJogador:CriarToggle("Voar", Estado.fly, function(v)
    if v then IniciarFly(); hub:Notificar("Voar","Ativado!","sucesso",2)
    else PararFly(); hub:Notificar("Voar","Desativado","info",2) end
end)
abaJogador:CriarSlider("Velocidade de Voo", 10, 400, Estado.voarVel, function(v)
    Estado.voarVel = v
end, { unidade=" ws" })

abaJogador:CriarSecao("Prender Automatico")
abaJogador:CriarTexto("Somente no time Guards.\nDetecta Criminals, teleporta e prende automaticamente.")
abaJogador:CriarToggle("Auto Prender", Estado.prenderAuto, function(v)
    if v then IniciarPrenderAuto()
        if Estado.prenderAuto then hub:Notificar("Auto Prender","Ativado!","sucesso",2) end
    else PararPrenderAuto(); hub:Notificar("Auto Prender","Desativado","info",2) end
end)

abaJogador:CriarSecao("Excluir do Auto Prender")
local dropExcluidos = abaJogador:CriarDropdown("Excluir Jogadores", ListarJogadoresTodos(),
    function(label, selMap)
        Estado.prenderExcluidos = {}
        if selMap then for nome, ativo in pairs(selMap) do if ativo then Estado.prenderExcluidos[nome]=true end end end
    end,
    { multi=true, search=true, maxVisible=6, placeholder="Nenhum excluido" }
)
abaJogador:CriarBotao("Atualizar Lista", function()
    dropExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("Jogador","Lista atualizada!","info",2)
end, { icone="🔄" })

-- ─────────────────────────────────────────────────────────────
-- ABA: ESP (extremamente melhorado)
-- ─────────────────────────────────────────────────────────────
local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Ativar ESP")
abaESP:CriarToggle("ESP Todos os Jogadores", Estado.espTodos, function(v)
    Estado.espTodos = v
    RecarregarESP()
    hub:Notificar("ESP", v and "ESP Todos ativado!" or "ESP desativado", v and "sucesso" or "info", 2)
end)
abaESP:CriarToggle("ESP Customizado (selecionar)", Estado.espCustom, function(v)
    Estado.espCustom = v; RecarregarESP()
end)

abaESP:CriarSecao("Elementos Visuais")
abaESP:CriarToggle("Highlight 3D", Estado.espHighlight, function(v)
    Estado.espHighlight = v
    for _, d in pairs(_espDados) do
        if d.hl and d.hl.Parent then
            d.hl.FillTransparency = v and 0.5 or 1; d.hl.Enabled = v
        end
    end
end)
abaESP:CriarToggle("Box Normal", Estado.espBoxes, function(v)
    Estado.espBoxes = v
end)
abaESP:CriarToggle("Corner Box (cantos)", Estado.espBoxCanto, function(v)
    Estado.espBoxCanto = v
end)
abaESP:CriarToggle("Nomes", Estado.espNomes, function(v)
    Estado.espNomes = v
    if not v then for _, d in pairs(_espDados) do if d.lblNome2D then d.lblNome2D.Visible=false end end end
end)
abaESP:CriarToggle("HP Bar", Estado.espHP, function(v)
    Estado.espHP = v
    if not v then for _, d in pairs(_espDados) do
        if d.hpBar then d.hpBar.Visible=false end
        if d.hpBarBg then d.hpBarBg.Visible=false end
        if d.hpTexto then d.hpTexto.Visible=false end
    end end
end)
abaESP:CriarToggle("Texto de HP (numeros)", Estado.espHPTexto, function(v)
    Estado.espHPTexto = v
end)
abaESP:CriarToggle("Distancia + Status + Time", Estado.espDistancia, function(v)
    Estado.espDistancia = v
    if not v then for _, d in pairs(_espDados) do if d.lblDist2D then d.lblDist2D.Visible=false end end end
end)
abaESP:CriarToggle("Skeleton (ossos)", Estado.espSkeleton, function(v)
    Estado.espSkeleton = v
    if not v then for _, d in pairs(_espDados) do for _, s in pairs(d.skeleton or {}) do s.Visible=false end end end
end)

abaESP:CriarSecao("Tracers")
abaESP:CriarToggle("Mostrar Tracers", Estado.espTracers, function(v)
    Estado.espTracers = v
    if not v then for _, d in pairs(_espDados) do if d.line then d.line.Visible=false end end end
end)
abaESP:CriarDropdown("Origem do Tracer", {"Centro","Pe"}, function(v)
    Estado.espTracerOrigem = v
end, { placeholder="Centro" })
abaESP:CriarSlider("Grossura do Tracer", 1, 10, Estado.espTracerGross, function(v)
    Estado.espTracerGross = v
    for _, d in pairs(_espDados) do if d.line then d.line.Thickness=v end end
end, { unidade="px" })
abaESP:CriarSlider("Transparencia do Tracer", 0, 90, math.floor(Estado.espTracerTransp*100), function(v)
    Estado.espTracerTransp = v/100
    for _, d in pairs(_espDados) do if d.line then d.line.Transparency=Estado.espTracerTransp end end
end, { unidade="%" })

abaESP:CriarSecao("Distancia Maxima")
abaESP:CriarSlider("Max Distancia ESP", 50, 2000, Estado.espMaxDist, function(v)
    Estado.espMaxDist = v
end, { unidade="m" })

abaESP:CriarSecao("Jogadores (ESP Customizado)")
local dropESPJogadores = abaESP:CriarDropdown("Selecionar Jogadores", ListarJogadoresTodos(),
    function(label, selMap)
        Estado.espJogadoresSel = {}
        if selMap then for nome, ativo in pairs(selMap) do if ativo then Estado.espJogadoresSel[nome]=true end end end
    end,
    { multi=true, search=true, maxVisible=6, placeholder="Selecionar jogadores..." }
)
abaESP:CriarBotao("Atualizar Lista", function()
    dropESPJogadores:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("ESP","Lista atualizada!","info",2)
end, { icone="🔄" })

abaESP:CriarSecao("Cores por Time")
abaESP:CriarColorPicker("Inmates", Estado.corInmate, function(cor)
    Estado.corInmate = cor; AtualizarCoresTime("Inmates")
end)
abaESP:CriarColorPicker("Guards", Estado.corGuard, function(cor)
    Estado.corGuard = cor; AtualizarCoresTime("Guards")
end)
abaESP:CriarColorPicker("Criminals", Estado.corCriminal, function(cor)
    Estado.corCriminal = cor; AtualizarCoresTime("Criminals")
end)
abaESP:CriarColorPicker("Outros", Estado.corOutro, function(cor)
    Estado.corOutro = cor; AtualizarCoresOutros()
end)

-- ─────────────────────────────────────────────────────────────
-- ABA: AIMBOT
-- ─────────────────────────────────────────────────────────────
local abaAimbot = hub:CriarAba("Aimbot", "🎯")

abaAimbot:CriarSecao("Ativar")
abaAimbot:CriarTexto("Mira automatica no inimigo mais proximo do centro da tela.")
abaAimbot:CriarToggle("Aimbot Ativo", Estado.aimbotAtivo, function(v)
    Estado.aimbotAtivo = v
    if v then IniciarAimbot(); hub:Notificar("Aimbot","Ativado! Time: "..(MeuTime() or "?"),"sucesso",2)
    else PararAimbot(); hub:Notificar("Aimbot","Desativado","info",2) end
end)
abaAimbot:CriarToggle("Segurar Botao Direito (Hold)", Estado.aimbotHoldKey, function(v)
    Estado.aimbotHoldKey = v
end)

abaAimbot:CriarSecao("Ajustes de Mira")
abaAimbot:CriarSlider("FOV (raio)", 20, 600, Estado.aimbotFov, function(v)
    Estado.aimbotFov = v
end, { unidade="px" })
abaAimbot:CriarSlider("Suavidade (Smooth)", 1, 100, math.floor(Estado.aimbotSmooth*100), function(v)
    Estado.aimbotSmooth = v/100
end, { unidade="%" })
abaAimbot:CriarDropdown("Parte Alvo", {"Head","HumanoidRootPart","UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm"},
    function(parte) Estado.aimbotParte = parte; hub:Notificar("Aimbot","Mirando em: "..parte,"info",2) end,
    { placeholder="Head" }
)

abaAimbot:CriarSecao("Opcoes Avancadas")
abaAimbot:CriarToggle("Somente com Linha de Visao", Estado.aimbotSoloVisivel, function(v)
    Estado.aimbotSoloVisivel = v
end)
abaAimbot:CriarToggle("Predicao de Movimento", Estado.aimbotPrediction, function(v)
    Estado.aimbotPrediction = v
    hub:Notificar("Aimbot", v and "Predicao ativada!" or "Predicao desativada", "info", 2)
end)
abaAimbot:CriarColorPicker("Cor do Circulo FOV", Estado.aimbotCorCirculo, function(cor)
    Estado.aimbotCorCirculo = cor
    _fovCircle.Color = cor
end)

abaAimbot:CriarSecao("Excluir do Aimbot")
local dropAimbotExcluidos = abaAimbot:CriarDropdown("Excluir Jogadores", ListarJogadoresTodos(),
    function(label, selMap)
        Estado.aimbotExcluidos = {}
        if selMap then for nome, ativo in pairs(selMap) do if ativo then Estado.aimbotExcluidos[nome]=true end end end
        local cnt = 0; for _ in pairs(Estado.aimbotExcluidos) do cnt=cnt+1 end
        hub:Notificar("Aimbot",cnt.." excluido(s)","aviso",2)
    end,
    { multi=true, search=true, maxVisible=6, placeholder="Nenhum excluido" }
)
abaAimbot:CriarBotao("Atualizar Lista", function()
    dropAimbotExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("Aimbot","Lista atualizada!","info",2)
end, { icone="🔄" })

-- ─────────────────────────────────────────────────────────────
-- ABA: TELEPORTE
-- ─────────────────────────────────────────────────────────────
local abaTeleporte = hub:CriarAba("Teleporte", "📍")

abaTeleporte:CriarSecao("Locais Conhecidos")
local nomesLocais = {}
for _, loc in ipairs(LOCAIS) do table.insert(nomesLocais, loc.nome) end
abaTeleporte:CriarDropdown("Teleportar para Local", nomesLocais, function(selecionado)
    for _, loc in ipairs(LOCAIS) do
        if loc.nome == selecionado then
            local myHRP = GetHRP()
            if myHRP then
                myHRP.CFrame = CFrame.new(loc.pos)
                hub:Notificar("Teleporte","Indo para: "..loc.nome,"sucesso",2)
            else hub:Notificar("Teleporte","Personagem nao disponivel.","erro",2) end
            break
        end
    end
end, { placeholder="Escolher local..." })

abaTeleporte:CriarSecao("Teleporte para Jogador")
local dropTeleporte = abaTeleporte:CriarDropdown("Teleportar para Jogador", ListarJogadoresTeleporte(),
    function(entrada)
        local nome = ExtrairUsername(entrada)
        local alvo = Players:FindFirstChild(nome)
        if not alvo then hub:Notificar("Teleporte","Jogador nao encontrado.","erro",2); return end
        local myHRP = GetHRP(); local alvHRP = GetHRP(alvo)
        if myHRP and alvHRP then
            myHRP.CFrame = alvHRP.CFrame * CFrame.new(0,0,-2)
            hub:Notificar("Teleporte","Teleportado para "..nome,"sucesso",2)
        else hub:Notificar("Teleporte","Personagem nao disponivel.","erro",2) end
    end,
    { placeholder="Escolher jogador..." }
)
abaTeleporte:CriarBotao("Atualizar Jogadores", function()
    dropTeleporte:AtualizarOpcoes(ListarJogadoresTeleporte())
    hub:Notificar("Teleporte","Lista atualizada!","info",2)
end, { icone="🔄" })

-- ─────────────────────────────────────────────────────────────
-- ABA: RADAR
-- ─────────────────────────────────────────────────────────────
local abaRadar = hub:CriarAba("Radar", "📡")
abaRadar:CriarSecao("Controle")
abaRadar:CriarTexto("Arraste pela barra para mover. ⊿ para redimensionar.")
abaRadar:CriarToggle("Radar Ativo", Estado.radarAtivo, function(v)
    Estado.radarAtivo = v
    if v then CriarRadar(); hub:Notificar("Radar","Radar ativado!","sucesso",2)
    else RemoverRadar(); hub:Notificar("Radar","Radar desativado","info",2) end
end)
abaRadar:CriarSecao("Ajustes")
abaRadar:CriarSlider("Zoom", 1, 30, math.floor(Estado.radarZoom*100), function(v)
    Estado.radarZoom = v/100
end, { unidade="%" })
abaRadar:CriarSlider("Tamanho", 120, 450, Estado.radarTamanho, function(v)
    Estado.radarTamanho = v
    if Estado.radarAtivo then CriarRadar() end
end, { unidade="px" })
abaRadar:CriarBotao("Resetar Posicao", function()
    Estado.radarPosX=nil; Estado.radarPosY=nil
    if Estado.radarAtivo then CriarRadar(); hub:Notificar("Radar","Posicao resetada!","info",2) end
end, { icone="📍" })

-- ─────────────────────────────────────────────────────────────
-- ABA: MISC
-- ─────────────────────────────────────────────────────────────
local abaMisc = hub:CriarAba("Misc", "🔧")

abaMisc:CriarSecao("Chat Spy")
abaMisc:CriarTexto("Captura e exibe mensagens de todos do servidor.\nFiltros por time, timestamps e contador inclusos.")
abaMisc:CriarToggle("Chat Spy", Estado.chatSpyAtivo, function(v)
    Estado.chatSpyAtivo = v
    if v then IniciarChatSpy(); hub:Notificar("Chat Spy","Ativado!","sucesso",2)
    else PararChatSpy(); hub:Notificar("Chat Spy","Desativado","info",2) end
end)
abaMisc:CriarBotao("Resetar Posicao Chat", function()
    Estado.chatSpyPosX=nil; Estado.chatSpyPosY=nil
    if Estado.chatSpyAtivo then PararChatSpy(); IniciarChatSpy(); hub:Notificar("Chat Spy","Posicao resetada!","info",2) end
end, { icone="📍" })

abaMisc:CriarSecao("Informacoes ao Vivo")
local lblPing = abaMisc:CriarTexto("🔴 Ping: carregando...")
local lblTime = abaMisc:CriarTexto("🏷️ Time: carregando...")
local lblPlrs = abaMisc:CriarTexto("👥 Jogadores: carregando...")
local lblFPS  = abaMisc:CriarTexto("⚡ FPS: carregando...")

local _ultimoPing = -1; local _ultimoTime = ""; local _ultimoPlrs = -1

RunService.RenderStepped:Connect(function()
    local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    if math.abs(ping - _ultimoPing) >= 5 then
        _ultimoPing = ping
        local ico = ping < 80 and "🟢" or ping < 150 and "🟡" or "🔴"
        if lblPing and lblPing.AtualizarTexto then lblPing:AtualizarTexto(ico.." Ping: "..ping.."ms") end
    end
    local time = LocalPlayer.Team and LocalPlayer.Team.Name or "Sem time"
    if time ~= _ultimoTime then
        _ultimoTime = time
        if lblTime and lblTime.AtualizarTexto then lblTime:AtualizarTexto("🏷️ Time: "..time) end
        hub:Notificar("Misc","Time mudou: "..time,"aviso",3)
        if Estado.prenderAuto and time ~= "Guards" then
            PararPrenderAuto()
            hub:Notificar("Auto Prender","Desativado (saiu de Guards)","erro",3)
        end
    end
    local plrs = #Players:GetPlayers()
    if plrs ~= _ultimoPlrs then
        _ultimoPlrs = plrs
        if lblPlrs and lblPlrs.AtualizarTexto then lblPlrs:AtualizarTexto("👥 Jogadores: "..plrs) end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local t0 = tick(); RunService.RenderStepped:Wait()
        local fps = math.floor(1/(tick()-t0+0.0001))
        if lblFPS and lblFPS.AtualizarTexto then lblFPS:AtualizarTexto("⚡ FPS: "..fps) end
    end
end)

-- ─────────────────────────────────────────────────────────────
-- ABA: CONFIG
-- ─────────────────────────────────────────────────────────────
local abaConfig = hub:CriarAba("Config", "⚙️")
abaConfig:CriarSecao("Aparencia")
hub:CriarDropdownTemas(abaConfig)
abaConfig:CriarSecao("Atalhos de Teclado")
if not UserInputService.TouchEnabled then
    abaConfig:CriarTexto("K = Abrir/Fechar Hub")
    abaConfig:CriarTeclaDeAtalho("Abrir/Fechar Hub", Enum.KeyCode.K, function()
        hub:AlternarVisibilidade()
    end)
else
    abaConfig:CriarTexto("Use o botao flutuante para abrir/fechar o Hub.")
end

-- ══════════════════════════════════════════════════════════════
--  EVENTOS DE JOGADORES
-- ══════════════════════════════════════════════════════════════
Players.PlayerAdded:Connect(function()
    if Estado.hubFechado then return end
    task.wait(0.5)
    dropTeleporte:AtualizarOpcoes(ListarJogadoresTeleporte())
    dropESPJogadores:AtualizarOpcoes(ListarJogadoresTodos())
    dropExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    dropAimbotExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
end)

Players.PlayerRemoving:Connect(function(plr)
    if Estado.hubFechado then return end
    task.wait(0.1)
    dropTeleporte:AtualizarOpcoes(ListarJogadoresTeleporte())
    dropESPJogadores:AtualizarOpcoes(ListarJogadoresTodos())
    dropExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    dropAimbotExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    Estado.espJogadoresSel[plr.Name]  = nil
    Estado.prenderExcluidos[plr.Name] = nil
    Estado.aimbotExcluidos[plr.Name]  = nil
end)

-- ══════════════════════════════════════════════════════════════
--  FECHAR HUB
-- ══════════════════════════════════════════════════════════════
hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP(); PararFly(); PararNoclip()
    PararPrenderAuto(); PararAimbot()
    RemoverRadar(); PararChatSpy()
    _fovCircle:Remove()
end)
