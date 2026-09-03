# בניית קובץ התקנה יחיד ועצמאי ל-Windows.
#
# אורז את index.html, app-icon.ico ו-install_journal.ps1 לתוך קובץ .bat אחד,
# כשכל אחד מהם מקודד ב-Base64 ומוטמע בסוף הקובץ.
#
# למה Base64 ולא טקסט רגיל: קבצי .bat נקראים ע"י cmd.exe בקידוד ה-OEM של
# המחשב (862 / 437 / 1255 - תלוי מכונה). טקסט בעברית היה נשבר במחשב אחר.
# Base64 הוא ASCII טהור ולכן חסין לחלוטין לקידוד.
#
# הרצה:  powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $repo 'dist\Task-Manager-Setup.bat'

# מה נארז: מזהה בקובץ -> שם הקובץ אחרי החילוץ -> מקור
$payloads = @(
    @{ Id = 'INDEX'; Name = 'index.html';          Path = Join-Path $repo 'index.html' },
    @{ Id = 'ICON';  Name = 'app-icon.ico';            Path = Join-Path $repo 'installer\app-icon.ico' },
    @{ Id = 'SETUP'; Name = 'install_journal.ps1'; Path = Join-Path $repo 'installer\install_journal.ps1' }
)

foreach ($p in $payloads) {
    if (-not (Test-Path $p.Path)) { throw ("חסר קובץ מקור: " + $p.Path) }
}

# ── ה-bootstrap ──────────────────────────────────────────────────────────
# חייב להיות ASCII טהור: הוא נקרא ע"י cmd.exe לפני שיש לנו שליטה על הקידוד.
# הטקסט בעברית יושב כולו בתוך install_journal.ps1 המוטמע, ולכן מוגן.
$bootstrap = @'
@echo off
setlocal
title Task-Manager Setup
set "SILENT="
if /i "%~1"=="/silent" set "SILENT=-Silent"
echo.
echo   ============================================
echo     Task-Manager  /  Personal Task Journal
echo   ============================================
echo.
echo   Installing...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { $L=[IO.File]::ReadAllLines('%~f0'); $d=Join-Path $env:TEMP 'TaskManagerSetup'; if(Test-Path $d){Remove-Item -LiteralPath $d -Recurse -Force}; New-Item -ItemType Directory -Force $d|Out-Null; foreach($p in @(@('INDEX','index.html'),@('ICON','app-icon.ico'),@('SETUP','install_journal.ps1'))){ $s=[Array]::IndexOf($L,(':::BEGIN:'+$p[0]+':::')); $e=[Array]::IndexOf($L,(':::END:'+$p[0]+':::')); if($s -lt 0 -or $e -le $s){throw ('payload missing: '+$p[0])}; $b64=-join $L[($s+1)..($e-1)]; [IO.File]::WriteAllBytes((Join-Path $d $p[1]),[Convert]::FromBase64String($b64)) }; & (Join-Path $d 'install_journal.ps1') %SILENT%; Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } catch { Write-Host ('SETUP ERROR: '+$_.Exception.Message) -ForegroundColor Red }"
echo.
if not defined SILENT pause
exit /b
'@

# ── הרכבת הקובץ ─────────────────────────────────────────────────────────
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append(($bootstrap -replace "`r?`n", "`r`n"))
[void]$sb.Append("`r`n")

foreach ($p in $payloads) {
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p.Path))
    [void]$sb.Append(":::BEGIN:$($p.Id):::`r`n")
    for ($i = 0; $i -lt $b64.Length; $i += 240) {
        [void]$sb.Append($b64.Substring($i, [Math]::Min(240, $b64.Length - $i)))
        [void]$sb.Append("`r`n")
    }
    [void]$sb.Append(":::END:$($p.Id):::`r`n")
}

New-Item -ItemType Directory -Force (Split-Path -Parent $out) | Out-Null
# ASCII ובלי BOM: BOM בתחילת קובץ bat גורם ל-cmd לשגיאה על השורה הראשונה
[IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.ASCIIEncoding))

$kb = [Math]::Round((Get-Item $out).Length / 1KB, 1)
Write-Host ""
Write-Host "  נבנה: $out" -ForegroundColor Green
Write-Host "  גודל: $kb KB" -ForegroundColor Gray
foreach ($p in $payloads) {
    Write-Host ("    - {0,-22} {1,7} bytes" -f $p.Name, (Get-Item $p.Path).Length) -ForegroundColor Gray
}
Write-Host ""
