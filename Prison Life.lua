local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

local Estado = {
    -- ESP
    espTodos        = false,
    espCustom       = false,
    espTracers      = true,
    espTracerGross  = 3,
    espTracerTransp = 0.15,
    espBoxes        = true,
    espNomes        = true,
    espDistancia    = true,
    espHP           = true,
    espSkeleton     = false,
    hubFechado      = false,
    espJogadoresSel = {},

    -- Cores
    corInmate   = Color3.fromRGB(255, 140,   0),
    corGuard    = Color3.fromRGB( 50, 130, 255),
    corCriminal = Color3.fromRGB(255,  50,  50),
    corOutro    = Color3.fromRGB(255, 255, 255),

    -- Movimento
    walkspeed        = 16,
    walkspeedAtivo   = false,
    fly              = false,
    voarVel          = 50,

    -- Auto Prender
    prenderAuto      = false,
    prenderExcluidos = {},

    -- Aimbot
    aimbotAtivo      = false,
    aimbotFov        = 120,
    aimbotSmooth     = 0.25,
    aimbotExcluidos  = {},
    aimbotParte      = "Head",
    aimbotSoloVisivel = true,

    -- Radar
    radarAtivo      = false,
    radarAberto     = false,
    radarMinimizado = false,
    radarZoom       = 0.05,
    radarTamanho    = 220,

    -- Chat Spy
    chatSpyAtivo = false,

    -- Hub
    hubAberto = true,
}

local _consESP  = {}
local _espDados = {}

-- ─── Utilitários ───────────────────────────────────────────────────────────────

local function LimparConexoes(lista)
    for _, c in pairs(lista) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    table.clear(lista)
end

local function GetChar()
    return LocalPlayer.Character
end
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
    local nome = plr.Team.Name
    if nome == "Inmates"   then return Estado.corInmate   end
    if nome == "Guards"    then return Estado.corGuard    end
    if nome == "Criminals" then return Estado.corCriminal end
    return Estado.corOutro
end

local function MeuTime()
    return LocalPlayer.Team and LocalPlayer.Team.Name or nil
end

local function AplicarWalkSpeed()
    local hum = GetHum()
    if hum then
        hum.WalkSpeed = Estado.walkspeedAtivo and Estado.walkspeed or 16
    end
end

-- ─── ESP MELHORADO ─────────────────────────────────────────────────────────────

local function EspAtivo()
    return Estado.espTodos or Estado.espCustom
end

local function DeveMostrarESP(plr)
    if Estado.espTodos then return true end
    if Estado.espCustom then
        return Estado.espJogadoresSel[plr.Name] == true
    end
    return false
end

local function RemoverEntradaESP(nome)
    local d = _espDados[nome]
    if not d then return end
    if d.hl  and d.hl.Parent  then d.hl:Destroy()  end
    if d.gui and d.gui.Parent then d.gui:Destroy() end
    if d.line       then pcall(function() d.line:Remove() end) end
    if d.boxTop     then pcall(function() d.boxTop:Remove() end) end
    if d.boxBottom  then pcall(function() d.boxBottom:Remove() end) end
    if d.boxLeft    then pcall(function() d.boxLeft:Remove() end) end
    if d.boxRight   then pcall(function() d.boxRight:Remove() end) end
    if d.hpBar      then pcall(function() d.hpBar:Remove() end) end
    if d.hpBarBg    then pcall(function() d.hpBarBg:Remove() end) end
    if d.lblNome2D  then pcall(function() d.lblNome2D:Remove() end) end
    if d.lblDist2D  then pcall(function() d.lblDist2D:Remove() end) end
    -- skeleton
    if d.skeleton then
        for _, ln in pairs(d.skeleton) do
            pcall(function() ln:Remove() end)
        end
    end
    _espDados[nome] = nil
end

local SKELETON_JOINTS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function CriarDrawingLine(cor, espessura, transp)
    local l = Drawing.new("Line")
    l.Visible      = false
    l.Color        = cor
    l.Thickness    = espessura or 1
    l.Transparency = transp or 0
    return l
end

local function CriarDrawingText(cor, tamanho)
    local t = Drawing.new("Text")
    t.Visible    = false
    t.Color      = cor
    t.Size       = tamanho or 13
    t.Font       = Drawing.Fonts.UI
    t.Outline    = true
    t.OutlineColor = Color3.new(0,0,0)
    t.Center     = true
    return t
end

local function CriarEntradaESP(plr)
    RemoverEntradaESP(plr.Name)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cor = CorDoTime(plr)

    -- Highlight (fill)
    local hl = Instance.new("Highlight")
    hl.FillColor           = cor
    hl.OutlineColor        = cor
    hl.FillTransparency    = 0.55
    hl.OutlineTransparency = 0.1
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = char
    hl.Parent              = char

    -- Billboard GUI (nome + info)
    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true
    gui.Size        = UDim2.new(0, 160, 0, 20)
    gui.StudsOffset = Vector3.new(0, 3.2, 0)
    gui.Adornee     = hrp
    gui.Parent      = hrp

    local lblNome = Instance.new("TextLabel")
    lblNome.Size                   = UDim2.new(1,0,1,0)
    lblNome.BackgroundTransparency = 1
    lblNome.Text                   = plr.DisplayName
    lblNome.TextColor3             = cor
    lblNome.Font                   = Enum.Font.GothamBold
    lblNome.TextSize               = 13
    lblNome.TextXAlignment         = Enum.TextXAlignment.Center
    lblNome.TextStrokeTransparency = 0.4
    lblNome.TextStrokeColor3       = Color3.new(0,0,0)
    lblNome.Parent                 = gui

    -- Drawing lines: tracer
    local tracer = CriarDrawingLine(cor, Estado.espTracerGross, Estado.espTracerTransp)

    -- Drawing: box 2D (4 linhas)
    local boxT = CriarDrawingLine(cor, 1.5, 0)
    local boxB = CriarDrawingLine(cor, 1.5, 0)
    local boxL = CriarDrawingLine(cor, 1.5, 0)
    local boxR = CriarDrawingLine(cor, 1.5, 0)

    -- Drawing: barra de HP
    local hpBg = CriarDrawingLine(Color3.fromRGB(20,20,20), 4, 0)
    local hpFill = CriarDrawingLine(Color3.fromRGB(60,220,100), 3, 0)

    -- Drawing: nome 2D e distancia
    local nomeTxt = CriarDrawingText(cor, 12)
    local distTxt = CriarDrawingText(Color3.fromRGB(200,200,200), 11)

    -- Skeleton lines
    local skeleton = {}
    for _ = 1, #SKELETON_JOINTS do
        table.insert(skeleton, CriarDrawingLine(cor, 1, 0.2))
    end

    _espDados[plr.Name] = {
        plr       = plr,
        hl        = hl,
        gui       = gui,
        lblNome   = lblNome,
        line      = tracer,
        boxTop    = boxT,
        boxBottom = boxB,
        boxLeft   = boxL,
        boxRight  = boxR,
        hpBar     = hpFill,
        hpBarBg   = hpBg,
        lblNome2D = nomeTxt,
        lblDist2D = distTxt,
        skeleton  = skeleton,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do
        RemoverEntradaESP(nome)
    end
end

local function AtualizarCoresTime(nomeTime)
    for _, d in pairs(_espDados) do
        if not d.plr then continue end
        local tn = d.plr.Team and d.plr.Team.Name
        if tn ~= nomeTime then continue end
        local cor = CorDoTime(d.plr)
        if d.hl and d.hl.Parent then
            d.hl.FillColor    = cor
            d.hl.OutlineColor = cor
        end
        if d.line      then d.line.Color      = cor end
        if d.boxTop    then d.boxTop.Color    = cor end
        if d.boxBottom then d.boxBottom.Color = cor end
        if d.boxLeft   then d.boxLeft.Color   = cor end
        if d.boxRight  then d.boxRight.Color  = cor end
        if d.lblNome   and d.lblNome.Parent then d.lblNome.TextColor3 = cor end
        if d.lblNome2D then d.lblNome2D.Color = cor end
        for _, s in pairs(d.skeleton or {}) do s.Color = cor end
    end
end

local function AtualizarCoresOutros()
    for _, d in pairs(_espDados) do
        if not d.plr then continue end
        local tn = d.plr.Team and d.plr.Team.Name
        if tn == "Inmates" or tn == "Guards" or tn == "Criminals" then continue end
        local cor = Estado.corOutro
        if d.hl and d.hl.Parent then
            d.hl.FillColor    = cor
            d.hl.OutlineColor = cor
        end
        if d.line      then d.line.Color      = cor end
        if d.boxTop    then d.boxTop.Color    = cor end
        if d.boxBottom then d.boxBottom.Color = cor end
        if d.boxLeft   then d.boxLeft.Color   = cor end
        if d.boxRight  then d.boxRight.Color  = cor end
        if d.lblNome   and d.lblNome.Parent then d.lblNome.TextColor3 = cor end
        if d.lblNome2D then d.lblNome2D.Color = cor end
        for _, s in pairs(d.skeleton or {}) do s.Color = cor end
    end
end

-- calcula bounding box 2D de um personagem
local function GetBoundingBox2D(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local visible = false
    local partes = {"Head","UpperTorso","LowerTorso","LeftHand","RightHand","LeftFoot","RightFoot"}
    for _, nome in ipairs(partes) do
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
    -- adiciona padding
    local pad = 4
    return {
        minX = minX - pad,
        minY = minY - pad,
        maxX = maxX + pad,
        maxY = maxY + pad,
        w    = (maxX - minX) + pad*2,
        h    = (maxY - minY) + pad*2,
    }
end

local function IniciarESP()
    LimparConexoes(_consESP)
    LimparTodoESP()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            CriarEntradaESP(plr)
        end
    end

    table.insert(_consESP, Players.PlayerAdded:Connect(function(plr)
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.6)
            if Estado.hubFechado or not EspAtivo() then return end
            CriarEntradaESP(plr)
        end))
        task.wait(0.6)
        if Estado.hubFechado or not EspAtivo() then return end
        if plr.Character then CriarEntradaESP(plr) end
    end))

    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(_consESP, plr.CharacterAdded:Connect(function()
                task.wait(0.6)
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
        if myHRP then
            local sp, onSc, depth = WorldToViewport(myHRP.Position - Vector3.new(0,2,0))
            tracerOrigem = (onSc and depth > 0) and sp or nil
        end
        if not tracerOrigem then
            tracerOrigem = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end

        for _, d in pairs(_espDados) do
            local plr = d.plr
            if not plr or not plr.Character then
                -- esconde tudo
                if d.line      then d.line.Visible      = false end
                if d.boxTop    then d.boxTop.Visible    = false end
                if d.boxBottom then d.boxBottom.Visible = false end
                if d.boxLeft   then d.boxLeft.Visible   = false end
                if d.boxRight  then d.boxRight.Visible  = false end
                if d.hpBar     then d.hpBar.Visible     = false end
                if d.hpBarBg   then d.hpBarBg.Visible   = false end
                if d.lblNome2D then d.lblNome2D.Visible  = false end
                if d.lblDist2D then d.lblDist2D.Visible  = false end
                for _, s in pairs(d.skeleton or {}) do s.Visible = false end
                continue
            end

            local char = plr.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            local deveVer = EspAtivo() and DeveMostrarESP(plr)
            local cor     = CorDoTime(plr)

            -- Highlight
            if d.hl and d.hl.Parent then
                d.hl.Enabled      = deveVer
                d.hl.FillColor    = cor
                d.hl.OutlineColor = cor
            end
            -- BillboardGui nome
            if d.gui and d.gui.Parent then
                d.gui.Enabled = deveVer and Estado.espNomes
            end
            if d.lblNome and d.lblNome.Parent then
                d.lblNome.TextColor3 = cor
                d.lblNome.Text       = plr.DisplayName
            end

            if not deveVer then
                if d.line      then d.line.Visible      = false end
                if d.boxTop    then d.boxTop.Visible    = false end
                if d.boxBottom then d.boxBottom.Visible = false end
                if d.boxLeft   then d.boxLeft.Visible   = false end
                if d.boxRight  then d.boxRight.Visible  = false end
                if d.hpBar     then d.hpBar.Visible     = false end
                if d.hpBarBg   then d.hpBarBg.Visible   = false end
                if d.lblNome2D then d.lblNome2D.Visible  = false end
                if d.lblDist2D then d.lblDist2D.Visible  = false end
                for _, s in pairs(d.skeleton or {}) do s.Visible = false end
                continue
            end

            local dist  = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
            local hp    = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local pct   = maxHp > 0 and math.clamp(hp / maxHp, 0, 1) or 0

            local barCor = pct > 0.6 and Color3.fromRGB(60,220,100)
                        or pct > 0.3 and Color3.fromRGB(255,190,40)
                        or              Color3.fromRGB(220,55,55)

            -- Bounding Box 2D
            local bb = GetBoundingBox2D(char)
            local spHRP, onSc, depth = WorldToViewport(hrp.Position)

            if bb and onSc and depth > 0 then
                local x1,y1,x2,y2 = bb.minX, bb.minY, bb.maxX, bb.maxY

                -- Box
                if Estado.espBoxes then
                    -- topo
                    d.boxTop.From    = Vector2.new(x1, y1)
                    d.boxTop.To      = Vector2.new(x2, y1)
                    d.boxTop.Color   = cor
                    d.boxTop.Visible = true
                    -- bottom
                    d.boxBottom.From    = Vector2.new(x1, y2)
                    d.boxBottom.To      = Vector2.new(x2, y2)
                    d.boxBottom.Color   = cor
                    d.boxBottom.Visible = true
                    -- left
                    d.boxLeft.From    = Vector2.new(x1, y1)
                    d.boxLeft.To      = Vector2.new(x1, y2)
                    d.boxLeft.Color   = cor
                    d.boxLeft.Visible = true
                    -- right
                    d.boxRight.From    = Vector2.new(x2, y1)
                    d.boxRight.To      = Vector2.new(x2, y2)
                    d.boxRight.Color   = cor
                    d.boxRight.Visible = true
                else
                    d.boxTop.Visible    = false
                    d.boxBottom.Visible = false
                    d.boxLeft.Visible   = false
                    d.boxRight.Visible  = false
                end

                -- HP Bar (esquerda da box)
                if Estado.espHP then
                    local barH = bb.h
                    local barX = x1 - 6
                    local barY1 = y1
                    local barY2 = y1 + barH

                    d.hpBarBg.From      = Vector2.new(barX, barY1)
                    d.hpBarBg.To        = Vector2.new(barX, barY2)
                    d.hpBarBg.Color     = Color3.fromRGB(20,20,20)
                    d.hpBarBg.Thickness = 4
                    d.hpBarBg.Visible   = true

                    local fillY2 = y1 + barH * pct
                    d.hpBar.From      = Vector2.new(barX, barY2) -- de baixo pra cima
                    d.hpBar.To        = Vector2.new(barX, barY2 - barH * pct)
                    d.hpBar.Color     = barCor
                    d.hpBar.Thickness = 3
                    d.hpBar.Visible   = true
                else
                    d.hpBar.Visible   = false
                    d.hpBarBg.Visible = false
                end

                -- Nome 2D (acima da box)
                if Estado.espNomes then
                    d.lblNome2D.Position = Vector2.new((x1+x2)/2, y1 - 16)
                    d.lblNome2D.Text     = plr.DisplayName
                    d.lblNome2D.Color    = cor
                    d.lblNome2D.Visible  = true
                else
                    d.lblNome2D.Visible = false
                end

                -- Distancia 2D (abaixo da box)
                if Estado.espDistancia then
                    local spd = hum.MoveDirection.Magnitude > 0.1 and "▶ correndo" or "◼ parado"
                    d.lblDist2D.Position = Vector2.new((x1+x2)/2, y2 + 4)
                    d.lblDist2D.Text     = dist .. "m  " .. hp .. "hp  " .. spd
                    d.lblDist2D.Color    = Color3.fromRGB(200,200,200)
                    d.lblDist2D.Size     = 11
                    d.lblDist2D.Visible  = true
                else
                    d.lblDist2D.Visible = false
                end
            else
                d.boxTop.Visible    = false
                d.boxBottom.Visible = false
                d.boxLeft.Visible   = false
                d.boxRight.Visible  = false
                d.hpBar.Visible     = false
                d.hpBarBg.Visible   = false
                d.lblNome2D.Visible = false
                d.lblDist2D.Visible = false
            end

            -- Skeleton
            if Estado.espSkeleton then
                for i, pair in ipairs(SKELETON_JOINTS) do
                    local pA = char:FindFirstChild(pair[1])
                    local pB = char:FindFirstChild(pair[2])
                    local sk = d.skeleton[i]
                    if pA and pB and sk then
                        local spA, okA, dA = WorldToViewport(pA.Position)
                        local spB, okB, dB = WorldToViewport(pB.Position)
                        if okA and okB and dA > 0 and dB > 0 then
                            sk.From      = spA
                            sk.To        = spB
                            sk.Color     = cor
                            sk.Thickness = 1
                            sk.Visible   = true
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

            -- Tracer
            if d.line then
                local sp2, onSc2, depth2 = WorldToViewport(hrp.Position - Vector3.new(0,2.5,0))
                if Estado.espTracers and onSc2 and depth2 > 0 then
                    d.line.From         = tracerOrigem
                    d.line.To           = sp2
                    d.line.Thickness    = Estado.espTracerGross
                    d.line.Transparency = Estado.espTracerTransp
                    d.line.Color        = cor
                    d.line.Visible      = true
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
    if EspAtivo() then
        PararESP()
        IniciarESP()
    else
        PararESP()
    end
end

-- ─── Fly ───────────────────────────────────────────────────────────────────────

local virtualKeys = {
    W = false, A = false, S = false, D = false,
    Space = false, Shift = false,
}

local function IsKeyDown(keyCode)
    if UserInputService:IsKeyDown(keyCode) then return true end
    if keyCode == Enum.KeyCode.W         then return virtualKeys.W     end
    if keyCode == Enum.KeyCode.A         then return virtualKeys.A     end
    if keyCode == Enum.KeyCode.S         then return virtualKeys.S     end
    if keyCode == Enum.KeyCode.D         then return virtualKeys.D     end
    if keyCode == Enum.KeyCode.Space     then return virtualKeys.Space end
    if keyCode == Enum.KeyCode.LeftShift then return virtualKeys.Shift end
    return false
end

local _flyMobileGui = nil

local function RemoverBotoesMobile()
    if _flyMobileGui and _flyMobileGui.Parent then
        _flyMobileGui:Destroy()
        _flyMobileGui = nil
    end
    for k in pairs(virtualKeys) do virtualKeys[k] = false end
end

local function CriarBotoesMobile()
    RemoverBotoesMobile()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name           = "FlyMobileControls"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = playerGui
    _flyMobileGui      = gui

    local BTN_SIZE = 64
    local ALPHA    = 0.35

    local function criarBotao(parent, label, posX, posY, key)
        local btn = Instance.new("TextButton")
        btn.Size                   = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
        btn.Position               = UDim2.new(0, posX, 1, posY)
        btn.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
        btn.BackgroundTransparency = ALPHA
        btn.BorderSizePixel        = 0
        btn.Text                   = label
        btn.TextColor3             = Color3.new(1,1,1)
        btn.Font                   = Enum.Font.GothamBold
        btn.TextSize               = 20
        btn.AutoButtonColor        = false
        btn.Parent                 = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent       = btn
        local stroke = Instance.new("UIStroke")
        stroke.Color        = Color3.fromRGB(255, 80, 80)
        stroke.Thickness    = 1.5
        stroke.Transparency = 0.4
        stroke.Parent       = btn
        local function setActive(on)
            virtualKeys[key]           = on
            btn.BackgroundTransparency = on and 0.05 or ALPHA
            stroke.Transparency        = on and 0    or 0.4
        end
        btn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                setActive(true)
            end
        end)
        btn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                setActive(false)
            end
        end)
        return btn
    end

    local pad   = 12
    local bS    = BTN_SIZE
    local row1Y = -(bS + pad + bS + pad + 8)
    local row2Y = -(bS + pad + 8)
    local leftX = pad

    criarBotao(gui, "^",  leftX + bS + pad,         row1Y, "W")
    criarBotao(gui, "<",  leftX,                    row2Y, "A")
    criarBotao(gui, "v",  leftX + bS + pad,         row2Y, "S")
    criarBotao(gui, ">",  leftX + (bS + pad) * 2,  row2Y, "D")

    local vp     = Camera.ViewportSize
    local rightX = vp.X - bS - pad - 70
    criarBotao(gui, "+", rightX, row1Y, "Space")
    criarBotao(gui, "-", rightX, row2Y, "Shift")
end

local _flyHB

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
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate    = true
        end
    end
    Estado.fly = false
end

local function IniciarFly()
    PararFly()
    Estado.fly = true
    if UserInputService.TouchEnabled then CriarBotoesMobile() end

    local char = GetChar()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Estado.fly = false; return end

    hum.AutoRotate = false

    local bv    = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P        = 9e4
    bv.Parent   = hrp

    local bg      = Instance.new("BodyGyro")
    bg.MaxTorque  = Vector3.new(1e5, 1e5, 1e5)
    bg.P          = 9e4
    bg.D          = 1e3
    bg.CFrame     = CFrame.new(Vector3.zero, Camera.CFrame.LookVector)
    bg.Parent     = hrp

    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end
        local hrp2 = GetHRP()
        if not hrp2 or not bv.Parent or not bg.Parent then PararFly(); return end

        local cam = Camera.CFrame
        local dir = Vector3.zero
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

-- ─── Aimbot ────────────────────────────────────────────────────────────────────

local _aimbotHB = nil

local function TemLinhaDaVisao(origem, destino)
    local direcao = (destino - origem)
    local dist    = direcao.Magnitude
    if dist < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = GetChar()
    if char then
        params.FilterDescendantsInstances = { char }
    end
    local resultado = workspace:Raycast(origem, direcao.Unit * dist, params)
    if not resultado then return true end
    local hit = resultado.Instance
    local hitChar = hit and (hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") and hit.Parent)
                        or (hit and hit:FindFirstChildOfClass("Humanoid") and hit)
    return hitChar ~= nil
end

local function EhAlvoAimbot(plr)
    if not plr or not plr.Team then return false end
    if Estado.aimbotExcluidos[plr.Name] then return false end
    local meuTime = MeuTime()
    if not meuTime then return false end
    local time = plr.Team.Name
    if meuTime == "Inmates" then
        return time == "Guards" or time == "Criminals"
    elseif meuTime == "Guards" then
        return time == "Inmates" or time == "Criminals"
    elseif meuTime == "Criminals" then
        return time == "Inmates" or time == "Guards"
    end
    return false
end

-- FOV circle drawing
local _fovCircle = Drawing.new("Circle")
_fovCircle.Visible      = false
_fovCircle.Filled       = false
_fovCircle.Color        = Color3.fromRGB(255, 255, 255)
_fovCircle.Thickness    = 1.5
_fovCircle.Transparency = 0.5
_fovCircle.NumSides     = 80

local function PararAimbot()
    if _aimbotHB then _aimbotHB:Disconnect(); _aimbotHB = nil end
    _fovCircle.Visible = false
end

local function IniciarAimbot()
    PararAimbot()
    local centro = Camera.ViewportSize / 2

    _aimbotHB = RunService.RenderStepped:Connect(function()
        if not Estado.aimbotAtivo or Estado.hubFechado then
            _fovCircle.Visible = false
            return
        end

        centro = Camera.ViewportSize / 2
        _fovCircle.Position = centro
        _fovCircle.Radius   = Estado.aimbotFov
        _fovCircle.Visible  = true

        local melhorAlvo = nil
        local melhorDist = math.huge
        local myHRP      = GetHRP()

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if not EhAlvoAimbot(plr) then continue end
            local char = plr.Character
            if not char then continue end
            local parte = char:FindFirstChild(Estado.aimbotParte) or char:FindFirstChild("HumanoidRootPart")
            if not parte then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            local sp, onScreen, depth = WorldToViewport(parte.Position)
            if not onScreen or depth <= 0 then continue end

            local distTela = (sp - centro).Magnitude
            if distTela > Estado.aimbotFov then continue end

            if Estado.aimbotSoloVisivel and myHRP then
                if not TemLinhaDaVisao(myHRP.Position, parte.Position) then continue end
            end

            if distTela < melhorDist then
                melhorDist  = distTela
                melhorAlvo  = parte
            end
        end

        if melhorAlvo then
            local vetor = (melhorAlvo.Position - Camera.CFrame.Position).Unit
            local novaCF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + vetor)
            Camera.CFrame = Camera.CFrame:Lerp(novaCF, Estado.aimbotSmooth)
        end
    end)
end

-- ─── RADAR ─────────────────────────────────────────────────────────────────────

local _radarGui         = nil
local _radarFrame       = nil
local _radarCanvas      = nil
local _radarTitleBar    = nil
local _radarMiniFrame   = nil -- frame minimizado (so barra)
local _radarPontosGUI   = {}
local _radarConn        = nil

local function RemoverRadar()
    if _radarConn then _radarConn:Disconnect(); _radarConn = nil end
    if _radarGui and _radarGui.Parent then _radarGui:Destroy(); _radarGui = nil end
    _radarFrame     = nil
    _radarCanvas    = nil
    _radarTitleBar  = nil
    _radarMiniFrame = nil
    _radarPontosGUI = {}
end

local function CriarRadar()
    RemoverRadar()

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name           = "RadarGUI"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = playerGui
    _radarGui = gui

    local SZ   = Estado.radarTamanho
    local barH = 28

    -- Frame principal
    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, SZ, 0, SZ + barH)
    frame.Position          = UDim2.new(1, -SZ - 16, 1, -SZ - barH - 16)
    frame.BackgroundColor3  = Color3.fromRGB(8, 8, 14)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel   = 0
    frame.ClipsDescendants  = true
    frame.Parent            = gui
    _radarFrame = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent       = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color        = Color3.fromRGB(60, 180, 255)
    stroke.Thickness    = 1.2
    stroke.Transparency = 0.4
    stroke.Parent       = frame

    -- Barra de titulo
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, barH)
    titleBar.Position         = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 60, 110)
    titleBar.BackgroundTransparency = 0.15
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = frame
    _radarTitleBar = titleBar

    local tc2 = Instance.new("UICorner")
    tc2.CornerRadius = UDim.new(0,10)
    tc2.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1,-50,1,0)
    titleLbl.Position               = UDim2.new(0,10,0,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = "📡  RADAR"
    titleLbl.TextColor3             = Color3.fromRGB(140, 200, 255)
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextSize               = 13
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.Parent                 = titleBar

    -- Canvas do radar (circulo)
    local canvas = Instance.new("Frame")
    canvas.Size              = UDim2.new(1, -8, 1, -barH - 8)
    canvas.Position          = UDim2.new(0, 4, 0, barH + 4)
    canvas.BackgroundColor3  = Color3.fromRGB(4, 14, 28)
    canvas.BackgroundTransparency = 0.05
    canvas.BorderSizePixel   = 0
    canvas.ClipsDescendants  = true
    canvas.Parent            = frame
    _radarCanvas = canvas

    local canvasCorner = Instance.new("UICorner")
    canvasCorner.CornerRadius = UDim.new(0, 8)
    canvasCorner.Parent       = canvas

    -- Cruzes de referencia
    local function CriarLinha(parent, sizeX, sizeY, posX, posY, transp)
        local l = Instance.new("Frame")
        l.Size                   = UDim2.new(sizeX[1], sizeX[2], sizeY[1], sizeY[2])
        l.Position               = UDim2.new(posX[1], posX[2], posY[1], posY[2])
        l.BackgroundColor3       = Color3.fromRGB(60, 180, 255)
        l.BackgroundTransparency = transp or 0.8
        l.BorderSizePixel        = 0
        l.Parent                 = parent
    end
    -- horizontal
    CriarLinha(canvas, {1,0},{0,1},{0,0},{0.5,-0.5}, 0.7)
    -- vertical
    CriarLinha(canvas, {0,1},{1,0},{0.5,-0.5},{0,0}, 0.7)

    -- Circulo de referencia (CSS via UICorner trick)
    local circulo = Instance.new("Frame")
    circulo.Size              = UDim2.new(0.7,0,0.7,0)
    circulo.Position          = UDim2.new(0.15,0,0.15,0)
    circulo.BackgroundTransparency = 1
    circulo.BorderSizePixel   = 0
    circulo.Parent            = canvas
    local circ2 = Instance.new("UICorner")
    circ2.CornerRadius = UDim.new(1,0)
    circ2.Parent = circulo
    local circStroke = Instance.new("UIStroke")
    circStroke.Color        = Color3.fromRGB(60, 180, 255)
    circStroke.Thickness    = 1
    circStroke.Transparency = 0.7
    circStroke.Parent       = circulo

    -- Ponto do jogador local (centro)
    local meuponto = Instance.new("Frame")
    meuponto.Size              = UDim2.new(0, 8, 0, 8)
    meuponto.Position          = UDim2.new(0.5,-4,0.5,-4)
    meuponto.BackgroundColor3  = Color3.fromRGB(255, 255, 100)
    meuponto.BorderSizePixel   = 0
    meuponto.Parent            = canvas
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(1,0)
    mc.Parent = meuponto

    -- Label Norte
    local norteL = Instance.new("TextLabel")
    norteL.Size                   = UDim2.new(0,20,0,14)
    norteL.Position               = UDim2.new(0.5,-10,0,2)
    norteL.BackgroundTransparency = 1
    norteL.Text                   = "N"
    norteL.TextColor3             = Color3.fromRGB(140,200,255)
    norteL.Font                   = Enum.Font.GothamBold
    norteL.TextSize               = 10
    norteL.Parent                 = canvas

    -- Frame minimizado (barra no canto)
    local miniFrame = Instance.new("Frame")
    miniFrame.Size             = UDim2.new(0, SZ, 0, barH)
    miniFrame.Position         = UDim2.new(1, -SZ - 16, 1, -barH - 16)
    miniFrame.BackgroundColor3 = Color3.fromRGB(20, 60, 110)
    miniFrame.BackgroundTransparency = 0.15
    miniFrame.BorderSizePixel  = 0
    miniFrame.Visible          = false
    miniFrame.Parent           = gui
    _radarMiniFrame = miniFrame

    local miniC = Instance.new("UICorner")
    miniC.CornerRadius = UDim.new(0,10)
    miniC.Parent = miniFrame

    local miniStroke = Instance.new("UIStroke")
    miniStroke.Color     = Color3.fromRGB(60,180,255)
    miniStroke.Thickness = 1.2
    miniStroke.Transparency = 0.4
    miniStroke.Parent    = miniFrame

    local miniLbl = Instance.new("TextLabel")
    miniLbl.Size                   = UDim2.new(1,-8,1,0)
    miniLbl.Position               = UDim2.new(0,8,0,0)
    miniLbl.BackgroundTransparency = 1
    miniLbl.Text                   = "📡  RADAR  [M para expandir]"
    miniLbl.TextColor3             = Color3.fromRGB(140, 200, 255)
    miniLbl.Font                   = Enum.Font.GothamBold
    miniLbl.TextSize               = 12
    miniLbl.TextXAlignment         = Enum.TextXAlignment.Left
    miniLbl.Parent                 = miniFrame

    -- Atualizar radar
    _radarConn = RunService.RenderStepped:Connect(function()
        if not Estado.radarAtivo then return end

        local myHRP = GetHRP()
        if not myHRP then return end

        local myCF   = myHRP.CFrame
        local camY   = Camera.CFrame.LookVector
        local angulo = math.atan2(camY.X, camY.Z)

        local zoom  = Estado.radarZoom
        local cSZ   = canvas.AbsoluteSize
        local cX    = cSZ.X / 2
        local cY    = cSZ.Y / 2
        local raioMax = math.min(cX, cY)

        -- Limpa pontos velhos
        for nome, ponto in pairs(_radarPontosGUI) do
            local plr = Players:FindFirstChild(nome)
            if not plr or not plr.Character then
                ponto:Destroy()
                _radarPontosGUI[nome] = nil
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local char = plr.Character
            local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp2 then
                if _radarPontosGUI[plr.Name] then
                    _radarPontosGUI[plr.Name].Visible = false
                end
                continue
            end

            local relativo = myHRP.CFrame:ToObjectSpace(hrp2.CFrame)
            local rx = relativo.Position.X
            local rz = relativo.Position.Z

            -- rotacionar pelo angulo da camera
            local cos = math.cos(-angulo)
            local sin = math.sin(-angulo)
            local px  = rx * cos - rz * sin
            local pz  = rx * sin + rz * cos

            local dx  = px * zoom
            local dz  = pz * zoom
            -- clamp ao raio
            local mag = math.sqrt(dx*dx + dz*dz)
            if mag > raioMax - 6 then
                local f = (raioMax - 6) / mag
                dx = dx * f
                dz = dz * f
            end

            local screenX = cX + dx
            local screenY = cY + dz

            local cor = CorDoTime(plr)

            -- cria ou reutiliza ponto
            local ponto = _radarPontosGUI[plr.Name]
            if not ponto or not ponto.Parent then
                ponto = Instance.new("Frame")
                ponto.Size             = UDim2.new(0,8,0,8)
                ponto.BackgroundColor3 = cor
                ponto.BorderSizePixel  = 0
                local pc = Instance.new("UICorner")
                pc.CornerRadius = UDim.new(1,0)
                pc.Parent = ponto
                ponto.Parent = canvas
                _radarPontosGUI[plr.Name] = ponto
            end

            ponto.BackgroundColor3 = cor
            ponto.Position = UDim2.new(0, math.floor(screenX - 4), 0, math.floor(screenY - 4))
            ponto.Visible  = true

            -- tooltip com nome no hover (via tag)
            ponto.Name = plr.Name
        end
    end)

    -- Atualizar visibilidade minimizado/expandido
    local function AtualizarVisibilidadeRadar()
        if not Estado.radarAtivo then
            _radarFrame.Visible    = false
            _radarMiniFrame.Visible = false
        elseif Estado.radarMinimizado then
            _radarFrame.Visible     = false
            _radarMiniFrame.Visible = true
        else
            _radarFrame.Visible     = true
            _radarMiniFrame.Visible = false
        end
    end

    Estado._atualizarRadarVis = AtualizarVisibilidadeRadar
    AtualizarVisibilidadeRadar()
end

local function AtualizarVisibilidadeRadar()
    if Estado._atualizarRadarVis then Estado._atualizarRadarVis() end
end

-- ─── CHAT SPY ──────────────────────────────────────────────────────────────────

local _chatSpyGui   = nil
local _chatSpyFrame = nil
local _chatSpyScroll = nil
local _chatSpyConn  = nil
local _chatSpyMsgs  = {}

local COR_CHAT = {
    sistema  = Color3.fromRGB(140, 200, 255),
    local_   = Color3.fromRGB(100, 255, 140),
    outro    = Color3.fromRGB(220, 220, 220),
    titulo   = Color3.fromRGB(255, 200, 80),
}

local function AdicionarMensagemChatSpy(remetente, texto, cor)
    if not _chatSpyScroll then return end
    table.insert(_chatSpyMsgs, {r=remetente, t=texto, c=cor})
    if #_chatSpyMsgs > 100 then table.remove(_chatSpyMsgs, 1) end

    local linha = Instance.new("Frame")
    linha.Size              = UDim2.new(1,-8,0,0)
    linha.Position          = UDim2.new(0,4,0,0)
    linha.BackgroundTransparency = 1
    linha.AutomaticSize     = Enum.AutomaticSize.Y
    linha.Parent            = _chatSpyScroll

    local txt = Instance.new("TextLabel")
    txt.Size             = UDim2.new(1,0,0,0)
    txt.BackgroundTransparency = 1
    txt.AutomaticSize    = Enum.AutomaticSize.Y
    txt.Text             = "[" .. remetente .. "]: " .. texto
    txt.TextColor3       = cor
    txt.Font             = Enum.Font.Gotham
    txt.TextSize         = 11
    txt.TextXAlignment   = Enum.TextXAlignment.Left
    txt.TextWrapped      = true
    txt.TextYAlignment   = Enum.TextYAlignment.Top
    txt.Parent           = linha

    -- auto scroll
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
    gui.Name           = "ChatSpyGUI"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = playerGui
    _chatSpyGui = gui

    local frame = Instance.new("Frame")
    frame.Size              = UDim2.new(0, 360, 0, 220)
    frame.Position          = UDim2.new(0, 16, 1, -240)
    frame.BackgroundColor3  = Color3.fromRGB(6, 8, 14)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel   = 0
    frame.Parent            = gui
    _chatSpyFrame = frame

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0,10)
    fc.Parent = frame

    local fs = Instance.new("UIStroke")
    fs.Color = Color3.fromRGB(255,200,80)
    fs.Thickness = 1.2
    fs.Transparency = 0.4
    fs.Parent = frame

    -- Titulo
    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1,0,0,28)
    titleBar.BackgroundColor3 = Color3.fromRGB(60,40,0)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = frame

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0,10)
    tc.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size                   = UDim2.new(1,-8,1,0)
    titleLbl.Position               = UDim2.new(0,8,0,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                   = "💬  CHAT SPY"
    titleLbl.TextColor3             = COR_CHAT.titulo
    titleLbl.Font                   = Enum.Font.GothamBold
    titleLbl.TextSize               = 13
    titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
    titleLbl.Parent                 = titleBar

    -- Scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                  = UDim2.new(1,-4,1,-32)
    scroll.Position              = UDim2.new(0,2,0,30)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel       = 0
    scroll.ScrollBarThickness    = 4
    scroll.ScrollBarImageColor3  = Color3.fromRGB(255,200,80)
    scroll.CanvasSize            = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    scroll.Parent                = frame
    _chatSpyScroll = scroll

    local layout = Instance.new("UIListLayout")
    layout.Padding           = UDim.new(0,3)
    layout.FillDirection     = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.Parent            = scroll

    AdicionarMensagemChatSpy("SISTEMA", "Chat Spy ativado!", COR_CHAT.sistema)
end

local function RemoverChatSpyGUI()
    if _chatSpyConn then _chatSpyConn:Disconnect(); _chatSpyConn = nil end
    if _chatSpyGui and _chatSpyGui.Parent then _chatSpyGui:Destroy() end
    _chatSpyGui    = nil
    _chatSpyFrame  = nil
    _chatSpyScroll = nil
end

local function IniciarChatSpy()
    CriarChatSpyGUI()

    -- Tenta capturar via TextChatService
    local ok, err = pcall(function()
        local channel = TextChatService:FindFirstChildOfClass("TextChannel")
            or TextChatService:WaitForChild("TextChannels", 2)
        if channel then
            _chatSpyConn = TextChatService.MessageReceived:Connect(function(msg)
                local autor = msg.TextSource and msg.TextSource.Name or "?"
                local plr = Players:FindFirstChild(autor)
                local nome = plr and plr.Name or autor
                local cor = (nome == LocalPlayer.Name) and COR_CHAT.local_ or COR_CHAT.outro
                AdicionarMensagemChatSpy(nome, msg.Text or "", cor)
            end)
        end
    end)

    -- Fallback: escutar via Players.PlayerChatted (legado)
    if not ok or not _chatSpyConn then
        local conns = {}
        local function EscutarJogador(plr)
            local c = plr.Chatted:Connect(function(msg)
                if not Estado.chatSpyAtivo then return end
                local cor = (plr == LocalPlayer) and COR_CHAT.local_ or COR_CHAT.outro
                AdicionarMensagemChatSpy(plr.Name, msg, cor)
            end)
            table.insert(conns, c)
        end
        for _, plr in ipairs(Players:GetPlayers()) do EscutarJogador(plr) end
        Players.PlayerAdded:Connect(EscutarJogador)
        _chatSpyConn = {
            Disconnect = function()
                for _, c in ipairs(conns) do c:Disconnect() end
            end
        }
    end
end

local function PararChatSpy()
    if _chatSpyConn then
        pcall(function() _chatSpyConn:Disconnect() end)
        _chatSpyConn = nil
    end
    RemoverChatSpyGUI()
end

-- ─── MISC (Ping, Time, Contadores) ────────────────────────────────────────────
-- (Essas informações são exibidas na aba Misc com atualização automática)

local _miscStats = {
    ping    = 0,
    time    = "?",
    players = 0,
    fps     = 0,
}

-- Atualiza estatísticas continuamente
RunService.RenderStepped:Connect(function()
    _miscStats.ping    = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    _miscStats.time    = LocalPlayer.Team and LocalPlayer.Team.Name or "Sem time"
    _miscStats.players = #Players:GetPlayers()
    _miscStats.fps     = math.floor(1 / RunService.RenderStepped:Wait())
end)

-- ─── Spawn / CharacterAdded ────────────────────────────────────────────────────

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly then IniciarFly() end
    AplicarWalkSpeed()
end)

-- ─── Hub ───────────────────────────────────────────────────────────────────────

local site = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub.lua",
    true
))()

local hub = site.novo("Reboco", "Escuro")

-- ─── Auto Prender ──────────────────────────────────────────────────────────────

local _prenderThread = nil
local _arrestRemote  = nil

local function GetRemote()
    if _arrestRemote and _arrestRemote.Parent then return _arrestRemote end
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    _arrestRemote = r and r:FindFirstChild("ArrestPlayer") or nil
    return _arrestRemote
end

local function GetCriminosos()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if plr.Team and plr.Team.Name == "Criminals" then
            if not Estado.prenderExcluidos[plr.Name] then
                table.insert(lista, plr)
            end
        end
    end
    return lista
end

local function EhCriminal(plr)
    return plr and plr.Team and plr.Team.Name == "Criminals"
end

local function RespawnarPersonagem()
    local hum = GetHum()
    if hum then hum.Health = 0 end
    local renasceu = false
    local conn
    conn = LocalPlayer.CharacterAdded:Connect(function()
        renasceu = true
        conn:Disconnect()
    end)
    local inicio = tick()
    while not renasceu and (tick() - inicio) < 5 do
        task.wait(0.05)
    end
    task.wait(0.5)
end

local function TentarPrender(alvo)
    if not alvo or not alvo.Parent then return false end
    if not EhCriminal(alvo) then return false end
    if Estado.prenderExcluidos[alvo.Name] then return false end
    local remote = GetRemote()
    if not remote then return false end

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
    while (tick() - inicio) < 2 do
        if not Estado.prenderAuto or Estado.hubFechado then break end
        if not alvo or not alvo.Parent then break end
        if Estado.prenderExcluidos[alvo.Name] then break end
        local myHRP2  = GetHRP()
        local alvHRP2 = GetHRP(alvo)
        if myHRP2 and alvHRP2 then
            myHRP2.CFrame = alvHRP2.CFrame * CFrame.new(0, 0, -1)
        end
        xpcall(function()
            remote:InvokeServer(alvo, 1)
        end, function() end)
        task.wait(0)
    end
    return true
end

local function ExecutarCooldown()
    if not Estado.prenderAuto or Estado.hubFechado then return end
    hub:Notificar("Auto Prender", "Renascendo...", "sucesso", 2)
    RespawnarPersonagem()
    task.wait(0.2)
end

local function LoopPrender()
    local semCrimNotificado = false
    while Estado.prenderAuto and not Estado.hubFechado do
        local criminosos = GetCriminosos()
        if #criminosos == 0 then
            if not semCrimNotificado then
                semCrimNotificado = true
                hub:Notificar("Auto Prender", "Nenhum Criminal disponivel!", "info", 4)
            end
            task.wait(0.5)
            continue
        end
        semCrimNotificado = false
        for _, alvo in ipairs(criminosos) do
            if not Estado.prenderAuto or Estado.hubFechado then break end
            if not alvo or not alvo.Parent then continue end
            if not EhCriminal(alvo) then continue end
            if Estado.prenderExcluidos[alvo.Name] then continue end
            hub:Notificar("Auto Prender", "Indo ate: " .. alvo.Name, "aviso", 2)
            local ok = TentarPrender(alvo)
            if ok then
                ExecutarCooldown()
            elseif not alvo or not alvo.Parent then
                hub:Notificar("Auto Prender", "Jogador saiu do jogo.", "info", 2)
            else
                hub:Notificar("Auto Prender", alvo.Name .. " nao disponivel.", "info", 2)
            end
            task.wait(0)
        end
        task.wait(0)
    end
end

local function IniciarPrenderAuto()
    Estado.prenderAuto = true
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end
    _prenderThread = task.spawn(LoopPrender)
end

local function PararPrenderAuto()
    Estado.prenderAuto = false
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end
end

-- ─── Helpers dropdown ──────────────────────────────────────────────────────────

local function ListarJogadoresTodos()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(lista, plr.Name)
        end
    end
    if #lista == 0 then lista = {"(nenhum)"} end
    return lista
end

local function ListarJogadoresTeleporte()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local entrada = plr.DisplayName ~= plr.Name
                and plr.DisplayName .. " (" .. plr.Name .. ")"
                or  plr.Name
            table.insert(lista, entrada)
        end
    end
    if #lista == 0 then lista = {"(nenhum jogador)"} end
    return lista
end

local function ExtrairUsername(entrada)
    local username = entrada:match("%((.-)%)$")
    return username or entrada
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA ESP
-- ═══════════════════════════════════════════════════════════════════════════════

local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Modos de ESP")

abaESP:CriarToggle("ESP Todos os Jogadores", Estado.espTodos, function(v)
    Estado.espTodos = v
    RecarregarESP()
    if v then
        hub:Notificar("ESP", "ESP Todos ativado!", "sucesso", 2)
    else
        if not Estado.espCustom then
            hub:Notificar("ESP", "ESP desativado", "info", 2)
        end
    end
end)

abaESP:CriarToggle("ESP Customizado (Dropdown)", Estado.espCustom, function(v)
    Estado.espCustom = v
    RecarregarESP()
end)

abaESP:CriarSecao("Elementos do ESP")

abaESP:CriarToggle("Highlight (preenchimento)", true, function(v)
    for _, d in pairs(_espDados) do
        if d.hl and d.hl.Parent then d.hl.FillTransparency = v and 0.55 or 1 end
    end
end)

abaESP:CriarToggle("Box 2D", Estado.espBoxes, function(v)
    Estado.espBoxes = v
    if not v then
        for _, d in pairs(_espDados) do
            if d.boxTop    then d.boxTop.Visible    = false end
            if d.boxBottom then d.boxBottom.Visible = false end
            if d.boxLeft   then d.boxLeft.Visible   = false end
            if d.boxRight  then d.boxRight.Visible  = false end
        end
    end
end)

abaESP:CriarToggle("Nomes", Estado.espNomes, function(v)
    Estado.espNomes = v
    for _, d in pairs(_espDados) do
        if d.lblNome2D then d.lblNome2D.Visible = false end
    end
end)

abaESP:CriarToggle("HP Bar", Estado.espHP, function(v)
    Estado.espHP = v
    if not v then
        for _, d in pairs(_espDados) do
            if d.hpBar   then d.hpBar.Visible   = false end
            if d.hpBarBg then d.hpBarBg.Visible = false end
        end
    end
end)

abaESP:CriarToggle("Distancia + Status", Estado.espDistancia, function(v)
    Estado.espDistancia = v
    if not v then
        for _, d in pairs(_espDados) do
            if d.lblDist2D then d.lblDist2D.Visible = false end
        end
    end
end)

abaESP:CriarToggle("Skeleton (ossos)", Estado.espSkeleton, function(v)
    Estado.espSkeleton = v
    if not v then
        for _, d in pairs(_espDados) do
            for _, s in pairs(d.skeleton or {}) do s.Visible = false end
        end
    end
end)

abaESP:CriarSecao("Filtro de Jogadores (ESP Customizado)")

local dropESPJogadores = abaESP:CriarDropdown(
    "ESP Especifico",
    ListarJogadoresTodos(),
    function(label, selMap)
        Estado.espJogadoresSel = {}
        if selMap then
            for nome, ativo in pairs(selMap) do
                if ativo then Estado.espJogadoresSel[nome] = true end
            end
        end
    end,
    { multi = true, search = true, maxVisible = 6, placeholder = "Selecionar jogadores..." }
)

abaESP:CriarBotao("Atualizar Lista", function()
    dropESPJogadores:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("ESP", "Lista atualizada!", "info", 2)
end, { icone = "🔄" })

abaESP:CriarSecao("Tracers")

abaESP:CriarToggle("Mostrar Tracers", Estado.espTracers, function(v)
    Estado.espTracers = v
    if not v then
        for _, d in pairs(_espDados) do
            if d.line then d.line.Visible = false end
        end
    end
end)

abaESP:CriarSlider("Grossura", 1, 20, Estado.espTracerGross, function(v)
    Estado.espTracerGross = v
    for _, d in pairs(_espDados) do
        if d.line then d.line.Thickness = v end
    end
end, { unidade = "px" })

abaESP:CriarSlider("Transparencia", 0, 90, math.floor(Estado.espTracerTransp * 100), function(v)
    Estado.espTracerTransp = v / 100
    for _, d in pairs(_espDados) do
        if d.line then d.line.Transparency = Estado.espTracerTransp end
    end
end, { unidade = "%" })

abaESP:CriarSecao("Cores por Time")

abaESP:CriarColorPicker("Inmates (laranja)", Estado.corInmate, function(cor)
    Estado.corInmate = cor
    AtualizarCoresTime("Inmates")
end)

abaESP:CriarColorPicker("Guards (azul)", Estado.corGuard, function(cor)
    Estado.corGuard = cor
    AtualizarCoresTime("Guards")
end)

abaESP:CriarColorPicker("Criminals (vermelho)", Estado.corCriminal, function(cor)
    Estado.corCriminal = cor
    AtualizarCoresTime("Criminals")
end)

abaESP:CriarColorPicker("Outros (branco)", Estado.corOutro, function(cor)
    Estado.corOutro = cor
    AtualizarCoresOutros()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA JOGADOR
-- ═══════════════════════════════════════════════════════════════════════════════

local abaJogador = hub:CriarAba("Jogador", "🧍")

abaJogador:CriarSecao("Movimento")

abaJogador:CriarToggle("Velocidade Customizada", Estado.walkspeedAtivo, function(v)
    Estado.walkspeedAtivo = v
    AplicarWalkSpeed()
    if v then
        hub:Notificar("Velocidade", "Ativada! " .. Estado.walkspeed .. " ws", "sucesso", 2)
    else
        hub:Notificar("Velocidade", "Resetada para 16 ws", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Andar", 8, 250, Estado.walkspeed, function(v)
    Estado.walkspeed = v
    if Estado.walkspeedAtivo then AplicarWalkSpeed() end
end, { unidade = " ws" })

abaJogador:CriarSecao("Teleporte")

local dropTeleporte = abaJogador:CriarDropdown(
    "Teleportar para",
    ListarJogadoresTeleporte(),
    function(entrada)
        local nome = ExtrairUsername(entrada)
        local alvo = Players:FindFirstChild(nome)
        if not alvo then
            hub:Notificar("Teleporte", "Jogador nao encontrado.", "erro", 2)
            return
        end
        local myHRP  = GetHRP()
        local alvHRP = GetHRP(alvo)
        if myHRP and alvHRP then
            myHRP.CFrame = alvHRP.CFrame * CFrame.new(0, 0, -2)
            hub:Notificar("Teleporte", "Teleportado para " .. nome, "sucesso", 2)
        else
            hub:Notificar("Teleporte", "Personagem nao disponivel.", "erro", 2)
        end
    end,
    false, true, 6, "Escolher jogador..."
)

abaJogador:CriarSecao("Prender")

abaJogador:CriarTexto("Detecta Criminals, teleporta e prende automaticamente.\nApos prender: respawna rapido e vai pro proximo alvo.")

abaJogador:CriarToggle("Prender Automatico", Estado.prenderAuto, function(v)
    if v then
        IniciarPrenderAuto()
        hub:Notificar("Auto Prender", "Ativado!", "sucesso", 2)
    else
        PararPrenderAuto()
        hub:Notificar("Auto Prender", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSecao("Excluir do Auto Prender")

local dropExcluidos = abaJogador:CriarDropdown(
    "Excluir Jogadores",
    ListarJogadoresTodos(),
    function(label, selMap)
        Estado.prenderExcluidos = {}
        if selMap then
            for nome, ativo in pairs(selMap) do
                if ativo then Estado.prenderExcluidos[nome] = true end
            end
        end
    end,
    { multi = true, search = true, maxVisible = 6, placeholder = "Nenhum excluido" }
)

abaJogador:CriarBotao("Atualizar Listas", function()
    dropExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    dropTeleporte:AtualizarOpcoes(ListarJogadoresTeleporte())
    dropESPJogadores:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("Jogador", "Listas atualizadas!", "info", 2)
end, { icone = "🔄" })

abaJogador:CriarSecao("Voar")

abaJogador:CriarTexto("Mobile: botoes aparecem na tela ao ativar\nPC: W/A/S/D = direcao | Space = subir | Shift = descer")

abaJogador:CriarToggle("Voar", Estado.fly, function(v)
    if v then
        IniciarFly()
        hub:Notificar("Voar", "Ativado!", "sucesso", 2)
    else
        PararFly()
        hub:Notificar("Voar", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Voo", 10, 350, Estado.voarVel, function(v)
    Estado.voarVel = v
end, { unidade = " ws" })

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA AIMBOT
-- ═══════════════════════════════════════════════════════════════════════════════

local abaAimbot = hub:CriarAba("Aimbot", "🎯")

abaAimbot:CriarSecao("Configuracao")

abaAimbot:CriarTexto("Alvo automatico baseado no seu time atual.\nNao mira atraves de paredes.\nFOV = circulo visivel na tela.")

abaAimbot:CriarToggle("Aimbot Ativo", Estado.aimbotAtivo, function(v)
    Estado.aimbotAtivo = v
    if v then
        IniciarAimbot()
        hub:Notificar("Aimbot", "Ativado! Time: " .. (MeuTime() or "?"), "sucesso", 2)
    else
        PararAimbot()
        hub:Notificar("Aimbot", "Desativado", "info", 2)
    end
end)

abaAimbot:CriarToggle("Somente com visao direta", Estado.aimbotSoloVisivel, function(v)
    Estado.aimbotSoloVisivel = v
end)

abaAimbot:CriarSecao("Ajustes")

abaAimbot:CriarSlider("FOV (raio na tela)", 30, 500, Estado.aimbotFov, function(v)
    Estado.aimbotFov = v
end, { unidade = "px" })

abaAimbot:CriarSlider("Suavidade", 1, 100, math.floor(Estado.aimbotSmooth * 100), function(v)
    Estado.aimbotSmooth = v / 100
end, { unidade = "%" })

abaAimbot:CriarDropdown(
    "Parte Alvo",
    { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    function(parte)
        Estado.aimbotParte = parte
        hub:Notificar("Aimbot", "Mirando em: " .. parte, "info", 2)
    end,
    { placeholder = "Head" }
)

abaAimbot:CriarSecao("Excecoes do Aimbot")

local dropAimbotExcluidos = abaAimbot:CriarDropdown(
    "Excluir do Aimbot",
    ListarJogadoresTodos(),
    function(label, selMap)
        Estado.aimbotExcluidos = {}
        if selMap then
            for nome, ativo in pairs(selMap) do
                if ativo then Estado.aimbotExcluidos[nome] = true end
            end
        end
        local cnt = 0
        for _ in pairs(Estado.aimbotExcluidos) do cnt = cnt + 1 end
        hub:Notificar("Aimbot", cnt .. " jogador(es) excluido(s)", "aviso", 2)
    end,
    { multi = true, search = true, maxVisible = 6, placeholder = "Nenhum excluido" }
)

abaAimbot:CriarBotao("Atualizar Lista", function()
    dropAimbotExcluidos:AtualizarOpcoes(ListarJogadoresTodos())
    hub:Notificar("Aimbot", "Lista atualizada!", "info", 2)
end, { icone = "🔄" })

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA RADAR
-- ═══════════════════════════════════════════════════════════════════════════════

local abaRadar = hub:CriarAba("Radar", "📡")

abaRadar:CriarSecao("Controle")

abaRadar:CriarTexto("Tecla M: alterna entre expandido e minimizado quando o radar estiver ativo.")

abaRadar:CriarToggle("Radar Ativo", Estado.radarAtivo, function(v)
    Estado.radarAtivo = v
    if v then
        Estado.radarMinimizado = false
        CriarRadar()
        hub:Notificar("Radar", "Radar ativado! [M] para minimizar", "sucesso", 3)
    else
        RemoverRadar()
        hub:Notificar("Radar", "Radar desativado", "info", 2)
    end
end)

abaRadar:CriarSecao("Ajustes")

abaRadar:CriarSlider("Zoom do Radar", 1, 30, math.floor(Estado.radarZoom * 100), function(v)
    Estado.radarZoom = v / 100
end, { unidade = "%" })

abaRadar:CriarSlider("Tamanho", 120, 350, Estado.radarTamanho, function(v)
    Estado.radarTamanho = v
    if Estado.radarAtivo then
        CriarRadar() -- recria com novo tamanho
    end
end, { unidade = "px" })

-- Keybind M para radar
local kbRadar = abaRadar:CriarTeclaDeAtalho("Radar (expandir/minimizar)", Enum.KeyCode.M, function()
    if not Estado.radarAtivo then
        -- Ativa o radar se nao estava ativo
        Estado.radarAtivo      = true
        Estado.radarMinimizado = false
        CriarRadar()
        hub:Notificar("Radar", "Radar ativado!", "sucesso", 2)
    else
        -- Alterna minimizado/expandido
        Estado.radarMinimizado = not Estado.radarMinimizado
        AtualizarVisibilidadeRadar()
        if Estado.radarMinimizado then
            hub:Notificar("Radar", "Radar minimizado", "info", 1)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA MISC
-- ═══════════════════════════════════════════════════════════════════════════════

local abaMisc = hub:CriarAba("Misc", "🔧")

abaMisc:CriarSecao("Chat Spy")

abaMisc:CriarTexto("Exibe todos os chats do servidor em uma janela separada.")

abaMisc:CriarToggle("Chat Spy", Estado.chatSpyAtivo, function(v)
    Estado.chatSpyAtivo = v
    if v then
        IniciarChatSpy()
        hub:Notificar("Chat Spy", "Ativado!", "sucesso", 2)
    else
        PararChatSpy()
        hub:Notificar("Chat Spy", "Desativado", "info", 2)
    end
end)

abaMisc:CriarSecao("Informacoes ao Vivo")

-- Labels de stats que são atualizados continuamente
local lblPing  = abaMisc:CriarTexto("🔴 Ping: carregando...")
local lblTime  = abaMisc:CriarTexto("🏷️ Time: carregando...")
local lblPlrs  = abaMisc:CriarTexto("👥 Jogadores: carregando...")
local lblFPS   = abaMisc:CriarTexto("⚡ FPS: carregando...")

-- Atualiza os labels automaticamente
local _ultimoPing  = -1
local _ultimoTime  = ""
local _ultimoPlrs  = -1

RunService.RenderStepped:Connect(function()
    -- Ping: atualiza so se mudar significativamente (+/- 5ms)
    local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    if math.abs(ping - _ultimoPing) >= 5 then
        _ultimoPing = ping
        local corPing = ping < 80 and "verde" or ping < 150 and "amarelo" or "vermelho"
        local icoPing = ping < 80 and "🟢" or ping < 150 and "🟡" or "🔴"
        if lblPing and lblPing.AtualizarTexto then
            lblPing:AtualizarTexto(icoPing .. " Ping: " .. ping .. "ms")
        end
    end

    -- Time: atualiza so se mudar
    local time = LocalPlayer.Team and LocalPlayer.Team.Name or "Sem time"
    if time ~= _ultimoTime then
        _ultimoTime = time
        if lblTime and lblTime.AtualizarTexto then
            lblTime:AtualizarTexto("🏷️ Time: " .. time)
        end
        hub:Notificar("Misc", "Time mudou: " .. time, "aviso", 3)
    end

    -- Jogadores: atualiza so se mudar
    local plrs = #Players:GetPlayers()
    if plrs ~= _ultimoPlrs then
        _ultimoPlrs = plrs
        if lblPlrs and lblPlrs.AtualizarTexto then
            lblPlrs:AtualizarTexto("👥 Jogadores: " .. plrs)
        end
    end
end)

-- FPS: atualiza a cada 1s
task.spawn(function()
    while true do
        task.wait(1)
        local t0 = tick()
        RunService.RenderStepped:Wait()
        local fps = math.floor(1 / (tick() - t0 + 0.0001))
        if lblFPS and lblFPS.AtualizarTexto then
            lblFPS:AtualizarTexto("⚡ FPS: " .. fps)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ABA CONFIG
-- ═══════════════════════════════════════════════════════════════════════════════

local abaConfig = hub:CriarAba("Config", "⚙️")

abaConfig:CriarSecao("Aparencia")
hub:CriarDropdownTemas(abaConfig)

abaConfig:CriarSecao("Atalhos de Teclado")

abaConfig:CriarTexto("K = Abrir/Fechar Hub\nM = Radar (expandir/minimizar)")

-- Keybind principal: K = abrir/fechar hub
local kbHub = abaConfig:CriarTeclaDeAtalho("Abrir/Fechar Hub", Enum.KeyCode.K, function()
    hub:AlternarVisibilidade()
end)

-- ─── Atualizar listas quando jogadores entram/saem ────────────────────────────

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

-- ─── Fechar hub ───────────────────────────────────────────────────────────────

hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP()
    PararFly()
    PararPrenderAuto()
    PararAimbot()
    RemoverRadar()
    PararChatSpy()
    _fovCircle:Remove()
end)
