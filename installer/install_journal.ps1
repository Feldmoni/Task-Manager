# יומן משימות אישי — התקנה כאפליקציית Edge (ללא הרשאות מנהל, ללא קבצי exe)
# -Silent : התקנה ללא תיבת דו-שיח בסוף (לבדיקות אוטומטיות)
param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
$ErrorActionPreference = 'Stop'
$APP = 'יומן משימות אישי'
$ID  = 'PersonalTaskJournal'

try {
  $edge = @("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            "C:\Program Files\Microsoft\Edge\Application\msedge.exe") |
          Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $edge) { throw 'Microsoft Edge לא נמצא במחשב.' }

  $srcRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
  $dir  = Join-Path $env:LOCALAPPDATA $ID
  $data = Join-Path $dir 'data'
  New-Item -ItemType Directory -Force $dir  | Out-Null
  New-Item -ItemType Directory -Force $data | Out-Null
  # index.html יושב בשורש הריפו (רמה אחת מעל installer/), או לצד הסקריפט בחבילה עצמאית
  $srcIndex = @((Join-Path $srcRoot 'index.html'),
                (Join-Path (Split-Path -Parent $srcRoot) 'index.html')) |
              Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $srcIndex) { throw 'index.html לא נמצא.' }
  Copy-Item $srcIndex $dir -Force
  Copy-Item (Join-Path $srcRoot 'icon.ico')   $dir -Force

  $indexUrl = 'file:///' + (($dir -replace '\\','/')) + '/index.html'
  $icon = Join-Path $dir 'icon.ico'
  $args = '--app="' + $indexUrl + '" --user-data-dir="' + $data + '"'

  $ws = New-Object -ComObject WScript.Shell
  # שני שמות: עברית (יומן) ואנגלית (Task-Manager) - כדי שחיפוש בתפריט Start ימצא בשתי השפות
  $lnkPaths = @()
  foreach ($n in @($APP, 'Task-Manager')) {
    $lnkPaths += Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$n.lnk"
    $lnkPaths += Join-Path ([Environment]::GetFolderPath('Desktop')) "$n.lnk"
  }
  foreach ($t in $lnkPaths) {
    $lnk = $ws.CreateShortcut($t)
    $lnk.TargetPath = $edge
    $lnk.Arguments = $args
    $lnk.IconLocation = "$icon,0"
    $lnk.WorkingDirectory = $dir
    $lnk.Description = $APP
    $lnk.Save()
  }

  # uninstaller
  $uninPath = Join-Path $dir 'uninstall.ps1'
  $removeLnks = ($lnkPaths | ForEach-Object {
    "Remove-Item -LiteralPath '$_' -Force -ErrorAction SilentlyContinue"
  }) -join "`r`n"
  $uninBody = @"
$removeLnks
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$ID' -Recurse -Force -ErrorAction SilentlyContinue
`$t = Join-Path `$env:TEMP 'ptj_un.ps1'
"Start-Sleep 1; Remove-Item -LiteralPath '$dir' -Recurse -Force -ErrorAction SilentlyContinue" | Out-File `$t -Encoding utf8
Start-Process powershell -ArgumentList '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',`$t
"@
  # חובה BOM: PowerShell 5.1 קורא קבצי ps1 כ-ANSI בלעדיו, והנתיבים בעברית נשברים
  [System.IO.File]::WriteAllText($uninPath, $uninBody, (New-Object System.Text.UTF8Encoding $true))

  $rk = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$ID"
  New-Item -Path $rk -Force | Out-Null
  Set-ItemProperty $rk 'DisplayName' $APP
  Set-ItemProperty $rk 'DisplayIcon' $icon
  Set-ItemProperty $rk 'DisplayVersion' '1.0.0'
  Set-ItemProperty $rk 'Publisher' 'Ilan Feldman'
  Set-ItemProperty $rk 'InstallLocation' $dir
  Set-ItemProperty $rk 'NoModify' 1
  Set-ItemProperty $rk 'NoRepair' 1
  Set-ItemProperty $rk 'UninstallString' ('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $uninPath + '"')

  if (-not $Silent -and ('System.Windows.Forms.MessageBox' -as [type])) {
    $r = [System.Windows.Forms.MessageBox]::Show("""$APP"" הותקן בהצלחה!`n`nנוצרו קיצורים בתפריט Start ובשולחן העבודה.`nלהפעיל עכשיו?", $APP, 'YesNo', 'Information')
    if ($r -eq 'Yes') { Start-Process $edge -ArgumentList $args }
  }
  Write-Output "INSTALLED_OK dir=$dir"
}
catch {
  Write-Output ("INSTALL_ERROR: " + $_.Exception.Message)
}
