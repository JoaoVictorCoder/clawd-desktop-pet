# Atividades espontaneas do Clawd: jogar, codar, pescar, cafe, ler, construir e bola.
# Carregado pelo clawd.ps1 (usa $S, $BR, $PAT, $PX, $OX, $OY etc. de la).

$BR['E'] = New-Brush 60 60 72      # plastico escuro (controle, notebook)
$BR['H'] = New-Brush 205 210 220   # linha de pesca / vapor / moldura
$BR['Q'] = New-Brush 150 40 50     # telhado escuro
$BR['V'] = New-Brush 50 120 55     # folha escura
$BR['S'] = New-Brush 180 220 255   # vidro

$PAT['steam'] = @('.H', 'H.', '.H')
$EYES['focused'] = $EYES.angry   # cara de concentrado, sem os simbolos de raiva

$PROP = @{
    pad    = @('.EEEEEEEE.', 'EEWEEEEYEE', 'EWWWEEBERE', 'EEWEEEELEE', '.EE....EE.')
    laptop = @('.EEEEEEEEEE.', '.EKKKKKKKKE.', '.EKKKKKKKKE.', '.EEEEEEEEEE.', 'EEEEEEEEEEEE')
    mug    = @('WMMW.', 'WWWWW', 'WWWW.', 'WWWW.')
    book   = @('NNNNNNNNNN', 'NNNYYYYNNN', 'NNNNNNNNNN', 'NNYYYYYYNN', 'NNNNNNNNNN')
    fish   = @('.BBB.B', 'BKBBBB', '.BBB.B')
    boot   = @('MM..', 'MM..', 'MMMM')
}

$S.act = $null; $S.actT = 0; $S.actK = 0; $S.actSit = $false; $S.actWalk = $false; $S.actLook = $null
$S.actExpr = $null; $S.actPhase = ''; $S.actFrame = 0; $S.nextAct = 2000
$S.codeL = @(); $S.catchBoot = $false; $S.buildX = 0; $S.lastKick = 0; $S.lastHouseCry = -9999

$GAMES = 'javaw|minecraft|roblox|valorant|league|fortnite|cs2|csgo|dota|gta|rocketleague|overwatch|genshin|apex|terraria|stardew|hollow'
$CODERS = '^(code|devenv|idea64|idea|pycharm64|pycharm|webstorm64|cursor|sublime_text|notepad\+\+|windowsterminal|powershell|pwsh|cmd|wt)$'
$READERS = 'winword|acrobat|acrord32|sumatrapdf|notion|obsidian|onenote|kindle'

function Get-FgProc { ([string]($S.fgInfo -split '\|', 2)[0]).ToLower() }

function Test-Game {
    $proc = Get-FgProc
    if (-not $proc) { return $false }
    if ($proc -match $GAMES) { return $true }
    $path = ''
    if ($S.lastFg -ne [IntPtr]::Zero) { try { $path = ([string][Win]::ProcPathOf($S.lastFg)).ToLower() } catch {} }
    return $path -match 'steamapps|epic games|riot games|xboxgames'
}

function Add-Weight($list, [string]$name, [int]$w) { for ($i = 0; $i -lt $w; $i++) { [void]$list.Add($name) } }

function Emit-At([string]$k, [double]$x, [double]$y, [double]$vx, [double]$vy, [int]$life) {
    if ($Parts.Count -lt 25) { [void]$Parts.Add(@{ k = $k; x = $x; y = $y; vx = $vx; vy = $vy; life = $life }) }
}

function New-CodeLine {
    $colors = 'N', 'Y', 'L', 'B'
    $ind = $rand.Next(0, 3); $len = $rand.Next(2, 7)
    $line = ''
    for ($i = 0; $i -lt 8; $i++) { if ($i -lt $ind -or $i -ge $ind + $len) { $line += '.' } else { $line += $colors[$rand.Next(4)] } }
    return $line
}

# ---------- inicio / fim ----------
function Start-Activity([string]$name) {
    if (-not (Test-Alive) -or $S.age -gt 0.5 -or $S.drag) { return $false }
    if ($name -eq 'fish' -and $S.plat -eq [IntPtr]::Zero) { return $false }
    if ($name -eq 'build' -and $S.plat -ne [IntPtr]::Zero) { return $false }
    $S.state = 'act'; $S.act = $name; $S.actT = 600; $S.actK = 0; $S.actFrame = 0
    $S.actSit = $false; $S.actWalk = $false; $S.actLook = $null; $S.actExpr = 'neutral'; $S.actPhase = ''
    $S.nextAct = $S.tick + $rand.Next(2400, 5400)
    switch ($name) {
        'game'   { $S.actT = $rand.Next(500, 900); $S.actSit = $true; $S.actExpr = 'focused'; $S.actLook = 0; Say (Line 'jogar_ini') }
        'code'   { $S.actT = $rand.Next(500, 800); $S.actSit = $true; $S.actLook = 0; $S.codeL = @((New-CodeLine), (New-CodeLine)); Say (Line 'codar_ini') }
        'fish'   { $S.actT = 99999; $S.actSit = $true; $S.actLook = 1; $S.actPhase = 'wait'; $S.actK = $rand.Next(150, 400); Say (Line 'pescar_ini') }
        'coffee' { $S.actT = $rand.Next(300, 500); $S.actExpr = 'happy'; Say (Line 'cafe_ini') }
        'read'   { $S.actT = $rand.Next(400, 700); $S.actSit = $true; $S.actLook = 0; Say (Line 'ler_ini') }
        'build'  { $S.actT = 99999; $S.actExpr = 'happy'; Start-Build; Say (Line 'construir_ini') }
        'ball'   {
            $S.actT = $rand.Next(700, 1100); $S.actExpr = 'happy'; $S.actWalk = $true
            if (-not $BallS.active) { Spawn-Ball }
            $BallS.life = -1
            Say (Line 'bola_ini')
        }
    }
    return $true
}

function End-Activity([string]$key) {
    if ($key) { Say (Line $key) }
    $S.act = $null
    Set-State 'idle'
}

# chamado pelo Pick-State: as vezes, do nada, comeca algo de acordo com o que o usuario esta fazendo
function Try-StartActivity {
    if ($S.tick -lt $S.nextAct -or $rand.Next(100) -ge 25) { return $false }
    $proc = Get-FgProc
    $h = (Get-Date).Hour
    $opts = New-Object System.Collections.ArrayList
    if (Test-Game) { Add-Weight $opts 'game' 6 }
    if ($proc -match $CODERS) { Add-Weight $opts 'code' 5 }
    if ($proc -match $READERS -or $S.fgInfo -match '\.pdf') { Add-Weight $opts 'read' 4 }
    if ($S.plat -ne [IntPtr]::Zero) { Add-Weight $opts 'fish' 6 }
    else {
        if (-not $World.active) { Add-Weight $opts 'build' 3 }
        if (-not $BallS.active) { Add-Weight $opts 'ball' 3 }
    }
    if ($h -ge 6 -and $h -lt 11) { Add-Weight $opts 'coffee' 4 } else { Add-Weight $opts 'coffee' 1 }
    Add-Weight $opts 'read' 1; Add-Weight $opts 'game' 1; Add-Weight $opts 'code' 1
    return (Start-Activity $opts[$rand.Next($opts.Count)])
}

# ---------- a cada tick (enquanto em atividade e no chao) ----------
function Step-Activity {
    $S.actT--
    $t = $S.tick
    switch ($S.act) {
        'game' {
            if ($t % 140 -eq 0 -and $rand.Next(100) -lt 55) {
                $l = Line 'jogando'; Say $l
                if ($l -match 'Morri|Lag') { Set-Mood 'sad' 40 } elseif ($l -match 'Combo|Toma') { Set-Mood 'excited' 40 }
            }
            if ($S.actT -le 0) { Set-Mood 'excited' 60; End-Activity 'jogar_fim'; Invoke-Hop; return }
        }
        'code' {
            if ($t % 10 -eq 0) { $S.codeL = @($S.codeL[1], (New-CodeLine)) }
            if ($t % 160 -eq 0 -and $rand.Next(100) -lt 50) {
                $l = Line 'codando'; Say $l
                if ($l -match 'Bug') { Set-Mood 'surprised' 30 } elseif ($l -match 'Compilou|Funcionou') { Set-Mood 'happy' 40 }
            }
            if ($S.actT -le 0) { End-Activity 'codar_fim'; return }
        }
        'fish' {
            if ($S.plat -eq [IntPtr]::Zero) { End-Activity; return }
            $S.actK--
            if ($S.actPhase -eq 'wait' -and $S.actK -le 0) { $S.actPhase = 'bite'; $S.actK = 35; Emit 'bang' }
            elseif ($S.actPhase -eq 'bite' -and $S.actK -le 0) { $S.actPhase = 'catch'; $S.actK = 30; $S.catchBoot = ($rand.Next(100) -lt 20) }
            elseif ($S.actPhase -eq 'catch' -and $S.actK -le 0) {
                if ($S.catchBoot) { Set-Mood 'sad' 50; Say (Line 'bota') } else { Set-Mood 'happy' 60; Say (Line 'peixe'); Emit 'heart' }
                if ($rand.Next(100) -lt 40) { $S.actPhase = 'wait'; $S.actK = $rand.Next(200, 450) } else { End-Activity; return }
            }
        }
        'coffee' {
            if ($t % 25 -eq 0) { Emit-At 'steam' ($OX + 16) ($OY - 1) 0 -0.05 30 }
            $S.actK = ($S.actK + 1) % 120   # gole a cada ~4s
            if ($S.actK -eq 100 -and $rand.Next(100) -lt 40) { Say (Line 'cafe') }
            if ($S.actT -le 0) { End-Activity; return }
        }
        'read' {
            if ($t % 200 -eq 0 -and $rand.Next(100) -lt 45) {
                $l = Line 'lendo'; Say $l
                if ($l -match 'acredito|twist') { Set-Mood 'surprised' 40 }
            }
            if ($S.actT -le 0) { End-Activity; return }
        }
        'build' { Step-Build }
        'ball' {
            Step-BallPlay
            if ($S.actT -le 0) { $BallS.life = 300; End-Activity 'bola_fim'; return }
        }
    }
}

# ---------- pose e objetos ----------
function Set-ActPose($grid) {
    for ($r = 0; $r -lt 8; $r++) { foreach ($c in 0, 1, 16, 17) { if ($grid[$r][$c] -eq 'O') { $grid[$r][$c] = '.' } } }
    $aL = 4; $aR = 4
    switch ($S.act) {
        'game' { $aL = 5; $aR = 5 }
        'code' { $k = [int][Math]::Floor($S.tick / 3) % 2; $aL = 5 + $k; $aR = 6 - $k }   # digitando
        'read' { $aL = 5; $aR = 5 }
        'coffee' { $aR = 3; if ($S.actK -ge 100) { $aR = 2 } }
        'fish' { $aR = 3 }
        'build' { if ($S.actFrame -gt 0) { $aL = 1; $aR = 1 } }
        'ball' { if ($S.actFrame -gt 0) { $aL = 1; $aR = 1 } }
    }
    foreach ($c in 0, 1) { $grid[$aL][$c] = 'O'; $grid[$aL + 1][$c] = 'O' }
    foreach ($c in 16, 17) { $grid[$aR][$c] = 'O'; $grid[$aR + 1][$c] = 'O' }
}

function Fill-Cell($gr, [string]$ch, [double]$x, [double]$y) {
    $gr.FillRectangle($BR[$ch], [int][Math]::Round($x) * $PX, [int][Math]::Round($y) * $PX, $PX, $PX)
}

function Draw-ActProps($gr) {
    if ($S.state -ne 'act') { return }
    $sit = 0; if ($S.actSit) { $sit = 1 }
    switch ($S.act) {
        'game' {
            Draw-Pattern $gr $PROP.pad ($OX + 4) ($OY + 4 + $sit)
            if ($S.tick % 2 -eq 0) {
                $btn = @(@(7, 1), @(6, 2), @(8, 2), @(7, 3), @(1, 2), @(2, 1), @(2, 3), @(3, 2))[$rand.Next(8)]
                Fill-Cell $gr 'H' ($OX + 4 + $btn[0]) ($OY + 4 + $sit + $btn[1])
            }
        }
        'code' {
            $lx = $OX + 3; $ly = $OY + 5
            Draw-Pattern $gr $PROP.laptop $lx $ly
            for ($i = 0; $i -lt 2; $i++) {
                $line = [string]$S.codeL[$i]
                for ($j = 0; $j -lt $line.Length; $j++) { $ch = $line[$j]; if ($ch -ne '.') { Fill-Cell $gr "$ch" ($lx + 2 + $j) ($ly + 1 + $i) } }
            }
        }
        'coffee' {
            $up = 0; if ($S.actK -ge 100) { $up = 1 }
            Draw-Pattern $gr $PROP.mug ($OX + 15) ($OY + 3 - $up)
        }
        'read' {
            Draw-Pattern $gr $PROP.book ($OX + 4) ($OY + 4 + $sit)
            if ($S.tick % 200 -lt 6) { for ($j = 5; $j -lt 10; $j++) { Fill-Cell $gr 'W' ($OX + 4 + $j) ($OY + 3 + $sit) } }   # virando a pagina
        }
        'fish' {
            $x0 = $OX + 17; $y0 = $OY + 3 + $sit
            for ($i = 0; $i -lt 6; $i++) { Fill-Cell $gr 'C' ($x0 + $i) ($y0 - $i) }
            $tipX = $x0 + 5; $tipY = $y0 - 5
            $bob = $OY + $ROWS + 8
            if ($S.actPhase -eq 'bite' -and ($S.tick / 4) % 2 -ge 1) { $bob += 1 }
            for ($y = $tipY + 1; $y -lt $bob; $y++) { Fill-Cell $gr 'H' $tipX $y }
            if ($S.actPhase -ne 'catch') { Fill-Cell $gr 'R' $tipX $bob; Fill-Cell $gr 'W' $tipX ($bob + 1) }
            else {
                # o peixe (ou a bota) voando pra mao dele
                $k = 1 - $S.actK / 30.0
                $fx = $tipX + (($OX + 8) - $tipX) * $k
                $fy = $bob + (($OY - 3) - $bob) * $k - 6 * [Math]::Sin([Math]::PI * $k)
                if ($S.catchBoot) { Draw-Pattern $gr $PROP.boot $fx $fy } else { Draw-Pattern $gr $PROP.fish $fx $fy }
            }
        }
    }
}

# ---------- construcao (blocos na area de trabalho) ----------
$BS = 6 * $PX
$WCOLS = 7; $WROWS = 6
$TEX = @{
    stone = @('GGGGGG', 'GDGGGG', 'GGGGDG', 'GGDGGG', 'GGGGGG', 'DGGGGD')
    plank = @('CCCCCC', 'CCCCCC', 'MMMMMM', 'CCCCCC', 'CCCCCC', 'MMMMMM')
    glass = @('HHHHHH', 'HSSSSH', 'HSWSSH', 'HSSWSH', 'HSSSSH', 'HHHHHH')
    door  = @('MMMMMM', 'MCCCCM', 'MCCCCM', 'MCCCYM', 'MCCCCM', 'MCCCCM')
    roof  = @('RRRRRR', 'QQQQQQ', 'RRRQRR', 'RRRQRR', 'QQQQQQ', 'RQRRRR')
    log   = @('MCCCCM', 'MCMCCM', 'MCCCCM', 'MCCMCM', 'MCCCCM', 'MCMCCM')
    leaf  = @('LLVLLL', 'LVLLVL', 'LLLLLL', 'VLLVLL', 'LLLLLV', 'LVLLLL')
}
$BLOCKCODE = @{ s = 'stone'; p = 'plank'; g = 'glass'; d = 'door'; r = 'roof'; l = 'log'; f = 'leaf' }
# plantas de baixo pra cima
$PLANS = @{
    casa   = @('.ssdss.', '.pgdgp.', '.ppppp.', 'rrrrrrr', '.rrrrr.', '..rrr..')
    arvore = @('...l...', '...l...', '...l...', '.fffff.', '.fffff.', '..fff..')
    torre  = @('..sss..', '..sgs..', '..sss..', '..sgs..', '..sss..', '..s.s..')
}
$World = @{ active = $false; x = 0; y = 0; blocks = (New-Object System.Collections.ArrayList); plan = $null; next = 0; life = -1; crumble = $false }

function New-ToyForm([int]$w, [int]$h) {
    $tf = New-Object System.Windows.Forms.Form
    $tf.FormBorderStyle = 'None'; $tf.StartPosition = 'Manual'; $tf.ShowInTaskbar = $false; $tf.TopMost = $true
    $tf.BackColor = [System.Drawing.Color]::Magenta; $tf.TransparencyKey = [System.Drawing.Color]::Magenta
    $tf.Location = New-Object System.Drawing.Point -32000, -32000
    $tf.Size = New-Object System.Drawing.Size $w, $h
    $dbProp.SetValue($tf, $true)
    return $tf
}

$worldF = New-ToyForm ($WCOLS * $BS) ($WROWS * $BS)
$worldF.Add_Paint({
    param($sender, $e)
    try {
        foreach ($bk in $World.blocks) {
            $texRows = $TEX[$bk.t]
            $x0 = $bk.bx * $BS; $y0 = ($WROWS - 1 - $bk.by) * $BS - [int]$bk.drop
            for ($i = 0; $i -lt 6; $i++) {
                $row = $texRows[$i]
                for ($j = 0; $j -lt 6; $j++) { $e.Graphics.FillRectangle($BR["$($row[$j])"], $x0 + $j * $PX, $y0 + $i * $PX, $PX, $PX) }
            }
        }
    } catch {}
})
# clicar num bloco quebra ele (e o Clawd fica bravo)
$worldF.Add_MouseDown({
    param($sender, $e)
    $bx = [int][Math]::Floor($e.X / $BS); $by = $WROWS - 1 - [int][Math]::Floor($e.Y / $BS)
    for ($i = $World.blocks.Count - 1; $i -ge 0; $i--) {
        $bk = $World.blocks[$i]
        if ($bk.bx -eq $bx -and $bk.by -eq $by) { $World.blocks.RemoveAt($i); $worldF.Invalidate(); break }
    }
    if ((Test-Alive) -and $S.tick - $S.lastHouseCry -gt 150) { $S.lastHouseCry = $S.tick; Set-Mood 'angry' 70; Say (Line 'casa_quebrada') }
})

function Clear-World {
    $World.blocks.Clear(); $World.active = $false; $World.crumble = $false; $World.life = -1
    $worldF.Location = New-Object System.Drawing.Point -32000, -32000
}

function Start-Build {
    Clear-World
    $area = Get-Area
    $wpx = $WCOLS * $BS
    $left = $S.sx - $wpx - 4 * $PX
    if ($left -lt $area.Left + 10) { $left = $S.sx + $SW + 4 * $PX }
    if ($left + $wpx -gt $area.Right - 10) { $left = $area.Left + 10 }
    $World.x = [int]$left; $World.y = $area.Bottom - $WROWS * $BS
    $planRows = $PLANS[@('casa', 'arvore', 'torre')[$rand.Next(3)]]
    $World.plan = New-Object System.Collections.ArrayList
    for ($by = 0; $by -lt $planRows.Count; $by++) {
        for ($bx = 0; $bx -lt $WCOLS; $bx++) {
            $code = [string]$planRows[$by][$bx]
            if ($code -ne '.') { [void]$World.plan.Add(@{ bx = $bx; by = $by; t = $BLOCKCODE[$code]; drop = 0 }) }
        }
    }
    $World.next = 0; $World.active = $true
    $worldF.Location = New-Object System.Drawing.Point $World.x, $World.y
    $worldF.Invalidate()
    # ele fica do lado da obra
    if ($World.x -lt $S.sx) { $S.buildX = $World.x + $wpx + $PX } else { $S.buildX = $World.x - $SW - $PX }
    $S.actPhase = 'walk'; $S.actWalk = $true; $S.actK = 0
}

function Step-Build {
    if ($S.actFrame -gt 0) { $S.actFrame-- }
    if ($S.actPhase -eq 'walk') {
        $dx = $S.buildX - $S.sx
        if ([Math]::Abs($dx) -le 2 * $S.speed) { $S.actPhase = 'place'; $S.actWalk = $false; $S.actK = 20 }
        else { $S.dir = [Math]::Sign($dx); $S.actLook = $S.dir; Move-Walk ($S.speed * 1.2) $true }
        return
    }
    if ($World.x -lt $S.sx) { $S.actLook = -1 } else { $S.actLook = 1 }
    $S.actK--
    if ($S.actK -gt 0) { return }
    if ($World.next -ge $World.plan.Count) { $World.life = 4000; Set-Mood 'excited' 80; End-Activity 'construir_fim'; return }
    $bk = $World.plan[$World.next]; $World.next++
    $bk.drop = 2 * $BS
    [void]$World.blocks.Add($bk)
    $S.actFrame = 8; $S.actK = 22
    if ($bk.by -ge 3 -and $rand.Next(100) -lt 50) { Invoke-Jump (-7 * $dpi) }
    if ($rand.Next(100) -lt 12) { Say (Line 'construindo') }
}

# ---------- bola ----------
$BALLPAT = @('..YYY..', '.RYYYB.', 'RRYYYBB', 'RRWWWBB', 'RRYYYBB', '.RYYYB.', '..YYY..')
$BSZ = 7 * $PX
$BallS = @{ active = $false; x = 0.0; y = 0.0; vx = 0.0; vy = 0.0; life = -1; spin = 0.0 }

$ballF = New-ToyForm $BSZ $BSZ
$ballF.Add_Paint({
    param($sender, $e)
    try {
        $flip = ([int][Math]::Floor($BallS.spin / (3 * $PX))) % 2 -eq 1   # parece que esta rolando
        for ($i = 0; $i -lt 7; $i++) {
            $row = $BALLPAT[$i]
            for ($j = 0; $j -lt 7; $j++) {
                $ch = "$($row[$j])"
                if ($ch -eq '.') { continue }
                if ($flip -and $ch -eq 'R') { $ch = 'B' } elseif ($flip -and $ch -eq 'B') { $ch = 'R' }
                $e.Graphics.FillRectangle($BR[$ch], $j * $PX, $i * $PX, $PX, $PX)
            }
        }
    } catch {}
})
# clicar na bola chuta ela pra longe do mouse, e o Clawd vem jogar
$ballF.Add_MouseDown({
    $cur = [System.Windows.Forms.Cursor]::Position
    $d = [Math]::Sign(($BallS.x + $BSZ / 2) - $cur.X); if ($d -eq 0) { $d = 1 }
    $BallS.vx = $d * 12 * $dpi; $BallS.vy = -11 * $dpi
    if ($S.state -eq 'act' -and $S.act -eq 'ball') { if ($rand.Next(100) -lt 40) { Say (Line 'bola') } }
    elseif ((Test-Alive) -and $S.state -ne 'sleep') { [void](Start-Activity 'ball') }
})

function Spawn-Ball {
    $BallS.x = $S.sx + $SW / 2 + $S.dir * 40 * $dpi; $BallS.y = $S.sy - 40 * $dpi
    $BallS.vx = $S.dir * 3 * $dpi; $BallS.vy = -4 * $dpi; $BallS.spin = 0
    $BallS.active = $true; $BallS.life = -1
}

function Hide-Ball {
    $BallS.active = $false
    $ballF.Location = New-Object System.Drawing.Point -32000, -32000
}

function Step-Ball {
    $pt = New-Object System.Drawing.Point ([int]($BallS.x + $BSZ / 2)), ([int]($BallS.y + $BSZ / 2))
    $area = [System.Windows.Forms.Screen]::FromPoint($pt).WorkingArea
    $gnd = $area.Bottom - $BSZ
    $BallS.vy += $GRAV * 0.8
    $BallS.x += $BallS.vx; $BallS.y += $BallS.vy; $BallS.spin += [Math]::Abs($BallS.vx)
    if ($BallS.y -ge $gnd) {
        $BallS.y = $gnd
        if ($BallS.vy -gt 2 * $dpi) { $BallS.vy = -$BallS.vy * 0.55 } else { $BallS.vy = 0 }
        $BallS.vx *= 0.97
    }
    $wall = $false
    if ($BallS.x -lt $area.Left) { $BallS.x = $area.Left; $BallS.vx = [Math]::Abs($BallS.vx) * 0.7; $wall = $true }
    if ($BallS.x -gt $area.Right - $BSZ) { $BallS.x = $area.Right - $BSZ; $BallS.vx = -[Math]::Abs($BallS.vx) * 0.7; $wall = $true }
    if ($BallS.y -lt $area.Top) { $BallS.y = $area.Top; $BallS.vy = [Math]::Abs($BallS.vy) }
    if ($wall -and [Math]::Abs($BallS.vx) -gt 4 * $dpi -and $S.state -eq 'act' -and $S.act -eq 'ball' -and $rand.Next(100) -lt 50) { Say 'Gol!'; Set-Mood 'excited' 50 }
    $ballF.Location = New-Object System.Drawing.Point ([int]$BallS.x), ([int]$BallS.y)
    $ballF.Invalidate()
    if ($BallS.life -gt 0) { $BallS.life--; if ($BallS.life -eq 0) { Hide-Ball } }
}

function Step-BallPlay {
    if ($S.actFrame -gt 0) { $S.actFrame-- }
    $cx = $S.sx + $SW / 2
    $dx = ($BallS.x + $BSZ / 2) - $cx
    $S.dir = [Math]::Sign($dx); if ($S.dir -eq 0) { $S.dir = 1 }
    $S.actLook = $S.dir
    $near = [Math]::Abs($dx) -lt ($SW + $BSZ) / 2 -and $BallS.y + $BSZ -gt $S.sy
    if ($near) {
        $S.actWalk = $false
        if ($S.tick - $S.lastKick -gt 20) {
            $S.lastKick = $S.tick
            $BallS.vx = $S.dir * (7 + $rand.NextDouble() * 7) * $dpi
            $BallS.vy = -(5 + $rand.NextDouble() * 8) * $dpi
            $S.actFrame = 6
            if ($rand.Next(100) -lt 20) { Say (Line 'bola') }
            if ($rand.Next(100) -lt 25) { Invoke-Jump (-6 * $dpi) }
        }
    } else {
        $S.actWalk = $true
        Move-Walk ($S.speed * 1.8) $true
    }
}

# ---------- todo tick (independente do Clawd) ----------
function Step-Toys {
    if ($World.active) {
        $dirty = $false
        foreach ($bk in $World.blocks) { if ($bk.drop -gt 0) { $bk.drop = [Math]::Max(0, $bk.drop - 3 * $PX); $dirty = $true } }
        # obra abandonada no meio (ele foi carregado, morreu...) tambem desmorona depois
        if ($World.life -lt 0 -and -not ($S.state -eq 'act' -and $S.act -eq 'build')) { $World.life = 2000 }
        if ($World.life -gt 0) {
            $World.life--
            if ($World.life -eq 0) { $World.crumble = $true; if ((Test-Alive) -and $World.blocks.Count -gt 0) { Say (Line 'casa_caiu') } }
        }
        if ($World.crumble -and $S.tick % 3 -eq 0) {
            if ($World.blocks.Count -gt 0) { $World.blocks.RemoveAt($World.blocks.Count - 1); $dirty = $true } else { Clear-World }
        }
        if ($dirty) { $worldF.Invalidate() }
    }
    if ($BallS.active) {
        if ($BallS.life -lt 0 -and -not ($S.state -eq 'act' -and $S.act -eq 'ball')) { $BallS.life = 600 }
        Step-Ball
    }
    if ($S.tick % 50 -eq 25) {
        [Win]::SetWindowPos($worldF.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null
        [Win]::SetWindowPos($ballF.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null
    }
}

function Init-Toys {
    $worldF.Show(); Set-ToolWindow $worldF
    $ballF.Show(); Set-ToolWindow $ballF
}

# ---------- menu ----------
$miAct = New-Object System.Windows.Forms.ToolStripMenuItem 'Atividades'
foreach ($pair in @(@('Jogar videogame', 'game'), @('Codar', 'code'), @('Pescar (em cima de janela)', 'fish'), @("Tomar caf$([char]0xE9)", 'coffee'), @('Ler', 'read'), @('Construir', 'build'), @('Jogar bola', 'ball'))) {
    $it = $miAct.DropDownItems.Add($pair[0]); $it.Tag = $pair[1]
    $it.Add_Click({ param($sender, $e) if (-not (Start-Activity ([string]$sender.Tag))) { Say "Agora n$([char]0xE3)o d$([char]0xE1)..." } })
}
$menu.Items.Insert(1, $miAct)
