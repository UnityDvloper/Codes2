local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ══════════════════════════════════════════════
--  ESTADO
-- ══════════════════════════════════════════════
local Estado = {
    esp             = false,
    espTracers      = true,
    espTracerGross  = 4,
    espTracerTransp = 0.1,
    corESP          = Color3.fromRGB(255, 50, 50),
    hubFechado      = false,

    walkspeed       = 16,
    fly             = false,
    voarVel         = 50,
    noclip          = false,

    prenderAuto     = false,
}

local _consESP  = {}
local _espDados = {}

local function LimparConexoes(lista)
    for _, c in pairs(lista) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    table.clear(lista)
end

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
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

-- ══════════════════════════════════════════════
--  CONTROLES MOBILE PARA O FLY
-- ══════════════════════════════════════════════
local virtualKeys = {
    W = false, A = false, S = false, D = false,
    Space = false, Shift = false,
}

local function IsKeyDown(keyCode)
    if UserInputService:IsKeyDown(keyCode) then return true end
    if keyCode == Enum.KeyCode.W          then return virtualKeys.W     end
    if keyCode == Enum.KeyCode.A          then return virtualKeys.A     end
    if keyCode == Enum.KeyCode.S          then return virtualKeys.S     end
    if keyCode == Enum.KeyCode.D          then return virtualKeys.D     end
    if keyCode == Enum.KeyCode.Space      then return virtualKeys.Space end
    if keyCode == Enum.KeyCode.LeftShift  then return virtualKeys.Shift end
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
    gui.Name            = "FlyMobileControls"
    gui.ResetOnSpawn    = false
    gui.IgnoreGuiInset  = true
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.Parent          = playerGui
    _flyMobileGui       = gui

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

    criarBotao(gui, "^",  leftX + bS + pad,   row1Y, "W")
    criarBotao(gui, "<",  leftX,              row2Y, "A")
    criarBotao(gui, "v",  leftX + bS + pad,   row2Y, "S")
    criarBotao(gui, ">",  leftX + (bS+pad)*2, row2Y, "D")

    local vp     = Camera.ViewportSize
    local rightX = vp.X - bS - pad
    criarBotao(gui, "+", rightX, row1Y, "Space")
    criarBotao(gui, "-", rightX, row2Y, "Shift")
end

-- ══════════════════════════════════════════════
--  ESP — CRIAR / REMOVER
-- ══════════════════════════════════════════════
local function RemoverEntradaESP(nome)
    local d = _espDados[nome]
    if not d then return end
    if d.hl  and d.hl.Parent  then d.hl:Destroy() end
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

    local cor = Estado.corESP

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
    gui.Size        = UDim2.new(0, 130, 0, 56)
    gui.StudsOffset = Vector3.new(0, 3.2, 0)
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

    local lblNome = Instance.new("TextLabel")
    lblNome.Size                   = UDim2.new(1,-8,0,16)
    lblNome.Position               = UDim2.new(0,4,0,4)
    lblNome.BackgroundTransparency = 1
    lblNome.Text                   = plr.Name
    lblNome.TextColor3             = cor
    lblNome.Font                   = Enum.Font.GothamBold
    lblNome.TextSize               = 12
    lblNome.TextXAlignment         = Enum.TextXAlignment.Center
    lblNome.Parent                 = bg

    local baraBg = Instance.new("Frame")
    baraBg.Size             = UDim2.new(1,-8,0,4)
    baraBg.Position         = UDim2.new(0,4,0,24)
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
    lblInfo.Size                   = UDim2.new(1,-8,0,12)
    lblInfo.Position               = UDim2.new(0,4,0,32)
    lblInfo.BackgroundTransparency = 1
    lblInfo.Text                   = "HP: ? | Dist: ?"
    lblInfo.TextColor3             = Color3.fromRGB(200,200,200)
    lblInfo.Font                   = Enum.Font.Gotham
    lblInfo.TextSize               = 10
    lblInfo.TextXAlignment         = Enum.TextXAlignment.Center
    lblInfo.Parent                 = bg

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
        lblInfo  = lblInfo,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do
        RemoverEntradaESP(nome)
    end
end

-- ══════════════════════════════════════════════
--  ESP — MOTOR
-- ══════════════════════════════════════════════
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
            if Estado.hubFechado or not Estado.esp then return end
            CriarEntradaESP(plr)
        end))
        task.wait(0.6)
        if Estado.hubFechado or not Estado.esp then return end
        if plr.Character then CriarEntradaESP(plr) end
    end))

    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(_consESP, plr.CharacterAdded:Connect(function()
                task.wait(0.6)
                if Estado.hubFechado or not Estado.esp then return end
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

            if d.hl  and d.hl.Parent  then d.hl.Enabled  = Estado.esp end
            if d.gui and d.gui.Parent then d.gui.Enabled = Estado.esp end

            if not Estado.esp then
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

            if d.line then
                local sp, onScreen, depth = WorldToViewport(hrp.Position - Vector3.new(0,2.5,0))
                if Estado.espTracers and onScreen and depth > 0 then
                    d.line.From         = tracerOrigem
                    d.line.To           = sp
                    d.line.Color        = Estado.corESP
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

-- ══════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════
local _noclipConn

local function IniciarNoclip()
    _noclipConn = RunService.Stepped:Connect(function()
        local char = GetChar()
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function PararNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
    local char = GetChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
end

-- ══════════════════════════════════════════════
--  FLY
-- ══════════════════════════════════════════════
local _flyHB

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB = nil end
    RemoverBotoesMobile()
    local char = GetChar()
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
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

    if UserInputService.TouchEnabled then
        CriarBotoesMobile()
    end

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
        if not hrp2 or not bv.Parent or not bg.Parent then
            PararFly(); return
        end

        local cam = Camera.CFrame
        local dir = Vector3.zero

        if IsKeyDown(Enum.KeyCode.W)         then dir = dir + cam.LookVector      end
        if IsKeyDown(Enum.KeyCode.S)         then dir = dir - cam.LookVector      end
        if IsKeyDown(Enum.KeyCode.A)         then dir = dir - cam.RightVector     end
        if IsKeyDown(Enum.KeyCode.D)         then dir = dir + cam.RightVector     end
        if IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0)  end
        if IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0)  end

        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * Estado.voarVel

        bg.CFrame = CFrame.new(
            Vector3.zero,
            Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
        )
    end)
end

-- reaplica ao respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly    then IniciarFly()   end
    if Estado.noclip then PararNoclip(); IniciarNoclip() end
    local hum = GetHum()
    if hum then hum.WalkSpeed = Estado.walkspeed end
end)

-- ══════════════════════════════════════════════
--  MONTA O HUB  (deve vir ANTES do Prender Auto)
-- ══════════════════════════════════════════════
local site = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub",
    true
))()

local hub = site.novo("ESP Universal", "Escuro", "Lento")

-- ══════════════════════════════════════════════
--  PRENDER AUTOMÁTICO  (definido APÓS o hub)
-- ══════════════════════════════════════════════
local _prenderThread = nil

-- pega o remote uma única vez e reutiliza
local _arrestRemote = nil
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
            table.insert(lista, plr)
        end
    end
    return lista
end

local function EhInmate(plr)  return plr and plr.Team and plr.Team.Name == "Inmates"   end
local function EhCriminal(plr) return plr and plr.Team and plr.Team.Name == "Criminals" end

-- posição salva ao ativar, para restaurar ao desativar/fechar hub
local _posAntes = nil

-- Teleporta o personagem local para um CFrame
local function TeleportarPara(cf)
    local hrp = GetHRP()
    if hrp then hrp.CFrame = cf end
end

-- Acha um ponto distante de todos os jogadores (fuga durante cooldown)
local function AcharPontoDistante()
    local myHRP = GetHRP()
    if not myHRP then return nil end
    local base = myHRP.Position

    -- tenta 12 direções aleatórias a 400+ studs de distância
    local melhor, melhorDist = nil, 0
    for i = 1, 12 do
        local ang = (i / 12) * math.pi * 2
        local candidato = base + Vector3.new(math.cos(ang) * 500, 0, math.sin(ang) * 500)

        -- calcula distância mínima de qualquer jogador nesse ponto
        local distMin = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            local hrp2 = GetHRP(plr)
            if hrp2 then
                local d = (hrp2.Position - candidato).Magnitude
                if d < distMin then distMin = d end
            end
        end

        if distMin > melhorDist then
            melhorDist = distMin
            melhor = candidato
        end
    end

    return melhor and CFrame.new(melhor + Vector3.new(0, 5, 0)) or nil
end

-- Tenta prender o alvo por até 5 segundos — teleporte + arrest a cada frame
local function TentarPrender(alvo)
    if not alvo or not alvo.Parent then return false end
    if not EhCriminal(alvo) then return false end
    local remote = GetRemote()
    if not remote then return false end

    local inicio = tick()
    local preso  = false

    while Estado.prenderAuto and not Estado.hubFechado do
        if not alvo or not alvo.Parent then break end
        if not EhCriminal(alvo) then preso = EhInmate(alvo); break end
        if (tick() - inicio) >= 5 then break end

        -- teleporta colado no alvo a cada frame
        local myHRP  = GetHRP()
        local alvHRP = GetHRP(alvo)
        if myHRP and alvHRP then
            myHRP.CFrame = alvHRP.CFrame * CFrame.new(0, 0, -1)
        end

        -- spamma o arrest a cada frame
        xpcall(function()
            remote:InvokeServer(alvo, 1)
        end, function() end)

        if EhInmate(alvo) then preso = true; break end

        task.wait(0) -- próximo frame, máximo de tentativas
    end

    return preso
end

-- Cooldown após prender: foge para ponto distante, espera 5s, volta pro próximo alvo
local function ExecutarCooldown()
    if not Estado.prenderAuto or Estado.hubFechado then return end

    hub:Notificar("Auto Prender", "Cooldown — fugindo por 5s...", "info", 5)

    -- teleporta para longe
    local pontoFuga = AcharPontoDistante()
    if pontoFuga then
        TeleportarPara(pontoFuga)
    end

    -- espera 5 segundos verificando se foi cancelado
    local inicio = tick()
    while (tick() - inicio) < 5 do
        if not Estado.prenderAuto or Estado.hubFechado then return end
        task.wait(0.1)
    end
end

local function LoopPrender()
    local semCrimNotificado = false
    local primeiroPreso     = false -- controla se já prendeu alguém (cooldown só após 1º preso)

    while Estado.prenderAuto and not Estado.hubFechado do
        local criminosos = GetCriminosos()

        if #criminosos == 0 then
            if not semCrimNotificado then
                semCrimNotificado = true
                hub:Notificar("Auto Prender", "Nenhum Criminoso no server!", "info", 4)
            end
            task.wait(0.5)
            continue
        end

        semCrimNotificado = false

        for _, alvo in ipairs(criminosos) do
            if not Estado.prenderAuto or Estado.hubFechado then break end
            if not alvo or not alvo.Parent then continue end
            if not EhCriminal(alvo) then continue end

            hub:Notificar("Auto Prender", "Prendendo: " .. alvo.Name, "aviso", 2)

            local ok = TentarPrender(alvo)

            if ok then
                hub:Notificar("Auto Prender", alvo.Name .. " foi preso!", "sucesso", 3)
                -- cooldown de 5s com fuga antes de ir pro próximo
                ExecutarCooldown()
            elseif not alvo or not alvo.Parent then
                hub:Notificar("Auto Prender", "Jogador saiu do jogo.", "info", 2)
            elseif EhInmate(alvo) then
                hub:Notificar("Auto Prender", alvo.Name .. " ja e Inmate.", "info", 2)
            else
                hub:Notificar("Auto Prender", "Timeout — proximo alvo.", "aviso", 2)
            end

            task.wait(0)
        end

        task.wait(0)
    end
end

local function IniciarPrenderAuto()
    -- salva posição atual antes de começar
    local myHRP = GetHRP()
    if myHRP then
        _posAntes = myHRP.CFrame
    end

    Estado.prenderAuto = true
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end
    _prenderThread = task.spawn(LoopPrender)
end

local function PararPrenderAuto()
    Estado.prenderAuto = false
    if _prenderThread then task.cancel(_prenderThread); _prenderThread = nil end

    -- volta para onde estava antes
    if _posAntes then
        task.wait(0.05) -- espera um frame pra garantir que o thread parou
        TeleportarPara(_posAntes)
        _posAntes = nil
    end
end

-- ╔══════════════════════════════════════════╗
-- ║  ABA: ESP                                ║
-- ╚══════════════════════════════════════════╝
local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Visibilidade")

abaESP:CriarToggle("ESP Players", Estado.esp, function(v)
    Estado.esp = v
    if v then
        IniciarESP()
        hub:Notificar("ESP", "Ativado!", "sucesso", 2)
    else
        PararESP()
        hub:Notificar("ESP", "Desativado", "info", 2)
    end
end)

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
end)

abaESP:CriarSlider("Transparencia (0=solido)", 0, 90, math.floor(Estado.espTracerTransp * 100), function(v)
    Estado.espTracerTransp = v / 100
    for _, d in pairs(_espDados) do
        if d.line then d.line.Transparency = Estado.espTracerTransp end
    end
end)

abaESP:CriarSecao("Cor")

abaESP:CriarColorPicker("Cor do ESP", Estado.corESP, function(cor)
    Estado.corESP = cor
    for _, d in pairs(_espDados) do
        if d.hl     and d.hl.Parent      then d.hl.FillColor            = cor end
        if d.stroke and d.stroke.Parent  then d.stroke.Color            = cor end
        if d.line                         then d.line.Color              = cor end
        if d.lblNome and d.lblNome.Parent then d.lblNome.TextColor3     = cor end
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: JOGADOR                            ║
-- ╚══════════════════════════════════════════╝
local abaJogador = hub:CriarAba("Jogador", "🧍")

abaJogador:CriarSecao("Movimento")

abaJogador:CriarToggle("Noclip (atravessar paredes)", Estado.noclip, function(v)
    Estado.noclip = v
    if v then
        IniciarNoclip()
        hub:Notificar("Noclip", "Ativado!", "sucesso", 2)
    else
        PararNoclip()
        hub:Notificar("Noclip", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Andar", 8, 250, Estado.walkspeed, function(v)
    Estado.walkspeed = v
    local hum = GetHum()
    if hum then hum.WalkSpeed = v end
end)

abaJogador:CriarSecao("Prender")

abaJogador:CriarTexto("Detecta Criminals, teleporta e prende automaticamente.\nTimeout de 5s por alvo. Fica esperando se nao houver alvos.")

abaJogador:CriarToggle("Prender Automatico", Estado.prenderAuto, function(v)
    if v then
        IniciarPrenderAuto()
        hub:Notificar("Auto Prender", "Ativado!", "sucesso", 2)
    else
        PararPrenderAuto()
        hub:Notificar("Auto Prender", "Desativado", "info", 2)
    end
end)

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
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: CONFIG                             ║
-- ╚══════════════════════════════════════════╝
local abaConfig = hub:CriarAba("Config", "⚙️")
abaConfig:CriarSecao("Aparencia")
hub:CriarDropdownTemas(abaConfig)

hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP()
    PararFly()
    PararNoclip()
    PararPrenderAuto()
end)
