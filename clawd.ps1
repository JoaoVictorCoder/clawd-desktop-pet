# Clawd - companion pixelado que anda na barra de tarefas, sobe nas janelas,
# conversa (via Claude Code) e tem emocoes.
#
# Clique: cutucar | Duplo clique: conversar | Arrastar: carregar/arremessar
# Passar o mouse em cima dele: carinho | Botao direito: menu

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$MODEL = 'haiku'   # modelo usado nas conversas (haiku = mais rapido)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class Win {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);

    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int v, int size);

    // janelas visiveis, em ordem de profundidade (a primeira e a de cima)
    public static List<IntPtr> Handles = new List<IntPtr>();
    public static List<RECT> Rects = new List<RECT>();
    static uint myPid = (uint)Process.GetCurrentProcess().Id;

    static string ClassOf(IntPtr h) { StringBuilder sb = new StringBuilder(64); GetClassName(h, sb, 64); return sb.ToString(); }

    public static string TitleOf(IntPtr h) { StringBuilder sb = new StringBuilder(256); GetWindowText(h, sb, 256); return sb.ToString(); }

    static bool GetBounds(IntPtr h, out RECT r) {
        if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) == 0) return true;
        return GetWindowRect(h, out r);
    }

    static bool Cloaked(IntPtr h) { int c; return DwmGetWindowAttribute(h, 14, out c, 4) == 0 && c != 0; }

    static bool Usable(IntPtr h) {
        if (!IsWindowVisible(h) || IsIconic(h) || Cloaked(h)) return false;
        if ((GetWindowLong(h, -20) & 0x80) != 0) return false;
        if (GetWindowTextLength(h) == 0) return false;
        uint pid; GetWindowThreadProcessId(h, out pid);
        if (pid == myPid) return false;
        string c = ClassOf(h);
        return c != "Progman" && c != "WorkerW" && c != "Shell_TrayWnd" && c != "Shell_SecondaryTrayWnd";
    }

    public static void Refresh() {
        Handles.Clear(); Rects.Clear();
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            RECT r;
            if (Usable(h) && GetBounds(h, out r) && r.Right - r.Left > 120 && r.Bottom - r.Top > 60) { Handles.Add(h); Rects.Add(r); }
            return true;
        }, IntPtr.Zero);
    }

    static bool Covered(int idx, int x, int y) {
        for (int j = 0; j < idx; j++) {
            RECT o = Rects[j];
            if (x >= o.Left && x < o.Right && y >= o.Top && y < o.Bottom) return true;
        }
        return false;
    }

    // janela cujo topo visivel foi cruzado entre y0 e y1 na coluna cx
    public static int FindLanding(int cx, int y0, int y1, int minTop) {
        for (int i = 0; i < Rects.Count; i++) {
            RECT r = Rects[i];
            if (r.Top <= minTop) continue;
            if (r.Top >= y0 && r.Top <= y1 && cx >= r.Left + 4 && cx < r.Right - 4 && !Covered(i, cx, r.Top)) return i;
        }
        return -1;
    }

    public static bool PickTarget(int footY, int minTop, int areaL, int areaR, int seed, out int tx, out int ttop) {
        Random rnd = new Random(seed);
        List<int> c = new List<int>();
        for (int i = 0; i < Rects.Count; i++) {
            RECT r = Rects[i];
            if (r.Top > minTop + 30 && r.Top < footY - 50 && r.Right - r.Left > 160) c.Add(i);
        }
        for (int t = 0; t < 25 && c.Count > 0; t++) {
            int i = c[rnd.Next(c.Count)]; RECT r = Rects[i];
            int lo = Math.Max(r.Left + 40, areaL + 60), hi = Math.Min(r.Right - 40, areaR - 60);
            if (hi <= lo) continue;
            int x = rnd.Next(lo, hi);
            if (!Covered(i, x, r.Top)) { tx = x; ttop = r.Top; return true; }
        }
        tx = 0; ttop = 0; return false;
    }

    public static bool Live(IntPtr h, out RECT r) {
        r = new RECT();
        if (!IsWindow(h) || !IsWindowVisible(h) || IsIconic(h) || Cloaked(h)) return false;
        return GetBounds(h, out r);
    }

    public static bool OnTop(IntPtr h, int x) {
        int i = Handles.IndexOf(h);
        if (i < 0) return true;
        return !Covered(i, x, Rects[i].Top);
    }

    public static string FgInfo(out IntPtr h) {
        h = GetForegroundWindow();
        uint pid; GetWindowThreadProcessId(h, out pid);
        if (h == IntPtr.Zero || pid == myPid) return null;
        string name = "";
        try { name = Process.GetProcessById((int)pid).ProcessName; } catch { }
        return name + "|" + TitleOf(h);
    }

    public static string ProcPathOf(IntPtr h) {
        uint pid; GetWindowThreadProcessId(h, out pid);
        try { return Process.GetProcessById((int)pid).MainModule.FileName; } catch { return ""; }
    }

    public static bool IsFullscreen(IntPtr h, int L, int T, int R, int B) {
        if (h == IntPtr.Zero) return false;
        string c = ClassOf(h);
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd") return false;
        uint pid; GetWindowThreadProcessId(h, out pid);
        if (pid == myPid) return false;
        RECT r; if (!GetBounds(h, out r)) return false;
        return r.Left <= L && r.Top <= T && r.Right >= R && r.Bottom >= B;
    }

    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO p);

    // segundos desde o ultimo uso de mouse/teclado
    public static double IdleSeconds() {
        LASTINPUTINFO i = new LASTINPUTINFO();
        i.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref i)) return 0;
        return unchecked((uint)Environment.TickCount - i.dwTime) / 1000.0;
    }

    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);

    // print da janela (mesmo coberta por outras), reduzido e em JPEG base64
    public static string CaptureBase64(IntPtr h, int maxSide) {
        RECT wr, vr;
        if (!Live(h, out vr) || !GetWindowRect(h, out wr)) return null;
        int w = wr.Right - wr.Left, hh = wr.Bottom - wr.Top;
        if (w < 50 || hh < 50 || w > 10000 || hh > 10000) return null;
        Rectangle crop = new Rectangle(vr.Left - wr.Left, vr.Top - wr.Top, vr.Right - vr.Left, vr.Bottom - vr.Top);
        crop.Intersect(new Rectangle(0, 0, w, hh));
        if (crop.Width < 50 || crop.Height < 50) return null;
        using (Bitmap full = new Bitmap(w, hh)) {
            bool ok;
            using (Graphics g = Graphics.FromImage(full)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
            if (!ok || Blank(full, crop)) {
                using (Graphics g = Graphics.FromImage(full)) { g.CopyFromScreen(wr.Left, wr.Top, 0, 0, new Size(w, hh)); }
            }
            double s = Math.Min(1.0, (double)maxSide / Math.Max(crop.Width, crop.Height));
            int ow = Math.Max(1, (int)(crop.Width * s)), oh = Math.Max(1, (int)(crop.Height * s));
            using (Bitmap small = new Bitmap(ow, oh)) {
                using (Graphics g = Graphics.FromImage(small)) {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.DrawImage(full, new Rectangle(0, 0, ow, oh), crop, GraphicsUnit.Pixel);
                }
                using (MemoryStream ms = new MemoryStream()) { small.Save(ms, ImageFormat.Jpeg); return Convert.ToBase64String(ms.ToArray()); }
            }
        }
    }

    // apps com aceleracao de video as vezes devolvem um print todo preto
    static bool Blank(Bitmap b, Rectangle r) {
        for (int i = 1; i < 8; i++)
            for (int j = 1; j < 8; j++) {
                Color c = b.GetPixel(r.Left + r.Width * i / 8, r.Top + r.Height * j / 8);
                if (c.R + c.G + c.B > 30) return false;
            }
        return true;
    }
}
"@ -ReferencedAssemblies System.Drawing
[Win]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$logPath = Join-Path $here 'clawd.log'
function Write-Log([string]$m) { try { Add-Content -Path $logPath -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $m) -Encoding UTF8 } catch {} }

$g0 = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$dpi = $g0.DpiX / 96.0
$g0.Dispose()

# ---------- constantes ----------
$COLS = 18; $ROWS = 10          # sprite
$OX = 6; $OY = 12               # posicao do sprite dentro da janela (em celulas)
$FW = 30; $FH = 32              # janela principal (em celulas): espaco pras particulas em cima e a linha de pesca embaixo
$PX = [int][Math]::Max(2, [Math]::Round(4 * $dpi))
$SW = $COLS * $PX; $SH = $ROWS * $PX
$GRAV = 0.9 * $dpi
$rand = New-Object System.Random

function New-Brush($r, $g, $b) { New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($r, $g, $b)) }
$BR = @{
    'O' = New-Brush 217 119 87     # corpo
    'K' = New-Brush 25 25 25       # olhos
    'R' = New-Brush 232 72 104     # coracao / raiva
    'P' = New-Brush 240 150 140    # bochecha
    'B' = New-Brush 120 175 255    # lagrima / zzz / suor
    'Y' = New-Brush 255 206 64     # estrela / exclamacao
    'N' = New-Brush 175 135 255    # nota musical
    'W' = New-Brush 245 245 245    # cabelo branco / fantasma
    'G' = New-Brush 150 150 162    # lapide
    'D' = New-Brush 70 70 82       # letras da lapide
    'M' = New-Brush 115 80 50      # terra
    'L' = New-Brush 80 170 80      # caule
    'C' = New-Brush 140 95 55      # bengala
}

# cor do corpo desbotando com a idade (0 = jovem, 10 = bem velhinho)
$AGEBR = @(for ($i = 0; $i -le 10; $i++) {
    $a = $i / 10.0
    New-Brush ([int](217 + (178 - 217) * $a)) ([int](119 + (160 - 119) * $a)) ([int](87 + (152 - 87) * $a))
})

$LYING = @(
    '..................',
    '..................',
    '...O.O......O.O...',
    '...O.O......O.O...',
    '..OOOOOOOOOOOOOO..',
    '..OOKOKOOOOKOKOO..',
    'OOOOOKOOOOOOKOOOOO',
    'OOOOKOKOOOOKOKOOOO',
    '..OOOOOOOOOOOOOO..',
    '..OOOOOOOOOOOOOO..'
)
$GRAVE = @(
    '......GGGGGGG.....',
    '.....GGGGGGGGG....',
    '....GGGGGGGGGGG...',
    '....GDDDGDGDDDG...',
    '....GDGDGDGDGDG...',
    '....GDDGGDGDDDG...',
    '....GDGDGDGDGGG...',
    '.Y..GGGGGGGGGGG.R.',
    '.L..GGGGGGGGGGG.L.',
    'MMMMMMMMMMMMMMMMMM'
)

$EYES = @{
    neutral   = @('.K.', '.K.', '...')
    thinking  = @('.K.', '.K.', '...')
    closed    = @('...', 'KKK', '...')
    sleep     = @('...', 'KKK', '...')
    happy     = @('.K.', 'K.K', '...')
    love      = @('R.R', 'RRR', '.R.')
    sad       = @('...', '.K.', '.K.')
    angry     = @('K..', '.K.', '.K.')
    surprised = @('KKK', 'K.K', 'KKK')
    scared    = @('KKK', 'K.K', 'KKK')
    dizzy     = @('K.K', '.K.', 'K.K')
    excited   = @('.Y.', 'YYY', '.Y.')
    sleepy    = @('...', 'KKK', '.K.')
}

$PAT = @{
    heart = @('.R.R.', 'RRRRR', 'RRRRR', '.RRR.', '..R..')
    z     = @('BBB', '..B', '.B.', 'B..', 'BBB')
    bang  = @('Y', 'Y', 'Y', '.', 'Y')
    what  = @('YYY', '..Y', '.Y.', '...', '.Y.')
    star  = @('.Y.', 'YYY', '.Y.')
    note  = @('..NN', '..N.', '..N.', 'NNN.', 'NN..')
    sweat = @('.B.', 'BBB', '.B.')
    anger = @('RR.RR', 'R...R', '.....', 'R...R', 'RR.RR')
    tear  = @('B', 'B')
    ghost = @('..WWWWWW..', '.WWWWWWWW.', '.WWKWWKWW.', 'WWWKWWKWWW', '.WWWWWWWW.', '.WWWWWWWW.', '.WW.WW.WW.', '.W..W..W..')
}

# ---------- falas ----------
$Falas = Get-Content (Join-Path $here 'falas.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Line([string]$key, $vars) {
    $list = @($Falas.$key)
    if ($list.Count -eq 0 -or -not $list[0]) { return '' }
    $t = [string]$list[$rand.Next($list.Count)]
    if ($vars) { foreach ($k in $vars.Keys) { $t = $t.Replace('{' + $k + '}', [string]$vars[$k]) } }
    return $t
}

function Get-AppLine([string]$info) {
    $low = $info.ToLower()
    foreach ($p in $Falas.apps.PSObject.Properties) {
        if ($low -match $p.Name) { $l = @($p.Value); return @{ key = $p.Name; text = [string]$l[$rand.Next($l.Count)] } }
    }
    return $null
}

function Get-ShortTitle([string]$t) {
    $parts = $t -split ' - '
    $s = $parts[$parts.Count - 1].Trim()
    if ($s.Length -gt 28) { $s = $s.Substring(0, 28) + '...' }
    return $s
}

# ---------- estado ----------
$S = @{
    sx = 0.0; sy = 0.0; vx = 0.0; vy = 0.0
    state = 'idle'; stateT = 60; dir = 1; look = 0; lookY = 0
    speed = 1.6 * $dpi; frame = 0; blink = 0; tick = 0; squash = 0
    drag = $false; moved = $false; dragMood = 'scared'; dragSaid = $false
    off = [System.Drawing.Point]::Empty; down = [System.Drawing.Point]::Empty; last = [System.Drawing.Point]::Empty
    dvx = 0.0; dvy = 0.0
    plat = [IntPtr]::Zero; pr = $null; platLeft = 0; platTop = 0
    mood = 'neutral'; moodT = 0; energy = 100.0; social = 70.0
    pokes = New-Object System.Collections.ArrayList
    petAcc = 0.0; hoverTick = 0; lastHover = [System.Drawing.Point]::Empty
    pendingClick = 0; suppressUp = $false
    thrown = $false; aiming = $false; tx = 0; ttop = 0
    lastFg = [IntPtr]::Zero; fgInfo = '|'; lastComment = -9999; lastWhee = -9999
    nextChatter = 400; nextPeek = 6000; hidden = $false; lastErr = -9999
    age = 0.0; deadT = 0; wasOld = $false; ghostOn = $false; gx = 0.0; gy = 0.0
}
$Parts = New-Object System.Collections.ArrayList   # particulas
$Balloon = @{ active = $false; text = ''; shown = 0; life = 0; prio = 0; hold = $false; w = 10; boxH = 10; tail = 10 }
$Chat = @{ busy = $false; proc = $null; out = $null; err = $null; start = 0; exe = $null; kind = 'chat'; img = $null; hist = New-Object System.Collections.ArrayList }

# config: ver = manda print da janela ativa nas conversas; espiar = comenta sozinho o que ve
$cfgPath = Join-Path $here 'config.json'
# envelhecer = envelhece e morre com o PC parado; morte_min = minutos parado ate morrer
$CFG = @{ ver = $true; espiar = $true; envelhecer = $true; morte_min = 10 }
if (Test-Path $cfgPath) {
    try {
        $j = Get-Content $cfgPath -Raw | ConvertFrom-Json
        foreach ($k in 'ver', 'espiar', 'envelhecer') { if ($null -ne $j.$k) { $CFG[$k] = [bool]$j.$k } }
        if ($j.morte_min -gt 0) { $CFG.morte_min = [double]$j.morte_min }
    } catch {}
}
function Save-Config { try { $CFG | ConvertTo-Json | Set-Content -Path $cfgPath -Encoding UTF8 } catch {} }

# Claude Code e opcional: sem ele o Clawd so usa as falas prontas
$claudeCands = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }) +
    @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\claude.exe", "$HOME\.local\bin\claude.exe", "$env:APPDATA\npm\claude.cmd")
foreach ($cand in $claudeCands) {
    if ($cand -and (Test-Path $cand)) { $Chat.exe = $cand; break }
}
$memPath = Join-Path $here 'memoria.json'
if (Test-Path $memPath) {
    try { foreach ($h in @(Get-Content $memPath -Raw -Encoding UTF8 | ConvertFrom-Json)) { [void]$Chat.hist.Add(@{ r = $h.r; t = $h.t }) } } catch {}
}

# ---------- janela principal ----------
function Set-ToolWindow($f) {
    $ex = [Win]::GetWindowLong($f.Handle, -20)
    [Win]::SetWindowLong($f.Handle, -20, ($ex -bor 0x80 -bor 0x08000000)) | Out-Null
}
$dbProp = [System.Windows.Forms.Form].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance')

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.StartPosition = 'Manual'
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::Magenta
$form.TransparencyKey = [System.Drawing.Color]::Magenta
$form.ClientSize = New-Object System.Drawing.Size ($FW * $PX), ($FH * $PX)
$form.Text = 'Clawd'
$dbProp.SetValue($form, $true)

# ---------- balao de fala ----------
$bb = [int][Math]::Max(2, [Math]::Round(2 * $dpi))
$pad = [int](8 * $dpi)
$maxW = [int](220 * $dpi)
$font = New-Object System.Drawing.Font ('Segoe UI Semibold', 10)
$tflags = [System.Windows.Forms.TextFormatFlags]'WordBreak, NoPrefix, NoPadding'
$dark = New-Brush 40 40 40
$white = New-Brush 255 255 255
$textColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$bub = New-Object System.Windows.Forms.Form
$bub.FormBorderStyle = 'None'
$bub.StartPosition = 'Manual'
$bub.ShowInTaskbar = $false
$bub.TopMost = $true
$bub.BackColor = [System.Drawing.Color]::Magenta
$bub.TransparencyKey = [System.Drawing.Color]::Magenta
$bub.Location = New-Object System.Drawing.Point -32000, -32000
$bub.Size = New-Object System.Drawing.Size 40, 40
$dbProp.SetValue($bub, $true)

$bub.Add_Paint({
    param($sender, $e)
    $gr = $e.Graphics; $w = $Balloon.w; $h = $Balloon.boxH; $b = $bb; $t = $Balloon.tail
    $gr.FillRectangle($dark, $b, 0, $w - 2 * $b, $h)
    $gr.FillRectangle($dark, 0, $b, $w, $h - 2 * $b)
    $gr.FillRectangle($white, $b, $b, $w - 2 * $b, $h - 2 * $b)
    $gr.FillRectangle($dark, $t - 3 * $b, $h - $b, 6 * $b, $b); $gr.FillRectangle($white, $t - 2 * $b, $h - $b, 4 * $b, $b)
    $gr.FillRectangle($dark, $t - 2 * $b, $h, 4 * $b, $b); $gr.FillRectangle($white, $t - $b, $h, 2 * $b, $b)
    $gr.FillRectangle($dark, $t - $b, $h + $b, 2 * $b, $b)
    $txt = $Balloon.text.Substring(0, [Math]::Min($Balloon.shown, $Balloon.text.Length))
    $rect = New-Object System.Drawing.Rectangle $pad, $pad, ($w - 2 * $pad + 2), ($h - 2 * $pad + 4)
    [System.Windows.Forms.TextRenderer]::DrawText($gr, $txt, $font, $rect, $textColor, $tflags)
})
$bub.Add_MouseDown({ Hide-Bubble })

function Say([string]$text, [int]$prio = 1, [switch]$Hold) {
    if (-not $text -or $S.hidden) { return }
    if ($Balloon.active -and $Balloon.prio -gt $prio) { return }
    $Balloon.text = $text; $Balloon.shown = 0; $Balloon.prio = $prio; $Balloon.hold = [bool]$Hold
    $Balloon.life = 50 + [int]($text.Length * 1.5)
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($text, $font, (New-Object System.Drawing.Size $maxW, 0), $tflags)
    $Balloon.w = [Math]::Max($sz.Width + 2 * $pad, 10 * $bb)
    $Balloon.boxH = $sz.Height + 2 * $pad
    $bub.Size = New-Object System.Drawing.Size $Balloon.w, ($Balloon.boxH + 2 * $bb)
    $Balloon.active = $true
    Update-Bubble
    $bub.Invalidate()
}

function Hide-Bubble {
    $Balloon.active = $false; $Balloon.prio = 0
    $bub.Location = New-Object System.Drawing.Point -32000, -32000
}

function Update-Bubble {
    if (-not $Balloon.active) { return }
    $area = Get-Area
    $cx = $S.sx + $SW / 2
    $top = $S.sy - 2 * $PX
    if ($S.ghostOn) { $cx = $S.sx + ($S.gx - $OX + 5) * $PX; $top = $S.sy + ($S.gy - $OY - 1) * $PX }   # fala o fantasminha
    $x = [int]($cx - $Balloon.w / 2)
    $x = [Math]::Max($area.Left + 4, [Math]::Min($x, $area.Right - $Balloon.w - 4))
    $y = [int]($top - $bub.Height)
    $y = [Math]::Max($area.Top + 4, $y)
    $Balloon.tail = [int][Math]::Max(4 * $bb, [Math]::Min($cx - $x, $Balloon.w - 4 * $bb))
    if ($bub.Left -ne $x -or $bub.Top -ne $y) { $bub.Location = New-Object System.Drawing.Point $x, $y }
}

# ---------- caixa de conversa ----------
$inp = New-Object System.Windows.Forms.Form
$inp.FormBorderStyle = 'None'
$inp.StartPosition = 'Manual'
$inp.ShowInTaskbar = $false
$inp.TopMost = $true
$inp.AutoScaleMode = 'None'
$inp.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$inp.ClientSize = New-Object System.Drawing.Size ([int](300 * $dpi)), ([int](62 * $dpi))
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'Fale com o Clawd  (Enter envia, Esc fecha)'
$lbl.ForeColor = [System.Drawing.Color]::FromArgb(217, 119, 87)
$lbl.Font = New-Object System.Drawing.Font ('Segoe UI', 9)
$lbl.AutoSize = $true
$lbl.Location = New-Object System.Drawing.Point ([int](8 * $dpi)), ([int](5 * $dpi))
$tb = New-Object System.Windows.Forms.TextBox
$tb.BorderStyle = 'FixedSingle'
$tb.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 55)
$tb.ForeColor = [System.Drawing.Color]::White
$tb.Font = New-Object System.Drawing.Font ('Segoe UI', 11)
$tb.Location = New-Object System.Drawing.Point ([int](8 * $dpi)), ([int](26 * $dpi))
$tb.Width = $inp.ClientSize.Width - [int](16 * $dpi)
$inp.Controls.Add($lbl); $inp.Controls.Add($tb)
$tb.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq 'Return') {
        $e.SuppressKeyPress = $true
        $msg = $tb.Text.Trim(); $tb.Clear(); $inp.Hide()
        if ($msg) { Start-Chat $msg }
    } elseif ($e.KeyCode -eq 'Escape') {
        $e.SuppressKeyPress = $true; $inp.Hide()
    }
})
$inp.Add_Deactivate({ $inp.Hide() })

function Show-Input {
    $area = Get-Area
    $x = [int]($S.sx + $SW / 2 - $inp.Width / 2)
    $x = [Math]::Max($area.Left + 4, [Math]::Min($x, $area.Right - $inp.Width - 4))
    $y = [Math]::Max($area.Top + 4, [int]($S.sy - $inp.Height - 3 * $PX))
    $inp.Location = New-Object System.Drawing.Point $x, $y
    $Chat.img = Get-Snapshot   # antes da caixa aparecer, pra pegar a janela do usuario
    if ($Balloon.prio -lt 3) { Hide-Bubble }
    if ($S.state -eq 'sleep') { Set-State 'idle' }
    elseif ($S.state -ne 'idle') { Set-State 'idle' }
    $S.stateT = 300
    $inp.Show(); $inp.Activate(); [Win]::SetForegroundWindow($inp.Handle) | Out-Null; $tb.Focus() | Out-Null
}

# ---------- conversa com o Claude ----------
function Get-Context {
    $parts = $S.fgInfo -split '\|', 2
    $on = 'cima da barra'
    if ($S.plat -ne [IntPtr]::Zero) { $on = 'cima da janela ' + (Get-ShortTitle ([Win]::TitleOf($S.plat))) }
    $title = $parts[1]; if ($title.Length -gt 60) { $title = $title.Substring(0, 60) }
    "{0:HH:mm}, humor {1}, energia {2}, carencia {3}. Usuario em: {4} - {5}. Voce esta em {6}." -f (Get-Date), (Get-Expr), [int]$S.energy, [int](100 - $S.social), $parts[0], $title, $on
}

# apps onde ele nunca espia (senhas, bancos, abas anonimas)
$PRIVATE = 'senha|password|bitwarden|1password|keepass|lastpass|dashlane|nubank|itau|bradesco|santander|caixa econ|banco|bank|inprivate|incognito|an.nima|privad'

# print menor = menos tokens (~ largura x altura / 750)
function Get-Snapshot([int]$maxSide = 768) {
    if (-not $CFG.ver -or $S.lastFg -eq [IntPtr]::Zero -or $S.fgInfo -match $PRIVATE) { return $null }
    try { return [Win]::CaptureBase64($S.lastFg, $maxSide) } catch { Write-Log ("print: " + $_); return $null }
}

function Get-Recent([int]$n) {
    @($Chat.hist | Select-Object -Last $n | ForEach-Object { if ($_.r -eq 'u') { 'Usuario: ' + $_.t } else { 'Clawd: ' + $_.t } })
}

function Start-Chat([string]$msg) {
    if ($Chat.busy) { Say (Line 'ocupado') 2; return }
    [void]$Chat.hist.Add(@{ r = 'u'; t = $msg })
    $S.social = [Math]::Min(100.0, $S.social + 25)
    $prompt = (Get-Context) + "`n" + ((Get-Recent 6) -join "`n")
    Invoke-Claude $prompt $Chat.img 'chat'
    $Chat.img = $null
}

function Start-Peek {
    if (-not $Chat.exe) { return }
    $img = Get-Snapshot 512
    if (-not $img) { return }
    $prompt = (Get-Context) + "`nEspiou a tela (print). Comente. Nao repita: " + ((Get-Recent 2) -join ' / ')
    Invoke-Claude $prompt $img 'peek'
}

function Invoke-Claude([string]$prompt, [string]$img, [string]$kind) {
    $Chat.kind = $kind
    if (-not $Chat.exe) {
        if ($kind -eq 'chat') { $Balloon.prio = 0; Say (Line 'sem_claude_instalado') 3; Set-Mood 'sad' 60 }
        return
    }
    $content = @()
    if ($img) { $content += @{ type = 'image'; source = @{ type = 'base64'; media_type = 'image/jpeg'; data = $img } } }
    $content += @{ type = 'text'; text = $prompt }
    $json = @{ type = 'user'; message = @{ role = 'user'; content = $content } } | ConvertTo-Json -Depth 8 -Compress
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $cargs = '-p --model ' + $MODEL + ' --tools "" --no-session-persistence --strict-mcp-config --disable-slash-commands --setting-sources "" --input-format stream-json --output-format stream-json --verbose --system-prompt-file "' + (Join-Path $here 'persona.txt') + '"'
        if ($Chat.exe -match '\.(cmd|bat)$') {
            # instalado via npm: precisa passar pelo cmd
            $psi.FileName = $env:ComSpec
            $psi.Arguments = '/d /s /c ""' + $Chat.exe + '" ' + $cargs + '"'
        } else {
            $psi.FileName = $Chat.exe
            $psi.Arguments = $cargs
        }
        $psi.WorkingDirectory = $here
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $p = [System.Diagnostics.Process]::Start($psi)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + "`n")
        $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $p.StandardInput.Close()
        $Chat.proc = $p; $Chat.out = $p.StandardOutput.ReadToEndAsync(); $Chat.err = $p.StandardError.ReadToEndAsync()
        $Chat.start = $S.tick; $Chat.busy = $true
        if ($kind -eq 'chat') { Say '...' 3 -Hold }
    } catch {
        Finish-Chat '' $_.ToString()
    }
}

function Get-ResultText([string]$out) {
    foreach ($l in ($out -split "`n")) {
        if ($l -match '"type"\s*:\s*"result"') {
            $o = $l | ConvertFrom-Json
            if ($o.is_error) { return @('', [string]$o.result) }
            return @([string]$o.result, '')
        }
    }
    return @('', 'sem resultado')
}

function Step-Chat {
    if (-not $Chat.busy) { return }
    if ($Chat.proc.HasExited -and $Chat.out.IsCompleted) {
        $out = $Chat.out.Result; $err = ''
        if ($Chat.err.IsCompleted) { $err = $Chat.err.Result }
        $Chat.busy = $false
        if ($Chat.proc.ExitCode -ne 0) { Finish-Chat '' ("exit " + $Chat.proc.ExitCode + ": " + $err + $out) }
        else { $res = Get-ResultText $out; Finish-Chat $res[0] ($res[1] + $err) }
    } elseif ($S.tick - $Chat.start -gt 2500) {
        try { $Chat.proc.Kill() } catch {}
        $Chat.busy = $false
        Finish-Chat '' 'timeout'
    } elseif ($Chat.kind -eq 'chat' -and $S.tick % 12 -eq 0) {
        $Balloon.text = '.' * (1 + ($S.tick / 12) % 3); $Balloon.shown = 3; $bub.Invalidate()
    }
}

$EMO = @{ feliz = 'happy'; amor = 'love'; triste = 'sad'; bravo = 'angry'; surpreso = 'surprised'; pensativo = 'thinking'; animado = 'excited'; sono = 'sleepy'; medo = 'scared'; neutro = 'neutral' }

function Finish-Chat([string]$out, [string]$err) {
    $Chat.busy = $false
    $txt = ''
    if ($out) { $txt = $out.Trim() }
    if (-not $txt) {
        if ($err) { Write-Log ("claude: " + $err) }
        if ($Chat.kind -eq 'peek') { return }
        $Balloon.prio = 0; Say (Line 'sem_claude') 3; Set-Mood 'sad' 60
        return
    }
    $mood = 'neutral'
    if ($txt -match '\[(\w+)\]') { $k = $matches[1].ToLower(); if ($EMO.ContainsKey($k)) { $mood = $EMO[$k] } }
    $acts = @([regex]::Matches($txt, '\{(\w+)\}') | ForEach-Object { $_.Groups[1].Value.ToLower() })
    $txt = ($txt -replace '\{\w+\}', '' -replace '\[\w+\]', '' -replace '\*', '' -replace '\s+', ' ').Trim()
    # as vezes a acao vem sem chaves no comeco da fala
    if ($txt -match '^(pular|dan\w+|dormir|explorar|acenar)\b[\s,.:!-]*') { $acts += $matches[1].ToLower(); $txt = $txt.Substring($matches[0].Length) }
    # garante fala curta: fica so com a primeira frase se passar do limite
    if ($txt.Length -gt 80) {
        $m = [regex]::Match($txt, '^.{10,80}?[.!?](\s|$)')
        if ($m.Success) { $txt = $m.Value.Trim() } else { $txt = $txt.Substring(0, 77).Trim() + '...' }
    }
    [void]$Chat.hist.Add(@{ r = 'c'; t = $txt })
    while ($Chat.hist.Count -gt 40) { $Chat.hist.RemoveAt(0) }
    try { ConvertTo-Json @($Chat.hist) -Depth 3 | Set-Content -Path $memPath -Encoding UTF8 } catch {}

    $Balloon.prio = 0
    Say $txt 3
    Set-Mood $mood 180
    foreach ($a in $acts) {
        switch -regex ($a) {
            '^pul' { Invoke-Hop }
            '^dan' { Set-State 'dance' }
            '^dorm' { Set-State 'sleep' }
            '^expl' { [void](Start-Climb) }
            '^acen' { Set-State 'wave' }
        }
    }
}

# ---------- emocoes e particulas ----------
function Test-Alive { $S.state -ne 'dead' -and $S.state -ne 'revive' }

function Get-Expr {
    if (-not (Test-Alive)) { return 'dead' }
    if ($S.state -eq 'sleep') { return 'sleep' }
    if ($S.drag -and $S.moved) { return $S.dragMood }
    if ($S.moodT -gt 0) { return $S.mood }
    if ($S.state -eq 'act' -and $S.actExpr) { return $S.actExpr }
    if ($Chat.busy) { return 'thinking' }
    if ($S.energy -lt 20) { return 'sleepy' }
    if ($S.social -lt 25) { return 'sad' }
    return 'neutral'
}

function Emit([string]$k, [int]$n = 1) {
    for ($i = 0; $i -lt $n; $i++) {
        if ($Parts.Count -gt 24) { return }
        $p = @{ k = $k; x = $OX + 7 + $rand.Next(-4, 5); y = $OY - 5 + $rand.Next(-1, 2); vx = ($rand.NextDouble() - 0.5) * 0.06; vy = -0.07 - $rand.NextDouble() * 0.05; life = 45 + $rand.Next(15) }
        if ($k -eq 'tear') { $p.x = $OX + 5 + $S.look; $p.y = $OY + 5; $p.vx = 0; $p.vy = 0.14; $p.life = 22 }
        if ($k -eq 'z') { $p.x = $OX + 14; $p.y = $OY - 2; $p.vx = 0.05; $p.vy = -0.06 }
        if ($k -eq 'sweat') { $p.x = $OX + 15; $p.y = $OY - 1; $p.vx = 0.03; $p.vy = 0.05; $p.life = 25 }
        [void]$Parts.Add($p)
    }
}

function Set-Mood([string]$m, [int]$t) {
    $S.mood = $m; $S.moodT = $t
    switch ($m) {
        'happy' { Emit 'note' }
        'love' { Emit 'heart' 2 }
        'sad' { Emit 'tear' }
        'angry' { Emit 'anger' }
        'surprised' { Emit 'bang' }
        'scared' { Emit 'sweat' }
        'excited' { Emit 'star' 2 }
        'thinking' { Emit 'what' }
    }
}

function Step-Particles {
    for ($i = $Parts.Count - 1; $i -ge 0; $i--) {
        $p = $Parts[$i]; $p.x += $p.vx; $p.y += $p.vy; $p.life--
        if ($p.life -le 0 -or $p.y -lt 0 -or $p.y -gt $FH) { $Parts.RemoveAt($i) }
    }
    $e = Get-Expr
    $t = $S.tick
    if ($e -eq 'sleep' -and $t % 35 -eq 0) { Emit 'z' }
    if ($e -eq 'love' -and $t % 30 -eq 0) { Emit 'heart' }
    if ($e -eq 'angry' -and $t % 45 -eq 0) { Emit 'anger' }
    if ($e -eq 'sad' -and $t % 90 -eq 0) { Emit 'tear' }
    if ($e -eq 'scared' -and $t % 25 -eq 0) { Emit 'sweat' }
    if ($e -eq 'thinking' -and $t % 70 -eq 0) { Emit 'what' }
    if ($e -eq 'excited' -and $t % 40 -eq 0) { Emit 'star' }
    if ($S.state -eq 'dance' -and $t % 22 -eq 0) { Emit 'note' }
}

# ---------- sprite ----------
function Get-DeadSprite {
    $t = $S.deadT
    $grid = New-Object 'char[][]' $ROWS
    if ($S.state -eq 'dead' -and $t -lt 30) { return Get-Sprite 'scared' }
    if ($S.state -eq 'dead' -and $t -lt 170) {
        for ($r = 0; $r -lt $ROWS; $r++) { $grid[$r] = $LYING[$r].ToCharArray() }
        if ($t -lt 110 -and ($t / 4) % 2 -eq 0) { foreach ($c in 3, 5, 12, 14) { $grid[2][$c] = '.' } }   # perninhas tremendo
        return $grid
    }
    # lapide subindo do chao (a terra fica sempre embaixo)
    $shift = 0
    if ($S.state -eq 'dead') { $shift = [Math]::Max(0, 9 - [int](($t - 170) / 2)) }
    for ($r = 0; $r -lt $ROWS; $r++) {
        if ($r - $shift -ge 0) { $grid[$r] = $GRAVE[$r - $shift].ToCharArray() } else { $grid[$r] = ('.' * $COLS).ToCharArray() }
    }
    $grid[9] = $GRAVE[9].ToCharArray()
    return $grid
}

function Get-Sprite([string]$force) {
    if (-not $force -and ($S.state -eq 'dead' -or $S.state -eq 'revive')) { return Get-DeadSprite }
    $expr = Get-Expr
    if ($force) { $expr = $force }
    if ($S.age -ge 0.5 -and $expr -eq 'neutral') { $expr = 'sleepy' }
    $grid = New-Object 'char[][]' $ROWS
    for ($r = 0; $r -lt $ROWS; $r++) { $grid[$r] = ('.' * $COLS).ToCharArray() }
    for ($r = 0; $r -lt 8; $r++) { for ($c = 2; $c -le 15; $c++) { $grid[$r][$c] = 'O' } }

    $held = $S.drag -and $S.moved
    $armL = 4; $armR = 4
    if ($held -or $expr -eq 'excited' -or $expr -eq 'scared') { $armL = 1; $armR = 1 }
    elseif ($expr -eq 'sad' -or $expr -eq 'sleepy' -or $expr -eq 'sleep') { $armL = 6; $armR = 6 }
    if ($S.state -eq 'dance') { if ($S.frame -eq 0) { $armL = 1; $armR = 4 } else { $armL = 4; $armR = 1 } }
    if ($S.state -eq 'wave') { $armR = @(1, 3)[$S.frame] }
    foreach ($c in 0, 1) { $grid[$armL][$c] = 'O'; $grid[$armL + 1][$c] = 'O' }
    foreach ($c in 16, 17) { $grid[$armR][$c] = 'O'; $grid[$armR + 1][$c] = 'O' }

    $pat = $EYES[$expr]
    if (-not $pat) { $pat = $EYES.neutral }
    if ($S.blink -gt 0 -and @('neutral', 'thinking', 'sad', 'angry', 'happy') -contains $expr) { $pat = $EYES.closed }
    $lx = 0; $ly = 0
    if (@('neutral', 'sad', 'angry', 'happy', 'surprised', 'sleepy', 'scared') -contains $expr) { $lx = $S.look; $ly = $S.lookY }
    if ($expr -eq 'thinking') { $lx = 1; $ly = -1 }
    for ($i = 0; $i -lt 3; $i++) {
        for ($j = 0; $j -lt 3; $j++) {
            $ch = $pat[$i][$j]; if ($ch -ne '.') { $grid[2 + $ly + $i][4 + $lx + $j] = $ch }
            $ch = $pat[$i][2 - $j]; if ($ch -ne '.') { $grid[2 + $ly + $i][11 + $lx + $j] = $ch }
        }
    }
    if (@('love', 'happy', 'excited') -contains $expr) { $grid[5][3] = 'P'; $grid[5][14] = 'P' }

    # velhice: cabelo branco, depois sobrancelhas, bigode e bengala
    if ($S.age -ge 0.3) { foreach ($c in 4, 6, 7, 10, 11, 13) { $grid[0][$c] = 'W' } }
    if ($S.age -ge 0.6) {
        foreach ($c in 3, 4, 5, 6, 7, 10, 11, 12, 13, 14) { $grid[0][$c] = 'W' }
        foreach ($c in 4, 5, 6, 11, 12, 13) { $grid[1][$c] = 'W' }
        foreach ($c in 6, 7, 8, 9, 10, 11) { $grid[5][$c] = 'W' }
        $cc = 17; $hc = 16
        if ($S.look -lt 0) { $cc = 0; $hc = 1 }
        for ($r = 3; $r -lt $ROWS; $r++) { $grid[$r][$cc] = 'C' }
        $grid[3][$hc] = 'C'
    }

    if ($S.state -eq 'act') { Set-ActPose $grid }

    $lifted = @()
    if (-not $held -and (@('walk', 'run', 'seek', 'goto', 'dance') -contains $S.state -or ($S.state -eq 'act' -and $S.actWalk))) {
        if ($S.frame -eq 0) { $lifted = 5, 14 } else { $lifted = 3, 12 }
    }
    foreach ($c in 3, 5, 12, 14) {
        $grid[8][$c] = 'O'
        if ($lifted -notcontains $c) { $grid[9][$c] = 'O' }
    }

    if ($S.state -eq 'sleep' -or $S.state -eq 'crouch' -or $S.squash -gt 0 -or $S.age -ge 0.6 -or ($S.state -eq 'act' -and $S.actSit)) {
        for ($r = $ROWS - 1; $r -gt 0; $r--) { $grid[$r] = $grid[$r - 1] }
        $grid[0] = ('.' * $COLS).ToCharArray()
    }
    return $grid
}

function Draw-Pattern($gr, $pat, [double]$x, [double]$y) {
    $bx = [int][Math]::Round($x); $by = [int][Math]::Round($y)
    for ($i = 0; $i -lt $pat.Count; $i++) {
        $row = $pat[$i]
        for ($j = 0; $j -lt $row.Length; $j++) {
            $ch = $row[$j]
            if ($ch -ne '.') { $gr.FillRectangle($BR["$ch"], ($bx + $j) * $PX, ($by + $i) * $PX, $PX, $PX) }
        }
    }
}

$form.Add_Paint({
    param($sender, $e)
    try {
        $gr = $e.Graphics
        $grid = Get-Sprite
        $body = $AGEBR[[int][Math]::Round($S.age * 10)]
        $shx = $OX
        if (($S.state -eq 'dead' -and $S.deadT -lt 30) -or ($S.state -eq 'revive' -and $S.deadT -ge 25)) { $shx += ($S.tick % 2) * 2 - 1 }   # tremedeira
        for ($r = 0; $r -lt $ROWS; $r++) {
            $row = $grid[$r]
            for ($c = 0; $c -lt $COLS; $c++) {
                $ch = $row[$c]
                if ($ch -eq 'O') { $gr.FillRectangle($body, ($shx + $c) * $PX, ($OY + $r) * $PX, $PX, $PX) }
                elseif ($ch -ne '.') { $gr.FillRectangle($BR["$ch"], ($shx + $c) * $PX, ($OY + $r) * $PX, $PX, $PX) }
            }
        }
        Draw-ActProps $gr
        foreach ($p in $Parts) { Draw-Pattern $gr $PAT[$p.k] $p.x $p.y }
        if ($S.ghostOn) { Draw-Pattern $gr $PAT.ghost $S.gx $S.gy }
        if ((Get-Expr) -eq 'dizzy') {
            $a = $S.tick * 0.18
            foreach ($k in 0, 1) {
                $ang = $a + $k * [Math]::PI
                Draw-Pattern $gr $PAT.star ($OX + 8 + 7 * [Math]::Cos($ang)) ($OY - 2 + 1.5 * [Math]::Sin($ang))
            }
        }
    } catch {}
})

# ---------- comportamento ----------
function Get-Area {
    $pt = New-Object System.Drawing.Point ([int]($S.sx + $SW / 2)), ([int]($S.sy + $SH / 2))
    [System.Windows.Forms.Screen]::FromPoint($pt).WorkingArea
}

function Set-State([string]$name) {
    $S.state = $name
    switch ($name) {
        'walk'  { $S.dir = @(-1, 1)[$rand.Next(2)]; $S.stateT = $rand.Next(60, 260) }
        'idle'  { $S.stateT = $rand.Next(40, 160) }
        'sleep' { $S.stateT = 999999 }
        'run'   { $S.stateT = 70 }
        'seek'  { $S.stateT = 300 }
        'dance' { $S.stateT = 160 }
        'wave'  { $S.stateT = 45 }
        'goto'  { $S.stateT = 450 }
        'crouch' { $S.stateT = 12 }
    }
}

function Invoke-Jump([double]$v) { $S.plat = [IntPtr]::Zero; $S.vy = $v }
function Invoke-Hop { Invoke-Jump (-11 * $dpi); $S.vx = 0; if ($S.state -ne 'dance') { Set-State 'idle' } }

function Start-Climb {
    $area = Get-Area
    $tx = 0; $tt = 0
    if ([Win]::PickTarget([int]($S.sy + $SH), $area.Top + 5, $area.Left, $area.Right, $rand.Next(), [ref]$tx, [ref]$tt)) {
        $S.tx = $tx; $S.ttop = $tt
        Set-State 'goto'
        return $true
    }
    return $false
}

function Pick-State {
    if ($S.age -gt 0.5) { if ($rand.Next(100) -lt 55) { Set-State 'walk' } else { Set-State 'idle' }; return }   # velhinho nao pula
    if ($S.energy -lt 15) { Set-State 'sleep'; Say (Line 'sono'); return }
    if (Try-StartActivity) { return }
    if ($S.social -lt 25 -and $rand.Next(100) -lt 45) {
        Set-State 'seek'
        if ($rand.Next(2) -eq 0) { Say (Line 'solitario') }
        return
    }
    $r = $rand.Next(100)
    if ($r -lt 38) { Set-State 'walk' }
    elseif ($r -lt 60) { Set-State 'idle' }
    elseif ($r -lt 80) { if (-not (Start-Climb)) { Set-State 'walk' } }
    elseif ($r -lt 86) { Invoke-Hop }
    elseif ($r -lt 91) { Set-State 'seek'; Emit 'what' }
    elseif ($r -lt 95) { Set-State 'dance' }
    elseif ($S.energy -lt 70) { Set-State 'sleep'; Say (Line 'sono') }
    else { Set-State 'idle' }
}

function Move-Walk([double]$spd, [bool]$allowFall = $false) {
    $nx = $S.sx + $S.dir * $spd
    $ncx = $nx + $SW / 2
    $r = $S.pr
    if ($S.plat -ne [IntPtr]::Zero -and $r) {
        if ($ncx -lt $r.Left + 2 -or $ncx -gt $r.Right - 2) {
            if ($allowFall -or $rand.Next(100) -lt 35) {
                Invoke-Jump (-4 * $dpi); $S.vx = $S.dir * 2 * $dpi
                if (-not $allowFall -and $rand.Next(2) -eq 0) { Say (Line 'wiii') }
                return
            }
            $S.dir = -$S.dir
            return
        }
    }
    $S.sx = $nx
    $every = 5; if ($spd -gt $S.speed * 1.5) { $every = 3 }
    if ($S.tick % $every -eq 0) { $S.frame = 1 - $S.frame }
}

function Step-Behavior {
    if (-not (Test-Alive)) { return }
    $cx = $S.sx + $SW / 2
    $cur = [System.Windows.Forms.Cursor]::Position
    $spd = $S.speed * (1 - 0.75 * $S.age)
    if ((Get-Expr) -eq 'sad') { $spd *= 0.6 }
    switch ($S.state) {
        'walk' { Move-Walk $spd }
        'run' { Move-Walk ($S.speed * 2.6) }
        'seek' {
            $dx = $cur.X - $cx
            if ([Math]::Abs($dx) -lt 30 * $dpi) {
                Set-State 'idle'
                if ($S.social -lt 40) { Say (Line 'achou') }
            } else { $S.dir = [Math]::Sign($dx); Move-Walk ($spd * 1.3) }
        }
        'goto' {
            $dx = $S.tx - $cx
            if ([Math]::Abs($dx) -le 3 * $S.speed) { Set-State 'crouch' }
            else { $S.dir = [Math]::Sign($dx); Move-Walk ($S.speed * 1.4) $true }
        }
        'crouch' {
            if ($S.stateT -le 1) {
                $h = ($S.sy + $SH) - $S.ttop + 30 * $dpi
                Set-State 'idle'
                if ($h -gt 20) { $S.aiming = $true; Invoke-Jump (-[Math]::Sqrt(2 * $GRAV * $h)) }
                return
            }
        }
        'dance' {
            if ($S.tick % 8 -eq 0) { $S.frame = 1 - $S.frame }
            if ($S.tick % 24 -eq 0) { Invoke-Jump (-4 * $dpi) }
        }
        'wave' { if ($S.tick % 7 -eq 0) { $S.frame = 1 - $S.frame } }
        'act' {
            if ($S.actWalk -and $S.tick % 4 -eq 0) { $S.frame = 1 - $S.frame }
            Step-Activity
            return
        }
        'sleep' {
            if ($S.energy -ge 100) { Set-State 'idle'; Set-Mood 'happy' 60; Say (Line 'acordou') }
        }
    }
    $S.stateT--
    if ($S.stateT -le 0) { Pick-State }
}

function Land([double]$impact, [bool]$onWin) {
    $S.vy = 0; $S.vx *= 0.4
    if ($impact -gt 6 * $dpi) { $S.squash = 4 }
    if ($S.thrown) {
        $S.thrown = $false; $S.moodT = 0
        if ($impact -gt 12 * $dpi) { Set-Mood 'dizzy' 120; Say (Line 'tonto') } else { Set-Mood 'happy' 40 }
    } elseif ($S.aiming) {
        $S.aiming = $false
        if ($onWin -and [Math]::Abs($S.platTop - $S.ttop) -lt 8) {
            Set-Mood 'happy' 70
            if ($rand.Next(100) -lt 45) { Say (Line 'pousou_janela' @{ janela = (Get-ShortTitle ([Win]::TitleOf($S.plat))) }) }
        } elseif ($rand.Next(2) -eq 0) { Say (Line 'errou') }
    }
}

function Drop-Plat([string]$why) {
    $S.plat = [IntPtr]::Zero; $S.pr = $null
    if ($why -eq 'gone') { Set-Mood 'scared' 40; if ($rand.Next(100) -lt 60) { Say (Line 'caiu_janela') } }
}

function Invoke-Poke {
    $S.social = [Math]::Min(100.0, $S.social + 4)
    if ($S.state -eq 'sleep') { Set-State 'idle'; Set-Mood 'angry' 70; Say (Line 'acordado'); return }
    [void]$S.pokes.Add($S.tick)
    while ($S.pokes.Count -gt 0 -and $S.pokes[0] -lt $S.tick - 150) { $S.pokes.RemoveAt(0) }
    $n = $S.pokes.Count
    if ($n -ge 6) {
        $S.pokes.Clear(); Set-Mood 'angry' 150; Say (Line 'chega') 2
        $S.dir = -[Math]::Sign([System.Windows.Forms.Cursor]::Position.X - ($S.sx + $SW / 2)); if ($S.dir -eq 0) { $S.dir = 1 }
        $S.state = 'run'; $S.stateT = 80
        return
    }
    if ($n -ge 3) { Set-Mood 'angry' 70; Say (Line 'irritado'); return }
    switch ($rand.Next(3)) {
        0 { Invoke-Hop; Set-Mood 'happy' 50 }
        1 { Set-Mood 'surprised' 40 }
        2 { Set-State 'wave'; Set-Mood 'happy' 50 }
    }
    Say (Line 'cutucar')
}

function Invoke-Pet {
    $S.social = [Math]::Min(100.0, $S.social + 8)
    Emit 'heart' 2
    if ($S.state -eq 'sleep') { return }
    Set-Mood 'love' 120
    if ($rand.Next(100) -lt 45) { Say (Line 'carinho') }
}

# ---------- mouse ----------
$form.Add_MouseDown({
    param($sender, $e)
    if ($e.Button -ne 'Left') { return }
    if (-not (Test-Alive)) { return }
    if ($e.Clicks -ge 2) {
        $S.drag = $false; $S.pendingClick = 0; $S.suppressUp = $true
        Show-Input
        return
    }
    $p = [System.Windows.Forms.Cursor]::Position
    $S.drag = $true; $S.moved = $false; $S.dragSaid = $false
    $S.dragMood = @('scared', 'excited', 'surprised')[$rand.Next(3)]
    $S.off = New-Object System.Drawing.Point ([int]($p.X - $S.sx)), ([int]($p.Y - $S.sy))
    $S.down = $p; $S.last = $p
    $S.dvx = 0; $S.dvy = 0
})

$form.Add_MouseMove({
    param($sender, $e)
    $p = [System.Windows.Forms.Cursor]::Position
    if (-not $S.drag) {
        if ($e.Button -ne 'None' -or -not (Test-Alive)) { return }
        $d = [Math]::Abs($p.X - $S.lastHover.X) + [Math]::Abs($p.Y - $S.lastHover.Y)
        if ($S.tick - $S.hoverTick -lt 15) { $S.petAcc += $d } else { $S.petAcc = 0 }
        $S.lastHover = $p; $S.hoverTick = $S.tick
        if ($S.petAcc -gt 400 * $dpi) { $S.petAcc = 0; Invoke-Pet }
        return
    }
    $S.dvx = $p.X - $S.last.X; $S.dvy = $p.Y - $S.last.Y
    $S.last = $p
    if (-not $S.moved -and [Math]::Abs($p.X - $S.down.X) + [Math]::Abs($p.Y - $S.down.Y) -gt 4) {
        $S.moved = $true; $S.plat = [IntPtr]::Zero; $S.pr = $null
        if ($S.state -eq 'sleep' -or $S.state -eq 'act') { $S.act = $null; Set-State 'idle' }
        if ($rand.Next(100) -lt 45) { Say (Line 'carregado') }
    }
    if ($S.moved) {
        $S.sx = $p.X - $S.off.X; $S.sy = $p.Y - $S.off.Y; $S.vx = 0; $S.vy = 0
        $form.Location = New-Object System.Drawing.Point ([int]($S.sx - $OX * $PX)), ([int]($S.sy - $OY * $PX))
        Update-Bubble
    }
})

$form.Add_MouseUp({
    param($sender, $e)
    if ($e.Button -ne 'Left') { return }
    if ($S.suppressUp) { $S.suppressUp = $false; return }
    if (-not $S.drag) { return }
    $S.drag = $false
    if ($S.moved) {
        $S.vx = [Math]::Max(-40, [Math]::Min(40, $S.dvx))
        $S.vy = [Math]::Max(-40, [Math]::Min(40, $S.dvy))
        Set-State 'idle'
        if ([Math]::Sqrt($S.dvx * $S.dvx + $S.dvy * $S.dvy) -gt 18 * $dpi) {
            $S.thrown = $true; Set-Mood 'scared' 999
            if ($rand.Next(2) -eq 0) { Say (Line 'arremessado') 2 }
        } elseif ($rand.Next(100) -lt 30) { Say (Line 'solto') }
    } else {
        $S.pendingClick = [int]([System.Windows.Forms.SystemInformation]::DoubleClickTime / 30) + 1
    }
})

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Items.Add('Conversar').Add_Click({ Show-Input }) | Out-Null
$menu.Items.Add('Explorar janelas').Add_Click({ if (-not (Start-Climb)) { Say 'Nenhuma janela pra subir agora...' } }) | Out-Null
$menu.Items.Add('Pular').Add_Click({ Invoke-Hop }) | Out-Null
$menu.Items.Add("Dan$([char]0xE7)ar").Add_Click({ Set-State 'dance'; Set-Mood 'happy' 100 }) | Out-Null
$menu.Items.Add('Dormir').Add_Click({ Set-State 'sleep' }) | Out-Null
$menu.Items.Add('-') | Out-Null
$miVer = New-Object System.Windows.Forms.ToolStripMenuItem 'Ver minha tela nas conversas'
$miVer.CheckOnClick = $true; $miVer.Checked = $CFG.ver
$miVer.Add_Click({ $CFG.ver = $miVer.Checked; Save-Config })
$miEsp = New-Object System.Windows.Forms.ToolStripMenuItem 'Espiar e comentar sozinho'
$miEsp.CheckOnClick = $true; $miEsp.Checked = $CFG.espiar
$miEsp.Add_Click({ $CFG.espiar = $miEsp.Checked; Save-Config })
$miAge = New-Object System.Windows.Forms.ToolStripMenuItem 'Envelhecer com o PC parado'
$miAge.CheckOnClick = $true; $miAge.Checked = $CFG.envelhecer
$miAge.Add_Click({ $CFG.envelhecer = $miAge.Checked; Save-Config })
$menu.Items.Add($miAge) | Out-Null
$menu.Items.Add($miVer) | Out-Null
$menu.Items.Add($miEsp) | Out-Null
$menu.Items.Add('Espiar agora').Add_Click({ if (-not $Chat.busy) { Start-Peek } }) | Out-Null
$menu.Items.Add('-') | Out-Null
$menu.Items.Add('Esquecer conversas').Add_Click({ $Chat.hist.Clear(); Remove-Item $memPath -ErrorAction SilentlyContinue; Say (Line 'esqueci') }) | Out-Null
$menu.Items.Add('Sair').Add_Click({ $form.Close() }) | Out-Null
$form.ContextMenuStrip = $menu

. (Join-Path $here 'atividades.ps1')

# ---------- velhice e morte (PC parado) ----------
function Step-Aging {
    if ($S.state -eq 'revive') {
        $S.deadT++
        # o fantasminha mergulha de volta na cova, a lapide treme e ele pula pra fora
        if ($S.ghostOn) {
            $S.gx += (($OX + 4) - $S.gx) * 0.2; $S.gy += (($OY + 3) - $S.gy) * 0.2
            if ($S.deadT -ge 25) { $S.ghostOn = $false }
        }
        if ($S.deadT -ge 50) {
            $S.age = 0; $S.wasOld = $false
            Set-State 'idle'; Invoke-Hop; Set-Mood 'surprised' 60
            Say (Line 'reviveu') 2
        }
        return
    }
    $idle = [Win]::IdleSeconds()
    if ($S.state -eq 'dead') {
        $S.deadT++
        if ($S.deadT -eq 30) { Emit 'sweat' }
        if ($S.deadT -ge 50) {
            # fantasminha sai do corpo e fica assombrando a lapide
            $gt = $S.deadT - 50
            $hx = $OX + 4 + 7 * [Math]::Sin($gt * 0.025)
            $hy = $OY - 9 + [Math]::Sin($gt * 0.1)
            $k = [Math]::Min(1.0, $gt / 80.0)
            $S.gx = ($OX + 4) + ($hx - ($OX + 4)) * $k
            $S.gy = ($OY + 2) + ($hy - ($OY + 2)) * $k
            $S.ghostOn = $true
            if ($gt -eq 90 -or ($gt -gt 90 -and $gt % 500 -eq 0 -and $rand.Next(100) -lt 70)) { Say (Line 'fantasma') }
        }
        if ($idle -lt 2 -and $S.deadT -gt 30) { $S.state = 'revive'; $S.deadT = 0; Hide-Bubble }
        return
    }
    if (-not $CFG.envelhecer) { $S.age = 0; return }

    $total = $CFG.morte_min * 60
    $start = $total * 0.4
    if ($idle -lt 2) {
        # voltou: rejuvenesce rapidinho
        if ($S.age -gt 0) {
            $S.age = [Math]::Max(0.0, $S.age - 0.03)
            if ($S.wasOld -and $S.age -eq 0) { $S.wasOld = $false; Set-Mood 'happy' 60; Say (Line 'rejuvenesceu') 2 }
        }
        return
    }
    $target = [Math]::Max(0.0, [Math]::Min(1.0, ($idle - $start) / ($total - $start)))
    if ($target -gt $S.age) { $S.age = $target }
    if ($S.age -ge 0.3) { $S.wasOld = $true }
    if ($S.age -ge 0.3 -and $S.state -eq 'sleep') { Set-State 'idle' }

    if ($S.age -ge 0.3 -and $S.tick % 450 -eq 0 -and -not $Balloon.active -and $rand.Next(100) -lt 60) { Say (Line 'velho') }
    if ($S.age -ge 1) {
        $S.state = 'dead'; $S.deadT = 0; $S.vx = 0; $S.drag = $false; $S.ghostOn = $false
        $Parts.Clear()
        Hide-Bubble; Say (Line 'morrendo') 3
    }
}

# ---------- loop principal ----------
function Step-Tick {
    $S.tick++
    $t = $S.tick
    if ($S.blink -gt 0) { $S.blink-- } elseif ($rand.Next(110) -eq 0) { $S.blink = 4 }
    if ($S.moodT -gt 0 -and $S.moodT -lt 999) { $S.moodT-- }
    if ($S.squash -gt 0) { $S.squash-- }
    if ($S.pendingClick -gt 0) { $S.pendingClick--; if ($S.pendingClick -eq 0) { Invoke-Poke } }
    Step-Aging

    # necessidades
    if ($t % 100 -eq 0) {
        $h = (Get-Date).Hour
        if ($S.state -eq 'sleep') { $S.energy += 2 } else { $S.energy -= $(if ($h -ge 23 -or $h -lt 6) { 0.35 } else { 0.15 }); $S.social -= 0.5 }
        $S.energy = [Math]::Max(0.0, [Math]::Min(100.0, $S.energy))
        $S.social = [Math]::Max(0.0, [Math]::Min(100.0, $S.social))
    }

    $area = Get-Area
    $cx = $S.sx + $SW / 2

    # janelas
    if ($t % 10 -eq 0) {
        [Win]::Refresh()
        if ($S.plat -ne [IntPtr]::Zero -and -not [Win]::OnTop($S.plat, [int]$cx)) { Drop-Plat 'covered' }

        $fg = [IntPtr]::Zero
        $info = [Win]::FgInfo([ref]$fg)
        $scr = [System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point ([int]$cx), ([int]$S.sy))).Bounds
        $full = [Win]::IsFullscreen($fg, $scr.Left, $scr.Top, $scr.Right, $scr.Bottom)
        if ($full -ne $S.hidden) {
            $S.hidden = $full
            $form.Opacity = $(if ($full) { 0 } else { 1 })
            if ($full) { Hide-Bubble }
        }
        # logo ao abrir, a janela ativa e o proprio Clawd: usa a janela de cima
        if ($S.lastFg -eq [IntPtr]::Zero -and -not $info -and [Win]::Handles.Count -gt 0) {
            $S.lastFg = [Win]::Handles[0]; $S.fgInfo = '|' + [Win]::TitleOf($S.lastFg)
        }
        if ($info -and $fg -ne $S.lastFg) {
            $S.lastFg = $fg; $S.fgInfo = $info
            # abriu um jogo: as vezes ele pega um controle e joga junto
            if (-not $S.hidden -and $S.state -ne 'act' -and $S.state -ne 'sleep' -and $t -ge $S.nextAct -and (Test-Game) -and $rand.Next(100) -lt 45) {
                [void](Start-Activity 'game')
            }
            if (-not $S.hidden -and $S.state -ne 'sleep' -and (Test-Alive) -and -not $Chat.busy -and $t - $S.lastComment -gt 1800 -and $rand.Next(100) -lt 40) {
                $al = Get-AppLine $info
                if ($al) {
                    $S.lastComment = $t
                    Say $al.text
                    if ($al.key -match 'spotify') { Set-State 'dance'; Set-Mood 'happy' 120 } else { Set-Mood 'happy' 40 }
                }
            }
        }
    }

    if (-not $S.drag) {
        $ground = $area.Bottom
        $maxX = $area.Right - $SW

        # acompanha a janela em que esta em cima
        if ($S.plat -ne [IntPtr]::Zero) {
            $r = New-Object 'Win+RECT'
            if (-not [Win]::Live($S.plat, [ref]$r) -or $r.Top -le $area.Top + 5) { Drop-Plat 'gone' }
            else {
                $dl = $r.Left - $S.platLeft; $dt = $r.Top - $S.platTop
                if ($dl -ne 0 -or $dt -ne 0) {
                    $S.sx += $dl; $S.platLeft = $r.Left; $S.platTop = $r.Top
                    if ([Math]::Abs($dl) + [Math]::Abs($dt) -gt 30 * $dpi -and $t - $S.lastWhee -gt 150) {
                        $S.lastWhee = $t; Set-Mood 'excited' 60; Say (Line 'janela_movendo')
                    }
                }
                $S.sy = $r.Top - $SH; $S.pr = $r
                $cx = $S.sx + $SW / 2
                if ($cx -lt $r.Left -or $cx -gt $r.Right) { Drop-Plat 'edge' }
            }
        }

        $foot = $S.sy + $SH
        $onPlat = $S.plat -ne [IntPtr]::Zero
        if ($S.vy -lt 0 -or (-not $onPlat -and $foot -lt $ground - 0.5)) {
            # no ar
            $S.vy = [Math]::Min($S.vy + $GRAV, 40 * $dpi)
            $nsy = $S.sy + $S.vy
            $S.sx += $S.vx; $S.vx *= 0.99
            if ($nsy -lt $area.Top) { $nsy = $area.Top; if ($S.vy -lt 0) { $S.vy = 0 } }
            $landed = $false
            if ($S.vy -gt 0) {
                $i = [Win]::FindLanding([int]($S.sx + $SW / 2), [int]$foot, [int]($nsy + $SH), $area.Top + 5)
                if ($i -ge 0) {
                    $rr = [Win]::Rects[$i]
                    $S.plat = [Win]::Handles[$i]; $S.platLeft = $rr.Left; $S.platTop = $rr.Top; $S.pr = $rr
                    $S.sy = $rr.Top - $SH; $landed = $true
                    Land $S.vy $true
                } elseif ($nsy + $SH -ge $ground) {
                    $S.sy = $ground - $SH; $landed = $true
                    Land $S.vy $false
                }
            }
            if (-not $landed) { $S.sy = $nsy }
        } else {
            if (-not $onPlat) { $S.sy = $ground - $SH }
            if ([Math]::Abs($S.vx) -gt 0.3) {
                $S.sx += $S.vx; $S.vx *= 0.85
                if ($onPlat -and $S.pr) { $c2 = $S.sx + $SW / 2; if ($c2 -lt $S.pr.Left -or $c2 -gt $S.pr.Right) { Drop-Plat 'edge' } }
            } else {
                $S.vx = 0
                Step-Behavior
            }
        }

        if ($S.sx -lt $area.Left) { $S.sx = $area.Left; $S.vx = -$S.vx * 0.5; $S.dir = 1 }
        if ($S.sx -gt $maxX) { $S.sx = $maxX; $S.vx = -$S.vx * 0.5; $S.dir = -1 }

        $nl = New-Object System.Drawing.Point ([int]($S.sx - $OX * $PX)), ([int]($S.sy - $OY * $PX))
        if ($form.Location -ne $nl) { $form.Location = $nl }
    }

    # para onde olhar
    if ($S.state -eq 'act' -and $null -ne $S.actLook) { $S.look = $S.actLook; $S.lookY = 0 }
    elseif (@('walk', 'run', 'seek', 'goto') -contains $S.state) { $S.look = $S.dir; $S.lookY = 0 }
    else {
        $cur = [System.Windows.Forms.Cursor]::Position
        $dx = $cur.X - ($S.sx + $SW / 2); $dy = $cur.Y - ($S.sy + $SH / 2)
        if ([Math]::Abs($dx) -lt 600 * $dpi -and [Math]::Abs($dy) -lt 500 * $dpi) {
            $S.look = $(if ([Math]::Abs($dx) -gt 25 * $dpi) { [Math]::Sign($dx) } else { 0 })
            $S.lookY = $(if ($dy -lt -60 * $dpi) { -1 } else { 0 })
        } else { $S.lookY = 0 }
    }

    # falas espontaneas
    if ($t -eq 40) {
        $h = (Get-Date).Hour
        $k = 'saudacao_noite'
        if ($h -lt 5) { $k = 'madrugada' } elseif ($h -lt 12) { $k = 'saudacao_manha' } elseif ($h -lt 18) { $k = 'saudacao_tarde' }
        Say (Line $k); Set-State 'wave'; Set-Mood 'happy' 60
    }
    # espiada espontanea na tela (a cada 20-40 min)
    if ($t -ge $S.nextPeek) {
        $S.nextPeek = $t + $rand.Next(40000, 80000)
        if ($CFG.espiar -and -not $S.hidden -and -not $Balloon.active -and -not $Chat.busy -and $S.state -ne 'sleep' -and (Test-Alive)) { Start-Peek }
    }
    if ($t -ge $S.nextChatter) {
        $S.nextChatter = $t + $rand.Next(3000, 7000)
        if (-not $Balloon.active -and -not $Chat.busy -and $S.state -ne 'sleep' -and (Test-Alive)) {
            $e = Get-Expr
            $k = 'aleatorio_neutro'
            if ($e -eq 'sad') { $k = @('triste', 'solitario')[$rand.Next(2)] }
            elseif ($e -eq 'sleepy') { $k = 'sono' }
            elseif ($e -eq 'happy' -or $e -eq 'love' -or $S.social -gt 70) { $k = 'aleatorio_feliz' }
            $h = (Get-Date).Hour
            if ($h -lt 5 -and $rand.Next(2) -eq 0) { $k = 'madrugada' }
            Say (Line $k)
        }
    }

    Step-Chat
    Step-Particles
    Step-Toys

    # balao
    if ($Balloon.active) {
        if ($Balloon.shown -lt $Balloon.text.Length) { $Balloon.shown += 2; $bub.Invalidate() }
        elseif (-not $Balloon.hold) { $Balloon.life--; if ($Balloon.life -le 0) { Hide-Bubble } }
        Update-Bubble
    }

    if ($t % 50 -eq 0) {
        [Win]::SetWindowPos($form.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null
        [Win]::SetWindowPos($bub.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null
    }
    $form.Invalidate()
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30
$timer.Add_Tick({
    try { Step-Tick }
    catch {
        if ($S.tick - $S.lastErr -gt 100) { $S.lastErr = $S.tick; Write-Log ($_.ToString() + ' @ ' + $_.InvocationInfo.PositionMessage) }
    }
})

$form.Add_Shown({
    Set-ToolWindow $form
    $bub.Show()
    Set-ToolWindow $bub
    Init-Toys
    $area = Get-Area
    $S.sx = $area.Left + $rand.Next([Math]::Max(1, $area.Width - $SW))
    $S.sy = $area.Top
    $timer.Start()
})

$form.Add_FormClosed({
    $timer.Stop()
    if ($Chat.busy) { try { $Chat.proc.Kill() } catch {} }
    [System.Windows.Forms.Application]::Exit()
})

[System.Windows.Forms.Application]::Run($form)
