$ErrorActionPreference = "Stop"

$startScript = Join-Path $PSScriptRoot "Start-AlecaFrame-ZH.ps1"
if (-not (Test-Path -LiteralPath $startScript)) {
    throw "缺少中文启动脚本：$startScript"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "AlecaFrame-ZH.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startScript`""
$shortcut.WorkingDirectory = $PSScriptRoot
$extensionsRoot = Join-Path $env:LOCALAPPDATA `
    "Overwolf\Extensions\afmcagbpgggkpdkokjhjkllpegnadmkignlonpjm"
$latestVersion = Get-ChildItem -LiteralPath $extensionsRoot -Directory `
    -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") } |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
$icon = if ($latestVersion) {
    Join-Path $latestVersion.FullName "icon.ico"
}
else {
    ""
}
if (Test-Path -LiteralPath $icon) {
    $shortcut.IconLocation = "$icon,0"
}
$shortcut.Description = "启动 AlecaFrame 简体中文版"
$shortcut.Save()

Write-Host ""
if (-not (Test-Path -LiteralPath $shortcutPath)) {
    throw "桌面快捷方式创建失败：$shortcutPath"
}
Write-Host "桌面快捷方式已创建：AlecaFrame-ZH（中文版）" -ForegroundColor Green
Write-Host "双击它即可启动中文版。原 AlecaFrame 快捷方式保持不变。"
