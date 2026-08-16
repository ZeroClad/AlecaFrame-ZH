$ErrorActionPreference = "Stop"

$appId = "afmcagbpgggkpdkokjhjkllpegnadmkignlonpjm"
$version = "2.6.90"
$extensionRoot = Join-Path $env:LOCALAPPDATA "Overwolf\Extensions\$appId\$version"
$dllPath = Join-Path $extensionRoot "NET\AlecaFrameClientLib.dll"
$stateRoot = Join-Path $env:LOCALAPPDATA "AlecaFrame-ZH-Patch"
$backupPath = Join-Path $stateRoot "NativeDllBackup\$version\AlecaFrameClientLib.dll"
$launcherScript = Join-Path $PSScriptRoot "Start-AlecaFrame-ZH.ps1"
$logPath = Join-Path $stateRoot "launcher.log"

function Restore-NativeDll {
    if (Test-Path -LiteralPath $backupPath) {
        Copy-Item -LiteralPath $backupPath -Destination $dllPath -Force
    }
}

function Stop-OverwolfProcesses {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like "Overwolf*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
}

if (-not (Test-Path -LiteralPath $dllPath)) {
    throw "找不到 AlecaFrame 原生模块：$dllPath"
}
if (-not (Test-Path -LiteralPath $launcherScript)) {
    throw "找不到启动脚本：$launcherScript"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
Copy-Item -LiteralPath $dllPath -Destination $backupPath -Force

$mutated = $false
try {
    Stop-OverwolfProcesses

    # The PE COFF timestamp is ignored by the CLR loader. Changing one bit tests
    # binary integrity handling without loading or modifying executable code.
    $bytes = [IO.File]::ReadAllBytes($dllPath)
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    $offset = $peOffset + 8
    if ($peOffset -lt 0x40 -or $offset -ge $bytes.Length) {
        throw "不是有效的 PE 程序集，未修改 DLL。"
    }

    $bytes[$offset] = $bytes[$offset] -bxor 0x01
    [IO.File]::WriteAllBytes($dllPath, $bytes)
    $mutated = $true

    & $launcherScript
    if ($LASTEXITCODE -ne 0) {
        throw "AlecaFrame 启动脚本返回失败代码：$LASTEXITCODE"
    }

    $latestLog = Get-Content -LiteralPath $logPath -Tail 20 -ErrorAction Stop
    if (-not ($latestLog -match "Chinese UI loaded successfully")) {
        throw "未检测到 AlecaFrame 成功加载记录。"
    }

    Write-Output "NATIVE_DLL_MUTATION_LAUNCH_SUCCEEDED"
}
finally {
    if ($mutated) {
        Stop-OverwolfProcesses
        Restore-NativeDll
        & $launcherScript
    }
}
