$ErrorActionPreference = "Stop"

$appId = "afmcagbpgggkpdkokjhjkllpegnadmkignlonpjm"
$overwolfExe = $null
$launcherExe = $null
$extensionsRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Extensions\$appId"
$packagesRoot = Join-Path $env:LOCALAPPDATA "Overwolf\PackagesCache\$appId"
$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$localizerSource = Join-Path $PSScriptRoot "alecaframe-zh-cn.js"
$itemTranslationsSource = Join-Path $PSScriptRoot "alecaframe-zh-cn-items.js"
$targetPages = @(
    "main.html",
    "AFBuilds.html",
    "InGameNotification.html",
    "relicOverlay.html",
    "relicRecommendation.html",
    "rivenOverlay.html",
    "SquadMakingMain.html",
    "SquadMakingSquad.html",
    "tradeFinishedNotification.html"
)
$scriptTag = '<script src="assets/js/alecaframe-zh-cn.js"></script>'
$itemTranslationsScriptTag = '<script src="assets/js/alecaframe-zh-cn-items.js"></script>'

function Write-LauncherLog {
    param([string]$Message)
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $line = "$(Get-Date -Format o) $Message"
    Add-Content -LiteralPath (Join-Path $stateRoot "launcher.log") -Value $line -Encoding UTF8
}

function Find-OverwolfInstall {
    $candidateDirectories = New-Object System.Collections.Generic.List[string]

    $running = Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path } |
        Select-Object -First 1
    if ($running) {
        $candidateDirectories.Add((Split-Path -Parent $running.Path))
    }

    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            } |
            Where-Object {
                $_.DisplayName -eq "Overwolf" -and $_.InstallLocation
            } |
            ForEach-Object {
                $candidateDirectories.Add($_.InstallLocation.TrimEnd("\"))
            }
    }

    $candidateDirectories.Add((Join-Path $env:LOCALAPPDATA "Overwolf"))
    if (${env:ProgramFiles(x86)}) {
        $candidateDirectories.Add((Join-Path ${env:ProgramFiles(x86)} "Overwolf"))
    }
    if ($env:ProgramFiles) {
        $candidateDirectories.Add((Join-Path $env:ProgramFiles "Overwolf"))
    }
    $candidateDirectories.Add("G:\overwolf")

    foreach ($directory in $candidateDirectories | Select-Object -Unique) {
        $overwolf = Join-Path $directory "Overwolf.exe"
        $launcher = Join-Path $directory "OverwolfLauncher.exe"
        if ((Test-Path -LiteralPath $overwolf) -and
            (Test-Path -LiteralPath $launcher)) {
            return [pscustomobject]@{
                Overwolf = $overwolf
                Launcher = $launcher
            }
        }
    }
    throw "找不到 Overwolf 安装目录，请先安装或修复 Overwolf。"
}

function Get-LatestVersionDirectory {
    $directory = Get-ChildItem -LiteralPath $extensionsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $directory) {
        throw "没有找到 AlecaFrame 安装版本。"
    }
    return $directory
}

function Assert-AppPath {
    param([string]$Path)
    $resolvedRoot = [IO.Path]::GetFullPath($extensionsRoot).TrimEnd("\") + "\"
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "安全检查失败：路径不属于 AlecaFrame 扩展目录。"
    }
}

function Restore-OfficialFiles {
    param(
        [string]$Version,
        [string]$VersionPath
    )
    Assert-AppPath $VersionPath
    $opk = Join-Path $packagesRoot "$Version\app.opk"
    $backupRoot = Join-Path $stateRoot "OfficialBackup\$Version"
    $entries = @("_metadata/verified_contents.json")
    $entries += $targetPages | ForEach-Object { "web/$_" }

    $backupComplete = $true
    foreach ($entryName in $entries) {
        $backupFile = Join-Path $backupRoot ($entryName.Replace("/", "\"))
        if (-not (Test-Path -LiteralPath $backupFile)) {
            $backupComplete = $false
            break
        }
    }

    if (Test-Path -LiteralPath $opk) {
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($opk)
        try {
            foreach ($entryName in $entries) {
                $entry = $archive.GetEntry($entryName)
                if (-not $entry) {
                    throw "官方 OPK 中缺少文件：$entryName"
                }
                $target = Join-Path $VersionPath ($entryName.Replace("/", "\"))
                $targetParent = Split-Path -Parent $target
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
                $input = $entry.Open()
                $output = [IO.File]::Create($target)
                try {
                    $input.CopyTo($output)
                }
                finally {
                    $output.Dispose()
                    $input.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }

        foreach ($entryName in $entries) {
            $source = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            $backup = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
        Write-LauncherLog "Official files restored from OPK and backed up"
    }
    elseif ($backupComplete) {
        foreach ($entryName in $entries) {
            $source = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            $target = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        Write-LauncherLog "Official OPK unavailable; restored local official backup"
    }
    else {
        $extraLocalizer = Join-Path $VersionPath "web\assets\js\alecaframe-zh-cn.js"
        if (Test-Path -LiteralPath $extraLocalizer) {
            throw "官方 OPK 缓存和本地备份都不存在。请在 Overwolf 中重新安装 AlecaFrame 后再启动中文版。"
        }
        foreach ($entryName in $entries) {
            $source = Join-Path $VersionPath ($entryName.Replace("/", "\"))
            if (-not (Test-Path -LiteralPath $source)) {
                throw "AlecaFrame 官方文件不完整：$entryName。请重新安装 AlecaFrame。"
            }
            if ($entryName -like "web/*") {
                $content = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
                if ($content.Contains($scriptTag)) {
                    throw "检测到旧汉化文件，但没有可用的官方备份。请重新安装 AlecaFrame。"
                }
            }
            $backup = Join-Path $backupRoot ($entryName.Replace("/", "\"))
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) `
                -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
        Write-LauncherLog "Official OPK unavailable; created local official backup"
    }

    foreach ($extraScript in @("alecaframe-zh-cn.js", "alecaframe-zh-cn-items.js")) {
        $extraLocalizer = Join-Path $VersionPath "web\assets\js\$extraScript"
        if (Test-Path -LiteralPath $extraLocalizer) {
            Remove-Item -LiteralPath $extraLocalizer -Force
        }
    }
}

function Add-ChineseFiles {
    param([string]$VersionPath)
    Assert-AppPath $VersionPath
    $webRoot = Join-Path $VersionPath "web"
    foreach ($relativePage in $targetPages) {
        $target = Join-Path $webRoot $relativePage
        $content = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
        if (-not $content.Contains($scriptTag)) {
            if ($content -notmatch "(?i)</body>") {
                throw "页面缺少 </body>，无法注入：$relativePage"
            }
            $patched = [regex]::Replace(
                $content,
                "(?i)</body>",
                "    $itemTranslationsScriptTag`r`n    $scriptTag`r`n</body>",
                1
            )
            [IO.File]::WriteAllText($target, $patched, [Text.UTF8Encoding]::new($false))
        }
    }
    Copy-Item -LiteralPath $localizerSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn.js") `
        -Force
    Copy-Item -LiteralPath $itemTranslationsSource `
        -Destination (Join-Path $webRoot "assets\js\alecaframe-zh-cn-items.js") `
        -Force
}

function Get-AlecaFrameRenderer {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "OverwolfBrowser.exe" -and
            $_.CommandLine -match "AlecaFrame"
        } |
        Select-Object -First 1
}

function Wait-OverwolfExtensionReady {
    param([datetime]$StartedAt)

    $traceRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Log"
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        Start-Sleep -Milliseconds 500
        $trace = Get-ChildItem -LiteralPath $traceRoot -Filter "Trace_*.log" -File `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($trace) {
            $tail = Get-Content -LiteralPath $trace.FullName -Tail 500 `
                -ErrorAction SilentlyContinue
            if ($tail -match "Loading extension '$appId") {
                Start-Sleep -Seconds 2
                return
            }
        }
    }
    throw "Overwolf 启动超时，未能加载 AlecaFrame 扩展。"
}

function Start-AlecaFrameAndWait {
    param([int]$TimeoutSeconds = 60)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $nextLaunch = Get-Date
    do {
        if ((Get-Date) -ge $nextLaunch) {
            Start-Process -FilePath $launcherExe `
                -ArgumentList "-launchapp", $appId, "-from-desktop"
            $nextLaunch = (Get-Date).AddSeconds(3)
        }
        Start-Sleep -Milliseconds 500
        $renderer = Get-AlecaFrameRenderer
        if ($renderer) {
            return $renderer
        }
    } while ((Get-Date) -lt $deadline)

    throw "AlecaFrame 启动超时。"
}

try {
    $overwolfInstall = Find-OverwolfInstall
    $overwolfExe = $overwolfInstall.Overwolf
    $launcherExe = $overwolfInstall.Launcher
    if (-not (Test-Path -LiteralPath $overwolfExe)) {
        throw "找不到 Overwolf：$overwolfExe"
    }
    if (-not (Test-Path -LiteralPath $launcherExe)) {
        throw "找不到 OverwolfLauncher：$launcherExe"
    }
    if (-not (Test-Path -LiteralPath $localizerSource)) {
        throw "缺少汉化词库：$localizerSource"
    }
    if (-not (Test-Path -LiteralPath $itemTranslationsSource)) {
        throw "缺少物品汉化词库：$itemTranslationsSource"
    }

    $versionDirectory = Get-LatestVersionDirectory
    Write-LauncherLog "Starting AlecaFrame ZH for $($versionDirectory.Name)"

    Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue | Stop-Process
    Start-Sleep -Seconds 4
    Restore-OfficialFiles -Version $versionDirectory.Name -VersionPath $versionDirectory.FullName

    $overwolfStartedAt = Get-Date
    Start-Process -FilePath $overwolfExe `
        -ArgumentList "--ow-disable-features=extension-validation,read-opk-from-memory"
    Wait-OverwolfExtensionReady -StartedAt $overwolfStartedAt

    # First launch uses untouched official files so Overwolf can complete its normal
    # integrity check and initialize AlecaFrame.
    $originalRenderer = Start-AlecaFrameAndWait -TimeoutSeconds 60
    Start-Sleep -Seconds 4

    Add-ChineseFiles -VersionPath $versionDirectory.FullName
    $patchTime = Get-Date

    # Reload only AlecaFrame's renderer so the rest of Overwolf remains running.
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "OverwolfBrowser.exe" -and
            $_.CommandLine -match "AlecaFrame"
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        }
    Start-Sleep -Seconds 3

    $null = Start-AlecaFrameAndWait -TimeoutSeconds 60

    $loaded = $false
    $mainLog = Join-Path $env:LOCALAPPDATA "Overwolf\Log\Apps\AlecaFrame\MainWindow.html.log"
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $mainLog) {
            $logItem = Get-Item -LiteralPath $mainLog
            if ($logItem.LastWriteTime -ge $patchTime.AddSeconds(-2)) {
                $tail = Get-Content -LiteralPath $mainLog -Tail 40 -ErrorAction SilentlyContinue
                if ($tail -match "\[AlecaFrame 中文补丁\] 已加载") {
                    $loaded = $true
                    break
                }
            }
        }
    }
    if (-not $loaded) {
        throw "中文脚本未能加载，请查看 $stateRoot\launcher.log"
    }

    Write-LauncherLog "Chinese UI loaded successfully"
}
catch {
    Write-LauncherLog "ERROR: $($_.Exception.Message)"
    try {
        Get-Process -Name "Overwolf" -ErrorAction SilentlyContinue | Stop-Process
        Start-Sleep -Seconds 3
        if ($versionDirectory) {
            Restore-OfficialFiles -Version $versionDirectory.Name -VersionPath $versionDirectory.FullName
        }
    }
    catch {
        Write-LauncherLog "RESTORE ERROR: $($_.Exception.Message)"
    }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "AlecaFrame 中文启动失败",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
