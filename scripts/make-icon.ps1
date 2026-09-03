# יצירת אייקון האפליקציה: וי לבן על ריבוע כחול מעוגל.
#
# עיצוב פשוט בכוונה - אייקון נקרא בעיקר בגודל 16px בשורת המשימות
# ובגודל 48px בשולחן העבודה, ושם פרטים קטנים נעלמים ממילא.
#
# מבנה הקובץ: הגדלים הקטנים נשמרים כ-DIB (BMP) כי .NET לא קורא
# פריימים דחוסי-PNG, והגודל 256 נשמר כ-PNG כדי לא לנפח את הקובץ
# (256x256 כ-DIB לבדו שוקל 270KB).
#
# הרצה:  powershell -ExecutionPolicy Bypass -File scripts\make-icon.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repo = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $repo 'installer\app-icon.ico'

$BG   = [System.Drawing.ColorTranslator]::FromHtml('#1f4e78')  # כחול האפליקציה
$FG   = [System.Drawing.Color]::White

function New-Frame([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.Clear([System.Drawing.Color]::Transparent)

    # ריבוע מעוגל במילוי מלא
    $m = [Math]::Max(1, [int]($s * 0.06))          # שוליים
    $r = [Math]::Max(2, [int]($s * 0.22))          # רדיוס פינה
    $x = $m; $y = $m; $w = $s - 2*$m; $h = $s - 2*$m
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($x,           $y,            $r*2, $r*2, 180, 90)
    $path.AddArc($x+$w-$r*2,   $y,            $r*2, $r*2, 270, 90)
    $path.AddArc($x+$w-$r*2,   $y+$h-$r*2,    $r*2, $r*2,   0, 90)
    $path.AddArc($x,           $y+$h-$r*2,    $r*2, $r*2,  90, 90)
    $path.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush($BG)
    $g.FillPath($brush, $path)

    # סימן וי
    $pen = New-Object System.Drawing.Pen($FG, [float]([Math]::Max(1.6, $s * 0.11)))
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $p1 = New-Object System.Drawing.PointF([float]($s*0.28), [float]($s*0.52))
    $p2 = New-Object System.Drawing.PointF([float]($s*0.44), [float]($s*0.68))
    $p3 = New-Object System.Drawing.PointF([float]($s*0.73), [float]($s*0.34))
    $g.DrawLines($pen, @($p1, $p2, $p3))

    $pen.Dispose(); $brush.Dispose(); $path.Dispose(); $g.Dispose()
    return $bmp
}

# ── המרת bitmap ל-DIB בפורמט שקובץ ico מצפה לו ──────────────────────────
function ConvertTo-Dib([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    # BITMAPINFOHEADER - הגובה כפול: תמונה + מסכת AND
    $bw.Write([uint32]40); $bw.Write([int32]$w); $bw.Write([int32]($h*2))
    $bw.Write([uint16]1);  $bw.Write([uint16]32); $bw.Write([uint32]0)
    $bw.Write([uint32]($w*$h*4)); $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write([uint32]0); $bw.Write([uint32]0)
    # פיקסלים BGRA, שורות מלמטה למעלה
    for ($y = $h-1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
        }
    }
    # מסכת AND - אפסים; שקיפות מגיעה מערוץ האלפא
    $rowBytes = [int][Math]::Floor(($w + 31) / 32) * 4
    $bw.Write((New-Object byte[] ($rowBytes * $h)))
    $bw.Flush()
    $bytes = $ms.ToArray(); $bw.Dispose(); $ms.Dispose()
    return $bytes
}

function ConvertTo-Png([System.Drawing.Bitmap]$bmp) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray(); $ms.Dispose()
    return $bytes
}

# ── הרכבת קובץ ה-ico ─────────────────────────────────────────────────────
$sizes  = @(16, 32, 48, 64, 256)
$frames = @()
foreach ($s in $sizes) {
    $bmp = New-Frame $s
    $data = if ($s -ge 256) { ConvertTo-Png $bmp } else { ConvertTo-Dib $bmp }
    $frames += ,@{ Size = $s; Data = $data; Bmp = $bmp }
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($f in $frames) {
    $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$f.Data.Length); $bw.Write([uint32]$offset)
    $offset += $f.Data.Length
}
# חובה לציין את העומס-יתר במפורש: בלי אינדקס ואורך PowerShell
# בוחר את Write(byte) וכותב בייט בודד במקום את כל המערך
foreach ($f in $frames) { $d = [byte[]]$f.Data; $bw.Write($d, 0, $d.Length) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($out, $ms.ToArray())
$bw.Dispose(); $ms.Dispose()

# תצוגות מקדימות לבדיקה ויזואלית
$prev = Join-Path $env:TEMP 'claude\icon-preview'
New-Item -ItemType Directory -Force $prev | Out-Null
foreach ($f in $frames) {
    $f.Bmp.Save((Join-Path $prev ("icon-{0}.png" -f $f.Size)), [System.Drawing.Imaging.ImageFormat]::Png)
    $f.Bmp.Dispose()
}

Write-Host ""
Write-Host "  נבנה: $out  ($([Math]::Round((Get-Item $out).Length/1KB,1)) KB)" -ForegroundColor Green
foreach ($f in $frames) { Write-Host ("    {0,3}x{1,-3} {2,7} bytes  {3}" -f $f.Size, $f.Size, $f.Data.Length, $(if($f.Size -ge 256){'PNG'}else{'DIB'})) -ForegroundColor Gray }
Write-Host "  תצוגות: $prev" -ForegroundColor Gray
Write-Host ""
