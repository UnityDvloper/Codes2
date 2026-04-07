local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

local Estado = {
    -- ESP
    espTodos        = false,
    espCustom       = false,
    espTracers      = true,
    espTracerGross  = 4,
    espTracerTransp = 0.1,
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

-- ─── ESP ───────────────────────────────────────────────────────────────────────

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
    if d.line then pcall(function() d.line:Remove() end) end
    _espDados[nome] = nil
end

local function CriarEntradaESP(plr)
    RemoverEntradaESP(plr.Name)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cor = CorDoTime(plr)

    local hl = Instance.new("Highlight")
    hl.FillColor           = cor
    hl.OutlineColor        = Color3.new(1,1,1)
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = char
    hl.Parent              = char

    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true
    gui.Size        = UDim2.new(0, 140, 0, 68)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.Adornee     = hrp
    gui.Parent      = hrp

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(1,0,1,0)
    bg.BackgroundColor3       = Color3.fromRGB(8,8,12)
    bg.BackgroundTransparency = 0.42
    bg.BorderSizePixel        = 0
    bg.Parent                 = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent       = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color        = cor
    stroke.Thickness    = 1
    stroke.Transparency = 0.25
    stroke.Parent       = bg

    local apelido   = plr.DisplayName
    local nomeTexto = plr.Name
    if apelido ~= nomeTexto then
        nomeTexto = apelido .. " (" .. plr.Name .. ")"
    end

    local lblNome = Instance.new("TextLabel")
    lblNome.Size                   = UDim2.new(1,-8,0,14)
    lblNome.Position               = UDim2.new(0,4,0,2)
    lblNome.BackgroundTransparency = 1
    lblNome.Text                   = nomeTexto
    lblNome.TextColor3             = cor
    lblNome.Font                   = Enum.Font.GothamBold
    lblNome.TextSize               = 10
    lblNome.TextXAlignment         = Enum.TextXAlignment.Center
    lblNome.TextScaled             = false
    lblNome.TextWrapped            = true
    lblNome.Parent                 = bg

    local teamName = (plr.Team and plr.Team.Name) or "Sem Time"
    local lblTime = Instance.new("TextLabel")
    lblTime.Size                   = UDim2.new(1,-8,0,10)
    lblTime.Position               = UDim2.new(0,4,0,17)
    lblTime.BackgroundTransparency = 1
    lblTime.Text                   = "[" .. teamName .. "]"
    lblTime.TextColor3             = cor
    lblTime.Font                   = Enum.Font.GothamBold
    lblTime.TextSize               = 9
    lblTime.TextXAlignment         = Enum.TextXAlignment.Center
    lblTime.Parent                 = bg

    local baraBg = Instance.new("Frame")
    baraBg.Size             = UDim2.new(1,-8,0,4)
    baraBg.Position         = UDim2.new(0,4,0,31)
    baraBg.BackgroundColor3 = Color3.fromRGB(30,30,30)
    baraBg.BorderSizePixel  = 0
    baraBg.Parent           = bg
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(1,0)
    c1.Parent       = baraBg

    local baraFill = Instance.new("Frame")
    baraFill.Size             = UDim2.new(1,0,1,0)
    baraFill.BackgroundColor3 = Color3.fromRGB(60,220,100)
    baraFill.BorderSizePixel  = 0
    baraFill.Parent           = baraBg
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(1,0)
    c2.Parent       = baraFill

    local lblInfo = Instance.new("TextLabel")
    lblInfo.Size                   = UDim2.new(1,-8,0,11)
    lblInfo.Position               = UDim2.new(0,4,0,38)
    lblInfo.BackgroundTransparency = 1
    lblInfo.Text                   = "HP: ? | Dist: ?"
    lblInfo.TextColor3             = Color3.fromRGB(200,200,200)
    lblInfo.Font                   = Enum.Font.Gotham
    lblInfo.TextSize               = 9
    lblInfo.TextXAlignment         = Enum.TextXAlignment.Center
    lblInfo.Parent                 = bg

    local lblDist = Instance.new("TextLabel")
    lblDist.Size                   = UDim2.new(1,-8,0,10)
    lblDist.Position               = UDim2.new(0,4,0,51)
    lblDist.BackgroundTransparency = 1
    lblDist.Text                   = ""
    lblDist.TextColor3             = Color3.fromRGB(160,210,255)
    lblDist.Font                   = Enum.Font.Gotham
    lblDist.TextSize               = 8
    lblDist.TextXAlignment         = Enum.TextXAlignment.Center
    lblDist.Parent                 = bg

    local line        = Drawing.new("Line")
    line.Visible      = false
    line.Thickness    = Estado.espTracerGross
    line.Color        = cor
    line.Transparency = Estado.espTracerTransp

    _espDados[plr.Name] = {
        plr      = plr,
        hl       = hl,
        gui      = gui,
        line     = line,
        stroke   = stroke,
        baraFill = baraFill,
        lblNome  = lblNome,
        lblTime  = lblTime,
        lblInfo  = lblInfo,
        lblDist  = lblDist,
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
        if d.hl     and d.hl.Parent      then d.hl.FillColor        = cor end
        if d.stroke and d.stroke.Parent  then d.stroke.Color        = cor end
        if d.line                         then d.line.Color          = cor end
        if d.lblNome and d.lblNome.Parent then d.lblNome.TextColor3 = cor end
        if d.lblTime and d.lblTime.Parent then d.lblTime.TextColor3 = cor end
    end
end

local function AtualizarCoresOutros()
    for _, d in pairs(_espDados) do
        if not d.plr then continue end
        local tn = d.plr.Team and d.plr.Team.Name
        if tn == "Inmates" or tn == "Guards" or tn == "Criminals" then continue end
        local cor = Estado.corOutro
        if d.hl     and d.hl.Parent      then d.hl.FillColor        = cor end
        if d.stroke and d.stroke.Parent  then d.stroke.Color        = cor end
        if d.line                         then d.line.Color          = cor end
        if d.lblNome and d.lblNome.Parent then d.lblNome.TextColor3 = cor end
        if d.lblTime and d.lblTime.Parent then d.lblTime.TextColor3 = cor end
    end
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
            if not plr or not plr.Character then continue end
            local char = plr.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            local deveVerESP = EspAtivo() and DeveMostrarESP(plr)
            local cor = CorDoTime(plr)

            if d.hl and d.hl.Parent then
                d.hl.Enabled   = deveVerESP
                d.hl.FillColor = cor
            end
            if d.gui    and d.gui.Parent    then d.gui.Enabled       = deveVerESP end
            if d.stroke and d.stroke.Parent then d.stroke.Color      = cor        end
            if d.line                        then d.line.Color        = cor        end
            if d.lblNome and d.lblNome.Parent then d.lblNome.TextColor3 = cor     end
            if d.lblTime and d.lblTime.Parent then
                d.lblTime.TextColor3 = cor
                local tn = (plr.Team and plr.Team.Name) or "Sem Time"
                d.lblTime.Text = "[" .. tn .. "]"
            end

            if not deveVerESP then
                if d.line then d.line.Visible = false end
                continue
            end

            local dist  = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
            local hp    = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local pct   = maxHp > 0 and (hp / maxHp) or 0

            local barCor = pct > 0.6 and Color3.fromRGB(60,220,100)
                        or pct > 0.3 and Color3.fromRGB(255,190,40)
                        or              Color3.fromRGB(220,55,55)

            if d.baraFill and d.baraFill.Parent then
                d.baraFill.Size             = UDim2.new(math.clamp(pct,0,1),0,1,0)
                d.baraFill.BackgroundColor3 = barCor
            end
            if d.lblInfo and d.lblInfo.Parent then
                d.lblInfo.Text = "HP "..hp.."/"..maxHp.."  |  "..dist.."m"
            end
            if d.lblDist and d.lblDist.Parent then
                local spd = hum.MoveDirection.Magnitude > 0.1 and "correndo" or "parado"
                d.lblDist.Text = spd
            end

            if d.line then
                local sp, onScreen, depth = WorldToViewport(hrp.Position - Vector3.new(0,2.5,0))
                if Estado.espTracers and onScreen and depth > 0 then
                    d.line.From         = tracerOrigem
                    d.line.To           = sp
                    d.line.Thickness    = Estado.espTracerGross
                    d.line.Transparency = Estado.espTracerTransp
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

local _aimbotCirculo = Drawing.new("Circle")
_aimbotCirculo.Visible      = false
_aimbotCirculo.Filled       = false
_aimbotCirculo.Color        = Color3.fromRGB(255, 255, 255)
_aimbotCirculo.Thickness    = 1.5
_aimbotCirculo.Transparency = 0.6
_aimbotCirculo.NumSides     = 64

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
    -- verifica se o que foi atingido faz parte de um personagem inimigo
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

local function PararAimbot()
    if _aimbotHB then _aimbotHB:Disconnect(); _aimbotHB = nil end
    _aimbotCirculo.Visible = false
end

local function IniciarAimbot()
    PararAimbot()
    local centro = Camera.ViewportSize / 2

    _aimbotHB = RunService.RenderStepped:Connect(function()
        if not Estado.aimbotAtivo or Estado.hubFechado then
            _aimbotCirculo.Visible = false
            return
        end

        centro = Camera.ViewportSize / 2
        _aimbotCirculo.Position = centro
        _aimbotCirculo.Radius   = Estado.aimbotFov
        _aimbotCirculo.Visible  = true

        local melhorAlvo    = nil
        local melhorDist    = math.huge
        local myHRP         = GetHRP()

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

            -- verifica linha de visão (sem paredes)
            if myHRP then
                if not TemLinhaDaVisao(myHRP.Position, parte.Position) then continue end
            end

            if distTela < melhorDist then
                melhorDist  = distTela
                melhorAlvo  = parte
            end
        end

        if melhorAlvo then
            local alvoPosicao = melhorAlvo.Position
            local vetor       = (alvoPosicao - Camera.CFrame.Position).Unit
            local novaCF      = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + vetor)
            Camera.CFrame     = Camera.CFrame:Lerp(novaCF, Estado.aimbotSmooth)
        end
    end)
end

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
        local hrp = GetHRP(alvo)
        if hrp and hum and hum.Health > 0 then break end
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
    if v then
        hub:Notificar("ESP", "ESP Customizado ativado!", "sucesso", 2)
    else
        if not Estado.espTodos then
            hub:Notificar("ESP", "ESP Customizado desativado", "info", 2)
        end
    end
end)

abaESP:CriarSecao("Filtro de Jogadores (ESP Customizado)")

abaESP:CriarTexto("Selecione jogadores para o ESP Customizado.")

local dropESPJogadores = abaESP:CriarDropdown(
    "ESP Especifico",
    ListarJogadoresTodos(),
    function(label, selMap)
        Estado.espJogadoresSel = {}
        if selMap then
            for nome, ativo in pairs(selMap) do
                if ativo then
                    Estado.espJogadoresSel[nome] = true
                end
            end
        end
    end,
    {
        multi       = true,
        search      = true,
        maxVisible  = 6,
        placeholder = "Selecionar jogadores...",
    }
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

abaJogador:CriarTexto("Jogadores selecionados aqui NAO serao presos pelo Auto Prender.")

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
        local cnt = 0
        for _ in pairs(Estado.prenderExcluidos) do cnt = cnt + 1 end
        if cnt > 0 then
            hub:Notificar("Auto Prender", cnt .. " jogador(es) excluido(s)", "aviso", 2)
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

abaAimbot:CriarTexto("Jogadores selecionados NAO serao mirados pelo Aimbot.")

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
-- ABA CONFIG
-- ═══════════════════════════════════════════════════════════════════════════════

local abaConfig = hub:CriarAba("Config", "⚙️")
abaConfig:CriarSecao("Aparencia")
hub:CriarDropdownTemas(abaConfig)

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
    Estado.espJogadoresSel[plr.Name]   = nil
    Estado.prenderExcluidos[plr.Name]  = nil
    Estado.aimbotExcluidos[plr.Name]   = nil
    local temSel = false
    for _ in pairs(Estado.espJogadoresSel) do temSel = true; break end
end)

-- ─── Fechar hub ───────────────────────────────────────────────────────────────

hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP()
    PararFly()
    PararPrenderAuto()
    PararAimbot()
    _aimbotCirculo:Remove()
end)
