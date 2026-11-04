# 32 truques aleatorios do Clawd. Cada um e um conjunto de blocos:
#   init  { param($k) }               ao comecar
#   step  { param($k) }               todo tick (inclusive no ar)
#   pose  { param($grid, $k) }        mexe no sprite (bracos, rosto)
#   draw  { param($gr, $k, $grid) }   desenha objetos por cima
# $k guarda o estado do truque: t (ticks), dur, sit, flip, hide, dark, walk, expr, look, d (dados livres)
# Carregado pelo clawd.ps1 depois do atividades.ps1.

$BR['F'] = New-Brush 255 105 180   # rosa chiclete

foreach ($kv in @{
    drop = @('B', 'B'); gum = @('F'); smoke = @('GG', 'GG'); speed = @('HH'); flame = @('Y', 'R'); rocket = @('Y', 'R')
    bubble = @('.H.', 'H.H', '.H.'); bubble2 = @('.HH.', 'H..H', 'H..H', '.HH.')
    spR = @('R'); spB = @('B'); spY = @('Y'); spN = @('N'); spL = @('L'); spF = @('F')
}.GetEnumerator()) { $PAT[$kv.Key] = $kv.Value }

$EYES['zen'] = $EYES.closed

$TP = @{
    gum1       = @('FF', 'FF')
    gum2       = @('.FF.', 'FFFF', 'FFFF', '.FF.')
    gum3       = @('..FFF..', '.FFFFF.', 'FFWFFFF', 'FFFFFFF', 'FFFFFFF', '.FFFFF.', '..FFF..')
    guitar     = @('CCCCCCC.RRR.', 'HHHHHHHRRKRR', 'CCCCCCC.RRR.')
    yoyo       = @('.R.', 'RWR', '.R.')
    kite       = @('..R..', '.RYR.', 'RYYYR', '.RYR.', '..R..')
    cloud      = @('...HHHH.......', '.HHHHHHHHH.HH.', 'HHHHHHHHHHHHHH', '.GGGGGGGGGGGG.')
    stormcloud = @('...GGGG.......', '.GGGGGGGGG.GG.', 'GGGGGGGGGGGGGG', '.DDDDDDDDDDDD.')
    umbrella   = @('.....RRRRRR.....', '...RRRRRRRRRR...', '.RRRRRRRRRRRRRR.', 'R.R.R.R.R.R.R.R.')
    bolt       = @('..YY', '.YY.', 'YYYY', '..YY', '.YY.', 'YY..')
    phone      = @('EEE', 'ESE', 'ESE', 'EEE')
    flash      = @('W.W.W', '.WWW.', 'WWWWW', '.WWW.', 'W.W.W')
    pizza      = @('MMMMM', 'YRYRY', '.YRY.', '..Y..')
    icecream   = @('.FFF.', 'FFFFF', 'FWFFF', '.MMM.', '.MMM.', '..M..')
    jR = @('RR', 'RR'); jB = @('BB', 'BB'); jY = @('YY', 'YY')
    shades     = @('KKKKKKKKKKKK', '.KKKK..KKKK.')
    hat        = @('.EEE.', '.EEE.', '.RRR.', 'EEEEE')
    rabbit     = @('W.W', 'W.W', 'WWW', 'WKW', 'WWW')
    skate      = @('.MMMMMMMMMMMMMM.', '..E..........E..')
    jetpack    = @('GG', 'GG', 'GG', 'RR')
    chute      = @('....RRRRRRRR....', '..RRWWRRRRWWRR..', '.RRRRRRRRRRRRRR.', 'R..............R')
    lens       = @('.HHH.', 'HSSSH', 'HSWSH', 'HSSSH', '.HHH.')
    can        = @('HHHH.', 'HHHHH', 'HHHH.')
    pot        = @('QQQQQ', '.QQQ.', '.QQQ.')
    flower     = @('.R.', 'RYR', '.R.')
    decks      = @('.EEEEE..EEEEE.', 'EEKKKEEEEKKKEE', 'EEEEEEEEEEEEEE')
    cell       = @('EE', 'ES', 'ES', 'EE')
    spikes     = @('..L...L...L...', '.LLL.LLL.LLL..')
    tail       = @('L...', 'LLLL')
    crack      = @('..H..', '.H.H.', 'H...H', '.H...', '..H..')
}

# ---------- ajudantes ----------
function Seq([string]$key, [int]$i) { $l = @($Falas.$key); if ($i -lt $l.Count) { return [string]$l[$i] }; return '' }

function Set-Arms($grid, [int]$aL, [int]$aR) {
    for ($r = 0; $r -lt 8; $r++) { foreach ($c in 0, 1, 16, 17) { if ($grid[$r][$c] -eq 'O') { $grid[$r][$c] = '.' } } }
    if ($aL -ge 0) { foreach ($c in 0, 1) { $grid[$aL][$c] = 'O'; $grid[$aL + 1][$c] = 'O' } }
    if ($aR -ge 0) { foreach ($c in 16, 17) { $grid[$aR][$c] = 'O'; $grid[$aR + 1][$c] = 'O' } }
}

function Draw-Line($gr, [string]$ch, [double]$x0, [double]$y0, [double]$x1, [double]$y1) {
    $n = [int][Math]::Ceiling([Math]::Max([Math]::Abs($x1 - $x0), [Math]::Abs($y1 - $y0)))
    for ($i = 0; $i -le $n; $i++) {
        $q = 0.0; if ($n -gt 0) { $q = $i / $n }
        Fill-Cell $gr $ch ($x0 + ($x1 - $x0) * $q) ($y0 + ($y1 - $y0) * $q)
    }
}

# controla o voo: a fisica soma a gravidade depois, entao compensa aqui
function Fly([double]$vx, [double]$vy) { $S.plat = [IntPtr]::Zero; $S.pr = $null; $S.vx = $vx; $S.vy = $vy - $GRAV }

function Burst([string]$kind, [double]$x, [double]$y, [int]$n, [double]$spd, [int]$life) {
    for ($i = 0; $i -lt $n; $i++) { $a = $i * 2 * [Math]::PI / $n; Emit-At $kind $x $y ([Math]::Cos($a) * $spd) ([Math]::Sin($a) * $spd) $life }
}

# ---------- os 32 truques ----------
$TRK = [ordered]@{}

$TRK.chiclete = @{ dur = 170
    step = { param($k) if ($k.t -eq 100) { Say 'POP!' 2; Set-Mood 'surprised' 50; Burst 'gum' ($OX + 9) ($OY + 5) 8 0.3 10 } }
    draw = { param($gr, $k, $grid)
        if ($k.t -lt 100) {
            $g = $TP['gum' + [int][Math]::Min(3, 1 + [Math]::Floor($k.t / 33))]
            Draw-Pattern $gr $g ($OX + 9 - $g[0].Length / 2) ($OY + 5 - $g.Count / 2)
        } else {
            foreach ($c in @(@(5, 4), @(7, 5), @(8, 4), @(10, 6), @(11, 4), @(12, 5), @(9, 6), @(6, 6))) { Fill-Cell $gr 'F' ($OX + $c[0]) ($OY + $c[1]) }
        }
    }
}

$TRK.espirro = @{ dur = 130
    init = { param($k) $k.expr = 'sleepy' }
    step = { param($k)
        if ($k.t -eq 40) { Say 'A... a...' }
        if ($k.t -eq 85) {
            Say 'ATCHIM!' 2; $k.expr = 'surprised'
            $S.vx = -$S.dir * 9 * $dpi
            for ($i = 0; $i -lt 5; $i++) { Emit-At 'drop' ($OX + 9 + $S.dir * 6) ($OY + 5) ($S.dir * (0.3 + $rand.NextDouble() * 0.3)) (($rand.NextDouble() - 0.5) * 0.2) 12 }
        }
    }
}

$TRK.soluco = @{ dur = 260
    step = { param($k)
        if ($k.t % 45 -eq 20) { Invoke-Jump (-4 * $dpi); Say 'hic!'; $k.expr = 'surprised' }
        elseif ($k.t % 45 -eq 35) { $k.expr = $null }
    }
}

$TRK.guitarra = @{ dur = 280
    init = { param($k) $k.expr = 'excited' }
    step = { param($k) if ($k.t % 18 -eq 0) { Emit 'note' }; if ($k.t % 36 -eq 0) { Invoke-Jump (-3 * $dpi) } }
    pose = { param($grid, $k) Set-Arms $grid 5 (4 + [int][Math]::Floor($k.t / 4) % 3) }
    draw = { param($gr, $k, $grid) Draw-Pattern $gr $TP.guitar ($OX + 2) ($OY + 5) }
}

$TRK.ioio = @{ dur = 240
    draw = { param($gr, $k, $grid)
        $len = [int](5 + 5 * [Math]::Sin($k.t * 0.12))
        for ($i = 0; $i -lt $len; $i++) { Fill-Cell $gr 'H' ($OX + 17) ($OY + 6 + $i) }
        Draw-Pattern $gr $TP.yoyo ($OX + 16) ($OY + 6 + $len)
    }
}

$TRK.pipa = @{ above = 12; dur = 320
    init = { param($k) $k.expr = 'happy'; $k.look = 1 }
    pose = { param($grid, $k) Set-Arms $grid 4 2 }
    draw = { param($gr, $k, $grid)
        $kx = $OX + 18 + 1.5 * [Math]::Sin($k.t * 0.05); $ky = $OY - 11 + [Math]::Sin($k.t * 0.08)
        Draw-Line $gr 'H' ($OX + 17) ($OY + 2) ($kx + 2) ($ky + 4)
        Draw-Pattern $gr $TP.kite $kx $ky
        for ($i = 1; $i -le 3; $i++) { Fill-Cell $gr @('Y', 'R')[$i % 2] ($kx + 2 + [Math]::Sin($k.t * 0.2 + $i)) ($ky + 4 + $i) }
    }
}

$TRK.chuva = @{ above = 10; dur = 320
    init = { param($k) $k.expr = 'sad' }
    step = { param($k)
        if ($k.t % 3 -eq 0) { $life = 14; if ($k.t -gt 110) { $life = 4 }; Emit-At 'drop' ($OX + 3 + $rand.Next(12)) ($OY - 6) 0 0.5 $life }
        if ($k.t -eq 60) { Say (Seq 'tr_chuva_seq' 0) }
        if ($k.t -eq 110) { $k.expr = 'happy'; Say (Seq 'tr_chuva_seq' 1) }
    }
    pose = { param($grid, $k) if ($k.t -gt 110) { Set-Arms $grid 4 2 } }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.cloud ($OX + 2) ($OY - 10)
        if ($k.t -gt 110) { Draw-Pattern $gr $TP.umbrella ($OX + 1) ($OY - 4); Draw-Line $gr 'C' ($OX + 16) ($OY - 1) ($OX + 16) ($OY + 2) }
    }
}

$TRK.raio = @{ above = 10; dur = 240
    init = { param($k) $k.expr = 'thinking' }
    step = { param($k)
        if ($k.t -eq 50) { $k.dark = $true; $k.expr = 'dizzy'; Say '...' 2 }
        if ($k.t -gt 50 -and $k.t -lt 170 -and $k.t % 10 -eq 0) { Emit-At 'smoke' ($OX + 5 + $rand.Next(8)) ($OY - 1) 0 -0.08 20 }
        if ($k.t -eq 170) { $k.dark = $false; $k.expr = 'happy'; Say (Seq 'tr_raio_seq' 0) }
    }
    draw = { param($gr, $k, $grid)
        if ($k.t -lt 190) { Draw-Pattern $gr $TP.stormcloud ($OX + 2) ($OY - 10) }
        if ($k.t -ge 46 -and $k.t -lt 56) { Draw-Pattern $gr $TP.bolt ($OX + 8) ($OY - 6) }
    }
}

$TRK.meditar = @{ dur = 330
    init = { param($k) $k.expr = 'zen'; $k.sit = $true }
    step = { param($k)
        if ($k.t -lt 30) { Fly 0 (-1.2 * $dpi) }
        elseif ($k.t -lt 280) {
            Fly 0 (0.4 * $dpi * [Math]::Sin($k.t * 0.08))
            if ($k.t % 20 -eq 0) { Emit-At 'star' ($OX + 2 + $rand.Next(14)) ($OY + $rand.Next(6)) 0 -0.05 15 }
        }
    }
    pose = { param($grid, $k) Set-Arms $grid 3 3 }
}

$TRK.flexoes = @{ dur = 240
    init = { param($k) $k.expr = 'focused'; $k.d.n = 0 }
    step = { param($k)
        $k.sit = ([int][Math]::Floor($k.t / 20) % 2) -eq 1
        if ($k.t -gt 0 -and $k.t % 40 -eq 0) { $k.d.n++; Say ([string]$k.d.n) }
        if ($k.t % 60 -eq 30) { Emit 'sweat' }
    }
    pose = { param($grid, $k) if ($k.sit) { Set-Arms $grid 6 6 } else { Set-Arms $grid 5 5 } }
}

$TRK.corda = @{ above = 4; dur = 290
    init = { param($k) $k.expr = 'happy' }
    step = { param($k) if ($k.t % 24 -eq 0) { Invoke-Jump (-6.5 * $dpi) } }
    draw = { param($gr, $k, $grid)
        $depth = $(if (($k.t % 24) -lt 12) { 6 } else { -8 })
        for ($x = 0; $x -le 17; $x++) { Fill-Cell $gr 'M' ($OX + $x) ($OY + 5 + $depth * [Math]::Sin([Math]::PI * $x / 17)) }
    }
}

$TRK.malabares = @{ above = 8; dur = 280
    pose = { param($grid, $k) $u = [int][Math]::Floor($k.t / 8) % 2; Set-Arms $grid (2 + 2 * $u) (4 - 2 * $u) }
    draw = { param($gr, $k, $grid)
        $jcol = 'jR', 'jB', 'jY'
        for ($i = 0; $i -lt 3; $i++) {
            $a = $k.t * 0.15 + $i * 2.094
            Draw-Pattern $gr $TP[$jcol[$i]] ($OX + 8 + 7 * [Math]::Cos($a)) ($OY - 4 + 3 * [Math]::Sin($a))
        }
    }
}

$TRK.selfie = @{ above = 6; dur = 170
    init = { param($k) $k.expr = 'happy'; $k.look = 1 }
    step = { param($k) if ($k.t -eq 70) { Say 'Xis!' }; if ($k.t -eq 120) { Say (Seq 'tr_selfie_seq' 0) } }
    pose = { param($grid, $k) Set-Arms $grid 4 1 }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.phone ($OX + 17) ($OY - 4)
        if ($k.t -ge 90 -and $k.t -lt 96) { Draw-Pattern $gr $TP.flash ($OX + 16) ($OY - 5) }
    }
}

$TRK.pizza = @{ dur = 200
    init = { param($k) $k.look = 1 }
    step = { param($k) if ($k.t % 45 -eq 30) { Say 'Nham!'; $k.expr = 'happy' } }
    pose = { param($grid, $k) $up = ($k.t % 45) -ge 22; Set-Arms $grid 4 $(if ($up) { 2 } else { 4 }) }
    draw = { param($gr, $k, $grid)
        $left = 4 - [int][Math]::Floor($k.t / 45)
        if ($left -gt 0) {
            $x = $OX + 16; $y = $OY + 3
            if (($k.t % 45) -ge 22) { $x = $OX + 13; $y = $OY + 2 }   # levando a boca
            Draw-Pattern $gr @($TP.pizza[0..($left - 1)]) $x $y
        }
    }
}

$TRK.sorvete = @{ above = 2; dur = 230
    init = { param($k) $k.look = 1; $k.expr = 'happy' }
    step = { param($k)
        if ($k.t % 30 -eq 0) { Emit-At 'gum' ($OX + 17) ($OY + 5) 0 0.25 10 }
        if ($k.t -eq 140) { Say 'Brain freeze!' 2; Set-Mood 'dizzy' 50 }
    }
    pose = { param($grid, $k) Set-Arms $grid 4 3 }
    draw = { param($gr, $k, $grid) Draw-Pattern $gr $TP.icecream ($OX + 15) ($OY - 1) }
}

$TRK.bolhas = @{ above = 6; dur = 260
    init = { param($k) $k.expr = 'happy'; $k.look = 1 }
    step = { param($k)
        if ($k.t % 12 -eq 0) { Emit-At @('bubble', 'bubble2')[$rand.Next(2)] ($OX + 18) ($OY - 2) (0.08 + $rand.NextDouble() * 0.12) (-0.05 - $rand.NextDouble() * 0.06) 70 }
    }
    pose = { param($grid, $k) Set-Arms $grid 4 3 }
    draw = { param($gr, $k, $grid) Draw-Line $gr 'C' ($OX + 17) ($OY + 3) ($OX + 18) ($OY + 1); Draw-Pattern $gr $PAT.bubble ($OX + 18) ($OY - 2) }
}

$TRK.fogos = @{ above = 12; dur = 230
    init = { param($k) $k.expr = 'excited'; $k.d.boom = New-Object System.Collections.ArrayList }
    step = { param($k)
        if ($k.t -eq 20 -or $k.t -eq 80 -or $k.t -eq 140) { Emit-At 'rocket' ($OX + 9) ($OY - 1) 0 -0.45 18; [void]$k.d.boom.Add($k.t + 18) }
        if ($k.d.boom -contains $k.t) {
            $sp = 'spR', 'spB', 'spY', 'spN', 'spL', 'spF'
            Burst $sp[$rand.Next($sp.Count)] ($OX + 9 + $rand.Next(-3, 4)) ($OY - 9) 12 0.25 18
            if ($k.t -lt 100) { Say (Seq 'tr_fogos_seq' 0) }
        }
    }
}

$TRK.oculos = @{ dur = 230
    step = { param($k) if ($k.t -eq 110) { Say (Seq 'tr_oculos_seq' 0) } }
    draw = { param($gr, $k, $grid)
        $dy = 0.0; if ($k.t -lt 15) { $dy = -(15 - $k.t) / 2.0 }   # oculos descendo
        Draw-Pattern $gr $TP.shades ($OX + 3) ($OY + 2 + $dy)
        $gx = $OX + 4 + [Math]::Floor($k.t / 3) % 14
        if ($gx -le $OX + 14) { Fill-Cell $gr 'W' $gx ($OY + 2 + $dy) }   # brilho passando
    }
}

$TRK.magica = @{ above = 2; dur = 260
    init = { param($k) $k.look = 1 }
    step = { param($k)
        if ($k.t -eq 60) { Say 'Abracadabra!'; for ($i = 0; $i -lt 6; $i++) { Emit-At 'star' ($OX + 19 + $rand.Next(5)) ($OY + 3 + $rand.Next(3)) (($rand.NextDouble() - 0.5) * 0.2) -0.1 15 } }
        if ($k.t -eq 95) { Say 'Tcharam!' 2; $k.expr = 'excited' }
    }
    pose = { param($grid, $k) $up = 2; if ($k.t -ge 50 -and $k.t -lt 70 -and ($k.t % 6) -lt 3) { $up = 1 }; Set-Arms $grid 4 $up }
    draw = { param($gr, $k, $grid)
        if ($k.t -ge 70) {
            $rx = $OX + 20; $ry = [Math]::Max($OY + 1, $OY + 6 - ($k.t - 70) * 0.3)
            if ($k.t -ge 140) { $rx += ($k.t - 140) * 0.12; $ry = $OY + 5 - [Math]::Abs([Math]::Sin(($k.t - 140) * 0.2)) * 2 }   # sai pulando
            if ($rx -lt $FW) { Draw-Pattern $gr $TP.rabbit $rx $ry }
        }
        Draw-Pattern $gr $TP.hat ($OX + 19) ($OY + 6)
        Draw-Line $gr 'K' ($OX + 17) ($OY + 2) ($OX + 19) ($OY + 0); Fill-Cell $gr 'W' ($OX + 19) ($OY - 1)
    }
}

$TRK.teleporte = @{ dur = 110
    step = { param($k)
        if ($k.t -lt 60 -and $k.t % 3 -eq 0) { Emit-At 'star' ($OX + 2 + $rand.Next(14)) ($OY + $rand.Next(10)) 0 -0.05 10 }
        if ($k.t -eq 20) { $k.hide = $true }
        if ($k.t -eq 40) {
            $area = Get-Area
            $S.plat = [IntPtr]::Zero; $S.pr = $null; $S.vx = 0; $S.vy = 0
            $S.sx = $area.Left + $rand.Next([Math]::Max(1, $area.Width - $SW)); $S.sy = $area.Bottom - $SH
        }
        if ($k.t -eq 60) { $k.hide = $false; Say (Seq 'tr_teleporte_seq' 0) }
    }
}

$TRK.clone = @{ above = 11; dur = 210
    step = { param($k)
        if ($k.t -eq 10 -or $k.t -eq 185) { for ($i = 0; $i -lt 6; $i++) { Emit-At 'star' ($OX + 2 + $rand.Next(14)) ($OY - 10 + $rand.Next(10)) 0 -0.05 12 } }
        if ($k.t -eq 25) { $k.expr = 'surprised'; Say (Seq 'tr_clone_seq' 0) }
        if ($k.t -eq 100) { $k.expr = 'happy'; Say (Seq 'tr_clone_seq' 1) }
    }
    draw = { param($gr, $k, $grid)
        if ($k.t -lt 12 -or $k.t -ge 188) { return }
        # um clone espelhado em pe na cabeca dele
        for ($r = 0; $r -lt $ROWS; $r++) {
            $row = $grid[$r]
            for ($c = 0; $c -lt $COLS; $c++) {
                $ch = $row[$COLS - 1 - $c]
                if ($ch -eq 'O') { $gr.FillRectangle($AGEBR[0], ($OX + $c) * $PX, ($OY - 10 + $r) * $PX, $PX, $PX) }
                elseif ($ch -ne '.') { $gr.FillRectangle($BR["$ch"], ($OX + $c) * $PX, ($OY - 10 + $r) * $PX, $PX, $PX) }
            }
        }
    }
}

$TRK.skate = @{ dur = 280
    init = { param($k) $k.expr = 'excited'; $S.dir = @(-1, 1)[$rand.Next(2)] }
    step = { param($k)
        $k.look = $S.dir
        if ($S.vy -eq 0) { Move-Walk ($S.speed * 3.5) $true }
        if ($k.t % 3 -eq 0) { Emit-At 'speed' ($OX + 9 - $S.dir * 10) ($OY + 4 + $rand.Next(4)) (-$S.dir * 0.2) 0 6 }
    }
    draw = { param($gr, $k, $grid) Draw-Pattern $gr $TP.skate ($OX + 1) ($OY + 9) }
}

$TRK.jetpack = @{ dur = 360
    init = { param($k) $k.expr = 'excited' }
    step = { param($k)
        if ($k.t -lt 260) {
            if ($k.t % 2 -eq 0) { Emit-At 'flame' ($OX - 1.5) ($OY + 7) 0 0.25 6 }
            if ($k.t -lt 50) { Fly 0 (-3 * $dpi) }
            else { Fly (3 * $dpi * [Math]::Cos(($k.t - 50) * 0.03)) (1.2 * $dpi * [Math]::Sin(($k.t - 50) * 0.06)) }
            if ($k.t -eq 60) { Say (Seq 'tr_jetpack_seq' 0) }
        } elseif ($k.t -gt 265 -and $S.vy -eq 0) { End-Trick 'tr_jetpack_fim' }
    }
    draw = { param($gr, $k, $grid) Draw-Pattern $gr $TP.jetpack ($OX - 2) ($OY + 3) }
}

$TRK.paraquedas = @{ above = 10; dur = 1500
    init = { param($k) $area = Get-Area; $S.plat = [IntPtr]::Zero; $S.pr = $null; $S.sy = $area.Top + 5; $S.vy = 0; $k.expr = 'happy' }
    step = { param($k)
        if ($k.t -gt 15 -and ($S.plat -ne [IntPtr]::Zero -or $S.sy + $SH -ge (Get-Area).Bottom - 1)) { End-Trick 'tr_paraquedas_fim'; return }
        Fly (1.2 * $dpi * [Math]::Sin($k.t * 0.04)) (1.3 * $dpi)
    }
    pose = { param($grid, $k) Set-Arms $grid 2 2 }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.chute ($OX + 1) ($OY - 9)
        Draw-Line $gr 'H' ($OX + 1) ($OY - 5) ($OX + 1) ($OY + 1)
        Draw-Line $gr 'H' ($OX + 16) ($OY - 5) ($OX + 16) ($OY + 1)
    }
}

$TRK.lupa = @{ dur = 300
    init = { param($k) $k.walk = $true; $S.dir = @(-1, 1)[$rand.Next(2)] }
    step = { param($k)
        $k.look = $S.dir
        if ($S.vy -eq 0) { Move-Walk ($S.speed * 0.5) }
        if ($k.t % 80 -eq 40) { Say (Line 'tr_lupa_meio') }
    }
    draw = { param($gr, $k, $grid)
        if ($S.dir -ge 0) { Draw-Pattern $gr $TP.lens ($OX + 16) ($OY + 1); Draw-Line $gr 'C' ($OX + 18) ($OY + 6) ($OX + 17) ($OY + 8) }
        else { Draw-Pattern $gr $TP.lens ($OX - 3) ($OY + 1); Draw-Line $gr 'C' ($OX - 1) ($OY + 6) $OX ($OY + 8) }
    }
}

$TRK.planta = @{ dur = 340
    init = { param($k) $k.look = 1 }
    step = { param($k) if ($k.t -lt 260 -and $k.t % 6 -eq 0) { Emit-At 'drop' ($OX + 21 + $rand.NextDouble()) ($OY + 5) 0.05 0.3 6 } }
    pose = { param($grid, $k) Set-Arms $grid 4 3 }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.can ($OX + 16) ($OY + 2)
        $h = [int][Math]::Min(6, [Math]::Floor($k.t / 40))
        for ($i = 1; $i -le $h; $i++) { Fill-Cell $gr 'L' ($OX + 23) ($OY + 7 - $i) }
        if ($h -ge 3) { Fill-Cell $gr 'V' ($OX + 22) ($OY + 4); Fill-Cell $gr 'V' ($OX + 24) ($OY + 5) }
        if ($h -ge 6) { Draw-Pattern $gr $TP.flower ($OX + 22) ($OY - 1) }
        Draw-Pattern $gr $TP.pot ($OX + 21) ($OY + 7)
    }
}

$TRK.pintar = @{ dur = 340
    init = { param($k) $k.look = 1; $k.d.cv = New-Object 'char[]' 48; for ($i = 0; $i -lt 48; $i++) { $k.d.cv[$i] = 'W' } }
    step = { param($k) if ($k.t % 8 -eq 0 -and $k.t -lt 300) { $k.d.cv[$rand.Next(48)] = @('R', 'B', 'Y', 'L', 'N', 'F')[$rand.Next(6)] } }
    pose = { param($grid, $k) Set-Arms $grid 4 (2 + [int][Math]::Floor($k.t / 5) % 3) }
    draw = { param($gr, $k, $grid)
        $ex = $OX + 20; $ey = $OY + 1
        Draw-Line $gr 'C' ($ex + 1) ($ey + 6) $ex ($OY + 9); Draw-Line $gr 'C' ($ex + 6) ($ey + 6) ($ex + 7) ($OY + 9)
        for ($i = 0; $i -lt 48; $i++) { Fill-Cell $gr ([string]$k.d.cv[$i]) ($ex + ($i % 8)) ($ey + [Math]::Floor($i / 8)) }
        Draw-Line $gr 'M' ($ex - 1) ($ey - 1) ($ex + 8) ($ey - 1); Draw-Line $gr 'M' ($ex - 1) ($ey + 6) ($ex + 8) ($ey + 6)
        Fill-Cell $gr 'C' ($OX + 18) ($OY + 2); Fill-Cell $gr 'R' ($OX + 19) ($OY + 2)   # pincel
    }
}

$TRK.dj = @{ above = 2; dur = 320
    init = { param($k) $k.expr = 'happy'; $k.look = 0 }
    step = { param($k)
        if ($k.t % 16 -eq 0) { Emit 'note' }
        if ($k.t % 24 -eq 0) { Invoke-Jump (-3 * $dpi) }
        if ($k.t -eq 120) { Say (Seq 'tr_dj_seq' 0) }
    }
    pose = { param($grid, $k) $u = [int][Math]::Floor($k.t / 6) % 2; Set-Arms $grid (5 + $u) (6 - $u) }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.decks ($OX + 2) ($OY + 6)
        $sp = [int][Math]::Floor($k.t / 3) % 3   # discos girando
        Fill-Cell $gr 'W' ($OX + 4 + $sp) ($OY + 7); Fill-Cell $gr 'W' ($OX + 13 - $sp) ($OY + 7)
        Draw-Line $gr 'E' ($OX + 2) ($OY - 1) ($OX + 15) ($OY - 1)   # fone
        foreach ($hx in ($OX + 1), ($OX + 16)) { Fill-Cell $gr 'R' $hx ($OY + 2); Fill-Cell $gr 'R' $hx ($OY + 3) }
    }
}

$TRK.telefone = @{ dur = 270
    init = { param($k) $k.look = -1 }
    step = { param($k)
        if ($k.t -lt 40 -and $k.t % 8 -eq 0) { Emit-At 'bang' ($OX - 2) ($OY + 1) 0 -0.05 6 }
        foreach ($pair in @(@(45, 0), @(110, 1), @(170, 2), @(230, 3))) { if ($k.t -eq $pair[0]) { Say (Seq 'tr_telefone_seq' $pair[1]) } }
        if ($k.t -eq 230) { $k.expr = 'sad' }
    }
    pose = { param($grid, $k) if ($k.t -ge 40) { Set-Arms $grid 1 4 } }
    draw = { param($gr, $k, $grid)
        if ($k.t -lt 40) { Draw-Pattern $gr $TP.cell ($OX - 3 + ($k.t % 2)) ($OY + 6) }   # tocando no chao
        else { Draw-Pattern $gr $TP.cell ($OX + 1) ($OY + 1) }
    }
}

$TRK.dino = @{ above = 3; dur = 240
    step = { param($k)
        if ($k.t -eq 60) { Say 'RAWR!' 2; $k.expr = 'focused'; Invoke-Jump (-5 * $dpi); Emit 'bang' }
        if ($k.t -eq 100) { $k.expr = 'happy' }
    }
    pose = { param($grid, $k)
        for ($c = 2; $c -le 15; $c++) { $grid[0][$c] = 'L'; $grid[1][$c] = 'L' }   # capuz
        if ($k.t -ge 60 -and $k.t -lt 100) { Set-Arms $grid 1 1 }
    }
    draw = { param($gr, $k, $grid)
        Draw-Pattern $gr $TP.spikes ($OX + 2) ($OY - 2)
        Draw-Pattern $gr $TP.tail ($OX - 4) ($OY + 5 + [int][Math]::Floor($k.t / 10) % 2)
    }
}

$TRK.toctoc = @{ above = 2; dur = 230
    init = { param($k) $k.look = 0 }
    step = { param($k)
        if ($k.t -lt 120 -and $k.t % 20 -eq 0) { Emit-At 'bang' ($OX + 19) ($OY + 1) 0 -0.05 8 }
        if ($k.t -eq 70) { Say (Seq 'tr_toctoc_seq' 0) }
        if ($k.t -eq 140) { $k.expr = 'surprised'; Say (Seq 'tr_toctoc_seq' 1) }
    }
    pose = { param($grid, $k) $knock = $k.t -lt 120 -and ([int][Math]::Floor($k.t / 10) % 2) -eq 0; Set-Arms $grid 4 $(if ($knock) { 2 } else { 3 }) }
    draw = { param($gr, $k, $grid) if ($k.t -ge 130) { Draw-Pattern $gr $TP.crack ($OX + 19) ($OY - 1) } }
}

$TRK.breakdance = @{ dur = 230
    init = { param($k) $k.flip = $true; $k.expr = 'excited' }
    step = { param($k)
        if ($k.t % 15 -eq 0) { Emit 'note' }
        if ($k.t % 40 -eq 20) { Invoke-Jump (-4 * $dpi) }
        if ($k.t -eq 225) { Set-Mood 'dizzy' 70 }
    }
    pose = { param($grid, $k) $u = [int][Math]::Floor($k.t / 6) % 2; Set-Arms $grid (2 + 4 * $u) (6 - 4 * $u) }
}

# ---------- motor ----------
$S.trk = $null; $S.nextTrick = 1200

function Start-Trick([string]$name) {
    if (-not (Test-Alive) -or $S.age -gt 0.5 -or $S.drag -or -not $TRK.Contains($name)) { return $false }
    $def = $TRK[$name]
    $S.act = $null
    $k = @{ name = $name; t = 0; dur = $def.dur; sit = $false; flip = $false; hide = $false; dark = $false; walk = $false; expr = $null; look = $null; d = @{} }
    $S.trk = $k; $S.state = 'trick'
    $S.nextTrick = $S.tick + $rand.Next(1800, 4500)
    if ($def.init) { & $def.init $k }
    Say (Line ('tr_' + $name))
    return $true
}

function End-Trick([string]$key) {
    if ($key) { Say (Line $key) }
    $S.trk = $null
    if ($S.state -eq 'trick') { Set-State 'idle' }
}

# todo tick, antes da fisica (por isso os truques podem voar)
function Step-Trick {
    $k = $S.trk
    if (-not $k) { Set-State 'idle'; return }
    $def = $TRK[$k.name]
    if ($def.step) { & $def.step $k }
    if ($S.trk -ne $k) { return }
    $k.t++
    if ($k.t -ge $k.dur) { End-Trick ('tr_' + $k.name + '_fim') }
}

function Set-TrickPose($grid) {
    $k = $S.trk
    if ($k -and $TRK[$k.name].pose) { & $TRK[$k.name].pose $grid $k }
}

function Draw-TrickProps($gr, $grid) {
    if ($S.state -ne 'trick' -or -not $S.trk) { return }
    $k = $S.trk
    if ($TRK[$k.name].draw) { & $TRK[$k.name].draw $gr $k $grid }
}

function Try-StartTrick {
    if ($S.tick -lt $S.nextTrick -or $rand.Next(100) -ge 20) { return $false }
    $names = @($TRK.Keys)
    return (Start-Trick $names[$rand.Next($names.Count)])
}

# ---------- menu ----------
$miTrk = New-Object System.Windows.Forms.ToolStripMenuItem 'Truques'
$miSur = $miTrk.DropDownItems.Add('Surpresa!')
$miSur.Add_Click({ $names = @($TRK.Keys); [void](Start-Trick $names[$rand.Next($names.Count)]) })
[void]$miTrk.DropDownItems.Add('-')
foreach ($name in $TRK.Keys) {
    $label = [string]$Falas.menu_truques.$name
    if (-not $label) { $label = $name }
    $it = $miTrk.DropDownItems.Add($label); $it.Tag = $name
    $it.Add_Click({ param($sender, $e) [void](Start-Trick ([string]$sender.Tag)) })
}
$menu.Items.Insert(2, $miTrk)
