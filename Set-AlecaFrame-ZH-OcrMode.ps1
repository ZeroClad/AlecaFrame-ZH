[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [bool]$Enabled
)

$ErrorActionPreference = "Stop"
$settingsPath = Join-Path $PSScriptRoot "AlecaFrame-ZH.settings.json"
$settings = [ordered]@{
    relicOcr = [ordered]@{
        enabled = $Enabled
    }
}

$settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
$state = if ($Enabled) { "启用" } else { "关闭" }
Write-Host "中文遗物 OCR 已$state。下次通过 AlecaFrame-ZH 启动时生效。" -ForegroundColor Green
