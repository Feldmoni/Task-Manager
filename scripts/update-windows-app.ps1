# עדכון אפליקציית Windows "יומן משימות אישי" לגרסה האחרונה מהריפו
# מריצים מתוך תיקיית הפרויקט:
#   powershell -ExecutionPolicy Bypass -File .\scripts\update-windows-app.ps1
#
# הסקריפט מחליף רק את index.html. תיקיית data (שבה שמורות המשימות) לא נגעת.

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$source   = Join-Path $repoRoot 'index.html'
$appDir   = Join-Path $env:LOCALAPPDATA 'PersonalTaskJournal'
$target   = Join-Path $appDir 'index.html'

Write-Host ''
Write-Host '=== עדכון יומן משימות אישי ===' -ForegroundColor Cyan

# 1. משיכת הגרסה האחרונה מ-GitHub
Write-Host ''
Write-Host '[1/3] מושך עדכונים מ-GitHub...' -ForegroundColor Yellow
try {
    git -C $repoRoot pull --ff-only
} catch {
    Write-Host '  ! git pull נכשל - ממשיך עם הקובץ המקומי' -ForegroundColor DarkYellow
}

# 2. בדיקות
Write-Host ''
Write-Host '[2/3] בודק קבצים...' -ForegroundColor Yellow

if (-not (Test-Path $source)) {
    Write-Host "  ! לא נמצא: $source" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $appDir)) {
    Write-Host "  ! האפליקציה אינה מותקנת ($appDir)" -ForegroundColor Red
    Write-Host '    יש להריץ קודם את "התקן.bat" מתיקיית ההתקנה.' -ForegroundColor Red
    exit 1
}

# אזהרה אם האפליקציה פתוחה - Edge עלול להחזיק את הקובץ
$running = @(Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -like '*PersonalTaskJournal*' })
if ($running) {
    Write-Host '  ! האפליקציה פתוחה - מומלץ לסגור אותה לפני העדכון.' -ForegroundColor DarkYellow
}

# 3. גיבוי הגרסה הקודמת והחלפה
Write-Host ''
Write-Host '[3/3] מעדכן...' -ForegroundColor Yellow

if (Test-Path $target) {
    $backup = Join-Path $appDir 'index.previous.html'
    Copy-Item $target $backup -Force
    Write-Host "  גיבוי הגרסה הקודמת: $backup" -ForegroundColor DarkGray
}

Copy-Item $source $target -Force

$size = (Get-Item $target).Length
Write-Host ''
Write-Host "  ✔ עודכן בהצלחה ($size bytes)" -ForegroundColor Green
Write-Host "    $target" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  המשימות השמורות לא הושפעו.' -ForegroundColor Green
Write-Host '  יש לסגור ולפתוח מחדש את האפליקציה כדי לראות את השינויים.' -ForegroundColor Cyan
Write-Host ''
