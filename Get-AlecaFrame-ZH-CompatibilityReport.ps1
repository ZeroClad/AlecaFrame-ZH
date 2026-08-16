[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch\CompatibilityReports"),
    [int]$AuditTailLines = 160
)

$ErrorActionPreference = "Stop"

function Get-FileTail {
    param([string]$Path, [int]$Lines)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Get-Content -LiteralPath $Path -Tail $Lines -ErrorAction SilentlyContinue |
        ForEach-Object {
            $line = [string]$_
            if ($line.Length -gt 1200) { $line.Substring(0, 1200) + " [truncated]" } else { $line }
        })
}

function Get-WindowBounds {
    param([string]$ProcessName)
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
    if (-not $process) { return $null }
    return [ordered]@{
        ProcessId = $process.Id
        Title = $process.MainWindowTitle
        Left = $process.MainWindowPosition.X
        Top = $process.MainWindowPosition.Y
        Width = $process.MainWindowSize.Width
        Height = $process.MainWindowSize.Height
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$ocrRoot = Join-Path $stateRoot "RelicChineseOcr"
$auditPath = Join-Path $ocrRoot "bridge-audit.log"
$launcherLogPath = Join-Path $stateRoot "launcher.log"
$latestRewardPath = Join-Path $ocrRoot "latest-reward.json"
$healthUri = "http://127.0.0.1:38147/health"
$now = Get-Date

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$health = [ordered]@{ Reachable = $false; Ready = $false; Error = $null }
try {
    $response = Invoke-RestMethod -Uri $healthUri -TimeoutSec 2 -ErrorAction Stop
    $health.Reachable = $true
    $health.Ready = [bool]$response.ready
    $health.Response = $response
}
catch {
    $health.Error = $_.Exception.Message
}

$screens = @([Windows.Forms.Screen]::AllScreens | ForEach-Object {
    [ordered]@{
        DeviceName = $_.DeviceName
        Primary = $_.Primary
        Bounds = [ordered]@{ Left = $_.Bounds.Left; Top = $_.Bounds.Top; Width = $_.Bounds.Width; Height = $_.Bounds.Height }
        WorkingArea = [ordered]@{ Left = $_.WorkingArea.Left; Top = $_.WorkingArea.Top; Width = $_.WorkingArea.Width; Height = $_.WorkingArea.Height }
    }
})

$warframe = @(Get-Process -Name "Warframe.x64","Warframe" -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{
        ProcessId = $_.Id
        Responding = $_.Responding
        MainWindowTitle = $_.MainWindowTitle
        MainWindowHandle = [int64]$_.MainWindowHandle
        WorkingSetMiB = [Math]::Round($_.WorkingSet64 / 1MB, 1)
        CPUSeconds = [Math]::Round($_.CPU, 1)
    }
})

$overwolfBrowsers = @(Get-Process -Name "OverwolfBrowser" -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{
        ProcessId = $_.Id
        Responding = $_.Responding
        MainWindowTitle = $_.MainWindowTitle
        WorkingSetMiB = [Math]::Round($_.WorkingSet64 / 1MB, 1)
        CPUSeconds = [Math]::Round($_.CPU, 1)
    }
})

$graphics = [Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
try {
    $dpi = [ordered]@{ GraphicsDpiX = [Math]::Round($graphics.DpiX, 2); GraphicsDpiY = [Math]::Round($graphics.DpiY, 2) }
}
finally {
    $graphics.Dispose()
}

$latestReward = $null
if (Test-Path -LiteralPath $latestRewardPath) {
    try { $latestReward = Get-Content -LiteralPath $latestRewardPath -Raw | ConvertFrom-Json }
    catch { $latestReward = [ordered]@{ ReadError = $_.Exception.Message } }
}

$report = [ordered]@{
    SchemaVersion = 1
    GeneratedAt = $now.ToString("o")
    Purpose = "AlecaFrame-ZH compatibility diagnosis. This report does not capture the screen, run OCR, or change overlay behavior."
    System = [ordered]@{
        WindowsVersion = [System.Environment]::OSVersion.VersionString
        Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
        Culture = [Globalization.CultureInfo]::CurrentCulture.Name
        UICulture = [Globalization.CultureInfo]::CurrentUICulture.Name
    }
    Displays = $screens
    WindowsDpi = $dpi
    Game = [ordered]@{
        Processes = $warframe
        MainWindow = Get-WindowBounds -ProcessName "Warframe.x64"
    }
    AlecaFrame = [ordered]@{
        OcrHealth = $health
        OverwolfBrowserProcesses = $overwolfBrowsers
        OcrAuditPath = $auditPath
        LatestRewardPath = $latestRewardPath
        LatestReward = $latestReward
    }
    RecentOcrAudit = Get-FileTail -Path $auditPath -Lines $AuditTailLines
    RecentLauncherLog = Get-FileTail -Path $launcherLogPath -Lines 80
    FeedbackChecklist = @(
        "请附上此 JSON 报告和问题发生时的完整游戏截图。",
        "说明 Warframe 的显示模式、游戏分辨率、HUD 缩放、是否为 HDR、是否使用超宽屏。",
        "说明问题属于：遗物选择推荐叠加层、开启后奖励选择叠加层，或两者之一。",
        "说明叠加层是否出现、出现时间、识别结果，以及发生问题时剩余倒计时。"
    )
}

$timestamp = $now.ToString("yyyyMMdd-HHmmss")
$jsonPath = Join-Path $OutputDirectory "AlecaFrame-ZH-Compatibility-$timestamp.json"
$textPath = Join-Path $OutputDirectory "AlecaFrame-ZH-Compatibility-$timestamp.txt"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$summary = @(
    "AlecaFrame-ZH compatibility report",
    "Generated: $($report.GeneratedAt)",
    "OCR service: reachable=$($health.Reachable), ready=$($health.Ready)",
    "Displays: " + (($screens | ForEach-Object { "$($_.DeviceName) $($_.Bounds.Width)x$($_.Bounds.Height) primary=$($_.Primary)" }) -join "; "),
    "Warframe processes: $($warframe.Count)",
    "OverwolfBrowser processes: $($overwolfBrowsers.Count)",
    "JSON report: $jsonPath",
    "",
    "Send the JSON report together with a full game screenshot and the feedback checklist inside the JSON file."
)
$summary | Set-Content -LiteralPath $textPath -Encoding UTF8

Write-Host "诊断报告已生成：$jsonPath"
Write-Host "摘要：$textPath"
